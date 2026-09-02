import sys
from chd_auth import CHDAuthSession
from chd_eams import CHDEamsClient

username = sys.argv[1] if len(sys.argv) > 1 else input("请输入学号: ")
password = sys.argv[2] if len(sys.argv) > 2 else input("请输入密码: ")

auth = CHDAuthSession()
print("Testing login...")
res = auth.login(username, password)
print("Login result:", res)

if res['success']:
    eams = CHDEamsClient(auth.session)
    std = eams.get_student_detail()
    print("Student:", std)
    
    ctx = eams.get_semesters_and_context()
    print("Current semester:", ctx['current_semester_id'], "Semesters count:", len(ctx['semesters']))
    
    ct = eams.get_course_table(ctx['current_semester_id'], ctx['std_id'])
    print("Courses parsed count:", len(ct['courses']))
    for c in ct['courses']:
        print(f"  {c['course_name']} | {c['day_name']} {c['period_desc']} | {c['room']} | {c['weeks_str']} | {c['teachers']}")
