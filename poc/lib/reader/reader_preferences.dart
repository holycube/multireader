import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读偏好：字号、行距、背景预设、屏幕亮度与主题色。
class ReaderPreferences extends ChangeNotifier {
  ReaderPreferences._(this._prefs);

  static const _keyFontSize = 'reader_font_size';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyBgPreset = 'reader_bg_preset';
  static const _keyScreenBrightness = 'reader_screen_brightness';
  static const _keyChunkSeparators = 'reader_chunk_separators';

  static const double minFontSize = 14;
  static const double maxFontSize = 24;
  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 2.0;

  final SharedPreferences _prefs;
  double? _screenBrightness;

  double get fontSize =>
      _prefs.getDouble(_keyFontSize)?.clamp(minFontSize, maxFontSize) ?? 17;

  double get lineHeight =>
      _prefs.getDouble(_keyLineHeight)?.clamp(minLineHeight, maxLineHeight) ??
      1.6;

  int get backgroundPreset =>
      _prefs.getInt(_keyBgPreset)?.clamp(0, 2) ?? 0;

  double get screenBrightness =>
      _screenBrightness ??
      _prefs.getDouble(_keyScreenBrightness)?.clamp(0.0, 1.0) ??
      0.5;

  bool get isNightMode => backgroundPreset == 2;

  bool get chunkSeparatorsEnabled =>
      _prefs.getBool(_keyChunkSeparators) ?? false;

  Color get backgroundColor => switch (backgroundPreset) {
        1 => const Color(0xFFF5EEDC),
        2 => const Color(0xFF1E1E1E),
        _ => Colors.white,
      };

  Color get textColor =>
      backgroundPreset == 2 ? Colors.white70 : Colors.black87;

  Color get chromeColor => backgroundColor;

  Color get settingsPanelColor => backgroundColor.withValues(alpha: 0.95);

  Color get chromeOnColor =>
      backgroundPreset == 2 ? Colors.white70 : Colors.black87;

  Color get unknownHighlightColor => backgroundPreset == 2
      ? const Color(0xFF4A7A6A)
      : const Color(0xFFB0CCC4);

  Color get lookupCardColor =>
      backgroundPreset == 2 ? const Color(0xFF2C2C2E) : Colors.white;

  Color get lookupCardOnColor =>
      backgroundPreset == 2 ? Colors.white : Colors.black87;

  bool get lookupCardIsDark => backgroundPreset == 2;

  Color get lookupCardBorderColor => backgroundPreset == 2
      ? const Color(0x1AFFFFFF)
      : Colors.transparent;

  TextStyle get bodyTextStyle => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: textColor,
      );

  static Future<ReaderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final instance = ReaderPreferences._(prefs);
    await instance._restoreScreenBrightness();
    return instance;
  }

  Future<void> _restoreScreenBrightness() async {
    final saved = _prefs.getDouble(_keyScreenBrightness);
    if (saved != null) {
      _screenBrightness = saved.clamp(0.0, 1.0);
      try {
        await ScreenBrightness.instance
            .setApplicationScreenBrightness(_screenBrightness!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('screen_brightness restore failed: $e');
        }
      }
      return;
    }

    try {
      final current = await ScreenBrightness.instance.application;
      _screenBrightness = current.clamp(0.0, 1.0);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('screen_brightness read failed: $e');
      }
      _screenBrightness = 0.5;
    }
  }

  Future<void> setFontSize(double value) async {
    await _prefs.setDouble(_keyFontSize, value.clamp(minFontSize, maxFontSize));
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    await _prefs.setDouble(
      _keyLineHeight,
      value.clamp(minLineHeight, maxLineHeight),
    );
    notifyListeners();
  }

  Future<void> setBackgroundPreset(int preset) async {
    await _prefs.setInt(_keyBgPreset, preset.clamp(0, 2));
    notifyListeners();
  }

  Future<void> setScreenBrightness(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _screenBrightness = clamped;
    await _prefs.setDouble(_keyScreenBrightness, clamped);
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(clamped);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('screen_brightness set failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> toggleNightMode() async {
    await setBackgroundPreset(isNightMode ? 0 : 2);
  }

  Future<void> setChunkSeparatorsEnabled(bool enabled) async {
    await _prefs.setBool(_keyChunkSeparators, enabled);
    notifyListeners();
  }
}
