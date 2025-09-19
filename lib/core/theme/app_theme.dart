import 'package:flutter/material.dart';

class AppTheme {
  // Eco-friendly color palette
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color secondaryGreen = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFFF8F00);
  static const Color warningRed = Color(0xFFD32F2F);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: secondaryGreen,
      tertiary: accentOrange,
      error: warningRed,
      background: backgroundLight,
      surface: surfaceLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: secondaryGreen,
      secondary: primaryGreen,
      tertiary: accentOrange,
      error: warningRed,
      background: backgroundDark,
      surface: surfaceDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      color: surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}
