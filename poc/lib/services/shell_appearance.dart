import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_design_tokens.dart';

/// Tab 壳层主题偏好：背景预设 + Accent（与 [ReaderPreferences] 独立存储）。
class AppThemePreferences {
  AppThemePreferences._(this._prefs);

  static const keyShellBgPreset = 'app_shell_bg_preset';
  static const keyAccentPreset = 'app_shell_accent_preset';

  /// 0 = 系统默认（不着色，由 Theme 决定）
  static const presetSystem = 0;
  static const presetWhite = 1;
  static const presetSepia = 2;
  static const presetDark = 3;
  static const presetWarm = 4;
  static const presetCool = 5;

  /// 0 墨绿 / 1 淡蓝 / 2 暖橙
  static const accentGreen = 0;
  static const accentBlue = 1;
  static const accentOrange = 2;

  static const designSystemBgPresets = <({String label, Color color, int preset})>[
    (label: '暖灰', color: AppColors.shellBgWarm, preset: presetWarm),
    (label: '冷灰', color: AppColors.shellBgCool, preset: presetCool),
  ];

  static const accentPresets = <({String label, Color color, Color light, int preset})>[
    (
      label: '墨绿',
      color: AppColors.accentGreen,
      light: AppColors.accentLightGreen,
      preset: accentGreen,
    ),
    (
      label: '淡蓝',
      color: AppColors.accentBlue,
      light: AppColors.accentLightBlue,
      preset: accentBlue,
    ),
    (
      label: '暖橙',
      color: AppColors.accentOrange,
      light: AppColors.accentLightOrange,
      preset: accentOrange,
    ),
  ];

  static const legacyBgPresets = <({String label, Color? color, int preset})>[
    (label: '系统默认', color: null, preset: presetSystem),
    (label: '白', color: AppColors.surface, preset: presetWhite),
    (label: '护眼黄', color: AppColors.shellBgSepia, preset: presetSepia),
    (label: '深灰', color: AppColors.surfaceDark, preset: presetDark),
  ];

  final SharedPreferences _prefs;

  int get shellBgPreset {
    final stored = _prefs.getInt(keyShellBgPreset);
    if (stored == null) return presetWarm;
    return stored.clamp(0, 5);
  }

  int get accentPreset =>
      _prefs.getInt(keyAccentPreset)?.clamp(0, 2) ?? accentGreen;

  bool get isDarkShell => shellBgPreset == presetDark;

  Color? resolveShellBackgroundColor() => switch (shellBgPreset) {
        presetWhite => AppColors.surface,
        presetSepia => AppColors.shellBgSepia,
        presetDark => AppColors.surfaceDark,
        presetWarm => AppColors.shellBgWarm,
        presetCool => AppColors.shellBgCool,
        _ => null,
      };

  /// 兼容旧 API 名称。
  int get backgroundPreset => shellBgPreset;

  Color? get backgroundColor => resolveShellBackgroundColor();

  static Future<AppThemePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemePreferences._(prefs);
  }

  Future<void> setShellBgPreset(int preset) async {
    await _prefs.setInt(keyShellBgPreset, preset.clamp(0, 5));
  }

  /// 兼容旧 API 名称。
  Future<void> setBackgroundPreset(int preset) =>
      setShellBgPreset(preset);

  Future<void> setAccentPreset(int preset) async {
    await _prefs.setInt(keyAccentPreset, preset.clamp(0, 2));
  }
}

/// 旧类名别名，便于渐进迁移。
typedef ShellAppearancePreferences = AppThemePreferences;
