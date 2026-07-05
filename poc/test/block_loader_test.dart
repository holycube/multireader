import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/block_loader.dart';

ContentBlock _blockMeta({
  required int index,
  required String contentPath,
  String storageType = DbConstants.storageTypePlain,
}) {
  return ContentBlock(
    id: 'block-$index',
    bookId: 'book-1',
    chapterId: 'chapter-1',
    blockOrderInChapter: index,
    globalBlockIndex: index,
    storageType: storageType,
    contentPath: contentPath,
    charCount: 10,
    parseStatus: DbConstants.parseStatusPending,
  );
}

Future<String> _writeTempBlock(Directory dir, int index, String text) async {
  final file = File('${dir.path}/block_${index.toString().padLeft(4, '0')}.txt');
  await file.writeAsString(text);
  return file.path;
}

void main() {
  group('BlockLoader', () {
    late Directory tempDir;
    late BlockLoader loader;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('block_loader_test');
      loader = BlockLoader();
    });

    tearDown(() async {
      loader.evictAll();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reads block content from disk', () async {
      final path = await _writeTempBlock(tempDir, 0, 'Hello block zero');
      final meta = _blockMeta(index: 0, contentPath: path);

      final loaded = await loader.load(meta);

      expect(loaded.content, 'Hello block zero');
      expect(loaded.meta.globalBlockIndex, 0);
    });

    test('returns cached block without re-reading file', () async {
      final path = await _writeTempBlock(tempDir, 0, 'original');
      final meta = _blockMeta(index: 0, contentPath: path);

      await loader.load(meta);
      await File(path).writeAsString('mutated on disk');

      final cached = await loader.load(meta);
      expect(cached.content, 'original');
    });

    test('evicts farthest block when cache exceeds max size', () async {
      final paths = <int, String>{};
      for (var i = 0; i < 4; i++) {
        paths[i] = await _writeTempBlock(tempDir, i, 'block $i');
      }

      loader.setCurrentIndex(1);
      await loader.load(_blockMeta(index: 0, contentPath: paths[0]!));
      await loader.load(_blockMeta(index: 1, contentPath: paths[1]!));
      await loader.load(_blockMeta(index: 2, contentPath: paths[2]!));

      expect(loader.getCached(0), isNotNull);
      expect(loader.getCached(1), isNotNull);
      expect(loader.getCached(2), isNotNull);

      await loader.load(_blockMeta(index: 3, contentPath: paths[3]!));
      loader.setCurrentIndex(3);

      expect(loader.getCached(3), isNotNull);
      expect(loader.getCached(0), isNull);
      expect(loader.getCached(1), isNotNull);
      expect(loader.getCached(2), isNotNull);
    });

    test('evictAll clears cache', () async {
      final path = await _writeTempBlock(tempDir, 0, 'data');
      await loader.load(_blockMeta(index: 0, contentPath: path));

      loader.evictAll();

      expect(loader.getCached(0), isNull);
      expect(loader.currentIndex, 0);
    });
  });

  group('AppDatabase block queries', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('getBlockByGlobalIndex and getNextBlock', () async {
      const bookId = 'book-1';
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insertBook(
        id: bookId,
        title: 'Test',
        sourceFormat: DbConstants.sourceFormatTxt,
        sourcePath: '/tmp/test.txt',
        importedAt: now,
      );

      await db.insertChaptersBatch([
        ChaptersCompanion.insert(
          id: 'ch-1',
          bookId: bookId,
          orderIndex: 0,
          title: 'Chapter 1',
        ),
      ]);

      await db.insertContentBlocksBatch([
        ContentBlocksCompanion.insert(
          id: 'b-0',
          bookId: bookId,
          chapterId: 'ch-1',
          blockOrderInChapter: 0,
          globalBlockIndex: 0,
          storageType: DbConstants.storageTypePlain,
          contentPath: '/tmp/block_0000.txt',
          charCount: 5,
        ),
        ContentBlocksCompanion.insert(
          id: 'b-1',
          bookId: bookId,
          chapterId: 'ch-1',
          blockOrderInChapter: 1,
          globalBlockIndex: 1,
          storageType: DbConstants.storageTypePlain,
          contentPath: '/tmp/block_0001.txt',
          charCount: 5,
        ),
      ]);

      final block0 = await db.getBlockByGlobalIndex(bookId, 0);
      final block1 = await db.getNextBlock(bookId, 0);
      final missing = await db.getBlockByGlobalIndex(bookId, 99);

      expect(block0?.id, 'b-0');
      expect(block1?.id, 'b-1');
      expect(missing, isNull);
    });
  });
}
