import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/stats_screen.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('\u7edf\u8ba1\u9875\u5c55\u793a\u9605\u8bfb\u6570\u636e\u4e0e\u8fd17\u65e5\u56fe\u8868',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.now().millisecondsSinceEpoch;
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    await db.insertBook(
      id: 'book-1',
      title: 'Test Novel',
      author: 'Author',
      sourceFormat: 'txt',
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );
    await db.markBookComplete(
      id: 'book-1',
      totalChapters: 1,
      totalBlocks: 10,
    );
    await db.insertChaptersBatch([
      ChaptersCompanion.insert(
        id: 'ch-1',
        bookId: 'book-1',
        orderIndex: 0,
        title: 'Chapter 1',
      ),
    ]);
    await db.insertContentBlocksBatch([
      ContentBlocksCompanion.insert(
        id: 'blk-1',
        bookId: 'book-1',
        chapterId: 'ch-1',
        blockOrderInChapter: 0,
        globalBlockIndex: 0,
        storageType: DbConstants.storageTypePlain,
        contentPath: '/blocks/0.txt',
        charCount: 100,
      ),
    ]);
    await db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: 'book-1',
        chapterId: 'ch-1',
        blockId: 'blk-1',
        updatedAt: now,
      ),
    );
    await db.insertKnownWord(word: 'alpha', addedAt: now);
    await db.insertKnownWord(word: 'beta', addedAt: now);
    await db.upsertVocabEntry(
      word: 'gamma',
      definition: 'test',
      starred: false,
    );
    await db.incrementDailyMinutes(
      date: todayKey,
      deltaMinutes: 25,
    );

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('\u7edf\u8ba1'), findsOneWidget);
    expect(find.text('\u6b63\u5728\u9605\u8bfb'), findsOneWidget);
    expect(find.text('\u6211\u7684\u6570\u636e'), findsOneWidget);
    expect(find.text('\u4eca\u65e5\u65b0\u8bcd'), findsOneWidget);
    expect(
      find.text('\u8fd1 7 \u65e5\u9605\u8bfb\u65f6\u957f\uff08\u5206\u949f\uff09'),
      findsOneWidget,
    );
    expect(find.text('\u8fde\u7eed\u9605\u8bfb'), findsOneWidget);
    expect(find.text('25m'), findsNWidgets(2));
    expect(find.textContaining('7'), findsWidgets);
    expect(find.text('\u7d2f\u8ba1\u65f6\u957f'), findsOneWidget);
    expect(find.text('Test Novel'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
