#!/bin/bash
# 方案B：直接部署到 Ubuntu VM（无 Docker）
# 用法：bash deploy.sh
set -e

APP_DIR="/opt/jobtrack"
SERVICE_NAME="jobtrack"
PYTHON="python3"

echo "=== JobTrack 直接部署脚本 ==="

# ── 1. 系统依赖 ──────────────────────────────────────
echo ">>> [1/7] 安装系统依赖..."
sudo apt-get update -q
sudo apt-get install -y -q \
  python3 python3-pip python3-venv \
  postgresql postgresql-contrib \
  nginx curl ufw

# ── 2. 防火墙 ────────────────────────────────────────
echo ">>> [2/7] 配置防火墙..."
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
sudo ufw --force enable
echo "    防火墙已开放 22/80/8000 端口"

# ── 3. 配置 PostgreSQL ───────────────────────────────
echo ">>> [3/7] 配置 PostgreSQL..."

# 从 .env 读取数据库配置
if [ ! -f .env ]; then
  echo "错误：未找到 .env，请先执行：cp .env.example .env && nano .env"
  exit 1
fi
source .env

sudo systemctl enable --now postgresql

# 创建数据库用户和库（幂等）
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

# 初始化表结构
sudo -u postgres psql -d "${DB_NAME}" -f schema.sql
echo "    数据库初始化完成"

# ── 4. 部署应用文件 ──────────────────────────────────
echo ">>> [4/7] 部署应用文件..."
sudo mkdir -p "${APP_DIR}/logs"
sudo cp db_api.py schema.sql "${APP_DIR}/"
sudo cp .env "${APP_DIR}/.env"
sudo chown -R www-data:www-data "${APP_DIR}"

# Python 虚拟环境
if [ ! -d "${APP_DIR}/venv" ]; then
  sudo -u www-data $PYTHON -m venv "${APP_DIR}/venv"
fi
sudo -u www-data "${APP_DIR}/venv/bin/pip" install --quiet --upgrade pip
sudo -u www-data "${APP_DIR}/venv/bin/pip" install --quiet -r requirements.txt
echo "    依赖安装完成"

# ── 4. 配置 systemd 服务 ─────────────────────────────
echo ">>> [5/7] 配置 systemd 服务..."
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=JobTrack API
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=www-data
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=${APP_DIR}/venv/bin/uvicorn db_api:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5
StandardOutput=append:${APP_DIR}/logs/app.log
StandardError=append:${APP_DIR}/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ${SERVICE_NAME}
echo "    服务已启动"

# ── 5. 配置 Nginx ────────────────────────────────────
echo ">>> [6/7] 配置 Nginx..."
sudo cp job-agent.html /var/www/html/index.html
sudo cp backup.sh "${APP_DIR}/backup.sh"
sudo chmod +x "${APP_DIR}/backup.sh"

sudo tee /etc/nginx/sites-available/${SERVICE_NAME} > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    client_max_body_size 10M;
    gzip on;
    gzip_types text/html text/css application/javascript;
}
EOF

sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

# 备份 cron（每天 03:00 执行，保留 7 天；引用 APP_DIR 稳定路径）
BACKUP_CRON="0 3 * * * bash ${APP_DIR}/backup.sh >> ${APP_DIR}/logs/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v "backup.sh"; echo "$BACKUP_CRON") | crontab -
echo "    Nginx 配置完成，备份 cron 已设置（每天 03:00）"

# ── 7. 完成 ─────────────────────────────────────────
echo ">>> [7/7] 验证服务..."
sleep 2
if curl -sf http://127.0.0.1:8000/health > /dev/null; then
  echo "    API 健康检查通过"
else
  echo "    警告：API 未响应，请检查日志：journalctl -u ${SERVICE_NAME} -n 50"
fi

echo ""
echo "=== 部署完成 ==="
VM_IP=$(hostname -I | awk '{print $1}')
echo "前端:  http://${VM_IP}"
echo "后端:  http://${VM_IP}:8000/health"
echo ""
echo "常用命令："
echo "  查看 API 日志:  sudo journalctl -u ${SERVICE_NAME} -f"
echo "  重启 API:       sudo systemctl restart ${SERVICE_NAME}"
echo "  更新代码:       bash deploy.sh"
