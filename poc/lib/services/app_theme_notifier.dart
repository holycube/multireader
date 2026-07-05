import 'package:flutter/foundation.dart';

import 'shell_appearance.dart';

/// 壳层主题偏好 [ChangeNotifier]；驱动 [MaterialApp.theme] 实时重建。
class AppThemeNotifier extends ChangeNotifier {
  AppThemeNotifier._(this._prefs);

  AppThemePreferences _prefs;

  AppThemePreferences get prefs => _prefs;

  static Future<AppThemeNotifier> load() async {
    final prefs = await AppThemePreferences.load();
    return AppThemeNotifier._(prefs);
  }

  Future<void> reload() async {
    _prefs = await AppThemePreferences.load();
    notifyListeners();
  }

  Future<void> setShellBgPreset(int preset) async {
    await _prefs.setShellBgPreset(preset);
    notifyListeners();
  }

  Future<void> setAccentPreset(int preset) async {
    await _prefs.setAccentPreset(preset);
    notifyListeners();
  }
}
