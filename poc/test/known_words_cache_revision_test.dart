import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/html_highlighter.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  test('cache revision bumps on addKnown and removeKnown', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    await cache.load(db);

    expect(cache.revision, 0);

    await cache.addKnown(db, 'alpha');
    expect(cache.revision, 1);
    expect(cache.isKnownNormalized('alpha'), isTrue);

    await cache.removeKnown(db, 'alpha');
    expect(cache.revision, 2);
    expect(cache.isKnownNormalized('alpha'), isFalse);

    await db.close();
  });

  test('highlight output is stable regardless of known words', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    await cache.load(db);
    final tempDir = await Directory.systemTemp.createTemp('revision_stable_');

    const raw = '<p>Bright cold day</p>';
    final pathA =
        '${tempDir.path}${Platform.pathSeparator}a.html';
    final pathB =
        '${tempDir.path}${Platform.pathSeparator}b.html';
    await File(pathA).writeAsString(raw);
    await File(pathB).writeAsString(raw);

    final resultEmpty = await HtmlHighlighter.highlightBlock(
      rawHtml: raw,
      contentPath: pathA,
      cache: cache,
      force: true,
    );

    await cache.addKnown(db, 'bright');
    final resultKnown = await HtmlHighlighter.highlightBlock(
      rawHtml: raw,
      contentPath: pathB,
      cache: cache,
      force: true,
    );

    expect(resultEmpty.html, resultKnown.html);
    expect(resultEmpty.html, contains('data-word="bright"'));
    expect(resultEmpty.html, isNot(contains('known')));

    await db.close();
    await tempDir.delete(recursive: true);
  });
}
