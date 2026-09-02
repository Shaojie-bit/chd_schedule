import 'package:flutter/material.dart';

class ScoreBadge extends StatelessWidget {
  final String score;

  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score.trim();
    final num = double.tryParse(s);

    Color bg;
    Color text;
    Color border;

    if (s == '优秀' || s == '优' || (num != null && num >= 90)) {
      bg = const Color(0x1F10B981);
      text = const Color(0xFF059669);
      border = const Color(0x4D10B981);
    } else if (s == '良好' || s == '良' || (num != null && num >= 80)) {
      bg = const Color(0x1F3B82F6);
      text = const Color(0xFF2563EB);
      border = const Color(0x4D3B82F6);
    } else if (s == '中等' || s == '中' || (num != null && num >= 70)) {
      bg = const Color(0x1F6366F1);
      text = const Color(0xFF4F46E5);
      border = const Color(0x4D6366F1);
    } else if (s == '及格' || s == '合格' || (num != null && num >= 60)) {
      bg = const Color(0x1FF59E0B);
      text = const Color(0xFFD97706);
      border = const Color(0x4DF59E0B);
    } else if (s.isNotEmpty) {
      bg = const Color(0x1FEF4444);
      text = const Color(0xFFDC2626);
      border = const Color(0x4DEF4444);
    } else {
      bg = Colors.grey.shade100;
      text = Colors.grey.shade600;
      border = Colors.grey.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        s.isEmpty ? '-' : s,
        style: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
