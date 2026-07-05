import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../services/dict_pack_service.dart';
import 'dict_entry.dart';
import 'dict_lookup_result.dart';

/// 内置 MVP JSON 词典：key 为归一化小写词形，value 为 [DictEntry]。
class DictLoader {
  DictLoader._();

  static final DictLoader instance = DictLoader._();

  static const assetPath = 'assets/dict/mvp_dict.json';
  static const aliasesAssetPath = 'assets/dict/mvp_dict_aliases.json';

  Map<String, DictEntry> _entries = const {};
  Map<String, DictAliasMeta> _aliases = const {};
  bool _loaded = false;
  Future<void>? _loadFuture;

  bool get isLoaded => _loaded;

  int get entryCount => _entries.length;

  int get aliasCount => _aliases.length;

  /// 加载词典；重复调用共享同一 Future。
  ///
  /// Debug / Profile / test：`rootBundle` 内置 assets。
  /// Release：本地缓存或 [DictPackService.ensureInstalled] 后读文件。
  Future<void> load({void Function(double progress)? onProgress}) {
    return _loadFuture ??= _loadImpl(onProgress: onProgress);
  }

  Future<void> _loadImpl({void Function(double progress)? onProgress}) async {
    if (!kReleaseMode) {
      await _loadFromAsset();
      return;
    }

    final service = DictPackService.instance;
    if (await service.isCacheValid()) {
      final dir = await service.cacheDirectory();
      await _loadFromFiles(dir);
      onProgress?.call(1.0);
      return;
    }

    await service.ensureInstalled(onProgress: onProgress);
    final dir = await service.cacheDirectory();
    await _loadFromFiles(dir);
  }

  Future<void> _loadFromAsset() async {
    final jsonText = await rootBundle.loadString(assetPath);
    var aliasesText = '{}';
    try {
      aliasesText = await rootBundle.loadString(aliasesAssetPath);
    } on FlutterError {
      // 别名文件可选；缺失时 resolve 仅走精确命中。
    }
    final parsed = await compute(_parseDictAssets, (jsonText, aliasesText));
    _entries = parsed.entries;
    _aliases = parsed.aliases;
    _loaded = true;
  }

  Future<void> _loadFromFiles(Directory dir) async {
    final dictFile = File('${dir.path}/${DictPackService.dictFileName}');
    final aliasesFile = File('${dir.path}/${DictPackService.aliasesFileName}');

    if (!await dictFile.exists()) {
      throw DictPackException('词典缓存缺失：${dictFile.path}');
    }

    final jsonText = await dictFile.readAsString();
    var aliasesText = '{}';
    if (await aliasesFile.exists()) {
      aliasesText = await aliasesFile.readAsString();
    }

    final parsed = await compute(_parseDictAssets, (jsonText, aliasesText));
    _entries = parsed.entries;
    _aliases = parsed.aliases;
    _loaded = true;
  }

  /// O(1) 查词；加载完成前返回 null。
  DictEntry? lookup(String normalized) {
    if (!_loaded || normalized.isEmpty) return null;
    return _entries[normalized];
  }

  /// 三级回落：精确命中 → 别名回落 → miss（原形优先，无 Tab）。
  DictLookupResult resolve(String normalized) {
    if (!_loaded || normalized.isEmpty) {
      return DictLookupResult(tappedWord: normalized);
    }

    final direct = _entries[normalized];
    if (direct != null) {
      return DictLookupResult(
        tappedWord: normalized,
        entry: direct,
      );
    }

    final alias = _aliases[normalized];
    if (alias != null) {
      return DictLookupResult(
        tappedWord: normalized,
        entry: _entries[alias.lemma],
        alias: alias,
      );
    }

    return DictLookupResult(tappedWord: normalized);
  }

  @visibleForTesting
  void resetForTesting() {
    _entries = const {};
    _aliases = const {};
    _loaded = false;
    _loadFuture = null;
  }

  /// 下载失败后允许再次调用 [load]。
  void clearPendingLoad() {
    if (_loaded) return;
    _entries = const {};
    _aliases = const {};
    _loaded = false;
    _loadFuture = null;
  }

  @visibleForTesting
  void loadMapForTesting(
    Map<String, DictEntry> entries, {
    Map<String, DictAliasMeta> aliases = const {},
  }) {
    _entries = Map<String, DictEntry>.from(entries);
    _aliases = Map<String, DictAliasMeta>.from(aliases);
    _loaded = true;
    _loadFuture = Future.value();
  }

  @visibleForTesting
  Future<void> loadFromFilesForTesting(Directory dir) => _loadFromFiles(dir);

  @visibleForTesting
  Future<void> loadFromPathsForTesting({
    required String dictPath,
    required String aliasesPath,
  }) async {
    final jsonText = await File(dictPath).readAsString();
    final aliasesText = await File(aliasesPath).readAsString();
    final parsed = await compute(_parseDictAssets, (jsonText, aliasesText));
    _entries = parsed.entries;
    _aliases = parsed.aliases;
    _loaded = true;
  }

  @visibleForTesting
  static Future<String> cacheDictPathForTesting() async {
    final dir = await DictPackService.instance.cacheDirectory();
    return p.join(dir.path, DictPackService.dictFileName);
  }
}

class _ParsedDictAssets {
  const _ParsedDictAssets({
    required this.entries,
    required this.aliases,
  });

  final Map<String, DictEntry> entries;
  final Map<String, DictAliasMeta> aliases;
}

_ParsedDictAssets _parseDictAssets((String, String) texts) {
  final (jsonText, aliasesText) = texts;
  return _ParsedDictAssets(
    entries: _parseDictJson(jsonText),
    aliases: _parseAliasesJson(aliasesText),
  );
}

Map<String, DictEntry> _parseDictJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('Dictionary root must be a JSON object');
  }
  final entries = <String, DictEntry>{};
  decoded.forEach((key, value) {
    if (value is! Map) return;
    final entry = DictEntry.fromJson(Map<String, dynamic>.from(value));
    if (entry.word.isEmpty) return;
    entries['$key'] = entry;
  });
  return entries;
}

Map<String, DictAliasMeta> _parseAliasesJson(String jsonText) {
  if (jsonText.trim().isEmpty) return const {};

  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('Aliases root must be a JSON object');
  }

  final aliases = <String, DictAliasMeta>{};
  decoded.forEach((key, value) {
    if (value is! Map) return;
    final meta = DictAliasMeta.fromJson(Map<String, dynamic>.from(value));
    if (meta.lemma.isEmpty || meta.exchangeKey.isEmpty) return;
    aliases['$key'] = meta;
  });
  return aliases;
}
