import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF004E7C);
  static const Color _accent = Color(0xFF1CB5E0);
  static const Color _success = Color(0xFF2E8B57);
  static const Color _warning = Color(0xFFE3A008);

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
          secondary: _accent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _primary,
          elevation: 0,
          centerTitle: false,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _primary,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(88, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFFE0F2F1),
          labelStyle: TextStyle(color: _success),
        ),
        useMaterial3: false,
      );

  static ThemeData get dark => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _primary,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _accent,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            minimumSize: const Size(88, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return _success;
      case 'in-transit':
        return _accent;
      case 'delayed':
        return _warning;
      default:
        return _primary;
    }
  }
}
