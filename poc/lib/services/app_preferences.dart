import 'package:shared_preferences/shared_preferences.dart';

/// 应用级 SharedPreferences 键与读写（阅读器偏好见 [ReaderPreferences]）。
class AppPreferences {
  AppPreferences._(this._prefs);

  static const keyPersonalizedRecommendation =
      'app_personalized_recommendation';

  final SharedPreferences _prefs;

  bool get personalizedRecommendation =>
      _prefs.getBool(keyPersonalizedRecommendation) ?? true;

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences._(prefs);
  }

  Future<void> setPersonalizedRecommendation(bool value) async {
    await _prefs.setBool(keyPersonalizedRecommendation, value);
  }
}
