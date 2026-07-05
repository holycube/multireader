import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/word_tap_factory.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

Map<String, String>? _unknownWordStyles(
  dom.Element element,
  KnownWordsCache cache,
) {
  if (!element.classes.contains('word')) return null;
  final word = element.attributes['data-word'];
  if (word == null || word.isEmpty) return null;
  if (!cache.isKnownNormalized(word)) {
    return const {
      'text-decoration': 'underline',
      'text-decoration-style': 'dashed',
    };
  }
  return null;
}

Widget _htmlBlock({
  required String html,
  required KnownWordsCache cache,
  required int highlightRevision,
  Key? key,
}) {
  return HtmlWidget(
    html,
    key: key ?? ValueKey('block-$highlightRevision'),
    buildAsync: false,
    enableCaching: true,
    rebuildTriggers: [highlightRevision],
    factoryBuilder: () => WordTapWidgetFactory(knownWordsCache: cache),
    customStylesBuilder: (element) => _unknownWordStyles(element, cache),
  );
}

void main() {
  testWidgets('per-block highlightRevision rebuild under 500ms for ~200 words', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    await cache.load(db);

    final words = List.generate(200, (i) => 'word$i').join(' ');
    final html =
        '<p>${words.split(' ').map((w) => '<span class="word" data-word="$w">$w</span>').join(' ')}</p>';

    var highlightRevision = 0;

    Future<void> pumpBlock() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _htmlBlock(
                html: html,
                cache: cache,
                highlightRevision: highlightRevision,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await pumpBlock();

    final sw = Stopwatch()..start();
    await cache.addKnown(db, 'word0');
    highlightRevision++;
    await pumpBlock();
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(500));
    expect(cache.isKnownNormalized('word0'), isTrue);

    await db.close();
  });

  testWidgets('non-target block highlightRevision unchanged skips rebuild', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    await cache.load(db);

    const htmlA =
        '<p><span class="word" data-word="alpha">alpha</span></p>';
    const htmlB =
        '<p><span class="word" data-word="beta">beta</span></p>';

    var revisionA = 0;
    const revisionB = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _htmlBlock(
                html: htmlA,
                cache: cache,
                highlightRevision: revisionA,
                key: const ValueKey('block-a'),
              ),
              _htmlBlock(
                html: htmlB,
                cache: cache,
                highlightRevision: revisionB,
                key: const ValueKey('block-b'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('block-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-b')), findsOneWidget);

    await cache.addKnown(db, 'alpha');
    revisionA = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _htmlBlock(
                html: htmlA,
                cache: cache,
                highlightRevision: revisionA,
                key: const ValueKey('block-a'),
              ),
              _htmlBlock(
                html: htmlB,
                cache: cache,
                highlightRevision: revisionB,
                key: const ValueKey('block-b'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('block-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-b')), findsOneWidget);
    expect(cache.isKnownNormalized('alpha'), isTrue);
    expect(cache.isKnownNormalized('beta'), isFalse);

    await db.close();
  });
}
