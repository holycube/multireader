import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 匿名本地 ID：首次启动生成 UUID 并存入 SharedPreferences。
class LocalIdentity {
  LocalIdentity._(this._prefs);

  static const _keyAnonymousId = 'app_anonymous_local_id';

  final SharedPreferences _prefs;

  String get anonymousId {
    final existing = _prefs.getString(_keyAnonymousId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    _prefs.setString(_keyAnonymousId, id);
    return id;
  }

  static Future<LocalIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = LocalIdentity._(prefs);
    identity.anonymousId;
    return identity;
  }
}
