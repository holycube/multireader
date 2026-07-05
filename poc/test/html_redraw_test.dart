import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/block_highlight_cache.dart';
import 'package:multi_novel_reader/reader/block_loader.dart';
import 'package:multi_novel_reader/reader/html_highlighter.dart';
import 'package:multi_novel_reader/reader/word_lookup_service.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache cache;
  late BlockHighlightCache highlightCache;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
    highlightCache = BlockHighlightCache();
    tempDir = await Directory.systemTemp.createTemp('html_redraw_test_');
    await cache.load(db);
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

  test('markKnown keeps highlight html and memory cache', () async {
    final loaded = await loadedBlock('<p>The quick fox jumps</p>');
    final first = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: cache,
      force: true,
    );
    expect(first.html, contains('data-word="fox"'));

    final service = WordLookupService(db: db, knownWordsCache: cache);
    await service.markKnown('fox');

    final second = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: cache,
    );

    expect(second.fromCache, isTrue);
    expect(second.html, first.html);
    expect(cache.revision, 1);
    expect(cache.isKnownNormalized('fox'), isTrue);
  });

  test('markKnown runtime path under 300ms without force highlight', () async {
    final words = List.generate(500, (i) => 'word$i').join(' ');
    final html = '<p>$words</p>';
    final loaded = await loadedBlock(html, index: 1);

    await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: cache,
      force: true,
    );

    final service = WordLookupService(db: db, knownWordsCache: cache);
    final sw = Stopwatch()..start();
    await service.markKnown('word250');
    final peek = await highlightCache.getOrHighlight(
      loaded: loaded,
      cache: cache,
    );
    sw.stop();

    expect(peek.fromCache, isTrue);
    expect(cache.revision, 1);
    expect(sw.elapsedMilliseconds, lessThan(300));
  });
}
