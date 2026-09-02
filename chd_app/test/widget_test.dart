import 'package:flutter_test/flutter_test.dart';
import 'package:chd_app/models/announcement.dart';
import 'package:chd_app/models/course.dart';
import 'package:chd_app/models/grade.dart';

void main() {
  test('Course model serialization test', () {
    final course = Course(
      id: 'c1',
      code: 'CS101',
      name: 'Python程序设计',
      credits: '2.0',
      category: '必修',
      teachers: '李老师',
      weeksDesc: '1-16周',
      slots: [
        CourseSlot(
          dayOfWeek: 1,
          startPeriod: 1,
          periodCount: 2,
          room: 'WX2304',
          weeks: [1, 2, 3, 4],
        ),
      ],
      colorHex: '#4F46E5',
    );

    final json = course.toJson();
    final restored = Course.fromJson(json);

    expect(restored.name, 'Python程序设计');
    expect(restored.slots.length, 1);
    expect(restored.slots.first.room, 'WX2304');
  });

  test('Grade model serialization test', () {
    final grade = CourseGrade(
      semesterId: '242',
      semesterName: '2025-2026学年2学期',
      term: '2025-2026 2',
      courseName: '形势与政策（六）',
      courseCode: '16SZ6006',
      category: '思政',
      credits: '0.25',
      score: '90',
      gpa: '4.0',
      usualScore: '',
      examScore: '90',
      midScore: '',
    );

    final json = grade.toJson();
    final restored = CourseGrade.fromJson(json);

    expect(restored.courseName, '形势与政策（六）');
    expect(restored.score, '90');
    expect(restored.gpa, '4.0');
  });

  test('Announcement model test', () {
    final ann = Announcement(
      id: 1,
      title: '系统通知',
      content: '欢迎使用课表App',
      type: 'notice',
      isPopup: true,
      versionCode: 1,
      downloadUrl: '',
      createdAt: '2026-09-02 20:00:00',
    );

    final json = ann.toJson();
    final restored = Announcement.fromJson(json);

    expect(restored.id, 1);
    expect(restored.title, '系统通知');
    expect(restored.isPopup, isTrue);
  });
}
