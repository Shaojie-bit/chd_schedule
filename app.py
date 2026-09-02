"""
长安大学现代化课表与教务信息聚合系统 - Web 服务
FastAPI + Uvicorn
"""

import os
import uuid
import base64
from datetime import date, datetime
from typing import Optional, Dict
from fastapi import FastAPI, HTTPException, Response, Request, Header
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, Response
from pydantic import BaseModel

from chd_auth import CHDAuthSession
from chd_eams import CHDEamsClient
from calendar_export import generate_ics_calendar

app = FastAPI(title="长安大学现代教务课表系统")

# 静态资源与持久化缓存路径
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
CACHE_DIR = os.path.join(os.path.dirname(__file__), "data_cache")
os.makedirs(STATIC_DIR, exist_ok=True)
os.makedirs(CACHE_DIR, exist_ok=True)

COOKIE_CACHE_FILE = os.path.join(CACHE_DIR, "session_cookies.json")
GRADES_CACHE_FILE = os.path.join(CACHE_DIR, "grades_cache.json")
OFFLINE_DATA_FILE = os.path.join(CACHE_DIR, "offline_data.json")

import json

def load_json_cache(filepath: str) -> Optional[dict]:
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return None
    return None

def save_json_cache(filepath: str, data: dict):
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print("Save cache error:", e)

# 内存会话管理映射 token -> {auth, eams, user_info, cached_tables}
SESSION_STORE: Dict[str, Dict] = {}

class LoginRequest(BaseModel):
    username: str
    password: str
    captcha: Optional[str] = ""

def get_client(token: Optional[str]) -> Optional[Dict]:
    if not token or token not in SESSION_STORE:
        # 如果内存中没有，但磁盘上有离线缓存与Cookie，尝试免密免登录自动恢复！
        saved_cookies = load_json_cache(COOKIE_CACHE_FILE)
        offline_data = load_json_cache(OFFLINE_DATA_FILE)
        if saved_cookies and offline_data:
            auth = CHDAuthSession()
            auth.import_cookies(saved_cookies)
            eams = CHDEamsClient(auth.session)
            SESSION_STORE[token or "default_token"] = {
                "auth": auth,
                "eams": eams,
                "user_info": offline_data.get("user", {}),
                "sem_ctx": {"semesters": offline_data.get("semesters", []), "std_id": offline_data.get("user", {}).get("student_id", "")},
                "cached_tables": {offline_data.get("current_semester_id", "262"): offline_data.get("course_data", {})},
                "updated_at": datetime.now()
            }
            return SESSION_STORE[token or "default_token"]
        return None
    return SESSION_STORE[token]

@app.post("/api/login")
async def login(req: LoginRequest):
    auth = CHDAuthSession()
    
    # 1. 优先尝试复用已保存的会话 Cookie，免除重复认证，防止账号被风控冻结！
    saved_cookies = load_json_cache(COOKIE_CACHE_FILE)
    session_reused = False
    if saved_cookies:
        auth.import_cookies(saved_cookies)
        if auth.is_session_alive():
            session_reused = True
            print(">>> 成功复用已有会话 Cookie，无需重新向 IDS 发起认证！<<<")

    # 2. 如果 Cookie 失效或不存在，才发起真实登录
    if not session_reused:
        res = auth.login(req.username, req.password, req.captcha or "")
        if not res.get("success"):
            return {
                "success": False,
                "message": res.get("message", "登录失败"),
                "need_captcha": res.get("need_captcha", False)
            }
        # 登录成功，立即保存 Cookie 到磁盘
        save_json_cache(COOKIE_CACHE_FILE, auth.export_cookies())

    # 3. 初始化 EAMS 客户端与基础信息
    token = str(uuid.uuid4())
    eams = CHDEamsClient(auth.session)
    
    # 检查离线缓存是否存在
    offline_data = load_json_cache(OFFLINE_DATA_FILE)
    if offline_data and session_reused:
        std_info = offline_data.get("user")
        sem_ctx = {"semesters": offline_data.get("semesters", []), "current_semester_id": offline_data.get("current_semester_id", "262")}
        curr_sem = offline_data.get("current_semester_id", "262")
        table_data = offline_data.get("course_data")
    else:
        std_info = eams.get_student_detail()
        sem_ctx = eams.get_semesters_and_context()
        curr_sem = sem_ctx.get("current_semester_id", "262")
        std_id = sem_ctx.get("std_id", "")
        table_data = eams.get_course_table(curr_sem, std_id)

        # 写入持久化离线缓存
        save_json_cache(OFFLINE_DATA_FILE, {
            "user": std_info,
            "semesters": sem_ctx.get("semesters", []),
            "current_semester_id": curr_sem,
            "course_data": table_data
        })

    SESSION_STORE[token] = {
        "auth": auth,
        "eams": eams,
        "user_info": std_info,
        "sem_ctx": sem_ctx,
        "cached_tables": {curr_sem: table_data},
        "updated_at": datetime.now()
    }

    return {
        "success": True,
        "token": token,
        "user": std_info,
        "current_semester_id": curr_sem,
        "semesters": sem_ctx.get("semesters", []),
        "course_data": table_data
    }

