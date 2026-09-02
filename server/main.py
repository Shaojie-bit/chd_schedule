import os
import ssl
import sqlite3
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    import pymysql
    import pymysql.cursors
    HAS_PYMYSQL = True
except ImportError:
    HAS_PYMYSQL = False

app = FastAPI(title="CHD 课表云端服务中心", version="1.0.0")

# 启用跨域支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 尝试加载当前目录下的 .env 配置文件 (若存在)
env_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.exists(env_path):
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

# 数据库配置：优先读取环境变量/配置，未配置则自动使用本地 SQLite
MYSQL_HOST = os.environ.get("MYSQL_HOST", "").strip()
MYSQL_PORT = int(os.environ.get("MYSQL_PORT", "3306"))
MYSQL_USER = os.environ.get("MYSQL_USER", "").strip()
MYSQL_PASSWORD = os.environ.get("MYSQL_PASSWORD", "").strip()
MYSQL_DB = os.environ.get("MYSQL_DB", "").strip()

# 本地 SQLite 保底配置
DB_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(DB_DIR, exist_ok=True)
SQLITE_PATH = os.path.join(DB_DIR, "analytics.db")

def get_db_connection():
    """获取数据库连接：若配置了 MySQL 则优先连接，失败或未配置则自动使用本地 SQLite"""
    if HAS_PYMYSQL and MYSQL_HOST and MYSQL_USER and MYSQL_PASSWORD and MYSQL_DB:
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            conn = pymysql.connect(
                host=MYSQL_HOST,
                port=MYSQL_PORT,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                database=MYSQL_DB,
                ssl=ctx,
                connect_timeout=6,
                cursorclass=pymysql.cursors.DictCursor
            )
            return conn, "mysql"
        except Exception as e:
            print(f"[Warn] MySQL 连接失败，降级为 SQLite: {e}")

    conn = sqlite3.connect(SQLITE_PATH)
    conn.row_factory = sqlite3.Row
    return conn, "sqlite"

def init_db():
    conn, db_type = get_db_connection()
    try:
        cursor = conn.cursor()
        if db_type == "mysql":
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_users (
                    student_id VARCHAR(32) PRIMARY KEY,
                    name VARCHAR(64) DEFAULT '',
                    college VARCHAR(128) DEFAULT '',
                    major VARCHAR(128) DEFAULT '',
                    grade VARCHAR(32) DEFAULT '',
                    campus VARCHAR(64) DEFAULT '',
                    first_seen DATETIME NOT NULL,
                    last_seen DATETIME NOT NULL,
                    app_version VARCHAR(32) DEFAULT '1.0.0',
                    device_id VARCHAR(128) DEFAULT '',
                    heartbeat_count INT DEFAULT 1
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ''')
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_activity_logs (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    student_id VARCHAR(32) NOT NULL,
                    timestamp DATETIME NOT NULL,
                    ip_address VARCHAR(64) DEFAULT '',
                    action VARCHAR(32) DEFAULT 'startup',
                    INDEX idx_student_time (student_id, timestamp)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ''')
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_announcements (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    content TEXT NOT NULL,
                    type VARCHAR(32) DEFAULT 'notice',
                    is_popup TINYINT DEFAULT 1,
                    version_code INT DEFAULT 1,
                    download_url VARCHAR(512) DEFAULT '',
                    created_at DATETIME NOT NULL,
                    is_active TINYINT DEFAULT 1
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ''')
        else:
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_users (
                    student_id TEXT PRIMARY KEY,
                    name TEXT, college TEXT, major TEXT, grade TEXT, campus TEXT,
                    first_seen TEXT, last_seen TEXT, app_version TEXT, device_id TEXT,
                    heartbeat_count INTEGER DEFAULT 1
                )
            ''')
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_activity_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    student_id TEXT, timestamp TEXT, ip_address TEXT, action TEXT
                )
            ''')
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS chd_announcements (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL, content TEXT NOT NULL, type TEXT DEFAULT 'notice',
                    is_popup INTEGER DEFAULT 1, version_code INTEGER DEFAULT 1,
                    download_url TEXT DEFAULT '', created_at TEXT NOT NULL, is_active INTEGER DEFAULT 1
                )
            ''')
        conn.commit()
    finally:
        conn.close()

