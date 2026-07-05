import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('book lifecycle: pending to complete appears in watchCompleteBooks',
      () async {
    const bookId = 'book-1';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Test Book',
      sourceFormat: DbConstants.sourceFormatEpub,
      sourcePath: '/tmp/test.epub',
      importedAt: now,
    );

    final pending = await db.getBookById(bookId);
    expect(pending!.importStatus, DbConstants.importStatusPending);

    await db.markBookComplete(
      id: bookId,
      totalChapters: 2,
      totalBlocks: 3,
    );

    final complete = await db.getBookById(bookId);
    expect(complete!.importStatus, DbConstants.importStatusComplete);
    expect(complete.totalChapters, 2);
    expect(complete.totalBlocks, 3);

    final shelf = await db.watchCompleteBooks().first;
    expect(shelf.map((b) => b.id), contains(bookId));
  });

  test('initParseQuota sets unlockedBlockCount to totalBlocks', () async {
    const bookId = 'book-quota';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Quota Book',
      sourceFormat: DbConstants.sourceFormatTxt,
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );
    await db.initParseQuota(bookId, totalBlocks: 150);

    final quota = await db.getParseQuota(bookId);
    expect(quota, isNotNull);
    expect(quota!.unlockedBlockCount, 150);
    expect(quota.freeAllowance, 150);
  });

  test('isBlockUnlocked allows all blocks within totalBlocks', () async {
    const bookId = 'book-unlock';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Unlock Book',
      sourceFormat: DbConstants.sourceFormatTxt,
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );
    await db.initParseQuota(bookId, totalBlocks: 150);

    expect(await db.isBlockUnlocked(bookId, 39), isTrue);
    expect(await db.isBlockUnlocked(bookId, 40), isTrue);
    expect(await db.isBlockUnlocked(bookId, 149), isTrue);
    expect(await db.isBlockUnlocked(bookId, 150), isFalse);
  });

  test('migrateParseQuotaToFullBook upgrades legacy quota', () async {
    const bookId = 'book-migrate';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Migrate Book',
      sourceFormat: DbConstants.sourceFormatTxt,
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );
    await db.markBookComplete(
      id: bookId,
      totalChapters: 1,
      totalBlocks: 200,
    );
    await db.into(db.parseQuota).insert(
          ParseQuotaCompanion.insert(bookId: bookId),
        );

    await db.migrateParseQuotaToFullBook();

    final quota = await db.getParseQuota(bookId);
    expect(quota!.unlockedBlockCount, 200);
    expect(await db.isBlockUnlocked(bookId, 199), isTrue);
    expect(await db.isBlockUnlocked(bookId, 200), isFalse);
  });

  test('upsertVocabEntry inserts then updates same word', () async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.upsertVocabEntry(
      word: 'novel',
      definition: 'n. 小说',
      starred: true,
      bookId: 'book-vocab',
      chapterId: 'ch-vocab',
      blockId: 'blk-vocab',
      context: 'read a novel',
    );
    expect(id, isNotEmpty);

    var rows = await db.getVocabByWord('novel');
    expect(rows, hasLength(1));
    expect(rows.first.starred, isTrue);
    expect(rows.first.definition, 'n. 小说');

    await db.upsertVocabEntry(
      word: 'novel',
      definition: 'n. 长篇小说',
      starred: false,
      context: 'a long novel',
    );

    rows = await db.getVocabByWord('novel');
    expect(rows, hasLength(1));
    expect(rows.first.id, id);
    expect(rows.first.starred, isFalse);
    expect(rows.first.definition, 'n. 长篇小说');
    expect(rows.first.context, 'a long novel');
    expect(rows.first.updatedAt, greaterThanOrEqualTo(now));
  });

  test('known_words insert, load Set, delete', () async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertKnownWord(word: 'hello', addedAt: now);
    await db.insertKnownWord(word: 'world', addedAt: now);

    final words = await db.getAllKnownWords();
    expect(words, containsAll(['hello', 'world']));

    await db.deleteKnownWord('hello');
    final afterDelete = await db.getAllKnownWords();
    expect(afterDelete, contains('world'));
    expect(afterDelete, isNot(contains('hello')));
  });

  test('reading_progress upsert overwrites same bookId', () async {
    const bookId = 'book-progress';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Progress Book',
      sourceFormat: DbConstants.sourceFormatTxt,
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );

    await db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: bookId,
        chapterId: 'ch-1',
        blockId: 'blk-1',
        charOffset: const Value(10),
        updatedAt: now,
      ),
    );
    await db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: bookId,
        chapterId: 'ch-2',
        blockId: 'blk-2',
        charOffset: const Value(50),
        updatedAt: now + 1,
      ),
    );

    final progress = await db.getProgress(bookId);
    expect(progress, isNotNull);
    expect(progress!.chapterId, 'ch-2');
    expect(progress.blockId, 'blk-2');
    expect(progress.charOffset, 50);
  });

  test('deleteBookCascade clears related rows and nulls vocab bookId',
      () async {
    const bookId = 'book-cascade';
    const chapterId = 'ch-cascade';
    const blockId = 'blk-cascade';
    const vocabId = 'vocab-1';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertBook(
      id: bookId,
      title: 'Cascade Book',
      sourceFormat: DbConstants.sourceFormatEpub,
      sourcePath: '/tmp/cascade.epub',
      importedAt: now,
    );
    await db.insertChaptersBatch([
      ChaptersCompanion.insert(
        id: chapterId,
        bookId: bookId,
        orderIndex: 0,
        title: 'Chapter 1',
      ),
    ]);
    await db.insertContentBlocksBatch([
      ContentBlocksCompanion.insert(
        id: blockId,
        bookId: bookId,
        chapterId: chapterId,
        blockOrderInChapter: 0,
        globalBlockIndex: 0,
        storageType: DbConstants.storageTypeHtml,
        contentPath: '/blocks/0.html',
        charCount: 100,
      ),
    ]);
    await db.initParseQuota(bookId, totalBlocks: 1);
    await db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: bookId,
        chapterId: chapterId,
        blockId: blockId,
        updatedAt: now,
      ),
    );
    await db.insertVocabEntry(
      VocabEntriesCompanion.insert(
        id: vocabId,
        word: 'cascade',
        bookId: Value(bookId),
        chapterId: Value(chapterId),
        blockId: Value(blockId),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.deleteBookCascade(bookId);

    expect(await db.getBookById(bookId), isNull);
    expect(await db.getChaptersByBook(bookId), isEmpty);
    expect(await db.getContentBlocksByBook(bookId), isEmpty);
    expect(await db.getParseQuota(bookId), isNull);
    expect(await db.getProgress(bookId), isNull);

    final vocab = await (db.select(db.vocabEntries)
          ..where((v) => v.id.equals(vocabId)))
        .getSingle();
    expect(vocab.bookId, isNull);
    expect(vocab.chapterId, isNull);
    expect(vocab.blockId, isNull);
  });

  test('incrementDailyMinutes accumulates without overwriting', () async {
    final today = DateTime.now();
    final todayKey = AppDatabase.statsDateKey(today);

    await db.incrementDailyMinutes(date: todayKey, deltaMinutes: 10);
    await db.incrementDailyMinutes(date: todayKey, deltaMinutes: 15);

    expect(await db.getTotalReadingMinutes(), 25);
    final trend = await db.getDailyMinutesTrend(days: 1);
    expect(trend.single.minutes, 25);
  });

  test('reading stats trend and word counts', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    await db.insertKnownWord(word: 'one', addedAt: now);
    await db.insertKnownWord(word: 'two', addedAt: now);
    await db.upsertVocabEntry(word: 'three', starred: false);
    await db.upsertDailyStats(date: todayKey, minutes: 42, newWordsCount: 2);

    expect(await db.countKnownWords(), 2);
    expect(await db.countVocabEntries(), 1);

    final trend = await db.getDailyMinutesTrend(days: 7);
    expect(trend, hasLength(7));
    expect(trend.last.date, todayKey);
    expect(trend.last.minutes, 42);
    expect(trend.where((d) => d.minutes > 0), hasLength(1));
  });
}
