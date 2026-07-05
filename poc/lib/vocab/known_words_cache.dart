import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../database/constants.dart';
import '../database/database.dart';
import 'word_normalizer.dart';

/// 全局已知词内存缓存：启动时从 Drift 加载，O(1) 查询。
class KnownWordsCache extends ChangeNotifier {
  KnownWordsCache();

  Set<String> _words = const {};
  bool _loaded = false;
  Future<void>? _loadFuture;
  int _revision = 0;

  /// 词库变更代数；阅读器按块 [highlightRevision] 刷新，此处仅计数。
  int get revision => _revision;

  /// 最近一次 [load] 的 DB 读取耗时（ms），仅调试用。
  int? lastLoadDbMs;

  /// 最近一次 [load] 的 List→Set 耗时（ms），仅调试用。
  int? lastLoadSetMs;

  /// 最近一次 [load] 总耗时（ms），仅调试用。
  int? lastLoadTotalMs;

  /// 只读视图，加载前为空集。
  Set<String> get words => UnmodifiableSetView(_words);

  bool get isLoaded => _loaded;

  /// 从数据库加载词库；重复调用共享同一 Future。
  Future<void> load(AppDatabase db) {
    return _loadFuture ??= _load(db);
  }

  Future<void> _load(AppDatabase db) async {
    final totalSw = Stopwatch()..start();

    final dbSw = Stopwatch()..start();
    final list = await db.getKnownWordStrings();
    dbSw.stop();
    lastLoadDbMs = dbSw.elapsedMilliseconds;

    final setSw = Stopwatch()..start();
    _words = list.toSet();
    setSw.stop();
    lastLoadSetMs = setSw.elapsedMilliseconds;

    totalSw.stop();
    lastLoadTotalMs = totalSw.elapsedMilliseconds;
    _loaded = true;
  }

  /// 对原文 token 归一化后查询；加载完成前返回 false。
  bool isKnown(String rawToken) {
    if (!_loaded) return false;
    final normalized = normalizeWord(rawToken);
    if (normalized.isEmpty) return false;
    return _words.contains(normalized);
  }

  /// 对已归一化词形查询；供高亮管线内部使用。
  bool isKnownNormalized(String word) {
    if (!_loaded || word.isEmpty) return false;
    return _words.contains(word);
  }

  /// 写入 DB 并更新内存 Set；词形自动归一化。
  Future<void> addKnown(
    AppDatabase db,
    String rawToken, {
    String source = DbConstants.wordSourceUser,
  }) async {
    final normalized = normalizeWord(rawToken);
    if (normalized.isEmpty) return;

    await db.insertKnownWord(
      word: normalized,
      source: source,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (_loaded) {
      _words = {..._words, normalized};
      _bumpRevision();
    }
  }

  /// 从 DB 删除并更新内存 Set。
  Future<void> removeKnown(AppDatabase db, String rawToken) async {
    final normalized = normalizeWord(rawToken);
    if (normalized.isEmpty) return;

    await db.deleteKnownWord(normalized);
    if (_loaded) {
      final next = {..._words}..remove(normalized);
      _words = next;
      _bumpRevision();
    }
  }

  void _bumpRevision() {
    _revision++;
  }

  /// Clears in-memory state so the next [load] re-reads from DB.
  void invalidate() {
    _words = const {};
    _loaded = false;
    _loadFuture = null;
    _revision = 0;
    lastLoadDbMs = null;
    lastLoadSetMs = null;
    lastLoadTotalMs = null;
  }

  @visibleForTesting
  void resetForTesting() => invalidate();
}
