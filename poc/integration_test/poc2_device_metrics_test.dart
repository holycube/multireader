import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/html_highlighter.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_loader.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';
import 'package:multi_novel_reader/reader/txt_highlighter.dart';

/// ?? POC2 ?????????????
/// ???flutter test integration_test/poc2_device_metrics_test.dart -d <deviceId>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('POC2 device metrics', () {
    late Directory tempDir;
    late AppDatabase db;
    late KnownWordsCache cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('poc2_device_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      cache = KnownWordsCache();
      DictLoader.instance.resetForTesting();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('HTML/TXT highlight, lookup, 40k Set on device', (tester) async {
      await cache.load(db);

      final words = List.generate(500, (i) => 'word$i').join(' ');
      final html = '<p>$words</p>';
      final path =
          '${tempDir.path}${Platform.pathSeparator}perf.html';
      await File(path).writeAsString(html);

      final htmlResult = await HtmlHighlighter.highlightBlock(
        rawHtml: html,
        contentPath: path,
        cache: cache,
        force: true,
      );

      final txtSw = Stopwatch()..start();
      TxtHighlighter.buildSpans(plainText: words, cache: cache);
      txtSw.stop();

      DictLoader.instance.loadMapForTesting({
        for (var i = 0; i < 5000; i++)
          'word$i': DictEntry(
            word: 'word$i',
            senses: [
              DictSense(
                pos: 'n.',
                meanings: DictMeaning.listFromStrings(['?? $i']),
              ),
            ],
          ),
      });
      final lookupSw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        DictLoader.instance.lookup('word${i % 5000}');
      }
      lookupSw.stop();

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
      final setSw = Stopwatch()..start();
      await cache.load(db);
      setSw.stop();

      // ignore: avoid_print
      print('[POC2-DEVICE] html=${htmlResult.elapsedMs}ms '
          'txt=${txtSw.elapsedMilliseconds}ms '
          'lookup=${lookupSw.elapsedMilliseconds}ms '
          '40kSet=${setSw.elapsedMilliseconds}ms');

      expect(htmlResult.elapsedMs, lessThan(200));
      expect(txtSw.elapsedMilliseconds, lessThan(200));
      expect(lookupSw.elapsedMilliseconds, lessThan(100));
      expect(setSw.elapsedMilliseconds, lessThan(500));
    });
  });
}
