import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBackground = Color(0xFF1A1F2E);
  static const Color cardBackground = Color(0xFF232837);
  static const Color accentColor = Color(0xFF2E7D5B);
  static const Color actionRequiredBadgeText = Color(0xFFE53935);
  static const Color actionRequiredBadgeBackground = Color(0xFF3D1F1F);
  static const Color completedBadgeText = Color(0xFF66BB6A);
  static const Color completedBadgeBackground = Color(0xFF1F3D20);
  static const Color informationalBadgeText = Color(0xFF42A5F5);
  static const Color informationalBadgeBackground = Color(0xFF1F2D3D);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9EAF);
  static const Color divider = Color(0xFF2D3348);
  static const Color fabColor = Color(0xFF2E7D5B);
  static const Color searchBarBackground = Color(0xFF2D3348);
}

class BadgeStyles {
  static Map<String, Map<String, Color>> badgeColors = {
    'Action Required': {
      'text': AppColors.actionRequiredBadgeText,
      'background': AppColors.actionRequiredBadgeBackground,
    },
    'Completed': {
      'text': AppColors.completedBadgeText,
      'background': AppColors.completedBadgeBackground,
    },
    'Informational': {
      'text': AppColors.informationalBadgeText,
      'background': AppColors.informationalBadgeBackground,
    },
  };

  static Map<String, Color> getBadgeStyle(String priority) {
    return badgeColors[priority] ??
        {'text': AppColors.textPrimary, 'background': AppColors.cardBackground};
  }
}

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.accentColor,
  scaffoldBackgroundColor: AppColors.primaryBackground,
  cardColor: AppColors.cardBackground,
  dividerColor: AppColors.divider,
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.fabColor,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primaryBackground,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  ),
  textTheme: TextTheme(
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  ),
);
