class CourseSlot {
  final int dayOfWeek; // 1 (Mon) - 7 (Sun)
  final int startPeriod; // 1 - 11
  final int periodCount;
  final String room;
  final List<int> weeks;

  CourseSlot({
    required this.dayOfWeek,
    required this.startPeriod,
    required this.periodCount,
    required this.room,
    required this.weeks,
  });

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startPeriod': startPeriod,
        'periodCount': periodCount,
        'room': room,
        'weeks': weeks,
      };

  factory CourseSlot.fromJson(Map<String, dynamic> json) => CourseSlot(
        dayOfWeek: json['dayOfWeek'] as int? ?? 1,
        startPeriod: json['startPeriod'] as int? ?? 1,
        periodCount: json['periodCount'] as int? ?? 1,
        room: json['room'] as String? ?? '',
        weeks: (json['weeks'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      );
}

class Course {
  final String id;
  final String code;
  final String name;
  final String credits;
  final String category;
  final String teachers;
  final String weeksDesc;
  final List<CourseSlot> slots;
  final String colorHex;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.category,
    required this.teachers,
    required this.weeksDesc,
    required this.slots,
    required this.colorHex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'credits': credits,
        'category': category,
        'teachers': teachers,
        'weeksDesc': weeksDesc,
        'slots': slots.map((s) => s.toJson()).toList(),
        'colorHex': colorHex,
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        credits: json['credits'] as String? ?? '',
        category: json['category'] as String? ?? '',
        teachers: json['teachers'] as String? ?? '',
        weeksDesc: json['weeksDesc'] as String? ?? '',
        slots: (json['slots'] as List<dynamic>?)
                ?.map((e) => CourseSlot.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        colorHex: json['colorHex'] as String? ?? '#4F46E5',
      );
}
