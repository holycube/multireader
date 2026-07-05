import '../database/database.dart';
import '../vocab/known_words_cache.dart';
import '../vocab/word_normalizer.dart';

/// 查词时的书籍/块上下文，用于写入 vocab_entries 例句定位。
class WordContext {
  const WordContext({
    required this.bookId,
    required this.chapterId,
    required this.blockId,
    required this.blockText,
  });

  final String bookId;
  final String chapterId;
  final String blockId;
  final String blockText;
}

/// 查词状态机四操作，对齐 docs/data-model.md §9。
class WordLookupService {
  WordLookupService({
    required this.db,
    required this.knownWordsCache,
  });

  final AppDatabase db;
  final KnownWordsCache knownWordsCache;

  /// 已会：INSERT known_words，保留已有 vocab_entries。
  Future<void> markKnown(String rawWord) async {
    final normalized = normalizeWord(rawWord);
    if (normalized.isEmpty) return;
    await knownWordsCache.addKnown(db, normalized);
  }

  /// 收藏：不变 known_words，INSERT/UPDATE vocab_entries starred=true。
  Future<void> starWord({
    required String rawWord,
    String? definition,
    WordContext? context,
  }) async {
    final normalized = normalizeWord(rawWord);
    if (normalized.isEmpty) return;

    final snippet = context == null
        ? null
        : extractContextSnippet(context.blockText, normalized);

    await db.upsertVocabEntry(
      word: normalized,
      definition: definition,
      context: snippet,
      bookId: context?.bookId,
      chapterId: context?.chapterId,
      blockId: context?.blockId,
      starred: true,
    );
  }

  /// 加入生词本：DELETE known_words + INSERT vocab starred=false。
  Future<void> addToVocab({
    required String rawWord,
    String? definition,
    WordContext? context,
  }) async {
    final normalized = normalizeWord(rawWord);
    if (normalized.isEmpty) return;

    final snippet = context == null
        ? null
        : extractContextSnippet(context.blockText, normalized);

    await knownWordsCache.removeKnown(db, normalized);
    await db.upsertVocabEntry(
      word: normalized,
      definition: definition,
      context: snippet,
      bookId: context?.bookId,
      chapterId: context?.chapterId,
      blockId: context?.blockId,
      starred: false,
    );
  }

  /// 确认已会：幂等 INSERT known_words，不变 vocab_entries。
  Future<void> confirmKnown(String rawWord) async {
    await markKnown(rawWord);
  }

  /// 在块文本中截取词首次出现前后各 [radius] 字符作为例句。
  static String? extractContextSnippet(
    String blockText,
    String normalized, {
    int radius = 40,
  }) {
    if (blockText.isEmpty || normalized.isEmpty) return null;

    final lower = blockText.toLowerCase();
    final target = normalized.toLowerCase();
    final index = _indexOfWord(lower, target);
    if (index < 0) return null;

    final start = (index - radius).clamp(0, blockText.length);
    final end = (index + target.length + radius).clamp(0, blockText.length);
    var snippet = blockText.substring(start, end).trim();
    if (start > 0) snippet = '…$snippet';
    if (end < blockText.length) snippet = '$snippet…';
    return snippet;
  }

  static int _indexOfWord(String lowerText, String normalized) {
    var searchFrom = 0;
    while (searchFrom < lowerText.length) {
      final index = lowerText.indexOf(normalized, searchFrom);
      if (index < 0) return -1;
      final beforeOk = index == 0 || !_isWordChar(lowerText[index - 1]);
      final afterIndex = index + normalized.length;
      final afterOk =
          afterIndex >= lowerText.length || !_isWordChar(lowerText[afterIndex]);
      if (beforeOk && afterOk) return index;
      searchFrom = index + 1;
    }
    return -1;
  }

  static bool _isWordChar(String char) {
    return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char);
  }
}
