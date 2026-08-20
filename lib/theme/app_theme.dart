import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0B0B0F);
  static const surface = Color(0xFF16161D);
  static const surfaceLight = Color(0xFF22222C);
  static const primary = Color(0xFF00D9A5);
  static const primaryDark = Color(0xFF00B388);
  static const accent = Color(0xFF6C5CE7);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF8E8E93);
  static const textMuted = Color(0xFF636366);
  static const divider = Color(0xFF2C2C2E);
  static const error = Color(0xFFFF453A);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D9A5), Color(0xFF00B4D8)],
  );

  static const gradientPlayer = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A2E), Color(0xFF0B0B0F)],
  );
}

/// 跨平台系统字体，避免运行时联网下载字体
const _fontFallback = [
  'PingFang SC',
  'Heiti SC',
  'Microsoft YaHei',
  'Noto Sans CJK SC',
  'sans-serif',
];

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamilyFallback: _fontFallback,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerColor: AppColors.divider,
    );
  }
}
