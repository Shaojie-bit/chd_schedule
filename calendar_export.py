"""
长安大学 iCalendar (.ics) 日历导出生成器
支持导入 iOS / Android (华为/小米/OPPO/vivo) / Outlook / Google Calendar
自带上课前 20 分钟提醒
"""

import uuid
from datetime import datetime, timedelta, date, time
from typing import List, Dict, Any

# 长安大学常规作息时间表（节次与具体时间对应）
PERIOD_TIMES = {
    1: (time(8, 0), time(8, 45)),
    2: (time(8, 50), time(9, 35)),
    3: (time(10, 5), time(10, 50)),
    4: (time(10, 55), time(11, 40)),
    5: (time(14, 0), time(14, 45)),
    6: (time(14, 50), time(15, 35)),
    7: (time(16, 0), time(16, 45)),
    8: (time(16, 50), time(17, 35)),
    9: (time(19, 0), time(19, 45)),
    10: (time(19, 50), time(20, 35)),
    11: (time(20, 40), time(21, 25)),
}

def generate_ics_calendar(
    courses: List[Dict[str, Any]],
    term_start_monday: date,
    calendar_name: str = "长安大学课程表",
    alarm_minutes: int = 20
) -> str:
    """根据课程列表生成 RFC 5545 标准 .ics 文本"""
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CHD Modern Timetable//CN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        f"X-WR-CALNAME:{calendar_name}",
        "X-WR-TIMEZONE:Asia/Shanghai",
        "BEGIN:VTIMEZONE",
        "TZID:Asia/Shanghai",
        "BEGIN:STANDARD",
        "TZOFFSETFROM:+0800",
        "TZOFFSETTO:+0800",
        "DTSTART:19700101T000000",
        "END:STANDARD",
        "END:VTIMEZONE"
    ]

    now_stamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    for course in courses:
        start_p = course.get("start_period", 1)
        end_p = course.get("end_period", start_p)
        day_offset = course.get("day", 0)  # 0=周一, 6=周日

        # 获取起止时间
        t_start = PERIOD_TIMES.get(start_p, (time(8, 0), time(8, 45)))[0]
        t_end = PERIOD_TIMES.get(end_p, (time(18, 0), time(18, 45)))[1]

        weeks = course.get("weeks", [])
        for w in weeks:
            # 计算当前周次当天的实际公历日期
            event_date = term_start_monday + timedelta(weeks=w - 1, days=day_offset)
            dt_start = datetime.combine(event_date, t_start)
            dt_end = datetime.combine(event_date, t_end)

            dt_start_str = dt_start.strftime("%Y%m%dT%H%M%S")
            dt_end_str = dt_end.strftime("%Y%m%dT%H%M%S")

            uid = f"{uuid.uuid4()}@chd.edu.cn"
            summary = course.get("course_name", "课程")
            location = course.get("room", "待定")
            teachers = course.get("teachers", "教师")
            desc = f"教师：{teachers}\\n节次：{course.get('period_desc', '')}\\n周次：第{w}周 (总{course.get('weeks_str', '')})\\n学分：{course.get('credits', '2')}"

            lines.extend([
                "BEGIN:VEVENT",
                f"UID:{uid}",
                f"DTSTAMP:{now_stamp}",
                f"SUMMARY:{summary}",
                f"LOCATION:{location}",
                f"DESCRIPTION:{desc}",
                f"DTSTART;TZID=Asia/Shanghai:{dt_start_str}",
                f"DTEND;TZID=Asia/Shanghai:{dt_end_str}",
                "STATUS:CONFIRMED"
            ])

            # 添加提前提醒
            if alarm_minutes > 0:
                lines.extend([
                    "BEGIN:VALARM",
                    "ACTION:DISPLAY",
                    f"DESCRIPTION:上课提醒：{summary}（{location}）",
                    f"TRIGGER:-PT{alarm_minutes}M",
                    "END:VALARM"
                ])

            lines.append("END:VEVENT")

    lines.append("END:VCALENDAR")
    return "\r\n".join(lines)
