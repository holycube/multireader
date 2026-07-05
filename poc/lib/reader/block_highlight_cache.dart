import 'block_loader.dart';
import '../vocab/known_words_cache.dart';
import 'html_highlighter.dart';

/// 块高亮内存池：内存 → 旁文件 → CPU 高亮；支持预取。
class BlockHighlightCache {
  final Map<int, String> _memory = {};
  final Map<int, Future<HtmlHighlightResult>> _inFlight = {};

  String? peek(int globalBlockIndex) => _memory[globalBlockIndex];

  void put(int globalBlockIndex, String html) {
    _memory[globalBlockIndex] = html;
  }

  void invalidate(int globalBlockIndex) {
    _memory.remove(globalBlockIndex);
    _inFlight.remove(globalBlockIndex);
  }

  void invalidateAll() {
    _memory.clear();
    _inFlight.clear();
  }

  /// 获取高亮 HTML；优先内存与旁文件缓存。
  Future<HtmlHighlightResult> getOrHighlight({
    required LoadedBlock loaded,
    required KnownWordsCache cache,
    bool force = false,
  }) async {
    final index = loaded.meta.globalBlockIndex;

    if (!force) {
      final cached = _memory[index];
      if (cached != null) {
        return HtmlHighlightResult(
          html: cached,
          elapsedMs: 0,
          wordCount: 0,
          fromCache: true,
        );
      }

      final inFlight = _inFlight[index];
      if (inFlight != null) {
        return inFlight;
      }
    } else {
      invalidate(index);
    }

    final future = _highlight(loaded, cache, force: force);
    _inFlight[index] = future;

    try {
      final result = await future;
      _memory[index] = result.html;
      return result;
    } finally {
      _inFlight.remove(index);
    }
  }

  /// 后台预取高亮，不阻塞调用方。
  void prefetch({
    required LoadedBlock loaded,
    required KnownWordsCache cache,
  }) {
    final index = loaded.meta.globalBlockIndex;
    if (_memory.containsKey(index) || _inFlight.containsKey(index)) return;

    _inFlight[index] = _highlight(loaded, cache, force: false).then((result) {
      _memory[index] = result.html;
      _inFlight.remove(index);
      return result;
    }).catchError((Object _) {
      _inFlight.remove(index);
      return HtmlHighlightResult(
        html: loaded.content,
        elapsedMs: 0,
        wordCount: 0,
      );
    });
  }

  Future<HtmlHighlightResult> _highlight(
    LoadedBlock loaded,
    KnownWordsCache cache, {
    required bool force,
  }) {
    return HtmlHighlighter.highlightBlock(
      rawHtml: loaded.content,
      contentPath: loaded.meta.contentPath,
      cache: cache,
      force: force,
    );
  }
}
