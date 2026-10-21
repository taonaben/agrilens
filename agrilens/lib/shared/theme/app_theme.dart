import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      dividerColor: AppColors.lightDivider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        Typography.blackMountainView.apply(
          bodyColor: AppColors.lightTextPrimary,
          displayColor: AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerColor: AppColors.darkDivider,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        Typography.whiteMountainView.apply(
          bodyColor: AppColors.darkTextPrimary,
          displayColor: AppColors.darkTextPrimary,
        ),
      ),
    );
  }
}
