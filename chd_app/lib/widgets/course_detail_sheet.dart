import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';

class CourseDetailSheet extends StatelessWidget {
  final Course course;
  final CourseSlot slot;

  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.slot,
  });

  static void show(BuildContext context, Course course, CourseSlot slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourseDetailSheet(course: course, slot: slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppTheme.parseHexColor(course.colorHex);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.code.isEmpty ? '校级通识/专业课程' : course.code,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.place_outlined, '上课地点', slot.room.isEmpty ? '待定' : slot.room),
          _buildInfoRow(Icons.person_outline, '任课教师', course.teachers.isEmpty ? '待定' : course.teachers),
          _buildInfoRow(
            Icons.access_time_outlined,
            '星期与节次',
            '周${_dayToString(slot.dayOfWeek)} 第 ${slot.startPeriod}~${slot.startPeriod + slot.periodCount - 1} 节',
          ),
          _buildInfoRow(Icons.school_outlined, '学分与类别', '${course.credits} 学分 · ${course.category}'),
          _buildInfoRow(Icons.calendar_today_outlined, '周次说明', course.weeksDesc.isEmpty ? '${slot.weeks.join(',')} 周' : course.weeksDesc),
          const SizedBox(height: 20),
          const Text(
            '1~20 周上课点阵分布',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildWeeksGrid(slot.weeks, baseColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeksGrid(List<int> activeWeeks, Color color) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.2,
      ),
      itemCount: 20,
      itemBuilder: (ctx, i) {
        final w = i + 1;
        final isActive = activeWeeks.contains(w);
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? color : AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Text(
            '$w',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? Colors.white : AppTheme.textMuted,
            ),
          ),
        );
      },
    );
  }

  String _dayToString(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    if (day >= 1 && day <= 7) return days[day - 1];
    return '$day';
  }
}
