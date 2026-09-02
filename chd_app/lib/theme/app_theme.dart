import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgCanvas = Color(0xFFF1F5F9); // 微灰蓝底色
  static const Color bgCard = Colors.white; // 纯白高透卡片
  static const Color textPrimary = Color(0xFF0F172A); // 900
  static const Color textSecondary = Color(0xFF475569); // 600
  static const Color textMuted = Color(0xFF94A3B8); // 400
  static const Color borderColor = Color(0xFFE2E8F0); // 柔灰边框

  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentRose = Color(0xFFE11D48);
  static const Color accentEmerald = Color(0xFF059669);
  static const Color accentAmber = Color(0xFFD97706);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgCanvas,
    primaryColor: accentIndigo,
    colorScheme: const ColorScheme.light(
      primary: accentIndigo,
      secondary: accentTeal,
      surface: bgCard,
      onSurface: textPrimary,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  static Color parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return accentIndigo;
    }
  }
}
