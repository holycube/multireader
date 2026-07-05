import '../../database/database.dart';
import '../../vocab/known_words_cache.dart';

/// 批量写入 known_words 并重新加载内存 Set。
Future<void> batchInsertKnownWords({
  required AppDatabase db,
  required KnownWordsCache cache,
  required List<String> words,
  required String source,
  void Function(int done, int total)? onProgress,
}) async {
  if (words.isEmpty) return;

  final addedAt = DateTime.now().millisecondsSinceEpoch;
  final total = words.length;

  for (var i = 0; i < total; i++) {
    await db.insertKnownWord(
      word: words[i],
      source: source,
      addedAt: addedAt,
    );
    onProgress?.call(i + 1, total);
  }

  await reloadKnownWordsCache(db: db, cache: cache);
}

/// 清空 known_words 并重新加载内存 Set。
Future<void> clearKnownWords({
  required AppDatabase db,
  required KnownWordsCache cache,
}) async {
  await db.customStatement('DELETE FROM known_words');
  await reloadKnownWordsCache(db: db, cache: cache);
}

/// 从 DB 重载词库缓存，并 bump revision 以触发阅读器高亮重绘。
Future<void> reloadKnownWordsCache({
  required AppDatabase db,
  required KnownWordsCache cache,
}) async {
  cache.invalidate();
  await cache.load(db);
  await _bumpCacheRevision(db, cache);
}

Future<void> _bumpCacheRevision(AppDatabase db, KnownWordsCache cache) async {
  const probe = 'zzzcacheprobe';
  await cache.addKnown(db, probe);
  await cache.removeKnown(db, probe);
}