init_db()

# 数据模型定义
class TelemetryReport(BaseModel):
    student_id: str
    name: Optional[str] = ""
    college: Optional[str] = ""
    major: Optional[str] = ""
    grade: Optional[str] = ""
    campus: Optional[str] = ""
    app_version: Optional[str] = "1.0.0"
    device_id: Optional[str] = ""
    action: Optional[str] = "startup"

class AnnouncementCreate(BaseModel):
    title: str
    content: str
    type: Optional[str] = "notice"
    is_popup: Optional[bool] = True
    version_code: Optional[int] = 1
    download_url: Optional[str] = ""

# ----------------- 客户端 API 路由 -----------------

@app.post("/api/telemetry/report")
async def report_telemetry(data: TelemetryReport, request: Request):
    """客户端活跃心跳上报"""
    if not data.student_id:
        return {"status": "ignored", "reason": "empty_id"}

    now = datetime.now()
    now_str = now.strftime("%Y-%m-%d %H:%M:%S")
    client_ip = request.client.host if request.client else "unknown"

    conn, db_type = get_db_connection()
    try:
        cursor = conn.cursor()
        if db_type == "mysql":
            cursor.execute('''
                INSERT INTO chd_users (student_id, name, college, major, grade, campus, first_seen, last_seen, app_version, device_id, heartbeat_count)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 1)
                ON DUPLICATE KEY UPDATE
                    name = CASE WHEN %s != '' THEN %s ELSE name END,
                    college = CASE WHEN %s != '' THEN %s ELSE college END,
                    major = CASE WHEN %s != '' THEN %s ELSE major END,
                    grade = CASE WHEN %s != '' THEN %s ELSE grade END,
                    campus = CASE WHEN %s != '' THEN %s ELSE campus END,
                    last_seen = %s,
                    app_version = %s,
                    device_id = %s,
                    heartbeat_count = heartbeat_count + 1
            ''', (
                data.student_id, data.name, data.college, data.major, data.grade, data.campus,
                now_str, now_str, data.app_version, data.device_id,
                data.name, data.name,
                data.college, data.college,
                data.major, data.major,
                data.grade, data.grade,
                data.campus, data.campus,
                now_str, data.app_version, data.device_id
            ))
            cursor.execute('''
                INSERT INTO chd_activity_logs (student_id, timestamp, ip_address, action)
                VALUES (%s, %s, %s, %s)
            ''', (data.student_id, now_str, client_ip, data.action))
        else:
            cursor.execute("SELECT heartbeat_count FROM chd_users WHERE student_id = ?", (data.student_id,))
            row = cursor.fetchone()
            if row:
                cursor.execute('''
                    UPDATE chd_users SET
                        name = CASE WHEN ? != '' THEN ? ELSE name END,
                        college = CASE WHEN ? != '' THEN ? ELSE college END,
                        major = CASE WHEN ? != '' THEN ? ELSE major END,
                        grade = CASE WHEN ? != '' THEN ? ELSE grade END,
                        campus = CASE WHEN ? != '' THEN ? ELSE campus END,
                        last_seen = ?, app_version = ?, device_id = ?, heartbeat_count = heartbeat_count + 1
                    WHERE student_id = ?
                ''', (
                    data.name, data.name, data.college, data.college, data.major, data.major,
                    data.grade, data.grade, data.campus, data.campus,
                    now_str, data.app_version, data.device_id, data.student_id
                ))
            else:
                cursor.execute('''
                    INSERT INTO chd_users (student_id, name, college, major, grade, campus, first_seen, last_seen, app_version, device_id, heartbeat_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
                ''', (
                    data.student_id, data.name, data.college, data.major, data.grade, data.campus,
                    now_str, now_str, data.app_version, data.device_id
                ))
            cursor.execute('''
                INSERT INTO chd_activity_logs (student_id, timestamp, ip_address, action)
                VALUES (?, ?, ?, ?)
            ''', (data.student_id, now_str, client_ip, data.action))
        conn.commit()
    finally:
        conn.close()

    return {"status": "ok", "timestamp": now_str}

