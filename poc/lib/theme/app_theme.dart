import 'package:flutter/material.dart';

import '../services/shell_appearance.dart';
import 'app_design_tokens.dart';

/// 由 [AppThemePreferences] 构建显式 [ThemeData]（不依赖 fromSeed 漂移）。
ThemeData buildAppTheme(AppThemePreferences prefs) {
  final isDarkShell = prefs.isDarkShell;
  final accent = AppColors.accentPair(prefs.accentPreset);
  final shellBg = prefs.resolveShellBackgroundColor();
  final fallbackShellBg = isDarkShell
      ? AppColors.shellBgDark
      : switch (prefs.shellBgPreset) {
          AppThemePreferences.presetSystem => const Color(0xFFFAFAFA),
          _ => AppColors.shellBgWarm,
        };

  if (isDarkShell) {
    final scheme = ColorScheme.dark(
      primary: accent.accent,
      onPrimary: AppColors.textOnAccent,
      primaryContainer: accent.accentLight.withValues(alpha: 0.25),
      onPrimaryContainer: AppColors.textPrimaryDark,
      secondary: accent.accent,
      onSecondary: AppColors.textOnAccent,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      outlineVariant: AppColors.hairline,
      error: AppColors.error,
    );
    return _baseTheme(
      colorScheme: scheme,
      scaffoldBackgroundColor: shellBg ?? fallbackShellBg,
      dividerColor: AppColors.hairline,
    );
  }

  final scheme = ColorScheme.light(
    primary: accent.accent,
    onPrimary: AppColors.textOnAccent,
    primaryContainer: accent.accentLight,
    onPrimaryContainer: accent.accent,
    secondary: accent.accent,
    onSecondary: AppColors.textOnAccent,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerHighest: AppColors.surfaceNested,
    surfaceContainerHigh: AppColors.surfaceNested,
    outlineVariant: AppColors.hairline,
    error: AppColors.error,
  );

  return _baseTheme(
    colorScheme: scheme,
    scaffoldBackgroundColor: shellBg ?? fallbackShellBg,
    dividerColor: AppColors.hairline,
  );
}

ThemeData _baseTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackgroundColor,
  required Color dividerColor,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scaffoldBackgroundColor,
      foregroundColor: colorScheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.primary);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final base = TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        );
        return base;
      }),
    ),
  );
}
