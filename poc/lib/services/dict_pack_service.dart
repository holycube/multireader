import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Release 词典包：CDN manifest → 下载 → SHA256 校验 → 本地缓存。
class DictPackService {
  DictPackService._({http.Client? client, String? manifestUrlOverride})
      : _client = client ?? http.Client(),
        _manifestUrlOverride = manifestUrlOverride;

  static DictPackService? _instance;

  static DictPackService get instance => _instance ??= DictPackService._();

  @visibleForTesting
  static void resetInstanceForTesting({
    http.Client? client,
    String? manifestUrlOverride,
  }) {
    _instance?.dispose();
    _instance = DictPackService._(
      client: client,
      manifestUrlOverride: manifestUrlOverride,
    );
    debugCacheRoot = null;
  }

  /// 测试用缓存根（替代 ApplicationSupport）。
  @visibleForTesting
  static Directory? debugCacheRoot;

  static const manifestUrl = String.fromEnvironment(
    'DICT_PACK_MANIFEST_URL',
    defaultValue: '',
  );

  static const cacheSubdirParts = ['dict', 'v1'];
  static const dictFileName = 'mvp_dict.json';
  static const aliasesFileName = 'mvp_dict_aliases.json';
  static const manifestFileName = 'manifest.json';

  final http.Client _client;
  final String? _manifestUrlOverride;

  String get _effectiveManifestUrl => _manifestUrlOverride ?? manifestUrl;

  void dispose() => _client.close();

  /// 缓存根目录 `{ApplicationSupport}/dict/v1/`。
  Future<Directory> cacheDirectory() async {
    final support = debugCacheRoot ?? await getApplicationSupportDirectory();
    final dir = Directory(p.joinAll([support.path, ...cacheSubdirParts]));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File dictFile(Directory dir) => File(p.join(dir.path, dictFileName));

  File aliasesFile(Directory dir) => File(p.join(dir.path, aliasesFileName));

  File manifestFile(Directory dir) => File(p.join(dir.path, manifestFileName));

  /// 本地缓存是否完整且 SHA256 与 manifest 一致。
  Future<bool> isCacheValid() async {
    final dir = await cacheDirectory();
    final manifest = await _readLocalManifest(dir);
    if (manifest == null) return false;

    final dict = dictFile(dir);
    final aliases = aliasesFile(dir);
    if (!await dict.exists() || !await aliases.exists()) return false;

    final dictMeta = manifest.fileFor(dictFileName);
    final aliasesMeta = manifest.fileFor(aliasesFileName);
    if (dictMeta == null || aliasesMeta == null) return false;

    return _sha256OfFile(dict) == dictMeta.sha256.toLowerCase() &&
        _sha256OfFile(aliases) == aliasesMeta.sha256.toLowerCase();
  }

  /// 下载并安装词典包；通过 [onProgress] 报告 0.0–1.0 进度。
  Future<void> ensureInstalled({void Function(double progress)? onProgress}) async {
    final url = _effectiveManifestUrl;
    if (url.isEmpty) {
      throw const DictPackException('未配置 DICT_PACK_MANIFEST_URL');
    }

    final dir = await cacheDirectory();
    if (await isCacheValid()) {
      onProgress?.call(1.0);
      return;
    }

    onProgress?.call(0.0);
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw DictPackException(
        'manifest 下载失败：HTTP ${response.statusCode}',
      );
    }

    final manifestBody = response.body;
    final manifest = DictPackManifest.parse(manifestBody);
    final dictMeta = manifest.fileFor(dictFileName);
    final aliasesMeta = manifest.fileFor(aliasesFileName);
    if (dictMeta == null || aliasesMeta == null) {
      throw const DictPackException('manifest 缺少词典文件条目');
    }

    onProgress?.call(0.05);
    await _downloadFile(
      dictMeta,
      dictFile(dir),
      onBytes: (received, total) {
        final fileWeight = total / (total + aliasesMeta.sizeBytes);
        onProgress?.call(0.05 + 0.9 * fileWeight * (received / total));
      },
    );

    onProgress?.call(0.95);
    await _downloadFile(
      aliasesMeta,
      aliasesFile(dir),
      onBytes: (received, total) {
        final dictWeight =
            dictMeta.sizeBytes / (dictMeta.sizeBytes + aliasesMeta.sizeBytes);
        onProgress?.call(
          0.05 + 0.9 * (dictWeight + (1 - dictWeight) * (received / total)),
        );
      },
    );

    await manifestFile(dir).writeAsString(manifestBody);

    if (!await isCacheValid()) {
      throw const DictPackException('下载后 SHA256 校验失败');
    }

    onProgress?.call(1.0);
  }