@app.get("/api/captcha")
async def get_captcha(username: str = ""):
    auth = CHDAuthSession()
    need = auth.check_need_captcha(username) if username else False
    img_b64 = ""
    if need:
        img_bytes = auth.get_captcha_image()
        img_b64 = base64.b64encode(img_bytes).decode('utf-8')
    return {"need_captcha": need, "image": img_b64}

@app.get("/api/schedule")
async def get_schedule(semester_id: str, token: Optional[str] = Header(None, alias="X-Auth-Token")):
    client_ctx = get_client(token)
    if not client_ctx:
        raise HTTPException(status_code=401, detail="请先登录")
    
    eams: CHDEamsClient = client_ctx["eams"]
    sem_ctx = client_ctx["sem_ctx"]
    std_id = sem_ctx.get("std_id", "")

    # 检查内存缓存
    if semester_id in client_ctx["cached_tables"]:
        return client_ctx["cached_tables"][semester_id]

    data = eams.get_course_table(semester_id, std_id)
    client_ctx["cached_tables"][semester_id] = data
    return data

@app.get("/api/grades")
async def get_grades(
    semester_id: Optional[str] = None,
    force_refresh: bool = False,
    token: Optional[str] = Header(None, alias="X-Auth-Token")
):
    # 如果不强制刷新，优先返回磁盘持久化缓存，毫秒级响应且零风控风险
    cached = load_json_cache(GRADES_CACHE_FILE)
    if cached and not force_refresh:
        return cached

    client_ctx = get_client(token)
    if not client_ctx:
        # 如果有缓存哪怕 token 失效也直接返回缓存
        if cached:
            return cached
        raise HTTPException(status_code=401, detail="请先登录")
    
    eams: CHDEamsClient = client_ctx["eams"]
    fresh_grades = eams.get_grades(semester_id)
    
    if fresh_grades.get("success"):
        save_json_cache(GRADES_CACHE_FILE, fresh_grades)
    
    return fresh_grades

@app.get("/api/exams")
async def get_exams(token: Optional[str] = Header(None, alias="X-Auth-Token")):
    client_ctx = get_client(token)
    if not client_ctx:
        raise HTTPException(status_code=401, detail="请先登录")
    
    eams: CHDEamsClient = client_ctx["eams"]
    return eams.get_exams()

@app.get("/api/export/ics")
async def export_ics(
    semester_id: str,
    term_start: str = "2026-08-31",
    token: Optional[str] = Header(None, alias="X-Auth-Token")
):
    client_ctx = get_client(token)
    if not client_ctx:
        raise HTTPException(status_code=401, detail="请先登录")

    eams: CHDEamsClient = client_ctx["eams"]
    sem_ctx = client_ctx["sem_ctx"]
    std_id = sem_ctx.get("std_id", "")

    data = client_ctx["cached_tables"].get(semester_id)
    if not data:
        data = eams.get_course_table(semester_id, std_id)
        client_ctx["cached_tables"][semester_id] = data

    courses = data.get("courses", [])

    try:
        start_date = datetime.strptime(term_start, "%Y-%m-%d").date()
    except Exception:
        start_date = date(2026, 8, 31)

    ics_content = generate_ics_calendar(courses, start_date)

    headers = {
        "Content-Disposition": f'attachment; filename="CHD_Course_{semester_id}.ics"',
        "Content-Type": "text/calendar; charset=utf-8"
    }
    return Response(content=ics_content, media_type="text/calendar", headers=headers)

@app.post("/api/logout")
async def logout(token: Optional[str] = Header(None, alias="X-Auth-Token")):
    if token and token in SESSION_STORE:
        del SESSION_STORE[token]
    return {"success": True}

# 挂载静态文件
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

@app.get("/")
async def index():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
