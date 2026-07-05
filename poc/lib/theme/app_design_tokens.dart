import 'package:flutter/material.dart';

/// 设计系统颜色 Token（见 docs/design-system.md §3.1）。
abstract final class AppColors {
  // 浅色壳层
  static const shellBgWarm = Color(0xFFF5F3EF);
  static const shellBgCool = Color(0xFFF7F7F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceNested = Color(0xFFF0EEEA);
  static const scrim = Color(0x66000000);

  // 文字
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFFC7C7CC);
  static const textOnAccent = Color(0xFFFFFFFF);

  // Accent A 墨绿
  static const accentGreen = Color(0xFF2D5A4A);
  static const accentLightGreen = Color(0xFFE8F0ED);

  // Accent B 淡蓝
  static const accentBlue = Color(0xFF4A7BF7);
  static const accentLightBlue = Color(0xFFEEF2FE);

  // Accent C 暖橙
  static const accentOrange = Color(0xFFE8913A);
  static const accentLightOrange = Color(0xFFFDF3E7);

  // 语义色
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const error = Color(0xFFFF3B30);

  // 分隔
  static const hairline = Color(0x0F000000);

  // 深色壳层
  static const shellBgDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const surfaceNestedDark = Color(0xFF2C2C2C);
  static const textPrimaryDark = Color(0xFFE5E5E5);
  static const textSecondaryDark = Color(0xFF8E8E93);

  // 遗留壳层预设
  static const shellBgSepia = Color(0xFFF5EEDC);

  static Color chevron(Color secondary) =>
      secondary.withValues(alpha: 0.7);

  static ({Color accent, Color accentLight}) accentPair(int preset) =>
      switch (preset) {
        1 => (accent: accentBlue, accentLight: accentLightBlue),
        2 => (accent: accentOrange, accentLight: accentLightOrange),
        _ => (accent: accentGreen, accentLight: accentLightGreen),
      };
}

/// 间距 Token（4pt 网格）。
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// 圆角 Token。
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const full = 999.0;
}

/// 壳层衬线字体族名（pubspec 注册）。
abstract final class AppFonts {
  static const display = 'NotoSerifSC';
}
