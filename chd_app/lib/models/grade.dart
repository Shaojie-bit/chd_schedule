class CourseGrade {
  final String semesterId;
  final String semesterName;
  final String term;
  final String courseName;
  final String courseCode;
  final String category;
  final String credits;
  final String score;
  final String gpa;
  final String usualScore;
  final String examScore;
  final String midScore;

  CourseGrade({
    required this.semesterId,
    required this.semesterName,
    required this.term,
    required this.courseName,
    required this.courseCode,
    required this.category,
    required this.credits,
    required this.score,
    required this.gpa,
    required this.usualScore,
    required this.examScore,
    required this.midScore,
  });

  Map<String, dynamic> toJson() => {
        'semesterId': semesterId,
        'semesterName': semesterName,
        'term': term,
        'courseName': courseName,
        'courseCode': courseCode,
        'category': category,
        'credits': credits,
        'score': score,
        'gpa': gpa,
        'usualScore': usualScore,
        'examScore': examScore,
        'midScore': midScore,
      };

  factory CourseGrade.fromJson(Map<String, dynamic> json) => CourseGrade(
        semesterId: json['semesterId'] as String? ?? json['semester_id'] as String? ?? '',
        semesterName: json['semesterName'] as String? ?? json['semester_name'] as String? ?? '',
        term: json['term'] as String? ?? '',
        courseName: json['courseName'] as String? ?? json['course_name'] as String? ?? '',
        courseCode: json['courseCode'] as String? ?? json['course_code'] as String? ?? '',
        category: json['category'] as String? ?? '',
        credits: json['credits'] as String? ?? '0',
        score: json['score'] as String? ?? '',
        gpa: json['gpa'] as String? ?? '',
        usualScore: json['usualScore'] as String? ?? json['usual_score'] as String? ?? '',
        examScore: json['examScore'] as String? ?? json['exam_score'] as String? ?? '',
        midScore: json['midScore'] as String? ?? json['mid_score'] as String? ?? '',
      );
}

class SemesterGradeSummary {
  final String academicYear;
  final String term;
  final String termDisplay;
  final String courseCount;
  final String totalCredits;
  final String gpa;

  SemesterGradeSummary({
    required this.academicYear,
    required this.term,
    required this.termDisplay,
    required this.courseCount,
    required this.totalCredits,
    required this.gpa,
  });

  Map<String, dynamic> toJson() => {
        'academicYear': academicYear,
        'term': term,
        'termDisplay': termDisplay,
        'courseCount': courseCount,
        'totalCredits': totalCredits,
        'gpa': gpa,
      };

  factory SemesterGradeSummary.fromJson(Map<String, dynamic> json) =>
      SemesterGradeSummary(
        academicYear: json['academicYear'] as String? ?? json['academic_year'] as String? ?? '',
        term: json['term'] as String? ?? '',
        termDisplay: json['termDisplay'] as String? ?? json['term_display'] as String? ?? '',
        courseCount: json['courseCount'] as String? ?? json['course_count'] as String? ?? '',
        totalCredits: json['totalCredits'] as String? ?? json['total_credits'] as String? ?? '',
        gpa: json['gpa'] as String? ?? '',
      );
}

class GradesData {
  final List<SemesterGradeSummary> summary;
  final List<CourseGrade> courseGrades;
  final int totalCourses;

  GradesData({
    required this.summary,
    required this.courseGrades,
    required this.totalCourses,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary.map((e) => e.toJson()).toList(),
        'courseGrades': courseGrades.map((e) => e.toJson()).toList(),
        'totalCourses': totalCourses,
      };

  factory GradesData.fromJson(Map<String, dynamic> json) => GradesData(
        summary: (json['summary'] as List<dynamic>?)
                ?.map((e) => SemesterGradeSummary.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        courseGrades: (json['courseGrades'] as List<dynamic>? ??
                json['course_grades'] as List<dynamic>?)
                ?.map((e) => CourseGrade.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        totalCourses: json['totalCourses'] as int? ?? json['total_courses'] as int? ?? 0,
      );
}
