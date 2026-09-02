import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/course.dart';
import '../models/grade.dart';
import '../models/student.dart';

const List<String> presetColors = [
  '#4F46E5', // Indigo
  '#0D9488', // Teal
  '#E11D48', // Rose
  '#D97706', // Amber
  '#7C3AED', // Purple
  '#0284C7', // Sky
  '#059669', // Emerald
  '#DB2777', // Pink
  '#475569', // Slate
  '#CA8A04', // Yellow
];

class CHDEamsService {
  final Dio dio;
  final String baseUrl = 'http://bkjw.chd.edu.cn/eams';

  CHDEamsService(this.dio);

  /// 获取学生学籍信息
  Future<StudentProfile?> getStudentDetail() async {
    try {
      final res = await dio.get('$baseUrl/stdDetail.action');
      final doc = html_parser.parse(res.data);
      final profile = <String, String>{};

      for (final tr in doc.querySelectorAll('tr')) {
        final cells = tr.querySelectorAll('td, th').map((e) => e.text.trim()).toList();
        for (var i = 0; i < cells.length; i++) {
          final t = cells[i];
          if (t.contains('姓名') && i + 1 < cells.length) {
            profile['name'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('学号') && i + 1 < cells.length) {
            profile['student_id'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('院系') && i + 1 < cells.length) {
            profile['college'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('专业') && i + 1 < cells.length) {
            profile['major'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('年级') && i + 1 < cells.length) {
            profile['grade'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('校区') && i + 1 < cells.length) {
            profile['campus'] = cells[i + 1].split(' ').first.trim();
          } else if (t.contains('班级') && i + 1 < cells.length) {
            profile['class_name'] = cells[i + 1].split(' ').first.trim();
          }
        }
      }

      final html = res.data.toString();
      if ((profile['name'] ?? '').isEmpty) {
        final m = RegExp(r'姓名[：:]\s*([^\s<]+)').firstMatch(html);
        if (m != null) profile['name'] = m.group(1) ?? '';
      }
      if ((profile['student_id'] ?? '').isEmpty) {
        final m = RegExp(r'学号[：:]\s*(\d+)').firstMatch(html);
        if (m != null) profile['student_id'] = m.group(1) ?? '';
      }

      return StudentProfile(
        name: profile['name'] ?? '',
        studentId: profile['student_id'] ?? '',
        department: profile['college'] ?? '',
        major: profile['major'] ?? '',
        grade: profile['grade'] ?? '',
        campus: profile['campus'] ?? '',
        adminClass: profile['class_name'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取学期列表与上下文参数
  Future<Map<String, dynamic>> getSemestersAndContext() async {
    try {
      final initRes = await dio.get('$baseUrl/courseTableForStd.action');
      final html = initRes.data.toString();

      var currSem = '262';
      final mSem = RegExp(r'''value:\s*["'](\d+)["']''').firstMatch(html);
      if (mSem != null) {
        currSem = mSem.group(1) ?? '262';
      }

      // std_id 提取 (bg.form.addInput(form, "ids", "123456"))
      var stdId = '';
      final mStd = RegExp(r'''bg\.form\.addInput\(form,\s*["']ids["'],\s*["'](\d+)["']\)''')
          .firstMatch(html);
      if (mStd != null) {
        stdId = mStd.group(1) ?? '';
      } else {
        final idMatch = RegExp(r'ids",\s*"(\d+)"').firstMatch(html);
        if (idMatch != null) {
          stdId = idMatch.group(1) ?? '';
        }
      }

      final queryRes = await dio.post(
        '$baseUrl/dataQuery.action',
        data: {'dataType': 'semester'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final semesters = <SemesterInfo>[];
      final qDoc = html_parser.parse(queryRes.data);

      for (final opt in qDoc.querySelectorAll('option')) {
        final val = opt.attributes['value'] ?? '';
        final text = opt.text.trim();
        if (val.isNotEmpty && text.isNotEmpty) {
          semesters.add(SemesterInfo(id: val, name: text));
        }
      }

      if (semesters.isEmpty) {
        semesters.addAll([
          SemesterInfo(id: '262', name: '2026-2027学年1学期'),
          SemesterInfo(id: '242', name: '2025-2026学年2学期'),
          SemesterInfo(id: '222', name: '2025-2026学年1学期'),
          SemesterInfo(id: '203', name: '2024-2025学年2学期'),
          SemesterInfo(id: '202', name: '2024-2025学年1学期'),
          SemesterInfo(id: '182', name: '2023-2024学年2学期'),
          SemesterInfo(id: '162', name: '2023-2024学年1学期'),
        ]);
      }

      return {
        'current_semester_id': currSem,
        'std_id': stdId,
        'semesters': semesters,
      };
    } catch (_) {
      return {
        'current_semester_id': '262',
        'std_id': '',
        'semesters': <SemesterInfo>[
          SemesterInfo(id: '262', name: '2026-2027学年1学期'),
          SemesterInfo(id: '242', name: '2025-2026学年2学期'),
          SemesterInfo(id: '222', name: '2025-2026学年1学期'),
        ],
      };
    }
  }

  /// 获取并解析课程表
  Future<List<Course>> getCourseTable(String semesterId, String stdId) async {
    try {
      final formData = {
        'ignoreHead': '1',
        'setting.kind': 'std',
        'startWeek': '',
        'semester.id': semesterId,
        'ids': stdId,
      };

      final res = await dio.post(
        '$baseUrl/courseTableForStd!courseTable.action',
        data: formData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final html = res.data.toString();
      final doc = html_parser.parse(html);

      // 1. 解析底部表格课程元数据 (代码, 课程名, 学分, 类别, 周次描述, 教师)
      final metaMap = <String, Map<String, dynamic>>{};
      for (final row in doc.querySelectorAll('table.gridtable tr')) {
        final tds = row.querySelectorAll('td');
        if (tds.length >= 8) {
          final code = tds[1].text.trim();
          final name = tds[3].text.trim();
          final credits = tds[4].text.trim();
          final category = tds[5].text.trim();
          final weeksDesc = tds[6].text.trim();
          final teachers = tds[7].text.trim();

          if (name.isNotEmpty && code.isNotEmpty) {
            metaMap[name] = {
              'code': code,
              'name': name,
              'credits': credits,
              'category': category,
              'weeksDesc': weeksDesc,
              'teachers': teachers,
            };
          }
        }
      }

      // 2. 解析 TaskActivity 脚本块
      final colorMap = <String, String>{};
      var colorIdx = 0;
      final courseSlotMap = <String, List<CourseSlot>>{};
      final courseTeacherMap = <String, String>{};

      final blockRegex = RegExp(
        r'var teachers = (\[.*?\]);.*?var courseName = "(.*?)";(.*?)(?=var teachers =|var table0 =|$)',
        dotAll: true,
      );

      for (final match in blockRegex.allMatches(html)) {
        final teachersJson = match.group(1) ?? '';
        final rawCourseName = match.group(2) ?? '';
        final actBody = match.group(3) ?? '';
        final cleanName =
            rawCourseName.replaceAll(RegExp(r'\(.*?\)'), '').trim();

        // 提取精确任课教师姓名
        final tNames = RegExp(r'name:\s*"([^"]+)"')
            .allMatches(teachersJson)
            .map((m) => m.group(1)!)
            .where((n) => n.isNotEmpty)
            .toSet()
            .join(', ');
        if (tNames.isNotEmpty) {
          courseTeacherMap[cleanName] = tNames;
        }

        if (!colorMap.containsKey(cleanName)) {
          colorMap[cleanName] = presetColors[colorIdx % presetColors.length];
          colorIdx++;
        }

        final actMatches = RegExp(
          r'activity = new TaskActivity\((.*?)\);(.*?)(?=activity = new TaskActivity|$)',
          dotAll: true,
        ).allMatches(actBody);

        for (final act in actMatches) {
          final argsStr = act.group(1) ?? '';
          final slotBody = act.group(2) ?? '';

          // 匹配地点与周掩码: "roomName", "0111111..."
          final roomMatch =
              RegExp(r'"(\*?[^"]*)",\s*"([01]+)"').firstMatch(argsStr);
          final rawRoom = roomMatch?.group(1) ?? '';
          final vWeeks = roomMatch?.group(2) ?? '';

          // 周次解析
          final activeWeeks = <int>[];
          for (var w = 1; w < vWeeks.length; w++) {
            if (vWeeks[w] == '1') activeWeeks.add(w);
          }
          if (activeWeeks.isEmpty) continue;

          // 时间槽位解析 index = day * unitCount + period
          final slotMatches = RegExp(r'index =(\d+)\*unitCount\+(\d+);')
              .allMatches(slotBody);
          if (slotMatches.isEmpty) continue;

          final periods = <int>[];
          var day = 0;
          for (final s in slotMatches) {
            day = int.parse(s.group(1)!);
            periods.add(int.parse(s.group(2)!));
          }
          periods.sort();

          final dayOfWeek = day + 1; // 0->Mon (1)
          final startPeriod = periods.first + 1; // 0->Period 1
          final periodCount = periods.length;

          // 清理地点：去除前导 * 号，完整保留 WX 编号（如 WX2304、WX2301）
          final roomClean = rawRoom.replaceAll('*', '').trim();

          final slot = CourseSlot(
            dayOfWeek: dayOfWeek,
            startPeriod: startPeriod,
            periodCount: periodCount,
            room: roomClean,
            weeks: activeWeeks,
          );

          courseSlotMap.putIfAbsent(cleanName, () => []).add(slot);
        }
      }

      // 组装最终课程列表
      final courses = <Course>[];
      var cId = 1;

      courseSlotMap.forEach((name, slots) {
        final meta = metaMap[name] ?? {};
        final parsedTeacher = courseTeacherMap[name];
        final metaTeacher = meta['teachers'] as String? ?? '';
        final finalTeacher = (parsedTeacher != null && parsedTeacher.isNotEmpty)
            ? parsedTeacher
            : (metaTeacher.isNotEmpty && metaTeacher != '待定' ? metaTeacher : '待定');

        courses.add(Course(
          id: 'c_${cId++}',
          code: meta['code'] as String? ?? '',
          name: name,
          credits: meta['credits'] as String? ?? '',
          category: meta['category'] as String? ?? '',
          teachers: finalTeacher,
          weeksDesc: meta['weeksDesc'] as String? ?? '',
          slots: slots,
          colorHex: colorMap[name] ?? '#4F46E5',
        ));
      });

      return courses;
    } catch (_) {
      return [];
    }
  }

  /// 获取学期 GPA 概览及每门课程具体成绩明细
  Future<GradesData> getGrades({String? semesterId}) async {
    try {
      // 1. 各学期汇总
      final histRes = await dio.post(
        '$baseUrl/teach/grade/course/person!historyCourseGrade.action?projectType=',
        options: Options(responseType: ResponseType.plain),
      );
      final histDoc = html_parser.parse(histRes.data);
      final summaryList = <SemesterGradeSummary>[];

      final tblHist = histDoc.querySelector('table.gridtable');
      if (tblHist != null) {
        final rows = tblHist.querySelectorAll('tr');
        for (var i = 1; i < rows.length; i++) {
          final cols = rows[i].querySelectorAll('td').map((td) => td.text.trim()).toList();
          if (cols.length >= 5) {
            summaryList.add(SemesterGradeSummary(
              academicYear: cols[0],
              term: cols[1],
              termDisplay: '${cols[0]} 第${cols[1]}学期',
              courseCount: cols[2],
              totalCredits: cols[3],
              gpa: cols[4],
            ));
          }
        }
      }

      // 2. 抓取各学期详细课程成绩清单 (77门课)
      const semMap = {
        '162': '2023-2024学年1学期',
        '182': '2023-2024学年2学期',
        '202': '2024-2025学年1学期',
        '203': '2024-2025学年2学期',
        '222': '2025-2026学年1学期',
        '242': '2025-2026学年2学期',
        '262': '2026-2027学年1学期',
      };

      final targetSemesters =
          (semesterId != null && semesterId != 'all') ? [semesterId] : semMap.keys.toList();

      final courseGrades = <CourseGrade>[];

      for (final sId in targetSemesters) {
        try {
          final res = await dio.get(
            '$baseUrl/teach/grade/course/person!search.action?semesterId=$sId&projectType=',
          );
          final doc = html_parser.parse(res.data);
          final tbl = doc.querySelector('table.gridtable');
          if (tbl == null) continue;

          final headers =
              tbl.querySelectorAll('th').map((th) => th.text.trim()).toList();
          final hMap = <String, int>{};
          for (var i = 0; i < headers.length; i++) {
            hMap[headers[i]] = i;
          }

          final rows = tbl.querySelectorAll('tr');
          for (var r = 1; r < rows.length; r++) {
            final tds = rows[r].querySelectorAll('td').map((td) => td.text.trim()).toList();
            if (tds.length < headers.length) continue;

            final termText = hMap.containsKey('学年学期')
                ? tds[hMap['学年学期']!]
                : (semMap[sId] ?? '');
            final cName = hMap.containsKey('课程名称') ? tds[hMap['课程名称']!] : '';
            final cCode = hMap.containsKey('课程代码') ? tds[hMap['课程代码']!] : '';
            final cCat = hMap.containsKey('课程类别') ? tds[hMap['课程类别']!] : '课程';
            final cCredit = hMap.containsKey('学分') ? tds[hMap['学分']!] : '0';

            var score = '';
            for (final k in ['最终', '总评成绩', '期末成绩']) {
              if (hMap.containsKey(k) && hMap[k]! < tds.length && tds[hMap[k]!].isNotEmpty) {
                score = tds[hMap[k]!];
                break;
              }
            }

            final gpa = hMap.containsKey('绩点') && hMap['绩点']! < tds.length
                ? tds[hMap['绩点']!]
                : '';
            final usual = hMap.containsKey('平时成绩') && hMap['平时成绩']! < tds.length
                ? tds[hMap['平时成绩']!]
                : '';
            final exam = hMap.containsKey('期末成绩') && hMap['期末成绩']! < tds.length
                ? tds[hMap['期末成绩']!]
                : '';
            final mid = hMap.containsKey('期中成绩') && hMap['期中成绩']! < tds.length
                ? tds[hMap['期中成绩']!]
                : '';

            if (cName.isNotEmpty) {
              courseGrades.add(CourseGrade(
                semesterId: sId,
                semesterName: semMap[sId] ?? termText,
                term: termText,
                courseName: cName,
                courseCode: cCode,
                category: cCat,
                credits: cCredit,
                score: score,
                gpa: gpa,
                usualScore: usual,
                examScore: exam,
                midScore: mid,
              ));
            }
          }
        } catch (_) {}
      }

      return GradesData(
        summary: summaryList,
        courseGrades: courseGrades,
        totalCourses: courseGrades.length,
      );
    } catch (_) {
      return GradesData(summary: [], courseGrades: [], totalCourses: 0);
    }
  }
}
