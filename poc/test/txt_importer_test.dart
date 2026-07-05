import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/import/book_paths.dart';
import 'package:multi_novel_reader/import/import_constants.dart';
import 'package:multi_novel_reader/import/import_result.dart';
import 'package:multi_novel_reader/import/txt_chapter_parser.dart';
import 'package:multi_novel_reader/import/txt_importer.dart';

void main() {
  group('parseTxtChapters', () {
    test('splits on chapter headers and excludes title from body', () {
      const text = '''
Chapter 1
First chapter body.

Chapter 2
Second chapter body.
''';

      final segments = parseTxtChapters(text);

      expect(segments.length, 2);
      expect(segments[0].title, 'Chapter 1');
      expect(segments[0].body, 'First chapter body.');
      expect(segments[1].title, 'Chapter 2');
      expect(segments[1].body, 'Second chapter body.');
    });

    test('matches CH. and roman numerals', () {
      const text = '''
CH. II
Body two.

chapter IV
Body four.
''';

      final segments = parseTxtChapters(text);
      expect(segments.length, 2);
      expect(segments[1].title, contains('IV'));
    });

    test('prepends preamble to first chapter body', () {
      const text = '''
Prologue text here.

Chapter 1
Chapter one body.
''';

      final segments = parseTxtChapters(text);
      expect(segments.first.body, contains('Prologue text here.'));
      expect(segments.first.body, contains('Chapter one body.'));
    });

    test('falls back to numbered segments when no chapter marker', () {
      final text = 'a' * (ImportConstants.blockCharLimit + 1);
      final segments = parseTxtChapters(text);

      expect(segments.length, 2);
      expect(segments[0].title, '第 1 段');
      expect(segments[0].body.length, ImportConstants.blockCharLimit);
      expect(segments[1].body.length, 1);
    });

    test('throws on empty file', () {
      expect(() => parseTxtChapters('   '), throwsA(isA<ImportException>()));
    });
  });

  group('TxtImporter integration', () {
    late Directory tempDir;
    late AppDatabase db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('txt_importer_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<ImportResult> importText(String name, String content) async {
      final txtFile = File('${tempDir.path}/$name');
      await txtFile.writeAsString(content);
      final paths = BookPaths.forRoot('${tempDir.path}/books');
      final importer = TxtImporter.withPaths(db, paths);
      return importer.importFromFile(txtFile);
    }

    test('imports txt with three chapters', () async {
      const content = '''
Chapter 1
Alpha.

Chapter 2
Beta.

Chapter 3
Gamma.
''';

      final result = await importText('three_chapters.txt', content);

      expect(result.title, 'three_chapters');
      expect(result.totalChapters, 3);
      expect(result.totalBlocks, 3);

      final book = await db.getBookById(result.bookId);
      expect(book!.importStatus, DbConstants.importStatusComplete);
      expect(book.sourceFormat, DbConstants.sourceFormatTxt);

      final chapters = await db.getChaptersByBook(result.bookId);
      expect(chapters.map((c) => c.title).toList(), [
        'Chapter 1',
        'Chapter 2',
        'Chapter 3',
      ]);

      final blocks = await db.getContentBlocksByBook(result.bookId);
      expect(blocks.length, 3);
      for (var i = 0; i < blocks.length; i++) {
        expect(blocks[i].globalBlockIndex, i);
        expect(blocks[i].storageType, DbConstants.storageTypePlain);
        expect(await File(blocks[i].contentPath).exists(), isTrue);
      }
    });

    test('splits long chapter into multiple blocks', () async {
      final body = 'x' * (ImportConstants.blockCharLimit + 1);
      final content = 'Chapter 1\n$body';

      final result = await importText('long_chapter.txt', content);
      expect(result.totalChapters, 1);
      expect(result.totalBlocks, 2);

      final chapter = (await db.getChaptersByBook(result.bookId)).first;
      expect(chapter.blockCount, 2);
    });

    test('initializes parse_quota with full book unlock', () async {
      final result = await importText('quota.txt', 'Chapter 1\nHello world.');

      final book = await db.getBookById(result.bookId);
      final quota = await db.getParseQuota(result.bookId);
      expect(quota!.unlockedBlockCount, book!.totalBlocks);
      expect(quota.freeAllowance, book.totalBlocks);
    });

    test('block file content matches charCount in database', () async {
      const content = 'Chapter 1\nExact content here.';
      final result = await importText('content_match.txt', content);

      final block = (await db.getContentBlocksByBook(result.bookId)).first;
      final fileContent = await File(block.contentPath).readAsString();

      expect(fileContent, 'Exact content here.');
      expect(block.charCount, fileContent.length);
    });
  });
}
