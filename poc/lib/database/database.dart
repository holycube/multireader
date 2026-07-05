import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'constants.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Books,
    Chapters,
    ContentBlocks,
    ReadingProgress,
    KnownWords,
    VocabEntries,
    ParseQuota,
    ReadingStatsDaily,
    ChunkBoundaries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                name: 'novel-reader',
                native: const DriftNativeOptions(
                  databaseDirectory: getApplicationSupportDirectory,
                ),
              ),
        );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(chunkBoundaries);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await migrateParseQuotaToFullBook();
        },
      );

  // --- Books ---

  Future<void> insertBook({
    required String id,
    required String title,
    String? author,
    String? coverPath,
    required String sourceFormat,
    required String sourcePath,
    required int importedAt,
  }) {
    return into(books).insert(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: Value(author),
        coverPath: Value(coverPath),
        sourceFormat: sourceFormat,
        sourcePath: sourcePath,
        importedAt: importedAt,
      ),
    );
  }

  Future<Book?> getBookById(String id) {
    return (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Stream<List<Book>> watchCompleteBooks() {
    return (select(books)
          ..where((b) => b.importStatus.equals(DbConstants.importStatusComplete))
          ..orderBy([(b) => OrderingTerm.desc(b.importedAt)]))
        .watch();
  }

  /// 书架列表：含进度与最近阅读时间，按 `reading_progress.updatedAt` 降序。
  Stream<List<BookshelfItem>> watchBookshelfItems() {
    return customSelect(
      '''
      SELECT
        b.id AS book_id,
        b.title AS book_title,
        b.author AS book_author,
        b.cover_path AS book_cover_path,
        b.source_format AS book_source_format,
        b.source_path AS book_source_path,
        b.import_status AS book_import_status,
        b.total_chapters AS book_total_chapters,
        b.total_blocks AS book_total_blocks,
        b.imported_at AS book_imported_at,
        rp.updated_at AS last_read_at,
        CASE
          WHEN rp.book_id IS NULL OR b.total_blocks <= 0 THEN 0.0
          WHEN cb.char_count <= 0 THEN
            CAST(cb.global_block_index AS REAL) / b.total_blocks
          ELSE
            (CAST(cb.global_block_index AS REAL)
              + CAST(rp.char_offset AS REAL) / cb.char_count)
            / b.total_blocks
        END AS progress_fraction
      FROM books b
      LEFT JOIN reading_progress rp ON rp.book_id = b.id
      LEFT JOIN content_blocks cb ON cb.id = rp.block_id
      WHERE b.import_status = ?
      ORDER BY COALESCE(rp.updated_at, 0) DESC, b.imported_at DESC
      ''',
      variables: [const Variable<String>(DbConstants.importStatusComplete)],
      readsFrom: {books, readingProgress, contentBlocks},
    ).watch().map((rows) => rows.map(_mapBookshelfRow).toList());
  }

  BookshelfItem _mapBookshelfRow(QueryRow row) {
    final book = Book(
      id: row.read<String>('book_id'),
      title: row.read<String>('book_title'),
      author: row.readNullable<String>('book_author'),
      coverPath: row.readNullable<String>('book_cover_path'),
      sourceFormat: row.read<String>('book_source_format'),
      sourcePath: row.read<String>('book_source_path'),
      importStatus: row.read<String>('book_import_status'),
      totalChapters: row.read<int>('book_total_chapters'),
      totalBlocks: row.read<int>('book_total_blocks'),
      importedAt: row.read<int>('book_imported_at'),
    );
    return BookshelfItem(
      book: book,
      progressFraction: row.read<double>('progress_fraction'),
      lastReadAt: row.readNullable<int>('last_read_at'),
    );
  }

  Future<void> markBookComplete({
    required String id,
    required int totalChapters,
    required int totalBlocks,
  }) {
    return (update(books)..where((b) => b.id.equals(id))).write(
      BooksCompanion(
        importStatus: const Value(DbConstants.importStatusComplete),
        totalChapters: Value(totalChapters),
        totalBlocks: Value(totalBlocks),
      ),
    );
  }

  Future<void> markBookFailed(String id) {
    return (update(books)..where((b) => b.id.equals(id))).write(
      const BooksCompanion(
        importStatus: Value(DbConstants.importStatusFailed),
      ),
    );
  }

  Future<void> updateBookCoverPath(String id, String coverPath) {
    return (update(books)..where((b) => b.id.equals(id))).write(
      BooksCompanion(coverPath: Value(coverPath)),
    );
  }

  /// 导入完成后批量写入章节、块、额度并标记 complete。
  Future<void> finalizeBookImport({
    required String bookId,
    required List<ChaptersCompanion> chapterRows,
    required List<ContentBlocksCompanion> blockRows,
    required int totalChapters,
    required int totalBlocks,
    String? coverPath,
  }) {
    return transaction(() async {
      if (coverPath != null) {
        await (update(books)..where((b) => b.id.equals(bookId))).write(
          BooksCompanion(coverPath: Value(coverPath)),
        );
      }
      await insertChaptersBatch(chapterRows);
      await insertContentBlocksBatch(blockRows);
      await initParseQuota(bookId, totalBlocks: totalBlocks);
      await markBookComplete(
        id: bookId,
        totalChapters: totalChapters,
        totalBlocks: totalBlocks,
      );
    });
  }

  // --- Chapters & ContentBlocks ---

  Future<void> insertChaptersBatch(List<ChaptersCompanion> rows) {
    if (rows.isEmpty) return Future.value();
    return batch((b) {
      b.insertAll(chapters, rows);
    });
  }

  Future<void> insertContentBlocksBatch(List<ContentBlocksCompanion> rows) {
    if (rows.isEmpty) return Future.value();
    return batch((b) {
      b.insertAll(contentBlocks, rows);
    });
  }

  Future<List<Chapter>> getChaptersByBook(String bookId) {
    return (select(chapters)
          ..where((c) => c.bookId.equals(bookId))
          ..orderBy([(c) => OrderingTerm.asc(c.orderIndex)]))
        .get();
  }

  Future<List<ContentBlock>> getContentBlocksByBook(String bookId) {
    return (select(contentBlocks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm.asc(b.globalBlockIndex)]))
        .get();
  }

  Future<ContentBlock?> getFirstBlockOfChapter(String chapterId) {
    return (select(contentBlocks)
          ..where((b) => b.chapterId.equals(chapterId))
          ..where((b) => b.blockOrderInChapter.equals(0)))
        .getSingleOrNull();
  }

  Future<ContentBlock?> getBlockById(String id) {
    return (select(contentBlocks)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
  }

  Future<ContentBlock?> getBlockByGlobalIndex(String bookId, int index) {
    return (select(contentBlocks)
          ..where((b) => b.bookId.equals(bookId))
          ..where((b) => b.globalBlockIndex.equals(index)))
        .getSingleOrNull();
  }

  Future<ContentBlock?> getNextBlock(String bookId, int currentIndex) {
    return getBlockByGlobalIndex(bookId, currentIndex + 1);
  }

  // --- ChunkBoundaries ---

  Future<void> saveChunkBoundaries(String blockId, List<int> boundaries) {
    return into(chunkBoundaries).insertOnConflictUpdate(
      ChunkBoundariesCompanion.insert(
        blockId: blockId,
        boundaries: Value(jsonEncode(boundaries)),
      ),
    );
  }

  Future<List<int>> getChunkBoundaries(String blockId) async {
    final row = await (select(chunkBoundaries)
          ..where((c) => c.blockId.equals(blockId)))
        .getSingleOrNull();
    if (row == null) return [];
    try {
      final list = jsonDecode(row.boundaries) as List<dynamic>;
      return list.cast<int>();
    } catch (_) {
      return [];
    }
  }

  // --- ParseQuota ---

  Future<void> initParseQuota(String bookId, {required int totalBlocks}) {
    return into(parseQuota).insert(
      ParseQuotaCompanion.insert(
        bookId: bookId,
        unlockedBlockCount: Value(totalBlocks),
        freeAllowance: Value(totalBlocks),
      ),
    );
  }

  /// 旧库升级：将仍受 40 块墙限制的额度提升至全书可读。
  Future<void> migrateParseQuotaToFullBook() async {
    await customStatement('''
      UPDATE parse_quota
      SET unlocked_block_count = (
        SELECT total_blocks FROM books WHERE books.id = parse_quota.book_id
      )
      WHERE unlocked_block_count < (
        SELECT total_blocks FROM books WHERE books.id = parse_quota.book_id
      )
    ''');
  }

  Future<ParseQuotaRow?> getParseQuota(String bookId) {
    return (select(parseQuota)..where((q) => q.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  Future<bool> isBlockUnlocked(String bookId, int globalBlockIndex) async {
    final quota = await getParseQuota(bookId);
    if (quota == null) return false;
    return globalBlockIndex < quota.unlockedBlockCount;
  }

  // --- ReadingProgress ---

  Future<void> upsertProgress(ReadingProgressCompanion row) {
    return into(readingProgress).insertOnConflictUpdate(row);
  }

  Future<ReadingProgressRow?> getProgress(String bookId) {
    return (select(readingProgress)..where((p) => p.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  // --- KnownWords ---

  Future<List<String>> getKnownWordStrings() async {
    final rows = await customSelect(
      'SELECT word FROM known_words',
      readsFrom: {knownWords},
    ).get();
    return [for (final row in rows) row.read<String>('word')];
  }

  Future<Set<String>> getAllKnownWords() async {
    final words = await getKnownWordStrings();
    return words.toSet();
  }

  Future<void> insertKnownWord({
    required String word,
    String source = DbConstants.wordSourceUser,
    required int addedAt,
  }) {
    return into(knownWords).insertOnConflictUpdate(
      KnownWordsCompanion.insert(
        word: word,
        source: Value(source),
        addedAt: addedAt,
      ),
    );
  }

  /// POC 验收：批量写入已知词（真机 40k Set 冷启动手测用）。
  Future<int> seedKnownWords({
    required int count,
    String source = DbConstants.wordSourceUser,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      for (var i = 0; i < count; i++) {
        b.insert(
          knownWords,
          KnownWordsCompanion.insert(
            word: 'word${i.toString().padLeft(5, '0')}',
            source: Value(source),
            addedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    final rows = await select(knownWords).get();
    return rows.length;
  }

  Future<void> deleteKnownWord(String word) {
    return (delete(knownWords)..where((w) => w.word.equals(word))).go();
  }

  // --- VocabEntries ---

  Future<void> insertVocabEntry(VocabEntriesCompanion row) {
    return into(vocabEntries).insert(row);
  }

  Future<void> updateVocabStarred({
    required String id,
    required bool starred,
    required int updatedAt,
  }) {
    return (update(vocabEntries)..where((v) => v.id.equals(id))).write(
      VocabEntriesCompanion(
        starred: Value(starred),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<List<VocabEntry>> getVocabByWord(String word) {
    return (select(vocabEntries)..where((v) => v.word.equals(word))).get();
  }

  /// 按词 upsert 生词本记录：已有则更新释义/例句/starred，否则插入新行。
  Future<String> upsertVocabEntry({
    required String word,
    String? definition,
    String? context,
    String? bookId,
    String? chapterId,
    String? blockId,
    required bool starred,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getVocabByWord(word);
    if (existing.isNotEmpty) {
      final row = existing.first;
      await (update(vocabEntries)..where((v) => v.id.equals(row.id))).write(
        VocabEntriesCompanion(
          definition: Value(definition ?? row.definition),
          context: Value(context ?? row.context),
          bookId: Value(bookId ?? row.bookId),
          chapterId: Value(chapterId ?? row.chapterId),
          blockId: Value(blockId ?? row.blockId),
          starred: Value(starred),
          updatedAt: Value(now),
        ),
      );
      return row.id;
    }

    final id = const Uuid().v4();
    await insertVocabEntry(
      VocabEntriesCompanion.insert(
        id: id,
        word: word,
        definition: Value(definition),
        context: Value(context),
        bookId: Value(bookId),
        chapterId: Value(chapterId),
        blockId: Value(blockId),
        starred: Value(starred),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  // --- ReadingStatsDaily ---

  Future<void> upsertDailyStats({
    required String date,
    String? bookId,
    required int minutes,
    required int newWordsCount,
  }) {
    return into(readingStatsDaily).insertOnConflictUpdate(
      ReadingStatsDailyCompanion.insert(
        date: date,
        bookId: Value(bookId),
        minutes: Value(minutes),
        newWordsCount: Value(newWordsCount),
      ),
    );
  }

  /// 累加当日阅读分钟：写入全站合计行（`bookId IS NULL`）及可选 per-book 行。
  Future<void> incrementDailyMinutes({
    required String date,
    required int deltaMinutes,
    String? bookId,
  }) async {
    if (deltaMinutes <= 0) return;
    await _incrementDailyMinutesRow(
      date: date,
      bookId: null,
      deltaMinutes: deltaMinutes,
    );
    if (bookId != null) {
      await _incrementDailyMinutesRow(
        date: date,
        bookId: bookId,
        deltaMinutes: deltaMinutes,
      );
    }
  }

  Future<void> _incrementDailyMinutesRow({
    required String date,
    required String? bookId,
    required int deltaMinutes,
  }) async {
    if (bookId == null) {
      final updated = await customUpdate(
        'UPDATE reading_stats_daily SET minutes = minutes + ?1 '
        'WHERE date = ?2 AND book_id IS NULL',
        variables: [
          Variable<int>(deltaMinutes),
          Variable<String>(date),
        ],
        updates: {readingStatsDaily},
      );
      if (updated == 0) {
        await into(readingStatsDaily).insert(
          ReadingStatsDailyCompanion.insert(
            date: date,
            minutes: Value(deltaMinutes),
            newWordsCount: const Value(0),
          ),
        );
      }
      return;
    }

    final existing = await (select(readingStatsDaily)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
    if (existing == null) {
      await into(readingStatsDaily).insert(
        ReadingStatsDailyCompanion.insert(
          date: date,
          bookId: Value(bookId),
          minutes: Value(deltaMinutes),
          newWordsCount: const Value(0),
        ),
      );
      return;
    }

    await (update(readingStatsDaily)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.bookId.equals(bookId)))
        .write(
      ReadingStatsDailyCompanion(
        minutes: Value(existing.minutes + deltaMinutes),
      ),
    );
  }

  /// 最近一次阅读的书籍（含进度）；无阅读记录时返回 null。
  Future<BookshelfItem?> getLastReadBook() async {
    final rows = await customSelect(
      '''
      SELECT
        b.id AS book_id,
        b.title AS book_title,
        b.author AS book_author,
        b.cover_path AS book_cover_path,
        b.source_format AS book_source_format,
        b.source_path AS book_source_path,
        b.import_status AS book_import_status,
        b.total_chapters AS book_total_chapters,
        b.total_blocks AS book_total_blocks,
        b.imported_at AS book_imported_at,
        rp.updated_at AS last_read_at,
        CASE
          WHEN rp.book_id IS NULL OR b.total_blocks <= 0 THEN 0.0
          WHEN cb.char_count <= 0 THEN
            CAST(cb.global_block_index AS REAL) / b.total_blocks
          ELSE
            (CAST(cb.global_block_index AS REAL)
              + CAST(rp.char_offset AS REAL) / cb.char_count)
            / b.total_blocks
        END AS progress_fraction
      FROM books b
      INNER JOIN reading_progress rp ON rp.book_id = b.id
      LEFT JOIN content_blocks cb ON cb.id = rp.block_id
      WHERE b.import_status = ?
      ORDER BY rp.updated_at DESC
      LIMIT 1
      ''',
      variables: [const Variable<String>(DbConstants.importStatusComplete)],
      readsFrom: {books, readingProgress, contentBlocks},
    ).get();
    if (rows.isEmpty) return null;
    return _mapBookshelfRow(rows.first);
  }

  /// 今日新增「已会」词数（按本地日历日 `addedAt` 统计）。
  Future<int> getTodayNewWords() {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        todayStart + const Duration(days: 1).inMilliseconds;
    final count = knownWords.word.count();
    return (selectOnly(knownWords)
          ..addColumns([count])
          ..where(
            knownWords.addedAt.isBetweenValues(todayStart, tomorrowStart - 1),
          ))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  /// 累计阅读分钟（全站合计行 `bookId IS NULL`）。
  Future<int> getTotalReadingMinutes() {
    final sum = readingStatsDaily.minutes.sum();
    return (selectOnly(readingStatsDaily)
          ..addColumns([sum])
          ..where(readingStatsDaily.bookId.isNull()))
        .map((row) => row.read(sum) ?? 0)
        .getSingle();
  }

  /// 近 [days] 天每日阅读分钟（优先全站合计行 `bookId IS NULL`）。
  Future<List<DailyMinutesStat>> getDailyMinutesTrend({int days = 7}) async {
    final safeDays = days.clamp(1, 90);
    final today = DateTime.now();
    final dateKeys = <String>[
      for (var i = safeDays - 1; i >= 0; i--)
        statsDateKey(today.subtract(Duration(days: i))),
    ];

    final rows = await (select(readingStatsDaily)
          ..where((t) => t.bookId.isNull())
          ..where((t) => t.date.isIn(dateKeys)))
        .get();

    final minutesByDate = <String, int>{};
    for (final row in rows) {
      minutesByDate[row.date] = (minutesByDate[row.date] ?? 0) + row.minutes;
    }
    return [
      for (final date in dateKeys)
        DailyMinutesStat(date: date, minutes: minutesByDate[date] ?? 0),
    ];
  }

  Future<int> countKnownWords() {
    final count = knownWords.word.count();
    return (selectOnly(knownWords)..addColumns([count]))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  Stream<List<VocabEntry>> watchVocabEntries() {
    return (select(vocabEntries)
          ..orderBy([(v) => OrderingTerm.desc(v.updatedAt)]))
        .watch();
  }

  Future<List<VocabEntry>> getVocabEntriesPage({
    required int limit,
    required int offset,
  }) {
    return (select(vocabEntries)
          ..orderBy([(v) => OrderingTerm.desc(v.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> countVocabEntries() {
    final count = vocabEntries.id.count();
    return (selectOnly(vocabEntries)..addColumns([count]))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  static String statsDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // --- Delete book cascade (data-model §6) ---

  Future<void> deleteBookCascade(String bookId) {
    return transaction(() async {
      await (delete(contentBlocks)..where((b) => b.bookId.equals(bookId)))
          .go();
      await (delete(chapters)..where((c) => c.bookId.equals(bookId))).go();
      await (delete(parseQuota)..where((q) => q.bookId.equals(bookId))).go();
      await (delete(readingProgress)..where((p) => p.bookId.equals(bookId)))
          .go();
      await (update(vocabEntries)..where((v) => v.bookId.equals(bookId))).write(
        const VocabEntriesCompanion(
          bookId: Value(null),
          chapterId: Value(null),
          blockId: Value(null),
        ),
      );
      await (delete(books)..where((b) => b.id.equals(bookId))).go();
    });
  }

}

/// 单日阅读分钟，用于统计趋势图。
class DailyMinutesStat {
  const DailyMinutesStat({required this.date, required this.minutes});

  final String date;
  final int minutes;
}

/// 书架列表项：书籍元数据 + 阅读进度。
class BookshelfItem {
  const BookshelfItem({
    required this.book,
    required this.progressFraction,
    this.lastReadAt,
  });

  final Book book;
  final double progressFraction;
  final int? lastReadAt;

  int get progressPercent {
    if (book.totalBlocks <= 0) return 0;
    return (progressFraction.clamp(0.0, 1.0) * 100).round();
  }
}
