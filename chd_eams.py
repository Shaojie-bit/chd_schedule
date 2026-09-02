"""
长安大学教务系统 (EAMS) 数据抓取与解析器
解析学生课表 (TaskActivity)、学期列表、学籍信息、成绩与考表
"""

import re
import requests
from bs4 import BeautifulSoup
from typing import Dict, List, Any, Optional

WEEKDAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

# 经典马卡龙/柔和高质感课程调色盘 (优雅、现代、互不冲突)
PRESET_COLORS = [
    {"bg": "#E8F0FE", "text": "#1A73E8", "border": "#AECBFA", "gradient": "linear-gradient(135deg, #E8F0FE 0%, #D2E3FC 100%)"},
    {"bg": "#FEF7E0", "text": "#B06000", "border": "#FDD663", "gradient": "linear-gradient(135deg, #FEF7E0 0%, #FCE8E6 100%)"},
    {"bg": "#E6F4EA", "text": "#137333", "border": "#CEEAD6", "gradient": "linear-gradient(135deg, #E6F4EA 0%, #CEEAD6 100%)"},
    {"bg": "#FCE8E6", "text": "#C5221F", "border": "#FAD2CF", "gradient": "linear-gradient(135deg, #FCE8E6 0%, #FAD2CF 100%)"},
    {"bg": "#F3E8FD", "text": "#8430CE", "border": "#D7AEFB", "gradient": "linear-gradient(135deg, #F3E8FD 0%, #E8D0FB 100%)"},
    {"bg": "#E0F2F1", "text": "#00796B", "border": "#80CBC4", "gradient": "linear-gradient(135deg, #E0F2F1 0%, #B2DFDB 100%)"},
    {"bg": "#FFF3E0", "text": "#E65100", "border": "#FFCC80", "gradient": "linear-gradient(135deg, #FFF3E0 0%, #FFE0B2 100%)"},
    {"bg": "#F1F8E9", "text": "#33691E", "border": "#C5E1A5", "gradient": "linear-gradient(135deg, #F1F8E9 0%, #DCEDC8 100%)"},
    {"bg": "#EDE7F6", "text": "#4527A0", "border": "#B39DDB", "gradient": "linear-gradient(135deg, #EDE7F6 0%, #D1C4E9 100%)"},
    {"bg": "#FCE4EC", "text": "#C2185B", "border": "#F48FB1", "gradient": "linear-gradient(135deg, #FCE4EC 0%, #F8BBD0 100%)"},
]

def _format_room_name(room: str) -> str:
    """美化教室名称显示"""
    if not room:
        return "地点待定"
    name = room.lstrip('*')
    if name.startswith('WX'):
        return f"渭水 {name[2:]}"
    elif name.startswith('HQ'):
        return f"本部 {name[2:]}"
    return name

