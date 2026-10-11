import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4C6FFF);
  static const ink = Color(0xFF18212F);
  static const muted = Color(0xFF75839C);
  static const subtle = Color(0xFF8C9AB6);
  static const background = Color(0xFFF5F7FB);
  static const navy = Color(0xFF10182B);
  static const navyLight = Color(0xFF1D2A4A);
  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFE59A1A);
  static const danger = Color(0xFFEA5B5B);
  static const primarySoft = Color(0xFFE8EEFF);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    error: AppColors.danger,
    surface: Colors.white,
  );

  final radius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.ink,
      titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6EAF2)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE6EAF2), space: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Color(0xFFE0E5EE))),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Color(0xFFE0E5EE))),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.subtle),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}
