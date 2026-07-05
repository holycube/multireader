import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/import/block_splitter.dart';
import 'package:multi_novel_reader/import/book_paths.dart';
import 'package:multi_novel_reader/import/epub_importer.dart';
import 'package:multi_novel_reader/import/html_path_rewriter.dart';
import 'package:multi_novel_reader/import/import_constants.dart';
import 'package:multi_novel_reader/import/plain_text_utils.dart';

import 'helpers/minimal_epub.dart';

void main() {
  group('block_splitter', () {
    test('returns single chunk when under limit', () {
      final text = 'a' * 1999;
      expect(splitByCharLimit(text), [text]);
    });

    test('splits at exactly 12000', () {
      final text = 'a' * 12000;
      final chunks = splitByCharLimit(text);
      expect(chunks, ['a' * 12000]);
    });

    test('splits into two chunks at 12001', () {
      final text = 'a' * 12001;
      final chunks = splitByCharLimit(text);
      expect(chunks.length, 2);
      expect(chunks[0].length, ImportConstants.blockCharLimit);
      expect(chunks[1].length, 1);
    });

    test('splits 24001 into three chunks', () {
      final text = 'b' * 24001;
      final chunks = splitByCharLimit(text);
      expect(chunks.length, 3);
      expect(chunks.fold<int>(0, (s, c) => s + c.length), 24001);
    });
  });

  group('plain_text_utils', () {
    test('stripHtmlTags removes tags and decodes entities', () {
      const html = '<p>Hello &amp; world</p>';
      expect(stripHtmlTags(html), 'Hello & world');
    });

    test('stripHtmlTagsForSplit preserves paragraph breaks', () {
      const html = '<p>Line one</p><p>Line two</p>';
      expect(stripHtmlTagsForSplit(html), 'Line one\n\nLine two');
    });

    test('wrapPlainTextAsHtml escapes special chars', () {
      final wrapped = wrapPlainTextAsHtml('<script>');
      expect(wrapped, '<p>&lt;script&gt;</p>');
    });

    test('wrapPlainTextAsHtml splits paragraphs', () {
      final wrapped = wrapPlainTextAsHtml('A\n\nB');
      expect(wrapped, '<p>A</p><p>B</p>');
    });
  });

  group('html_path_rewriter', () {
    test('rewrites img src to assets path', () {
      const html = '<img src="images/cover.png" alt="cover"/>';
      final result = HtmlPathRewriter.rewrite(
        html,
        'OEBPS/chapter1.xhtml',
        {'images/cover.png': 'assets/cover.png'},
      );
      expect(result, contains('src="assets/cover.png"'));
    });

    test('leaves external urls unchanged', () {
      const html = '<a href="https://example.com">link</a>';
      final result = HtmlPathRewriter.rewrite(html, 'OEBPS/ch1.xhtml', {});
      expect(result, html);
    });
  });

  group('EpubImporter integration', () {
    late Directory tempDir;
    late AppDatabase db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('epub_importer_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('imports minimal epub with chapters and blocks', () async {
      final epubBytes = buildMinimalEpub();
      final epubFile = File('${tempDir.path}/test.epub');
      await epubFile.writeAsBytes(epubBytes);

      final paths = BookPaths.forRoot('${tempDir.path}/books');
      final importer = EpubImporter.withPaths(db, paths);
      final result = await importer.importFromFile(epubFile);

      expect(result.title, 'Test Book');
      expect(result.totalChapters, 1);
      expect(result.totalBlocks, 1);

      final book = await db.getBookById(result.bookId);
      expect(book!.importStatus, DbConstants.importStatusComplete);

      final blocks = await db.getContentBlocksByBook(result.bookId);
      expect(blocks.length, 1);
      expect(await File(blocks.first.contentPath).exists(), isTrue);
    });

    test('splits long chapter into multiple blocks', () async {
      final body = longBodyHtml(ImportConstants.blockCharLimit + 500);
      final epubBytes = buildMinimalEpub(bodyHtml: body);
      final epubFile = File('${tempDir.path}/long.epub');
      await epubFile.writeAsBytes(epubBytes);

      final paths = BookPaths.forRoot('${tempDir.path}/books');
      final importer = EpubImporter.withPaths(db, paths);
      final result = await importer.importFromFile(epubFile);

      expect(result.totalBlocks, greaterThan(1));
    });

    test('copies images to assets and rewrites html paths', () async {
      final pngBytes = List<int>.generate(64, (i) => i);
      final epubBytes = buildMinimalEpub(
        bodyHtml: '<p>Image below.</p><img src="images/pixel.png"/>',
        imageFileName: 'images/pixel.png',
        imageBytes: pngBytes,
      );
      final epubFile = File('${tempDir.path}/image.epub');
      await epubFile.writeAsBytes(epubBytes);

      final paths = BookPaths.forRoot('${tempDir.path}/books');
      final importer = EpubImporter.withPaths(db, paths);
      final result = await importer.importFromFile(epubFile);

      final assetsDir = Directory(paths.assetsDir(result.bookId));
      expect(await assetsDir.exists(), isTrue);

      final blocks = await db.getContentBlocksByBook(result.bookId);
      final html = await File(blocks.first.contentPath).readAsString();
      expect(html, contains('src="assets/'));
    });
  });
}
