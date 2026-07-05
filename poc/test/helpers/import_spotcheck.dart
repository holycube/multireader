import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/import/book_paths.dart';

/// ????????data-model ??/?/???????
Future<void> assertImportSpotcheck({
  required AppDatabase db,
  required BookPaths paths,
  required String bookId,
  required int expectedBlocks,
}) async {
  final book = await db.getBookById(bookId);
  expect(book, isNotNull);
  expect(book!.importStatus, DbConstants.importStatusComplete);
  expect(book.totalBlocks, expectedBlocks);

  final chapters = await db.getChaptersByBook(bookId);
  expect(chapters, isNotEmpty);
  for (var i = 0; i < chapters.length; i++) {
    expect(chapters[i].orderIndex, i);
  }

  final blocks = await db.getContentBlocksByBook(bookId);
  expect(blocks.length, expectedBlocks);
  for (var i = 0; i < blocks.length; i++) {
    expect(blocks[i].globalBlockIndex, i);
    expect(
      await File(blocks[i].contentPath).exists(),
      isTrue,
      reason: '??????: ${blocks[i].contentPath}',
    );
  }

  final chapterBlockTotals = <String, int>{};
  for (final block in blocks) {
    chapterBlockTotals[block.chapterId] =
        (chapterBlockTotals[block.chapterId] ?? 0) + 1;
  }
  for (final chapter in chapters) {
    expect(chapter.blockCount, chapterBlockTotals[chapter.id]);
  }

  final quota = await db.getParseQuota(bookId);
  expect(quota, isNotNull);
  expect(quota!.unlockedBlockCount, expectedBlocks);
  expect(quota.freeAllowance, expectedBlocks);

  final bookDir = Directory(paths.bookDir(bookId));
  expect(await bookDir.exists(), isTrue);
}