@app.get("/api/announcements/latest")
async def get_latest_announcement():
    """获取最新生效公告"""
    conn, _ = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, title, content, type, is_popup, version_code, download_url, created_at
            FROM chd_announcements
            WHERE is_active = 1
            ORDER BY id DESC LIMIT 1
        ''')
        row = cursor.fetchone()
        if not row:
            return {"has_announcement": False}

        created_val = row["created_at"]
        if isinstance(created_val, datetime):
            created_val = created_val.strftime("%Y-%m-%d %H:%M:%S")

        return {
            "has_announcement": True,
            "data": {
                "id": row["id"],
                "title": row["title"],
                "content": row["content"],
                "type": row["type"],
                "is_popup": bool(row["is_popup"]),
                "version_code": row["version_code"],
                "download_url": row["download_url"],
                "created_at": str(created_val),
            }
        }
    finally:
        conn.close()

@app.get("/api/announcements")
async def get_all_announcements():
    """获取所有生效公告"""
    conn, _ = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, title, content, type, is_popup, version_code, download_url, created_at
            FROM chd_announcements
            WHERE is_active = 1
            ORDER BY id DESC
        ''')
        rows = cursor.fetchall()
        data_list = []
        for r in rows:
            created_val = r["created_at"]
            if isinstance(created_val, datetime):
                created_val = created_val.strftime("%Y-%m-%d %H:%M:%S")
            data_list.append({
                "id": r["id"],
                "title": r["title"],
                "content": r["content"],
                "type": r["type"],
                "is_popup": bool(r["is_popup"]),
                "version_code": r["version_code"],
                "download_url": r["download_url"],
                "created_at": str(created_val),
            })
        return {"total": len(data_list), "data": data_list}
    finally:
        conn.close()

# ----------------- 管理后台 API -----------------

@app.post("/api/admin/announcements")
async def create_announcement(item: AnnouncementCreate):
    """发布新公告"""
    now = datetime.now()
    now_str = now.strftime("%Y-%m-%d %H:%M:%S")
    conn, db_type = get_db_connection()
    try:
        cursor = conn.cursor()
        ph = "%s" if db_type == "mysql" else "?"
        sql = f'''
            INSERT INTO chd_announcements (title, content, type, is_popup, version_code, download_url, created_at, is_active)
            VALUES ({ph}, {ph}, {ph}, {ph}, {ph}, {ph}, {ph}, 1)
        '''
        cursor.execute(sql, (item.title, item.content, item.type, 1 if item.is_popup else 0, item.version_code, item.download_url, now_str))
        new_id = cursor.lastrowid
        conn.commit()
        return {"status": "ok", "id": new_id, "created_at": now_str}
    finally:
        conn.close()

@app.delete("/api/admin/announcements/{ann_id}")
async def delete_announcement(ann_id: int):
    """下架公告"""
    conn, db_type = get_db_connection()
    try:
        cursor = conn.cursor()
        ph = "%s" if db_type == "mysql" else "?"
        cursor.execute(f"UPDATE chd_announcements SET is_active = 0 WHERE id = {ph}", (ann_id,))
        conn.commit()
        return {"status": "ok", "deleted_id": ann_id}
    finally:
        conn.close()

