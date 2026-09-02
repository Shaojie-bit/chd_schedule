# CHD 课表云端服务中心 (CHD Schedule Server)

> 🚀 专为「长安大学现代化课表 App」打造的轻量级云端数据统计、活跃度监控与全校通知公告/版本更新推送中心。

[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)

---

## 📖 目录

- [系统架构](#-系统架构)
- [核心功能](#-核心功能)
- [配置说明](#-配置说明)
- [部署教程](#-部署教程)
  - [方式一：原生 Ubuntu / Linux 部署 (推荐)](#方式一原生-ubuntu--linux-部署-推荐)
  - [方式二：Docker Compose 一键部署](#方式二docker-compose-一键部署)
  - [方式三：Systemd 系统守护进程 (开机自启)](#方式三systemd-系统守护进程-开机自启)
- [云服务器防火墙放行指南](#-云服务器防火墙放行指南)
- [RESTful API 接口规范](#-restful-api-接口规范)
- [常见问题与排错 (FAQ)](#-常见问题与排错-faq)
- [开源协议与安全须知](#-开源协议与安全须知)

---

## 🏛 系统架构

```text
┌───────────────────────┐         HTTP (2543)          ┌────────────────────────────────┐
│   CHD 课表 Flutter     │ ─────────────────────────►  │      FastAPI 服务端            │
│   Android / iOS App   │ ◄─────────────────────────  │   (http://<ip>:2543)           │
└───────────────────────┘     心跳上报 / 拉取最新通知    └───────────────┬────────────────┘
                                                                        │
                                                ┌───────────────────────┴───────────────────────┐
                                                ▼                                               ▼
                                  ┌───────────────────────────┐                   ┌───────────────────────────┐
                                  │   云端 MySQL (可选)       │                   │    内置 SQLite (默认保底)  │
                                  │   (Azure / 阿里云 / 腾讯云)│                   │    (data/analytics.db)    │
                                  └───────────────────────────┘                   └───────────────────────────┘
```

- **高容错与解耦设计**：
  - 手机 App 完全独立运行，即使服务器关机或断网，App 依然**100% 离线可用**，不阻断任何课表与成绩查询；
  - 服务端优先连接配置的云端 MySQL 数据库；若未配置或数据库连不上，系统**自动平滑降级为本地 SQLite 单文件存储**，实现零配置秒级开箱即用。

---

## ✨ 核心功能

### 1. 📈 学生用户量与活跃度多维统计
- **自动去重登记**：按学生学号唯一标识，记录学号、姓名、学院、专业、校区、首次使用时间、最后活跃时间；
- **活跃度指标**：自动计算**累计使用总人数**、**今日实时在线人数**、**近 7 日活跃留存**；
- **全校分布洞察**：按学院、专业自动归纳统计分布。

### 2. 📢 通知公告与版本更新全量分发
- **在线发布新通知**：支持发布**普通通知 (notice)**、**版本升级 (update)**、**重要提醒 (warning)**；
- **弹窗强提醒**：勾选“启动弹窗”后，学生下次打开 App 会在屏幕居中弹出沉浸式通知卡片；
- **版本更新直链**：支持填写新版 APK 下载地址，学生点击即可一键跳转更新。

### 3. 🖥️ 现代化响应式 Web 管理面板
- 浏览器直接访问 `http://<服务器IP>:2543/admin`；
- 采用 Bento Grid 设计风格，适配手机端与电脑端浏览器；
- 实时自动轮询刷新最新数据，支持一键下架历史公告。

---

## ⚙️ 配置说明

服务端支持两种数据库运行模式：

### 1. 极简模式 (默认)
**无需任何数据库配置**！直接启动即可，系统会自动在 `data/analytics.db` 创建本地 SQLite 数据库。

### 2. 生产云数据库模式 (MySQL / Azure Database)
如需多机共享或云端持久化存储，可在 `server` 目录下创建 `.env` 文件（参考 `.env.example`）：

```bash
cp .env.example .env
```

编辑 `.env` 文件填入你的数据库参数：
```env
MYSQL_HOST=your-mysql-host.mysql.database.azure.com
MYSQL_PORT=3306
MYSQL_USER=your_db_username
MYSQL_PASSWORD=your_db_password
MYSQL_DB=your_database_name
```

> ⚠️ **安全警告**：包含真实密码的 `.env` 文件已由 `.gitignore` 自动忽略，**严禁将包含明文密码的配置文件提交到 GitHub 公开仓库**！

---

## 🚀 部署教程

### 方式一：原生 Ubuntu / Linux 部署 (推荐)

#### 1. 准备环境
进入 Ubuntu 终端，安装 Python 基础依赖：
```bash
sudo apt update && sudo apt install -y python3 python3-pip python3-venv
```

#### 2. 解压与启动
将 `server` 文件夹上传到服务器（例如 `/home/ubuntu/server`）：
```bash
cd /home/ubuntu/server
chmod +x start.sh

# 后台静默启动
nohup ./start.sh > server.log 2>&1 &
```

#### 3. 检查运行状态
```bash
# 查看启动日志
cat server.log

# 预期看到：
# INFO:     Application startup complete.
# INFO:     Uvicorn running on http://0.0.0.0:2543 (Press CTRL+C to quit)
```

---

### 方式二：Docker Compose 一键部署

若服务器已安装 Docker 和 Docker Compose：

```bash
cd server
docker compose up -d
```

查看运行容器：
```bash
docker compose ps
docker compose logs -f
```

---

### 方式三：Systemd 系统守护进程 (开机自启)

如需在服务器重启后自动恢复运行，可配置 Systemd 服务：

```bash
sudo tee /etc/systemd/system/chd-server.service << 'EOF'
[Unit]
Description=CHD Schedule Cloud Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/server
ExecStart=/home/ubuntu/server/venv/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 2543
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 激活并启动开机自启
sudo systemctl daemon-reload
sudo systemctl enable chd-server
sudo systemctl start chd-server
sudo systemctl status chd-server
```

---

## 🛡️ 云服务器防火墙放行指南

外部无法打开 `http://<IP>:2543/admin` 时，99% 是因为云厂商的网络安全组拦截了入站流量：

### 1. 微软 Azure 虚拟机 (Azure Portal)
1. 登录 Azure 门户 -> 进入你的虚拟机 -> 点击左侧 **网络 (Networking)**；
2. 点击 **添加入站端口规则 (Add inbound port rule)**；
3. **目标端口范围 (Destination port ranges)**：填 `2543`；
4. **协议 (Protocol)**：选择 `TCP`（或 `Any`）；
5. **操作 (Action)**：选择 `Allow (允许)`；
6. 点击保存，约 15 秒后生效。

### 2. 阿里云 / 腾讯云 / 华为云
- 进入云服务器 ECS/CVM 控制台 -> **安全组 (Security Groups)** -> **入站规则**；
- 添加规则：协议 `TCP`，端口 `2543`，授权对象 `0.0.0.0/0`，操作 `允许`。

### 3. Ubuntu 本机防火墙 (UFW)
在终端执行：
```bash
sudo ufw allow 2543/tcp
sudo ufw reload
```

---

## 📡 RESTful API 接口规范

### 1. 客户端心跳上报
- **URL**: `POST /api/telemetry/report`
- **Content-Type**: `application/json`
- **Request Body**:
  ```json
  {
    "student_id": "2023xxxxxx",
    "name": "某某同学",
    "college": "土地工程学院",
    "major": "土地整治工程",
    "grade": "2023",
    "campus": "渭水校区",
    "app_version": "1.0.0",
    "device_id": "dev_1725280000000_1234",
    "action": "startup"
  }
  ```
- **Response**:
  ```json
  { "status": "ok", "timestamp": "2026-09-02 20:30:00" }
  ```

---

### 2. 获取最新公告
- **URL**: `GET /api/announcements/latest`
- **Response**:
  ```json
  {
    "has_announcement": true,
    "data": {
      "id": 1,
      "title": "课表系统 v1.1 更新提醒",
      "content": "已优化教室地点显示，支持左右滑动切换周次与日期联动。",
      "type": "update",
      "is_popup": true,
      "version_code": 2,
      "download_url": "https://...",
      "created_at": "2026-09-02 20:00:00"
    }
  }
  ```

---

### 3. 获取所有生效公告列表
- **URL**: `GET /api/announcements`
- **Response**:
  ```json
  {
    "total": 1,
    "data": [ ... ]
  }
  ```

---

### 4. 管理面板统计数据汇总
- **URL**: `GET /api/admin/stats`
- **Response**:
  ```json
  {
    "db_type": "mysql",
    "total_users": 128,
    "today_active": 45,
    "week_active": 110,
    "colleges": [
      { "name": "土地工程学院", "count": 52 },
      { "name": "公路学院", "count": 30 }
    ],
    "users": [ ... ],
    "announcements": [ ... ]
  }
  ```

---

### 5. 发布新公告 (管理接口)
- **URL**: `POST /api/admin/announcements`
- **Request Body**:
  ```json
  {
    "title": "放假排课通知",
    "content": "本周五课程调整至周日补课，请同学们注意查看。",
    "type": "notice",
    "is_popup": true,
    "download_url": ""
  }
  ```

---

### 6. 下架公告 (管理接口)
- **URL**: `DELETE /api/admin/announcements/{id}`

---

## ❓ 常见问题与排错 (FAQ)

### Q1: 浏览器提示 `20.200.219.153 未发送任何数据 (ERR_EMPTY_RESPONSE)`？
- **原因**：现代浏览器在地址栏直接输入 IP 时会**强制尝试 HTTPS**。本项目后端为轻量 HTTP 协议；
- **解决**：在浏览器地址栏手动输入协议头：**`http://<服务器IP>:2543/admin`**（确保是 `http` 而非 `https`），或使用 Chrome 的无痕模式 (`Ctrl + Shift + N`) 打开。

### Q2: 浏览器一直转圈提示超时 (`Connection Timed Out`)？
- **原因**：云服务商的外部安全组（如 Azure NSG）未放行 `2543` 端口；
- **验证**：在服务器终端输入 `curl http://127.0.0.1:2543/admin`，若能正常打印出 HTML，说明是外部网络规则问题，请参考上文[防火墙放行指南](#-云服务器防火墙放行指南)。

### Q3: 如何修改后端监听端口？
- 修改 `start.sh` 中的 `PORT=2543` 变量为你需要的端口；
- 若使用 Docker，修改 `docker-compose.yml` 中的端口映射 `2543:2543`。

---

## 🔒 开源协议与安全须知

- 本服务端代码采用 [MIT License](LICENSE) 开源；
- **学生隐私保护**：心跳上报仅用于校园课表工具的活跃度与版本升级统计，数据全部保存在部署者私有数据库中，不向任何第三方上报；
- **代码安全规范**：在向 GitHub、Gitee 等公开平台推送代码前，请确保遵循 `.gitignore` 规则，严禁泄露个人学号、教务密码及云数据库账号密码。
