import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

/// 壳层专用文字样式（Noto Serif SC）；阅读器与查词卡不使用此类。
abstract final class AppTextStyles {
  static TextStyle sectionTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
    );
  }

  static TextStyle statValue(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
    );
  }
}
