class StudentProfile {
  final String name;
  final String studentId;
  final String department;
  final String major;
  final String grade;
  final String campus;
  final String adminClass;

  StudentProfile({
    required this.name,
    required this.studentId,
    required this.department,
    required this.major,
    required this.grade,
    required this.campus,
    required this.adminClass,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'studentId': studentId,
        'department': department,
        'major': major,
        'grade': grade,
        'campus': campus,
        'adminClass': adminClass,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        name: json['name'] as String? ?? '',
        studentId: json['studentId'] as String? ?? json['student_id'] as String? ?? '',
        department: json['department'] as String? ?? '',
        major: json['major'] as String? ?? '',
        grade: json['grade'] as String? ?? '',
        campus: json['campus'] as String? ?? '',
        adminClass: json['adminClass'] as String? ?? json['admin_class'] as String? ?? '',
      );
}

class SemesterInfo {
  final String id;
  final String name;

  SemesterInfo({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory SemesterInfo.fromJson(Map<String, dynamic> json) => SemesterInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}
