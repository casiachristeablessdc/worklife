import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const eucalyptus = Color(0xFFCBD4B1);
  static const eucalyptusDark = Color(0xFF4E5A3A);
  static const peach = Color(0xFFF6ECD6);
  static const ivory = Color(0xFFFFFBF2);
  static const pistachio = Color(0xFFE8ECC9);
  static const clay = Color(0xFFD6A574);
  static const clayDark = Color(0xFF5C3F22);
  static const ink = Color(0xFF2E2A22);
  static const sub = Color(0xFF8A8371);
  static const line = Color(0x14000000);
  static const page = Color(0xFFEFE9D8);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ivory,

      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.clay,
        onPrimary: Colors.white,
        secondary: AppColors.eucalyptus,
        onSecondary: AppColors.eucalyptusDark,
        surface: AppColors.ivory,
        onSurface: AppColors.ink,
      ),

      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        headlineSmall: GoogleFonts.fraunces(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.sub,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.sub,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 0,
        ),
        constraints: const BoxConstraints(
          minHeight: 42,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.line,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.clay,
            width: 1.5,
          ),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.sub,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          backgroundColor: AppColors.clay,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}