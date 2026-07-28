import 'package:flutter/material.dart';

/// Design tokens. Source of truth: docs/DESIGN_SYSTEM.md — keep these in
/// sync if that doc changes, and vice versa.
const appBackground = Color(0xFF121214);
const appSurface = Color(0xFF1B1C1F);
const appLine = Color(0xFF2A2B2F);
const appAccent = Color(0xFFFFB020);
const appPaper = Color(0xFFF5F4F0);
const appTextMuted = Color(0xFF8B8D93);

class AppColors {
  AppColors._();

  static const background = appBackground;
  static const surface = appSurface;
  static const line = appLine;
  static const accent = appAccent;
  static const paper = appPaper;
  static const textMuted = appTextMuted;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.accent,
      onPrimary: AppColors.background,
    ),
    fontFamily: 'Inter',
  );
}
