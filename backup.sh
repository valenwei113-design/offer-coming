#!/bin/bash
BACKUP_DIR="$(dirname "$0")/backups"
DATE=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/jobsdb_$DATE.sql.gz"

mkdir -p "$BACKUP_DIR"

# 从 .env 读取数据库配置
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-jobsdb}"

PGPASSWORD="$DB_PASSWORD" pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" | gzip > "$FILE"

# 只保留最近 7 天的备份
find "$BACKUP_DIR" -name "jobsdb_*.sql.gz" -mtime +7 -delete

echo "[$(date)] Backup saved: $FILE ($(du -sh $FILE | cut -f1))"
