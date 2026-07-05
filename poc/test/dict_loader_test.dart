import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/services/dict_pack_service.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_loader.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DictLoader.instance.resetForTesting();
  });

  test('load reads asset and lookup returns DictEntry', () async {
    await DictLoader.instance.load();
    expect(DictLoader.instance.isLoaded, isTrue);
    expect(DictLoader.instance.entryCount, greaterThanOrEqualTo(8000));
    expect(DictLoader.instance.lookup('hello'), isNotNull);

    final credit = DictLoader.instance.lookup('credit');
    expect(credit, isNotNull);
    expect(credit!.senses.length, greaterThan(1));
    expect(credit.examTags, isNotEmpty);

    expect(DictLoader.instance.lookup('not-a-real-word-xyz'), isNull);
  });

  test('resolve uses alias map when loaded from assets', () async {
    await DictLoader.instance.load();
    expect(DictLoader.instance.aliasCount, greaterThan(0));

    final ringing = DictLoader.instance.resolve('ringing');
    if (DictLoader.instance.lookup('ring') != null) {
      expect(ringing.hasVariantTabs, isTrue);
      expect(ringing.entry?.word, 'ring');
      expect(ringing.alias?.exchangeKey, 'i');
    }
  });

  test('loadFromPathsForTesting reads dict files from disk', () async {
    final tempDir = await Directory.systemTemp.createTemp('dict_loader_test_');
    try {
      const dictContent =
          '{"sample":{"word":"sample","senses":[{"pos":"n.","meanings":[{"text":"sample","primary":true}]}]}}';
      const aliasesContent =
          '{"samples":{"lemma":"sample","exchangeKey":"s"}}';

      final dictPath = '${tempDir.path}/mvp_dict.json';
      final aliasesPath = '${tempDir.path}/mvp_dict_aliases.json';
      await File(dictPath).writeAsString(dictContent);
      await File(aliasesPath).writeAsString(aliasesContent);

      await DictLoader.instance.loadFromPathsForTesting(
        dictPath: dictPath,
        aliasesPath: aliasesPath,
      );

      expect(DictLoader.instance.isLoaded, isTrue);
      expect(DictLoader.instance.lookup('sample'), isNotNull);
      expect(DictLoader.instance.resolve('samples').entry?.word, 'sample');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('release cache path helper matches DictPackService layout', () async {
    final tempDir = await Directory.systemTemp.createTemp('dict_loader_cache_');
    DictPackService.debugCacheRoot = tempDir;
    try {
      final cachePath = await DictLoader.cacheDictPathForTesting();
      expect(
        p.normalize(cachePath),
        p.normalize(
          p.joinAll([
            tempDir.path,
            ...DictPackService.cacheSubdirParts,
            DictPackService.dictFileName,
          ]),
        ),
      );
    } finally {
      DictPackService.debugCacheRoot = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('lookup is fast after load', () async {
    DictLoader.instance.loadMapForTesting({
      for (var i = 0; i < 5000; i++)
        'word$i': DictEntry(
          word: 'word$i',
          senses: [
            DictSense(
              pos: 'n.',
              meanings: DictMeaning.listFromStrings(['meaning $i']),
            ),
          ],
        ),
    });

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      DictLoader.instance.lookup('word${i % 5000}');
    }
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });

  test('loadMapForTesting supports unit tests without assets', () {
    DictLoader.instance.loadMapForTesting({
      'test': DictEntry(
        word: 'test',
        senses: [
          DictSense(
            pos: 'n.',
            meanings: DictMeaning.listFromStrings(['test']),
          ),
        ],
      ),
    });
    expect(DictLoader.instance.lookup('test'), isNotNull);
    expect(DictLoader.instance.lookup('test')!.summaryForVocab(), 'n. test');
    expect(DictLoader.instance.lookup('missing'), isNull);
  });
}
