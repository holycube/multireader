import 'dart:io';

import '../database/database.dart';

/// 已加载的块：元数据 + 文件全文。
class LoadedBlock {
  const LoadedBlock({
    required this.meta,
    required this.content,
  });

  final ContentBlock meta;
  final String content;
}

/// 按块从文件系统读取内容，LRU 缓存当前块 ±1（最多 3 项）。
class BlockLoader {
  BlockLoader({this.maxCacheSize = 3});

  final int maxCacheSize;

  final Map<int, LoadedBlock> _cache = {};
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// 从缓存或磁盘加载块内容。
  Future<LoadedBlock> load(ContentBlock meta) async {
    final index = meta.globalBlockIndex;
    final cached = _cache[index];
    if (cached != null) {
      _currentIndex = index;
      return cached;
    }

    final content = await File(meta.contentPath).readAsString();
    final loaded = LoadedBlock(meta: meta, content: content);
    _putCache(index, loaded);
    _currentIndex = index;
    return loaded;
  }

  /// 后台预热相邻块，不阻塞调用方。
  void prefetch(ContentBlock? meta) {
    if (meta == null) return;
    final index = meta.globalBlockIndex;
    if (_cache.containsKey(index)) return;

    File(meta.contentPath).readAsString().then((content) {
      if (_cache.containsKey(index)) return;
      _putCache(index, LoadedBlock(meta: meta, content: content));
    }).ignore();
  }

  /// 根据当前焦点索引预热 index±1。
  Future<void> prefetchAdjacentAsync({
    required Future<ContentBlock?> Function(int index) resolveMeta,
  }) async {
    final prev = _currentIndex > 0
        ? await resolveMeta(_currentIndex - 1)
        : null;
    final next = await resolveMeta(_currentIndex + 1);
    if (prev != null) prefetch(prev);
    if (next != null) prefetch(next);
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
  }

  LoadedBlock? getCached(int index) => _cache[index];

  void evictAll() {
    _cache.clear();
    _currentIndex = 0;
  }

  void _putCache(int index, LoadedBlock loaded) {
    if (_cache.containsKey(index)) {
      _cache[index] = loaded;
      return;
    }

    while (_cache.length >= maxCacheSize) {
      _evictFarthestFrom(_currentIndex);
    }
    _cache[index] = loaded;
  }

  void _evictFarthestFrom(int center) {
    if (_cache.isEmpty) return;

    var farthestKey = _cache.keys.first;
    var maxDistance = (farthestKey - center).abs();

    for (final key in _cache.keys) {
      final distance = (key - center).abs();
      if (distance > maxDistance) {
        maxDistance = distance;
        farthestKey = key;
      }
    }
    _cache.remove(farthestKey);
  }
}
