
import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0a0e14);
  static const Color primary = Color(0xFF4cc9ff);
  static const Color cardBg = Color(0xCC0a0e14); // 80% opacity
  static const Color borderColor = Color(0xFF1e2a3a);
  static const Color textPrimary = Color(0xFFe0f2ff);
  static const Color textSecondary = Color(0xFF8bacc1);

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: background,
        onSurface: textPrimary,
      ),
      // Avoid runtime Google Fonts fetching on Android (offline-safe).
      // If you want a custom font later, prefer bundling it as an asset in pubspec.
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: const BorderSide(color: borderColor),
        ),
      ),
    );
  }
}
