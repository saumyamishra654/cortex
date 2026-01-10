import 'package:flutter/material.dart';

/// Cortex App Theme
/// Light mode: Sky blue inspired
/// Dark mode: Tron/Cyberpunk inspired with cyan accents
class AppTheme {
  // Light mode colors (Sky blue + nature)
  static const Color lightBackground = Color(0xFFE8F4FC); // Sky blue
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF2D9CDB); // Ocean blue
  static const Color lightSecondary = Color(0xFF56CCB2); // Teal green
  static const Color lightText = Color(0xFF1A3A4A);
  static const Color lightTextSecondary = Color(0xFF5A7A8A);
  static const Color lightSuccess = Color(0xFF4CAF50);
  static const Color lightError = Color(0xFFE57373);
  static const Color lightCardBorder = Color(0xFFB8D8E8);

  // Dark mode colors (Tron inspired)
  static const Color darkBackground = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF12121A);
  static const Color darkPrimary = Color(0xFF00D4FF); // Cyan glow
  static const Color darkSecondary = Color(0xFF00FF9F); // Neon green
  static const Color darkText = Color(0xFFE0F7FF);
  static const Color darkTextSecondary = Color(0xFF7AB8CC);
  static const Color darkSuccess = Color(0xFF00FF9F);
  static const Color darkError = Color(0xFFFF4757);
  static const Color darkCardBorder = Color(0xFF00D4FF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        error: lightError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSecondary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: lightText, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightTextSecondary,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: lightText),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightTextSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkSurface,
        error: darkError,
        onPrimary: darkBackground,
        onSecondary: darkBackground,
        onSurface: darkText,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkCardBorder.withValues(alpha: 0.3), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkPrimary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: darkPrimary, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkCardBorder.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkCardBorder.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextSecondary,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: darkPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: darkText),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),
    );
  }
}