class CHDEamsClient:
    def __init__(self, session: requests.Session):
        self.session = session
        self.base_url = 'http://bkjw.chd.edu.cn/eams'

    def get_student_detail(self) -> Dict[str, Any]:
        """获取学生学籍信息"""
        try:
            res = self.session.get(f'{self.base_url}/stdDetail.action', timeout=8)
            res.encoding = 'utf-8'
            soup = BeautifulSoup(res.text, 'html.parser')
            
            detail = {
                "name": "",
                "student_id": "",
                "college": "",
                "major": "",
                "grade": "",
                "campus": "",
                "class_name": "",
                "study_years": "4",
                "status": "在校"
            }
            
            for tr in soup.find_all('tr'):
                tds = [td.get_text(" ", strip=True) for td in tr.find_all(['td', 'th'])]
                for i, text in enumerate(tds):
                    if '姓名：' in text and i + 1 < len(tds):
                        detail['name'] = tds[i+1].split()[0]
                    elif '学号：' in text and i + 1 < len(tds):
                        detail['student_id'] = tds[i+1].split()[0]
                    elif '院系：' in text and i + 1 < len(tds):
                        detail['college'] = tds[i+1].split()[0]
                    elif '专业：' in text and i + 1 < len(tds):
                        detail['major'] = tds[i+1].split()[0]
                    elif '所在年级：' in text and i + 1 < len(tds):
                        detail['grade'] = tds[i+1].split()[0]
                    elif '所属校区：' in text and i + 1 < len(tds):
                        detail['campus'] = tds[i+1].split()[0]
                    elif '行政班级：' in text and i + 1 < len(tds):
                        detail['class_name'] = tds[i+1].split()[0]
                    elif '学制：' in text and i + 1 < len(tds):
                        detail['study_years'] = tds[i+1].split()[0]

            # 备用容错：如果表格解析为空，从正则寻找
            if not detail['name']:
                m_name = re.search(r'姓名[：:]\s*([^\s<]+)', res.text)
                if m_name: detail['name'] = m_name.group(1)
            if not detail['student_id']:
                m_id = re.search(r'学号[：:]\s*(\d+)', res.text)
                if m_id: detail['student_id'] = m_id.group(1)

            return detail
        except Exception as e:
            return {"error": str(e), "name": "同学"}

    def get_semesters_and_context(self) -> Dict[str, Any]:
        """获取学期列表及当前学生内部系统 ID"""
        try:
            # 1. 访问父页面以初始化上下文并提取当前 semesterId 和 stdId
            res = self.session.get(f'{self.base_url}/courseTableForStd.action', timeout=10)
            res.encoding = 'utf-8'
            html = res.text

            # 提取默认 semesterId
            curr_semester_id = "262"
            m_sem = re.search(r'value:\s*["\'](\d+)["\']', html)
            if m_sem:
                curr_semester_id = m_sem.group(1)

            # 提取学生内部 ID (ids)
            std_id = ""
            m_std = re.search(r'bg\.form\.addInput\(form,\s*["\']ids["\'],\s*["\'](\d+)["\']\)', html)
            if m_std:
                std_id = m_std.group(1)

            # 2. 查询所有学期列表
            dq_res = self.session.post(
                f'{self.base_url}/dataQuery.action',
                data={'dataType': 'semester'},
                timeout=8
            )
            dq_res.encoding = 'utf-8'
            soup = BeautifulSoup(dq_res.text, 'html.parser')
            
            semesters = []
            for opt in soup.find_all('option'):
                sem_id = opt.get('value')
                sem_name = opt.get_text(strip=True)
                if sem_id and sem_name:
                    semesters.append({
                        "id": sem_id,
                        "name": sem_name,
                        "is_current": (sem_id == curr_semester_id)
                    })

            # 如果学期列表为空，提供默认安全保底
            if not semesters:
                semesters = [
                    {"id": "262", "name": "2026-2027学年1学期", "is_current": True},
                    {"id": "242", "name": "2025-2026学年2学期", "is_current": False},
                    {"id": "222", "name": "2025-2026学年1学期", "is_current": False}
                ]

            return {
                "semesters": semesters,
                "current_semester_id": curr_semester_id,
                "std_id": std_id
            }
        except Exception as e:
            return {
                "semesters": [{"id": "262", "name": "2026-2027学年1学期", "is_current": True}],
                "current_semester_id": "262",
                "std_id": "",
                "error": str(e)
            }

    def get_course_table(self, semester_id: str = "262", std_id: str = "") -> Dict[str, Any]:
        """获取并解析指定学期的全套课表数据"""
        try:
            # 如果 std_id 为空，先获取 context
            if not std_id:
                ctx = self.get_semesters_and_context()
                std_id = ctx.get('std_id', '')

            post_data = {
                'ignoreHead': '1',
                'setting.kind': 'std',
                'startWeek': '',
                'semester.id': semester_id,
                'ids': std_id
            }

            res = self.session.post(
                f'{self.base_url}/courseTableForStd!courseTable.action',
                data=post_data,
                timeout=12
            )
            res.encoding = 'utf-8'
            html = res.text

            # 1. 解析课程列表表格（学分、类型、考核等元数据）
            soup = BeautifulSoup(html, 'html.parser')
            course_meta_map = {}
            tbl_meta = soup.find('table', id=lambda x: x and x.startswith('grid'))
            if tbl_meta:
                for row in tbl_meta.find_all('tr')[1:]:
                    cols = [td.get_text(strip=True) for td in row.find_all('td')]
                    if len(cols) >= 10:
                        code = cols[2]
                        name = cols[3]
                        credits = cols[5]
                        category = cols[4]
                        weeks_desc = cols[8]
                        teachers = cols[9]
                        course_meta_map[code] = {
                            "code": code,
                            "name": name,
                            "credits": credits,
                            "category": category,
                            "weeks_desc": weeks_desc,
                            "teachers": teachers
                        }

            # 2. 解析脚本中的 TaskActivity
            # 格式：activity = new TaskActivity(...)
            # index = day * unitCount + period;
            raw_activities = []
            
            # 分割 course block
            blocks = re.findall(
                r'var teachers = (\[.*?\]);.*?var courseName = "(.*?)";(.*?)(?=var teachers =|var table0 =|$)',
                html,
                re.DOTALL
            )

            color_map = {}
            color_index = 0

            for teachers_json, raw_course_name, act_body in blocks:
                clean_name = re.sub(r'\(.*?\)$', '', raw_course_name).strip()
                if clean_name not in color_map:
                    color_map[clean_name] = PRESET_COLORS[color_index % len(PRESET_COLORS)]
                    color_index += 1

                # 提取老师名字
                t_names = re.findall(r'name:\s*"([^"]+)"', teachers_json)
                teachers_str = ', '.join(dict.fromkeys(t_names))

                act_matches = re.findall(
                    r'activity = new TaskActivity\((.*?)\);(.*?)(?=activity = new TaskActivity|$)',
                    act_body,
                    re.DOTALL
                )

                for args_str, slot_body in act_matches:
                    # 匹配教室与周掩码: "roomName", "011111111000..."
                    room_match = re.search(r'"(\*?[^"]*)",\s*"([01]+)"', args_str)
                    raw_room = room_match.group(1) if room_match else ""
                    v_weeks = room_match.group(2) if room_match else ""
                    
                    # 课程代码
                    code_match = re.search(r'"([A-Za-z0-9_\.]+)"', args_str)
                    course_code = code_match.group(1) if code_match else ""

                    # 解析周次掩码
                    active_weeks = [w for w, bit in enumerate(v_weeks) if bit == '1' and w > 0]
                    if not active_weeks:
                        continue

                    # 解析时间槽位: index = day * unitCount + period
                    slots = re.findall(r'index =(\d+)\*unitCount\+(\d+);', slot_body)
                    if not slots:
                        continue

                    # 按星期分组槽位
                    day_to_periods = {}
                    for d_str, p_str in slots:
                        d = int(d_str)
                        p = int(p_str) + 1  # 转化为 1 索引节次 (1~11)
                        day_to_periods.setdefault(d, []).append(p)

                    meta = course_meta_map.get(course_code, {})

                    for day, periods in day_to_periods.items():
                        periods = sorted(periods)
                        start_period = periods[0]
                        end_period = periods[-1]
                        span = len(periods)

                        raw_activities.append({
                            "course_name": clean_name,
                            "full_name": raw_course_name,
                            "course_code": course_code,
                            "teachers": teachers_str or meta.get('teachers', '主讲教师'),
                            "room": _format_room_name(raw_room),
                            "raw_room": raw_room,
                            "day": day,                       # 0=周一, 6=周日
                            "day_name": WEEKDAY_NAMES[day] if 0 <= day < 7 else f"周{day}",
                            "start_period": start_period,     # 比如第3节
                            "end_period": end_period,         # 比如第4节
                            "period_span": span,              # 连上几节
                            "periods": periods,
                            "period_desc": f"第{start_period}-{end_period}节" if start_period != end_period else f"第{start_period}节",
                            "weeks": active_weeks,
                            "weeks_str": f"{active_weeks[0]}-{active_weeks[-1]}周" if active_weeks else "",
                            "credits": meta.get('credits', '2'),
                            "category": meta.get('category', '专业课程'),
                            "color": color_map[clean_name]
                        })

            # 计算最大周次（通常为 16~20 周）
            max_week = 20
            all_weeks = [w for act in raw_activities for w in act['weeks']]
            if all_weeks:
                max_week = max(max(all_weeks), 18)

            return {
                "success": True,
                "semester_id": semester_id,
                "max_weeks": max_week,
                "courses": raw_activities,
                "course_meta": list(course_meta_map.values())
            }
        except Exception as e:
            return {"success": False, "error": str(e), "courses": []}

    def get_grades(self, semester_id: Optional[str] = None) -> Dict[str, Any]:
        """获取学生学期 GPA 概览及每门课的具体详细成绩清单"""
        try:
            # 1. 抓取各学期汇总 (GPA, 总学分, 门数)
            url_history = f'{self.base_url}/teach/grade/course/person!historyCourseGrade.action?projectType='
            res_history = self.session.post(url_history, timeout=10)
            res_history.encoding = 'utf-8'
            soup_history = BeautifulSoup(res_history.text, 'html.parser')
            
            history_summary = []
            tbl_hist = soup_history.find('table', class_='gridtable')
            if tbl_hist:
                for row in tbl_hist.find_all('tr')[1:]:
                    cols = [td.get_text(strip=True) for td in row.find_all('td')]
                    if len(cols) >= 5:
                        history_summary.append({
                            "academic_year": cols[0],
                            "term": cols[1],
                            "term_display": f"{cols[0]} 第{cols[1]}学期",
                            "course_count": cols[2],
                            "total_credits": cols[3],
                            "gpa": cols[4]
                        })

            # 2. 抓取各学期详细课程成绩清单
            sem_map = {
                "162": "2023-2024学年1学期",
                "182": "2023-2024学年2学期",
                "202": "2024-2025学年1学期",
                "203": "2024-2025学年2学期",
                "222": "2025-2026学年1学期",
                "242": "2025-2026学年2学期",
                "262": "2026-2027学年1学期"
            }

            target_semesters = [semester_id] if semester_id and semester_id != 'all' else list(sem_map.keys())

            course_grades = []
            for s_id in target_semesters:
                url_search = f'{self.base_url}/teach/grade/course/person!search.action?semesterId={s_id}&projectType='
                res_search = self.session.get(url_search, timeout=8)
                res_search.encoding = 'utf-8'
                soup_search = BeautifulSoup(res_search.text, 'html.parser')
                
                tbl_search = soup_search.find('table', class_='gridtable')
                if tbl_search:
                    headers = [th.get_text(strip=True) for th in tbl_search.find_all('th')]
                    h_map = {h: idx for idx, h in enumerate(headers)}
                    
                    rows = tbl_search.find_all('tr')[1:]
                    for tr in rows:
                        tds = [td.get_text(strip=True) for td in tr.find_all('td')]
                        if len(tds) < len(headers):
                            continue
                        
                        term_text = tds[h_map.get('学年学期', 0)] if '学年学期' in h_map else sem_map.get(s_id, '')
                        c_name = tds[h_map['课程名称']] if '课程名称' in h_map else ''
                        c_code = tds[h_map['课程代码']] if '课程代码' in h_map else ''
                        c_cat = tds[h_map.get('课程类别', -1)] if '课程类别' in h_map else '课程'
                        c_credit = tds[h_map.get('学分', -1)] if '学分' in h_map else '0'
                        
                        # 成绩可能在 '最终' 或 '总评成绩'
                        score = ''
                        for key in ['最终', '总评成绩', '期末成绩']:
                            if key in h_map and h_map[key] < len(tds) and tds[h_map[key]]:
                                score = tds[h_map[key]]
                                break
                        
                        gpa = tds[h_map['绩点']] if '绩点' in h_map and h_map['绩点'] < len(tds) else ''
                        usual = tds[h_map['平时成绩']] if '平时成绩' in h_map and h_map['平时成绩'] < len(tds) else ''
                        exam = tds[h_map['期末成绩']] if '期末成绩' in h_map and h_map['期末成绩'] < len(tds) else ''
                        mid = tds[h_map['期中成绩']] if '期中成绩' in h_map and h_map['期中成绩'] < len(tds) else ''

                        if c_name:
                            course_grades.append({
                                "semester_id": s_id,
                                "semester_name": sem_map.get(s_id, term_text),
                                "term": term_text,
                                "course_name": c_name,
                                "course_code": c_code,
                                "category": c_cat,
                                "credits": c_credit,
                                "score": score,
                                "gpa": gpa,
                                "usual_score": usual,
                                "exam_score": exam,
                                "mid_score": mid
                            })

            return {
                "success": True,
                "summary": history_summary,
                "course_grades": course_grades,
                "total_courses": len(course_grades)
            }
        except Exception as e:
            return {"success": False, "error": str(e), "summary": [], "course_grades": []}

    def get_exams(self) -> Dict[str, Any]:
        """获取学生考试日程"""
        try:
            url = f'{self.base_url}/stdExamTable.action'
            res = self.session.get(url, timeout=8)
            res.encoding = 'utf-8'
            soup = BeautifulSoup(res.text, 'html.parser')
            
            exams = []
            for row in soup.find_all('tr'):
                tds = [td.get_text(strip=True) for td in row.find_all('td')]
                if len(tds) >= 6 and any(k in tds[1] for k in ['课', '学', '法', '语', '工程', '政治', '论文']):
                    exams.append({
                        "code": tds[0],
                        "name": tds[1],
                        "category": tds[2],
                        "time": tds[4] if len(tds) > 4 else "待定",
                        "location": tds[5] if len(tds) > 5 else "待定"
                    })
            return {"success": True, "exams": exams}
        except Exception as e:
            return {"success": False, "error": str(e), "exams": []}
