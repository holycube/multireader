import 'package:package_info_plus/package_info_plus.dart';

/// 应用元信息（版本号等），供「评价应用」等设置项展示。
class AppMetadata {
  AppMetadata._({
    required this.version,
    required this.buildNumber,
    required this.appName,
  });

  final String version;
  final String buildNumber;
  final String appName;

  static AppMetadata get fallback => AppMetadata._(
        version: '1.0.0',
        buildNumber: '1',
        appName: '小说阅读器',
      );

  static Future<AppMetadata> load() async {
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(milliseconds: 100),
      );
      return AppMetadata._(
        version: info.version,
        buildNumber: info.buildNumber,
        appName: info.appName,
      );
    } catch (_) {
      return fallback;
    }
  }
}
