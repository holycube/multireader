import 'package:drift/drift.dart';

import 'constants.dart';

@DataClassName('Book')
@TableIndex(name: 'books_import_status', columns: {#importStatus})
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get sourceFormat => text()();
  TextColumn get sourcePath => text()();
  TextColumn get importStatus => text().withDefault(
        const Constant(DbConstants.importStatusPending),
      )();
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();
  IntColumn get totalBlocks => integer().withDefault(const Constant(0))();
  IntColumn get importedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Chapter')
@TableIndex(name: 'chapters_book_order', columns: {#bookId, #orderIndex})
class Chapters extends Table {
  TextColumn get id => text()();
  late final TextColumn bookId = text().references(Books, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get title => text()();
  IntColumn get blockCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ContentBlock')
@TableIndex(
  name: 'content_blocks_book_global_index',
  columns: {#bookId, #globalBlockIndex},
)
@TableIndex(name: 'content_blocks_chapter', columns: {#chapterId})
class ContentBlocks extends Table {
  TextColumn get id => text()();
  late final TextColumn bookId = text().references(Books, #id)();
  late final TextColumn chapterId = text().references(Chapters, #id)();
  IntColumn get blockOrderInChapter => integer()();
  IntColumn get globalBlockIndex => integer()();
  TextColumn get storageType => text()();
  TextColumn get contentPath => text()();
  IntColumn get charCount => integer()();
  TextColumn get parseStatus => text().withDefault(
        const Constant(DbConstants.parseStatusPending),
      )();
  IntColumn get parsedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReadingProgressRow')
class ReadingProgress extends Table {
  late final TextColumn bookId = text().references(Books, #id)();
  TextColumn get chapterId => text()();
  TextColumn get blockId => text()();
  IntColumn get charOffset => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DataClassName('KnownWord')
class KnownWords extends Table {
  TextColumn get word => text()();
  TextColumn get source => text().withDefault(
        const Constant(DbConstants.wordSourceUser),
      )();
  IntColumn get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {word};
}

@DataClassName('VocabEntry')
class VocabEntries extends Table {
  TextColumn get id => text()();
  TextColumn get word => text()();
  TextColumn get definition => text().nullable()();
  TextColumn get context => text().nullable()();
  TextColumn get bookId => text().nullable()();
  TextColumn get chapterId => text().nullable()();
  TextColumn get blockId => text().nullable()();
  BoolColumn get starred =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ParseQuotaRow')
class ParseQuota extends Table {
  late final TextColumn bookId = text().references(Books, #id)();
  IntColumn get unlockedBlockCount => integer().withDefault(
        const Constant(DbConstants.defaultFreeAllowance),
      )();
  IntColumn get freeAllowance => integer().withDefault(
        const Constant(DbConstants.defaultFreeAllowance),
      )();
  IntColumn get lastAdUnlockAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DataClassName('ReadingStatsDailyRow')
class ReadingStatsDaily extends Table {
  TextColumn get date => text()();
  TextColumn get bookId => text().nullable()();
  IntColumn get minutes => integer().withDefault(const Constant(0))();
  IntColumn get newWordsCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {date, bookId};
}

/// Stores pre-computed syntactic chunk boundary offsets for a ContentBlock.
/// `boundaries` is a JSON-encoded sorted list of char offsets, e.g. "[18,54,89]".
/// Absence of a row means the block has not been processed yet.
class ChunkBoundaries extends Table {
  TextColumn get blockId =>
      text().references(ContentBlocks, #id, onDelete: KeyAction.cascade)();
  TextColumn get boundaries => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {blockId};
}
