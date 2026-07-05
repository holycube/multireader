import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/block_highlight_cache.dart';
import 'package:multi_novel_reader/reader/block_loader.dart';
import 'package:multi_novel_reader/reader/html_highlighter.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache cache;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
    tempDir = await Directory.systemTemp.createTemp('html_highlight_test');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedKnown(String word) async {
    await db.insertKnownWord(
      word: word,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String> writeBlockFile(String name, String html) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(html);
    return file.path;
  }

  test('unknown word gets span with data-word and unknown class', () async {
    await cache.load(db);

    final path = await writeBlockFile(
      'block.html',
      '<p>It was a Bright cold day.</p>',
    );

    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: '<p>It was a Bright cold day.</p>',
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.html, contains('data-word="bright"'));
    expect(result.html, contains('class="word"'));
    expect(result.html, contains('>Bright</span>'));
    expect(result.html, isNot(contains('text-decoration-style:dashed')));
  });

  test('known word in source still gets neutral word span only', () async {
    await seedKnown('bright');
    await cache.load(db);

    final path = await writeBlockFile('known.html', '<p>Bright day</p>');
    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: '<p>Bright day</p>',
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(
      result.html,
      contains('<span class="word" data-word="bright">Bright</span>'),
    );
    expect(
      result.html,
      contains('<span class="word" data-word="day"'),
    );
    expect(result.html, isNot(contains('known')));
    expect(result.html, isNot(contains('unknown')));
    expect(
      RegExp(r'<span class="word"[^>]*text-decoration').hasMatch(result.html),
      isFalse,
    );
  });

  test('script text is not tokenized', () async {
    await cache.load(db);

    final path = await writeBlockFile(
      'script.html',
      '<script>var secret = Bright;</script><p>Visible Bright</p>',
    );
    final result = await HtmlHighlighter.highlightBlock(
      rawHtml:
          '<script>var secret = Bright;</script><p>Visible Bright</p>',
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.html, contains('var secret = Bright;'));
    expect(result.html, contains('data-word="bright"'));
    expect(
      RegExp(r'<script>[\s\S]*Bright[\s\S]*</script>').hasMatch(result.html),
      isTrue,
    );
    expect(
      RegExp(r'<script>[\s\S]*data-word[\s\S]*</script>').hasMatch(result.html),
      isFalse,
    );
  });

  test('wraps bare body text in nr-word-wrap paragraph', () async {
    await cache.load(db);

    const raw =
        '<body>A Course in Economics<img src="cover.jpg"/><h1>Title</h1></body>';
    final path = await writeBlockFile('cover.html', raw);
    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: raw,
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.html, contains('class="nr-word-wrap"'));
    expect(result.html, contains('data-word="course"'));
    expect(
      RegExp(r'^<span', multiLine: true).hasMatch(result.html.trim()),
      isFalse,
    );
  });

  test('head title text is not tokenized', () async {
    await cache.load(db);

    const raw =
        '<head><title>Bright Day</title></head><p>Visible Bright</p>';
    final path = await writeBlockFile('head.html', raw);
    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: raw,
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.html, contains('<title>Bright Day</title>'));
    expect(
      RegExp(r'<title>[^<]*</title>').hasMatch(result.html),
      isTrue,
    );
    expect(result.html, contains('data-word="bright"'));
  });

  test('reads versioned side cache when source unchanged', () async {
    await cache.load(db);

    final path = await writeBlockFile('cache.html', '<p>Hello world</p>');
    final cachePath = HtmlHighlighter.cachePathFor(path);
    await File(cachePath).writeAsString(
      '${highlightCacheVersionPrefix}<p>CACHED</p>',
    );

    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: '<p>Hello world</p>',
      contentPath: path,
      cache: cache,
    );

    expect(result.fromCache, isTrue);
    expect(result.html, '<p>CACHED</p>');
  });

  test('ignores legacy cache without version prefix', () async {
    await cache.load(db);

    final path = await writeBlockFile('legacy.html', '<p>Hello world</p>');
    final cachePath = HtmlHighlighter.cachePathFor(path);
    await File(cachePath).writeAsString('<p>STALE CACHE</p>');

    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: '<p>Hello world</p>',
      contentPath: path,
      cache: cache,
    );

    expect(result.fromCache, isFalse);
    expect(result.html, isNot(contains('STALE CACHE')));
    expect(result.html, contains('data-word="hello"'));
  });

  test('force skips side cache and recomputes', () async {
    await seedKnown('hello');
    await cache.load(db);

    final path = await writeBlockFile('force.html', '<p>Hello</p>');
    final cachePath = HtmlHighlighter.cachePathFor(path);
    await File(cachePath).writeAsString(
      '${highlightCacheVersionPrefix}<p>STALE CACHE</p>',
    );

    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: '<p>Hello</p>',
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.fromCache, isFalse);
    expect(result.html, contains('class="word"'));
    expect(result.html, isNot(contains('STALE CACHE')));
  });

  test('~500 words highlight completes within 200ms', () async {
    await cache.load(db);

    final words = List.generate(500, (i) => 'word$i').join(' ');
    final html = '<p>$words</p>';
    final path = await writeBlockFile('perf.html', html);

    final result = await HtmlHighlighter.highlightBlock(
      rawHtml: html,
      contentPath: path,
      cache: cache,
      force: true,
    );

    expect(result.wordCount, greaterThanOrEqualTo(500));
    expect(result.elapsedMs, lessThan(200));
  });
}
