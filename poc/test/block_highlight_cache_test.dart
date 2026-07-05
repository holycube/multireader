import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/block_highlight_cache.dart';
import 'package:multi_novel_reader/reader/block_loader.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache knownWords;
  late BlockHighlightCache highlightCache;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    knownWords = KnownWordsCache();
    highlightCache = BlockHighlightCache();
    tempDir = await Directory.systemTemp.createTemp('highlight_cache_test');
    await knownWords.load(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LoadedBlock> loadedBlock(String html, {int index = 0}) async {
    final path = '${tempDir.path}${Platform.pathSeparator}block_$index.html';
    await File(path).writeAsString(html);
    final meta = ContentBlock(
      id: 'block-$index',
      bookId: 'book-1',
      chapterId: 'chapter-1',
      blockOrderInChapter: 0,
      globalBlockIndex: index,
      storageType: DbConstants.storageTypeHtml,
      contentPath: path,
      charCount: html.length,
      parseStatus: DbConstants.parseStatusDone,
      parsedAt: null,
    );
    return LoadedBlock(meta: meta, content: html);
  }

  test('second getOrHighlight hits memory cache', () async {
    final loaded = await loadedBlock('<p>Hello world</p>');

    final first = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: knownWords,
    );
    final second = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: knownWords,
    );

    expect(first.html, second.html);
    expect(second.fromCache, isTrue);
    expect(second.elapsedMs, 0);
  });

  test('prefetch warms memory for subsequent getOrHighlight', () async {
    final loaded = await loadedBlock('<p>Prefetch works</p>', index: 1);

    highlightCache.prefetch(loaded: loaded, cache: knownWords);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final result = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: knownWords,
    );

    expect(result.fromCache, isTrue);
    expect(result.html, contains('data-word="prefetch"'));
  });

  test('invalidate forces recompute', () async {
    final loaded = await loadedBlock('<p>Invalidate me</p>', index: 2);

    await highlightCache.getOrHighlight(loaded: loaded, cache: knownWords);
    highlightCache.invalidate(2);

    final result = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: knownWords,
      force: true,
    );

    expect(result.fromCache, isFalse);
    expect(result.html, contains('data-word="invalidate"'));
  });
}