@app.get("/api/admin/stats")
async def get_admin_stats():
    """管理后台综合统计"""
    today_prefix = date.today().strftime("%Y-%m-%d")
    seven_days_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d %H:%M:%S")

    conn, db_type = get_db_connection()
    try:
        cursor = conn.cursor()
        ph = "%s" if db_type == "mysql" else "?"

        # 总用户数
        cursor.execute("SELECT COUNT(*) as cnt FROM chd_users")
        total_users = cursor.fetchone()
        total_users_count = total_users["cnt"] if isinstance(total_users, dict) else total_users[0]

        # 今日活跃
        cursor.execute(f"SELECT COUNT(DISTINCT student_id) as cnt FROM chd_activity_logs WHERE timestamp >= {ph}", (today_prefix,))
        row_today = cursor.fetchone()
        today_active = row_today["cnt"] if isinstance(row_today, dict) else row_today[0]

        # 近7日活跃
        cursor.execute(f"SELECT COUNT(DISTINCT student_id) as cnt FROM chd_activity_logs WHERE timestamp >= {ph}", (seven_days_ago,))
        row_week = cursor.fetchone()
        week_active = row_week["cnt"] if isinstance(row_week, dict) else row_week[0]

        # 学院分布
        cursor.execute('''
            SELECT COALESCE(NULLIF(college, ''), '未填写') as college_name, COUNT(*) as count
            FROM chd_users GROUP BY college_name ORDER BY count DESC LIMIT 10
        ''')
        colleges = [{"name": r["college_name"], "count": r["count"]} for r in cursor.fetchall()]

        # 最近用户列表
        cursor.execute('''
            SELECT student_id, name, college, major, grade, campus, last_seen, heartbeat_count, app_version
            FROM chd_users ORDER BY last_seen DESC LIMIT 50
        ''')
        raw_users = cursor.fetchall()
        users_list = []
        for u in raw_users:
            ls = u["last_seen"]
            if isinstance(ls, datetime):
                ls = ls.strftime("%Y-%m-%d %H:%M:%S")
            users_list.append({
                "student_id": u["student_id"],
                "name": u["name"],
                "college": u["college"],
                "major": u["major"],
                "grade": u["grade"],
                "campus": u["campus"],
                "last_seen": str(ls),
                "heartbeat_count": u["heartbeat_count"],
                "app_version": u["app_version"]
            })

        # 公告列表
        cursor.execute("SELECT id, title, content, type, is_popup, created_at, is_active FROM chd_announcements ORDER BY id DESC")
        raw_ann = cursor.fetchall()
        announcements = []
        for a in raw_ann:
            ca = a["created_at"]
            if isinstance(ca, datetime):
                ca = ca.strftime("%Y-%m-%d %H:%M:%S")
            announcements.append({
                "id": a["id"],
                "title": a["title"],
                "content": a["content"],
                "type": a["type"],
                "is_popup": a["is_popup"],
                "created_at": str(ca),
                "is_active": a["is_active"]
            })

        return {
            "db_type": db_type,
            "total_users": total_users_count,
            "today_active": today_active,
            "week_active": week_active,
            "colleges": colleges,
            "users": users_list,
            "announcements": announcements
        }
    finally:
        conn.close()

# ----------------- 现代化 Web 管理看板 -----------------

@app.get("/")
async def root():
    return RedirectResponse(url="/admin")