  Future<void> _downloadFile(
    DictPackFileMeta meta,
    File destination, {
    void Function(int received, int total)? onBytes,
  }) async {
    final part = File('${destination.path}.part');
    if (await part.exists()) await part.delete();

    final request = http.Request('GET', Uri.parse(meta.url));
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw DictPackException(
        '下载 ${meta.url} 失败：HTTP ${streamed.statusCode}',
      );
    }

    final total = meta.sizeBytes > 0
        ? meta.sizeBytes
        : streamed.contentLength ?? 0;
    final sink = part.openWrite();
    var received = 0;

    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onBytes?.call(received, total);
      }
    }
    await sink.close();

    final hash = _sha256OfFile(part);
    if (hash != meta.sha256.toLowerCase()) {
      await part.delete();
      if (await destination.exists()) await destination.delete();
      throw DictPackException(
        '${destination.path} SHA256 不匹配（期望 ${meta.sha256}，实际 $hash）',
      );
    }

    if (await destination.exists()) await destination.delete();
    await part.rename(destination.path);
  }

  Future<DictPackManifest?> _readLocalManifest(Directory dir) async {
    final file = manifestFile(dir);
    if (!await file.exists()) return null;
    try {
      return DictPackManifest.parse(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  String _sha256OfFile(File file) {
    final bytes = file.readAsBytesSync();
    return sha256.convert(bytes).toString();
  }
}

class DictPackException implements Exception {
  const DictPackException(this.message);

  final String message;

  @override
  String toString() => 'DictPackException: $message';
}

class DictPackManifest {
  const DictPackManifest({
    required this.version,
    required this.files,
  });

  final String version;
  final Map<String, DictPackFileMeta> files;

  DictPackFileMeta? fileFor(String fileName) => files[fileName];

  static DictPackManifest parse(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('manifest 根节点必须是 JSON 对象');
    }

    final version = '${decoded['version'] ?? '1'}';
    final files = <String, DictPackFileMeta>{};

    final filesRaw = decoded['files'];
    if (filesRaw is Map) {
      filesRaw.forEach((key, value) {
        if (value is! Map) return;
        files['$key'] = DictPackFileMeta.fromJson(
          Map<String, dynamic>.from(value),
        );
      });
    } else {
      final dictRaw = decoded['dict'];
      final aliasesRaw = decoded['aliases'];
      if (dictRaw is Map) {
        files[DictPackService.dictFileName] = DictPackFileMeta.fromJson(
          Map<String, dynamic>.from(dictRaw),
        );
      }
      if (aliasesRaw is Map) {
        files[DictPackService.aliasesFileName] = DictPackFileMeta.fromJson(
          Map<String, dynamic>.from(aliasesRaw),
        );
      }
    }

    if (files.isEmpty) {
      throw const FormatException('manifest 缺少词典文件条目');
    }

    return DictPackManifest(version: version, files: files);
  }
}

class DictPackFileMeta {
  const DictPackFileMeta({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  final String url;
  final String sha256;
  final int sizeBytes;

  factory DictPackFileMeta.fromJson(Map<String, dynamic> json) {
    return DictPackFileMeta(
      url: '${json['url'] ?? ''}',
      sha256: '${json['sha256'] ?? ''}'.toLowerCase(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}
