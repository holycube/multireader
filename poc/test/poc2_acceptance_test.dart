import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/html_highlighter.dart';
import 'package:multi_novel_reader/reader/txt_highlighter.dart';
import 'package:multi_novel_reader/reader/word_lookup_service.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_loader.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late KnownWordsCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('poc2_acceptance_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
    DictLoader.instance.resetForTesting();
    DictLoader.instance.loadMapForTesting({
      for (var i = 0; i < 5000; i++)
        'word$i': DictEntry(
          word: 'word$i',
          senses: [
            DictSense(
              pos: 'n.',
              meanings: DictMeaning.listFromStrings(['释义']),
            ),
          ],
        ),
    });
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> writeBlockFile(String name, String content) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(content);
    return file.path;
  }

  group('POC2 acceptance', () {
    test('HTML 5000 words highlight < 1s (warm)', () async {
      await cache.load(db);

      final words = List.generate(5000, (i) => 'word$i').join(' ');
      final html = '<p>$words</p>';
      final path = await writeBlockFile('perf.html', html);

      // JIT / allocator warmup — full-suite runs contend on CPU without this.
      await HtmlHighlighter.highlightBlock(
        rawHtml: html,
        contentPath: path,
        cache: cache,
        force: true,
      );

      final sw = Stopwatch()..start();
      final result = await HtmlHighlighter.highlightBlock(
        rawHtml: html,
        contentPath: path,
        cache: cache,
        force: true,
      );
      sw.stop();

      expect(result.wordCount, greaterThanOrEqualTo(5000));
      // POC report target ~200ms isolated; allow headroom when entire suite runs.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('TXT 5000 words buildSpans < 200ms', () async {
      await cache.load(db);

      final words = List.generate(5000, (i) => 'word$i').join(' ');
      final sw = Stopwatch()..start();
      final result = TxtHighlighter.buildSpans(plainText: words, cache: cache);
      sw.stop();

      expect(result.wordCount, 5000);
      expect(sw.elapsedMilliseconds, lessThan(200));
    });

    test('JSON dict lookup 10000x < 100ms', () async {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        DictLoader.instance.lookup('word${i % 5000}');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('40k known_words Set cold load < 500ms', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.batch((batch) {
        for (var i = 0; i < 40000; i++) {
          batch.insert(
            db.knownWords,
            KnownWordsCompanion.insert(
              word: 'word${i.toString().padLeft(5, '0')}',
              addedAt: now,
            ),
          );
        }
      });

      cache.resetForTesting();
      final sw = Stopwatch()..start();
      await cache.load(db);
      sw.stop();

      expect(cache.words.length, 40000);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });
}
