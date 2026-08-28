import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens matched to PotentialScreenrendersI1.pdf.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0A1F2E);
  static const Color navyDeep = Color(0xFF06151F);
  static const Color headerTeal = Color(0xFF0D3B4A);
  static const Color teal = Color(0xFF2EC4B6);
  static const Color tealSoft = Color(0xFFD8F5F1);
  static const Color tealDark = Color(0xFF0E8F84);
  static const Color good = Color(0xFF1F8A5B);
  static const Color goodSoft = Color(0xFFE4F6EC);
  static const Color reduce = Color(0xFFE09F3E);
  static const Color avoid = Color(0xFFC44536);
  static const Color foam = Color(0xFFF4F7F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF14212B);
  static const Color muted = Color(0xFF6B7A86);
  static const Color line = Color(0xFFE6ECF0);
  static const Color star = Color(0xFFF4A261);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final TextTheme textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 34,
        color: Colors.white,
        height: 1.1,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.ink,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.ink,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 1.45,
        color: AppColors.ink,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        height: 1.45,
        color: AppColors.muted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.ink,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.foam,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.navy,
        secondary: AppColors.teal,
        surface: AppColors.card,
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.foam,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static Color classificationColor(String classification) {
    switch (classification.toUpperCase()) {
      case 'GOOD CHOICE':
      case 'BEST CHOICE':
        return AppColors.good;
      case 'REDUCE':
        return AppColors.reduce;
      case 'AVOID':
        return AppColors.avoid;
      default:
        return AppColors.muted;
    }
  }
}