@app.head("/admin")
@app.get("/admin", response_class=HTMLResponse)
async def admin_dashboard():
    return """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CHD 课表管理服务中心 | 统计看板与公告发布</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&family=Noto+Sans+SC:wght@400;500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #4F46E5;
      --primary-hover: #4338CA;
      --bg: #F8FAFC;
      --card-bg: #FFFFFF;
      --text-main: #0F172A;
      --text-muted: #64748B;
      --border: #E2E8F0;
      --success: #10B981;
      --warning: #F59E0B;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', 'Noto Sans SC', sans-serif; }
    body { background: var(--bg); color: var(--text-main); line-height: 1.5; padding: 24px 32px; }
    header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
    .logo-area { display: flex; align-items: center; gap: 12px; }
    .logo-badge { background: var(--primary); color: white; width: 42px; height: 42px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px; box-shadow: 0 8px 16px rgba(79, 70, 229, 0.25); }
    h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .subtitle { font-size: 13px; color: var(--text-muted); }
    .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 24px; }
    .metric-card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 16px; padding: 20px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.02); }
    .metric-title { font-size: 12px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
    .metric-value { font-size: 32px; font-weight: 800; color: var(--text-main); }
    .metric-tag { font-size: 11px; padding: 2px 8px; border-radius: 6px; font-weight: 700; display: inline-block; margin-top: 6px; }
    .tag-green { background: #ECFDF5; color: var(--success); }
    .tag-blue { background: #EEF2FF; color: var(--primary); }
    .layout-cols { display: grid; grid-template-columns: 2fr 1fr; gap: 24px; }
    .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 16px; padding: 24px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.02); margin-bottom: 24px; }
    .card-title { font-size: 16px; font-weight: 700; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center; }
    table { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }
    th { color: var(--text-muted); font-weight: 600; padding: 10px 12px; border-bottom: 1px solid var(--border); }
    td { padding: 12px; border-bottom: 1px solid #F1F5F9; color: var(--text-main); }
    tr:last-child td { border-bottom: none; }
    .badge { padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; }
    .badge-primary { background: #EEF2FF; color: var(--primary); }
    .form-group { margin-bottom: 14px; }
    label { display: block; font-size: 12px; font-weight: 700; color: var(--text-muted); margin-bottom: 6px; }
    input, textarea, select { width: 100%; padding: 10px 12px; border: 1px solid var(--border); border-radius: 10px; font-size: 13px; outline: none; transition: border-color 0.2s; }
    input:focus, textarea:focus, select:focus { border-color: var(--primary); ring: 2px rgba(79,70,229,0.1); }
    button.btn { background: var(--primary); color: white; border: none; padding: 10px 18px; border-radius: 10px; font-size: 13px; font-weight: 700; cursor: pointer; transition: all 0.2s; width: 100%; }
    button.btn:hover { background: var(--primary-hover); transform: translateY(-1px); }
    .del-btn { background: none; border: none; color: #EF4444; font-size: 12px; cursor: pointer; font-weight: 700; }
    .del-btn:hover { text-decoration: underline; }
    .ann-item { padding: 12px 14px; border: 1px solid var(--border); border-radius: 10px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: flex-start; }
  </style>
</head>
<body>
  <header>
    <div class="logo-area">
      <div class="logo-badge">C</div>
      <div>
        <h1>CHD 课表管理中心</h1>
        <p class="subtitle" id="dbTypeDesc">学生用户量统计与通知公告分发服务 (Azure MySQL 云端驱动)</p>
      </div>
    </div>
    <div>
      <button class="btn" style="width: auto;" onclick="loadStats()">刷新数据</button>
    </div>
  </header>

  <div class="metrics-grid">
    <div class="metric-card">
      <div class="metric-title">累计使用总学生数</div>
      <div class="metric-value" id="totalUsers">-</div>
      <div class="metric-tag tag-blue">去重学号登记</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">今日活跃人数</div>
      <div class="metric-value" id="todayActive">-</div>
      <div class="metric-tag tag-green">实时在线统计</div>
    </div>
    <div class="metric-card">
      <div class="metric-title">近 7 天活跃度</div>
      <div class="metric-value" id="weekActive">-</div>
      <div class="metric-tag tag-blue">周留存指标</div>
    </div>
  </div>

  <div class="layout-cols">
    <div>
      <div class="card">
        <div class="card-title">最近活跃学生列表 (前 50 名)</div>
        <div style="overflow-x: auto;">
          <table>
            <thead>
              <tr>
                <th>学号</th>
                <th>姓名</th>
                <th>学院 / 专业</th>
                <th>校区</th>
                <th>最后活跃时间</th>
                <th>频次</th>
              </tr>
            </thead>
            <tbody id="userTableBody">
              <tr><td colspan="6" style="text-align: center; color: var(--text-muted);">正在载入数据...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div>
      <div class="card">
        <div class="card-title">📢 发布新通知 / 更新公告</div>
        <form id="annForm" onsubmit="publishAnnouncement(event)">
          <div class="form-group">
            <label>公告标题</label>
            <input type="text" id="annTitle" placeholder="例如：课表系统 v1.1 更新提醒" required>
          </div>
          <div class="form-group">
            <label>通知正文</label>
            <textarea id="annContent" rows="3" placeholder="请输入通知公告详情..." required></textarea>
          </div>
          <div class="form-group">
            <label>通知类型</label>
            <select id="annType">
              <option value="notice">普通通知 (notice)</option>
              <option value="update">应用版本升级 (update)</option>
              <option value="warning">重要紧急提醒 (warning)</option>
            </select>
          </div>
          <div class="form-group" style="display: flex; gap: 8px; align-items: center;">
            <input type="checkbox" id="annPopup" checked style="width: 16px; height: 16px;">
            <label for="annPopup" style="margin: 0; cursor: pointer;">启动时居中弹窗提醒</label>
          </div>
          <div class="form-group">
            <label>安装包下载链接 (可选)</label>
            <input type="url" id="annUrl" placeholder="如需推送新安装包直链请填此处">
          </div>
          <button type="submit" class="btn">🚀 立即推送给所有用户</button>
        </form>
      </div>

      <div class="card">
        <div class="card-title">已生效的公告列表</div>
        <div id="annList">正在载入公告...</div>
      </div>
    </div>
  </div>

  <script>
    async function loadStats() {
      try {
        const res = await fetch('/api/admin/stats');
        const data = await res.json();
        document.getElementById('totalUsers').innerText = data.total_users;
        document.getElementById('todayActive').innerText = data.today_active;
        document.getElementById('weekActive').innerText = data.week_active;
        document.getElementById('dbTypeDesc').innerText = `学生用户量统计与通知公告分发服务 (${data.db_type === 'mysql' ? 'Azure MySQL 云端驱动' : '本地 SQLite 保底'})`;

        const tbody = document.getElementById('userTableBody');
        if (!data.users || data.users.length === 0) {
          tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #94A3B8; padding: 24px;">暂无学生使用记录</td></tr>';
        } else {
          tbody.innerHTML = data.users.map(u => `
            <tr>
              <td><strong>${u.student_id}</strong></td>
              <td>${u.name || '-'}</td>
              <td>${u.college ? u.college + ' ' + (u.major || '') : '-'}</td>
              <td><span class="badge badge-primary">${u.campus || '渭水校区'}</span></td>
              <td style="color: #64748B;">${u.last_seen}</td>
              <td><strong>${u.heartbeat_count}</strong> 次</td>
            </tr>
          `).join('');
        }

        const annContainer = document.getElementById('annList');
        const activeAnns = (data.announcements || []).filter(a => a.is_active);
        if (activeAnns.length === 0) {
          annContainer.innerHTML = '<p style="color: #94A3B8; font-size: 13px;">暂无发布中的公告</p>';
        } else {
          annContainer.innerHTML = activeAnns.map(a => `
            <div class="ann-item">
              <div>
                <strong style="font-size: 13px;">${a.title}</strong>
                <p style="font-size: 12px; color: #64748B; margin: 4px 0;">${a.content}</p>
                <div style="font-size: 11px; color: #94A3B8;">${a.created_at} · ${a.is_popup ? '弹窗提醒' : '静默通知'}</div>
              </div>
              <button class="del-btn" onclick="deleteAnnouncement(${a.id})">下架</button>
            </div>
          `).join('');
        }
      } catch (e) {
        console.error(e);
      }
    }

    async function publishAnnouncement(e) {
      e.preventDefault();
      const payload = {
        title: document.getElementById('annTitle').value.trim(),
        content: document.getElementById('annContent').value.trim(),
        type: document.getElementById('annType').value,
        is_popup: document.getElementById('annPopup').checked,
        download_url: document.getElementById('annUrl').value.trim()
      };
      const res = await fetch('/api/admin/announcements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        alert('公告发布成功！所有学生 App 启动时即可接收。');
        document.getElementById('annForm').reset();
        loadStats();
      }
    }

    async function deleteAnnouncement(id) {
      if (!confirm('确定要下架此公告吗？')) return;
      await fetch('/api/admin/announcements/' + id, { method: 'DELETE' });
      loadStats();
    }

    loadStats();
    setInterval(loadStats, 10000);
  </script>
</body>
</html>
"""
