import 'dart:io';

import 'package:path_provider/path_provider.dart';
/// 计算与清理应用临时目录与 cache 目录占用。
class CacheManager {
  CacheManager._();

  static Future<int> calculateCacheBytes() async {
    try {
      return await _calculateCacheBytes();
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _calculateCacheBytes() async {
    try {
      var total = 0;
      final tempDir = await getTemporaryDirectory();
      total += await _dirSize(tempDir);

      try {
        final cacheDir = await getApplicationCacheDirectory();
        total += await _dirSize(cacheDir);
      } catch (_) {
        // 部分平台可能不支持 application cache。
      }

      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    await _clearDir(tempDir);

    try {
      final cacheDir = await getApplicationCacheDirectory();
      await _clearDir(cacheDir);
    } catch (_) {}
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static Future<void> _clearDir(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
