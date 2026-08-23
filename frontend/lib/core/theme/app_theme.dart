import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ocean-branded theme aligned with the SukaSeafood proposal deck.
class AppTheme {
  AppTheme._();

  static const Color navy = Color(0xFF0B1F33);
  static const Color deepSea = Color(0xFF12324A);
  static const Color teal = Color(0xFF2EC4B6);
  static const Color foam = Color(0xFFE8F7F5);
  static const Color sand = Color(0xFFF3E7C9);
  static const Color gold = Color(0xFFD4A017);
  static const Color danger = Color(0xFFC44536);
  static const Color caution = Color(0xFFE09F3E);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      primary: deepSea,
      secondary: teal,
      surface: foam,
    );

    final TextTheme textTheme = GoogleFonts.dmSansTextTheme().copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w700,
        color: navy,
        fontSize: 34,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: navy,
        fontSize: 26,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        color: navy,
        fontSize: 20,
      ),
      bodyLarge: GoogleFonts.dmSans(fontSize: 16, height: 1.45, color: navy),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, height: 1.45, color: navy),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: foam,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: teal.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: navy,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.dmSans(color: navy.withValues(alpha: 0.45)),
      ),
    );
  }

  static Color classificationColor(String? classification) {
    switch ((classification ?? '').toUpperCase()) {
      case 'GOOD CHOICE':
      case 'BEST CHOICE':
        return const Color(0xFF2A9D8F);
      case 'REDUCE':
        return caution;
      case 'AVOID':
        return danger;
      default:
        return Colors.blueGrey;
    }
  }
}
