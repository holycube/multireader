import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/txt_highlighter.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache cache;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedKnown(String word) async {
    await db.insertKnownWord(
      word: word,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  test('tokenizePlain preserves whitespace and words', () {
    const text = 'It was a  Bright\ncold day.';
    final parts = TxtHighlighter.tokenizePlain(text);

    expect(parts.map((p) => p.value).join(), text);
    expect(parts.where((p) => !p.isWhitespace).map((p) => p.value).toList(), [
      'It',
      'was',
      'a',
      'Bright',
      'cold',
      'day.',
    ]);
  });

  test('unknown word gets dashed underline style', () async {
    await cache.load(db);

    final result = TxtHighlighter.buildSpans(
      plainText: 'It was a Bright cold day.',
      cache: cache,
    );

    final unknownSpan = _findSpanWithText(result.rootSpan, 'Bright');
    expect(unknownSpan, isNotNull);
    expect(
      unknownSpan!.style?.decoration,
      TextDecoration.underline,
    );
    expect(
      unknownSpan.style?.decorationStyle,
      TextDecorationStyle.dashed,
    );
    expect(unknownSpan.style?.decorationThickness, 1.5);
  });

  test('dark mode highlight uses custom decoration color', () async {
    await cache.load(db);
    const darkHighlight = Color(0xFF81D4FA);

    final result = TxtHighlighter.buildSpans(
      plainText: 'Bright day',
      cache: cache,
      unknownHighlightColor: darkHighlight,
    );

    final unknownSpan = _findSpanWithText(result.rootSpan, 'Bright');
    expect(unknownSpan, isNotNull);
    expect(unknownSpan!.style?.decorationColor, darkHighlight);
    expect(unknownSpan.style?.decorationThickness, 1.5);
  });

  test('known word has no underline decoration', () async {
    await seedKnown('bright');
    await cache.load(db);

    final result = TxtHighlighter.buildSpans(
      plainText: 'Bright day',
      cache: cache,
    );

    final knownSpan = _findSpanWithText(result.rootSpan, 'Bright');
    expect(knownSpan, isNotNull);
    expect(knownSpan!.style?.decoration, isNull);
  });

  test('normalizeWord strips edge punctuation for lookup', () async {
    await cache.load(db);

    final result = TxtHighlighter.buildSpans(
      plainText: '"Bright," she said.',
      cache: cache,
    );

    final span = _findSpanWithText(result.rootSpan, '"Bright,"');
    expect(span, isNotNull);
    expect(
      span!.style?.decoration,
      TextDecoration.underline,
    );
  });

  test('onWordTap receives normalized word and isUnknown flag', () async {
    await seedKnown('day');
    await cache.load(db);

    String? tappedWord;
    bool? tappedUnknown;

    TxtHighlighter.buildSpans(
      plainText: 'Bright day',
      cache: cache,
      onWordTap: (normalized, isUnknown) {
        tappedWord = normalized;
        tappedUnknown = isUnknown;
      },
    ).recognizers.first.onTap?.call();

    expect(tappedWord, 'bright');
    expect(tappedUnknown, isTrue);
  });

  test('buildSpans handles ~500 words under 200ms', () async {
    await cache.load(db);

    final words = List.generate(500, (i) => 'word$i').join(' ');
    final stopwatch = Stopwatch()..start();
    final result = TxtHighlighter.buildSpans(plainText: words, cache: cache);
    stopwatch.stop();

    expect(result.wordCount, 500);
    expect(stopwatch.elapsedMilliseconds, lessThan(200));
  });
}

TextSpan? _findSpanWithText(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text) return span;
    if (span.children != null) {
      for (final child in span.children!) {
        final found = _findSpanWithText(child, text);
        if (found != null) return found;
      }
    }
  }
  return null;
}
