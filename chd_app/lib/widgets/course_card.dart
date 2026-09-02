import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import 'course_detail_sheet.dart';

class CourseGridCell extends StatelessWidget {
  final Course course;
  final CourseSlot slot;

  const CourseGridCell({
    super.key,
    required this.course,
    required this.slot,
  });

  String _formatRoom(String raw) {
    if (raw.isEmpty) return '';
    // 插入零宽断字符 \u200B，允许任意英数编号（如 WX2304）在容器宽度不足时随时折行，绝不被截断为省略号
    return raw.split('').join('\u200B');
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppTheme.parseHexColor(course.colorHex);

    return InkWell(
      onTap: () => CourseDetailSheet.show(context, course, slot),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(1.0),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: baseColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              maxLines: slot.periodCount > 1 ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: baseColor.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            if (slot.room.isNotEmpty) ...[
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _formatRoom(slot.room),
                  maxLines: 3,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
