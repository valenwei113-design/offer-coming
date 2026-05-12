# Offer Coming

> 🌐 [中文](#中文) | [English](#english)

---

<a name="中文"></a>
# 中文

## 一、项目概述

**项目名称**：Offer Coming

**项目定位**：面向求职者的 AI 全流程辅助工具，支持多用户，可小范围商用

**核心功能**：
- **科技资讯**：登录后首屏，显示投递统计 + 聚合 AI 科技资讯（Anthropic / The Verge AI / Hacker News RSS）
- **投递记录**：在线新增、编辑、删除申请记录；图片/截图 AI 自动识别填写；搜索、排序、分页；AI 对话查询数据
- **简历优化**：上传简历（PDF / Word / 图片）+ JD（PDF / TXT / Word / 图片），AI 匹配分析（含评分）；一键生成针对性简历；AI 对话精调简历；导出 Word / PDF
- **宇宙力量**：选择一条申请记录，点击信封，AI 以宇宙视角生成哲学风格来信
- **管理员后台**：用户管理、邀请码管理、反馈查看、数据概览
- **双语支持**：中文 / English 一键切换

---

## 二、技术栈

| 层级 | 技术 |
|------|------|
| 大模型（对话 / 数据查询 / 宇宙来信） | DeepSeek V4 Pro（via API） |
| 大模型（简历分析 / 生成） | DeepSeek V4 Pro（via API） |
| 大模型（视觉简历优化 / 图片解析） | Qwen VL Max / Plus（via 阿里云百炼） |
| 后端 | Python FastAPI + uvicorn |
| 数据库 | PostgreSQL |
| 前端 | 纯 HTML + Chart.js |
| 文档导出 | python-docx（Word）、fpdf2（PDF） |
| 版本管理 | GitHub |

---

## 三、系统架构

```
用户浏览器
    │
    ├── 科技资讯（Tab: home）
    │       ├── 前端直接统计 allApps 数据，无额外请求
    │       └── GET /rss-proxy?url=...  →  透传 RSS 源（Anthropic / The Verge / HN）
    │
    ├── 投递记录（Tab: tracker）
    │       ├── GET/POST/PUT/DELETE /applications
    │       ├── POST /applications/parse-image  →  Qwen VL Plus（图片识别）
    │       └── POST /chat  →  DeepSeek V4 Pro（NL→SQL→NL）
    │
    ├── 简历优化（Tab: jdmatch）
    │       ├── POST /parse-jd             →  Qwen VL Plus（图片）/ mammoth（Word）
    │       ├── POST /analyze              →  DeepSeek V4 Pro（匹配分析）
    │       ├── POST /optimize-resume-visual →  Qwen VL Max（PDF/图片简历优化）
    │       ├── POST /optimize-word-resume   →  DeepSeek V4 Pro（Word 简历优化）
    │       └── POST /export-resume        →  python-docx / fpdf2 生成文件流
    │
    ├── 宇宙力量（Tab: fate）
    │       └── POST /analyze  →  DeepSeek V4 Pro（哲学风格宇宙来信）
    │
    └── 管理员后台（adminView，仅 admin）
            └── GET/POST/DELETE /admin/*
```

---

## 四、数据库结构

### 表1：job_applications
| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | 主键 |
| company | TEXT | 公司名称 |
| position | TEXT | 职位名称 |
| applied_date | DATE | 投递日期 |
| location | TEXT | 国家 / 地区 |
| link | TEXT | 职位链接 |
| feedback | TEXT | 进度（NULL / No Response / Fail / Offer / Interview / Online Assessment） |
| work_type | TEXT | Remote / Onsite / Hybrid |
| notes | TEXT | 备注 |
| user_id | INTEGER | 关联用户 |

### 表2：users
| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | 主键 |
| email | TEXT | 邮箱（唯一） |
| password_hash | TEXT | bcrypt 哈希 |
| is_admin | BOOLEAN | 是否管理员 |
| created_at | TIMESTAMPTZ | 注册时间 |

### 表3：invite_codes
| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL | 主键 |
| code | TEXT | 邀请码（唯一） |
| created_by | INTEGER | 生成者（管理员） |
| used_by | INTEGER | 使用者 |
| is_active | BOOLEAN | 是否有效 |
| created_at | TIMESTAMPTZ | 生成时间 |
| used_at | TIMESTAMPTZ | 使用时间 |

### 表4：chat_usage
| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | INTEGER | 用户 ID |
| date | DATE | 日期 |
| count | INTEGER | 当日调用次数 |

### 表5：work_permits
| 字段 | 类型 | 说明 |
|------|------|------|
| country | TEXT | 国家 |
| visa | TEXT | 签证 / 工作许可类型 |
| annual_salary | TEXT | 年薪门槛 |
| permanent_residence | TEXT | 永居申请年限 |

---

## 五、API 接口

### 公开接口（无需 token）
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /auth/register | 注册（邮箱 + 密码），返回 JWT token |
| POST | /auth/login | 登录，返回 JWT token |
| GET | /health | 健康检查 |

### 业务接口（需要 Bearer token）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /applications | 获取当前用户的申请记录 |
| POST | /applications | 新增申请记录 |
| PUT | /applications/{id} | 编辑申请记录 |
| DELETE | /applications/{id} | 删除申请记录 |
| POST | /applications/parse-image | 上传图片，AI 识别并返回字段 JSON（每日限 30 次） |
| POST | /parse-jd | 上传 Word / 图片，提取 JD 纯文本（每分钟限 20 次） |
| POST | /chat | AI 对话查询（每日限 30 次，每分钟限 30 次） |
| POST | /analyze | 简历分析 / 宇宙来信（每日限 30 次，每分钟限 10 次） |
| POST | /optimize-resume-visual | PDF / 图片简历优化，返回 HTML（每分钟限 5 次） |
| POST | /optimize-word-resume | Word 简历优化，返回 HTML（每分钟限 5 次） |
| POST | /export-resume | 导出简历文件（docx / pdf） |
| GET | /rss-proxy | RSS 代理（白名单域名透传，需登录） |
| GET | /stats/summary | 总数、地点数 |
| GET | /stats/countries | Top 5 投递地点 |
| GET | /stats/worktype | 工作类型分布 |

### 管理员接口（需要 Admin token）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /admin/users | 查看所有用户 |
| DELETE | /admin/users/{id} | 删除用户及其所有记录 |
| PATCH | /admin/users/{id}/toggle-admin | 切换管理员权限 |
| PATCH | /admin/users/{id}/reset-password | 重置密码 |
| GET | /admin/invite-codes | 查看邀请码列表 |
| POST | /admin/invite-codes | 生成邀请码 |
| DELETE | /admin/invite-codes/{id} | 撤销邀请码 |
| GET | /admin/stats | 数据概览（用户数、今日新增、反馈数、可用邀请码） |
| GET | /admin/feedback | 查看用户反馈 |

---

## 六、前端功能

- **登录 / 注册**：首次访问显示认证界面；邮箱 + 密码即可注册；登录后 token 存入 localStorage，30 天有效
- **科技资讯**：登录后默认进入；显示今日日期、投递总数 / 面试中 / 录用三项统计；聚合 Anthropic、The Verge AI、Hacker News 三个 RSS 源，按时间倒序展示，点击直达原文，支持手动刷新
- **简历优化**：上传简历（PDF / Word / 图片）；上传或粘贴 JD（PDF / TXT / Word / 图片）；匹配分析（评分 + 技能匹配 / 缺口 / ATS 关键词）；一键优化简历（AI 生成针对性 HTML 版本）；左侧面板可折叠；AI 对话精调简历内容；导出 Word / PDF
- **投递记录**：图片 / 截图 AI 自动识别新增；手动新增；搜索、排序、分页（每页 30 条）；点击记录编辑；备注字段；AI 对话查询数据
- **宇宙力量**：选择一条申请记录，点击中央信封触发翻盖动画，AI 以宇宙视角生成 2-3 句哲学风格来信；可重复获取
- **管理员后台**：用户管理（删除、切换权限、重置密码）、邀请码管理、用户反馈查看、数据概览

---

## 七、安全

- JWT token 鉴权（SECRET_KEY 存于 .env，不进 git）
- DeepSeek / Qwen API Key 存于 .env，不进 git
- 开放注册（邮箱 + 密码），管理员可选择性启用邀请码
- SQL 安全检查：仅允许 SELECT，强制 user_id 过滤，禁止访问非授权表
- /chat 每用户每日 30 次 / 每分钟 30 次；/analyze 每用户每日 30 次 / 每分钟 10 次；图片解析每日 30 次
- /rss-proxy 域名白名单，仅允许指定 RSS 源，需登录才可访问
- CORS 白名单控制
- 全局错误日志写入 logs/error.log
- 每日凌晨 3 点自动备份数据库，保留 7 天

---

## 八、项目文件结构

```
~/jobtrack/
├── db_api.py          # FastAPI 后端
├── job-agent.html     # 前端单页应用
├── schema.sql         # 数据库建表语句
├── requirements.txt   # Python 依赖
├── deploy.sh          # 生产环境一键部署脚本
├── backup.sh          # 数据库备份脚本
├── import_jobs.py     # 历史数据导入脚本
├── .env.example       # 环境变量模板
├── .env               # 密钥配置（不进 git）
├── logs/              # 运行日志
└── backups/           # 数据库备份文件
```

---

## 九、部署

### 环境要求
- Python 3.10+
- PostgreSQL

### 步骤

```bash
# 1. 克隆项目
git clone https://github.com/valenwei113-design/offer-coming.git
cd offer-coming

# 2. 安装依赖
pip install -r requirements.txt

# 3. 配置环境变量
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY、QWEN_API_KEY、SECRET_KEY 和数据库信息

# 4. 建表
psql -U postgres -d jobsdb -f schema.sql

# 5. 创建日志目录
mkdir -p logs

# 6. 启动服务
uvicorn db_api:app --host 0.0.0.0 --port 8000
```

### 生产环境部署

```bash
# 将项目上传到服务器后，一键部署
bash deploy.sh
```

部署脚本会自动完成：系统依赖安装、PostgreSQL 配置、Python 虚拟环境创建、systemd 服务注册、防火墙配置、数据库每日自动备份。

### 本地开发

```bash
# 带热重载启动
uvicorn db_api:app --host 0.0.0.0 --port 8000 --reload

# 前端直接用浏览器打开
open job-agent.html
```

---

<a name="english"></a>
# English

## 1. Overview

**Project Name**: Offer Coming

**Purpose**: An AI-powered end-to-end job search assistant with multi-user support, suitable for small-scale deployment.

**Key Features**:
- **Tech News**: Default landing page after login — shows application stats and aggregated AI tech news (Anthropic / The Verge AI / Hacker News RSS)
- **Applications**: Add, edit, delete records; AI image/screenshot parsing; search, sort, paginate; AI chat to query your data
- **Resume**: Upload resume (PDF / Word / Image) + JD (PDF / TXT / Word / Image), AI match analysis (with score); one-click AI resume optimization; AI chat to refine the resume; export as Word / PDF
- **Cosmic Forces**: Select an application, click the envelope, receive a philosophical letter written from the universe's perspective
- **Admin Panel**: User management, invite codes, feedback viewer, stats overview
- **Bilingual**: Chinese / English toggle

---

## 2. Tech Stack

| Layer | Technology |
|-------|-----------|
| LLM (Chat / Data query / Cosmic letter) | DeepSeek V4 Pro (via API) |
| LLM (Resume analysis / generation) | DeepSeek V4 Pro (via API) |
| LLM (Visual resume optimization / Image parsing) | Qwen VL Max / Plus (via Alibaba Cloud) |
| Backend | Python FastAPI + uvicorn |
| Database | PostgreSQL |
| Frontend | Vanilla HTML + Chart.js |
| Document Export | python-docx (Word), fpdf2 (PDF) |
| Version Control | GitHub |

---

## 3. Architecture

```
User Browser
    │
    ├── Tech News Tab (home)
    │       ├── Stats computed client-side from loaded data
    │       └── GET /rss-proxy?url=...  →  proxy RSS feeds (Anthropic / The Verge / HN)
    │
    ├── Applications Tab
    │       ├── GET/POST/PUT/DELETE /applications
    │       ├── POST /applications/parse-image  →  Qwen VL Plus (image recognition)
    │       └── POST /chat  →  DeepSeek V4 Pro (NL→SQL→NL)
    │
    ├── Resume Tab
    │       ├── POST /parse-jd               →  Qwen VL Plus (image) / mammoth (Word)
    │       ├── POST /analyze                →  DeepSeek V4 Pro (match analysis)
    │       ├── POST /optimize-resume-visual →  Qwen VL Max (PDF/image resume)
    │       ├── POST /optimize-word-resume   →  DeepSeek V4 Pro (Word resume)
    │       └── POST /export-resume          →  python-docx / fpdf2 file stream
    │
    ├── Cosmic Forces Tab (fate)
    │       └── POST /analyze  →  DeepSeek V4 Pro (philosophical cosmic letter)
    │
    └── Admin View (admin only)
            └── GET/POST/DELETE /admin/*
```

---

## 4. Database Schema

### Table 1: job_applications
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| company | TEXT | Company name |
| position | TEXT | Job title |
| applied_date | DATE | Application date |
| location | TEXT | Country / Region |
| link | TEXT | Job posting URL |
| feedback | TEXT | Status (NULL / No Response / Fail / Offer / Interview / Online Assessment) |
| work_type | TEXT | Remote / Onsite / Hybrid |
| notes | TEXT | Notes |
| user_id | INTEGER | Owner (foreign key) |

### Table 2: users
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| email | TEXT | Email (unique) |
| password_hash | TEXT | bcrypt hash |
| is_admin | BOOLEAN | Admin flag |
| created_at | TIMESTAMPTZ | Registration time |

### Table 3: invite_codes
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| code | TEXT | Invite code (unique) |
| created_by | INTEGER | Issuing admin |
| used_by | INTEGER | Redeemer |
| is_active | BOOLEAN | Still valid |
| created_at | TIMESTAMPTZ | Created at |
| used_at | TIMESTAMPTZ | Redeemed at |

### Table 4: chat_usage
| Column | Type | Description |
|--------|------|-------------|
| user_id | INTEGER | User ID |
| date | DATE | Date |
| count | INTEGER | Daily usage count |

### Table 5: work_permits
| Column | Type | Description |
|--------|------|-------------|
| country | TEXT | Country |
| visa | TEXT | Visa / work permit type |
| annual_salary | TEXT | Minimum salary threshold |
| permanent_residence | TEXT | Years to permanent residency |

---

## 5. API Reference

### Public Endpoints (no token required)
| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/register | Register with email + password, returns JWT |
| POST | /auth/login | Login, returns JWT |
| GET | /health | Health check |

### Authenticated Endpoints (Bearer token required)
| Method | Path | Description |
|--------|------|-------------|
| GET | /applications | List current user's applications |
| POST | /applications | Create application |
| PUT | /applications/{id} | Update application |
| DELETE | /applications/{id} | Delete application |
| POST | /applications/parse-image | Upload image, AI extracts fields as JSON (30/day) |
| POST | /parse-jd | Upload Word / image, extract JD plain text (20/min) |
| POST | /chat | AI chat query (30/day, 30/min per user) |
| POST | /analyze | Resume match analysis / cosmic letter (30/day, 10/min per user) |
| POST | /optimize-resume-visual | Optimize PDF/image resume, returns HTML (5/min) |
| POST | /optimize-word-resume | Optimize Word resume, returns HTML (5/min) |
| POST | /export-resume | Export resume file (docx or pdf) |
| GET | /rss-proxy | RSS proxy (allowlisted domains only, login required) |
| GET | /stats/summary | Total applications & locations |
| GET | /stats/countries | Top 5 locations |
| GET | /stats/worktype | Work type distribution |

### Admin Endpoints (Admin token required)
| Method | Path | Description |
|--------|------|-------------|
| GET | /admin/users | List all users |
| DELETE | /admin/users/{id} | Delete user and all their data |
| PATCH | /admin/users/{id}/toggle-admin | Toggle admin role |
| PATCH | /admin/users/{id}/reset-password | Reset user password |
| GET | /admin/invite-codes | List invite codes |
| POST | /admin/invite-codes | Generate invite code |
| DELETE | /admin/invite-codes/{id} | Revoke invite code |
| GET | /admin/stats | Overview (users, new today, feedback, available invites) |
| GET | /admin/feedback | View user feedback |

---

## 6. Frontend Features

- **Auth**: Shown on first visit; email + password registration; JWT stored in localStorage for 30 days
- **Tech News**: Default tab after login — today's date, 3 stat cards (total / interviews / offers); aggregated RSS from Anthropic, The Verge AI, and Hacker News sorted by recency; click to open original article; manual refresh
- **Resume**: Upload resume (PDF / Word / Image); upload or paste JD (PDF / TXT / Word / Image); match analysis with score, skill gaps, and ATS keywords; one-click AI resume optimization (generates HTML); collapsible left panel; AI chat to refine output; export as Word / PDF
- **Applications**: AI image/screenshot auto-fill; manual add; search, sort by date, paginate (30/page); inline edit; notes field; AI chat to query data
- **Cosmic Forces**: Select an application, click the centered envelope to trigger an opening animation; receive a 2–3 sentence philosophical letter from the universe's perspective; repeat as desired
- **Admin Panel**: User management (delete, toggle admin, reset password), invite code management, feedback list, stats overview

---

## 7. Security

- JWT authentication (SECRET_KEY in .env, excluded from git)
- DeepSeek / Qwen API keys in .env, excluded from git
- Open registration (email + password), optional invite codes for admin
- SQL safety: SELECT only, mandatory user_id filter, blocked unauthorized tables
- Rate limits: /chat 30/day & 30/min; /analyze 30/day & 10/min; image parse 30/day per user
- /rss-proxy domain allowlist, login required — cannot be used as open proxy
- CORS allowlist
- Global error logging to logs/error.log
- Automated daily DB backup at 3 AM, retained for 7 days

---

## 8. File Structure

```
~/jobtrack/
├── db_api.py          # FastAPI backend
├── job-agent.html     # Frontend (single-page app)
├── schema.sql         # Database schema
├── requirements.txt   # Python dependencies
├── deploy.sh          # One-click production deployment script
├── backup.sh          # Database backup script
├── import_jobs.py     # Historical data import script
├── .env.example       # Environment variable template
├── .env               # Secrets (excluded from git)
├── logs/              # Runtime logs
└── backups/           # Database backup files
```

---

## 9. Deployment

### Requirements
- Python 3.10+
- PostgreSQL

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/valenwei113-design/offer-coming.git
cd offer-coming

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env — fill in DEEPSEEK_API_KEY, QWEN_API_KEY, SECRET_KEY, and DB credentials

# 4. Initialize database
psql -U postgres -d jobsdb -f schema.sql

# 5. Create log directory
mkdir -p logs

# 6. Start server
uvicorn db_api:app --host 0.0.0.0 --port 8000
```

### Production Deployment

```bash
# Upload project to server, then one-click deploy
bash deploy.sh
```

The deploy script automates: system dependencies, PostgreSQL setup, Python venv, systemd service, firewall, and daily database backups.

### Local Development

```bash
# Start with hot reload
uvicorn db_api:app --host 0.0.0.0 --port 8000 --reload

# Open frontend directly in browser
open job-agent.html
```
