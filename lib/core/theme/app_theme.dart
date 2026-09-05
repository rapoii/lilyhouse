import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS, // Forces iOS scroll physics (BouncingScrollPhysics) and Cupertino transitions globally!
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryPink,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPink,
        secondary: AppColors.pastelPink,
        surface: AppColors.cardBg,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.largeTitle,
      ),
    );
  }
}
