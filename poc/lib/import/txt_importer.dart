import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/constants.dart';
import '../database/database.dart';
import 'block_splitter.dart';
import 'book_paths.dart';
import 'chunk_boundary_processor.dart';
import 'import_result.dart';
import 'txt_chapter_parser.dart';

/// TXT 导入管线：正则分章 / 兜底切块 → plain 块文件 → Drift 落表。
class TxtImporter {
  TxtImporter(this._db, this._paths);

  final AppDatabase _db;
  final BookPaths _paths;
  final _uuid = const Uuid();

  static Future<TxtImporter> create(AppDatabase db) async {
    final paths = await BookPaths.create();
    return TxtImporter(db, paths);
  }

  TxtImporter.withPaths(this._db, this._paths);

  Future<ImportResult> importFromFile(File txtFile) async {
    final bookId = _uuid.v4();
    final sourcePath = txtFile.path;
    final now = DateTime.now().millisecondsSinceEpoch;
    var bookInserted = false;

    try {
      final fullText = await txtFile.readAsString();
      final title = p.basenameWithoutExtension(sourcePath);
      final segments = parseTxtChapters(fullText);

      await _db.insertBook(
        id: bookId,
        title: title,
        sourceFormat: DbConstants.sourceFormatTxt,
        sourcePath: sourcePath,
        importedAt: now,
      );
      bookInserted = true;

      await _paths.ensureBookDirs(bookId);

      final chapterRows = <ChaptersCompanion>[];
      final blockRows = <ContentBlocksCompanion>[];
      var globalBlockIndex = 0;
      String? firstBlockPath;

      for (var chapterOrder = 0; chapterOrder < segments.length; chapterOrder++) {
        final segment = segments[chapterOrder];
        final chapterId = _uuid.v4();
        final chunks = _chunksForSegment(segment);
        final blockCount = chunks.length;

        chapterRows.add(
          ChaptersCompanion.insert(
            id: chapterId,
            bookId: bookId,
            orderIndex: chapterOrder,
            title: segment.title,
            blockCount: Value(blockCount),
          ),
        );

        for (var blockOrder = 0; blockOrder < chunks.length; blockOrder++) {
          final blockId = _uuid.v4();
          final blockIndex = globalBlockIndex;
          final blockPath = _paths.blockPath(bookId, blockIndex, 'txt');
          final chunk = chunks[blockOrder];

          await File(blockPath).writeAsString(chunk, flush: true);
          firstBlockPath ??= blockPath;

          blockRows.add(
            ContentBlocksCompanion.insert(
              id: blockId,
              bookId: bookId,
              chapterId: chapterId,
              blockOrderInChapter: blockOrder,
              globalBlockIndex: blockIndex,
              storageType: DbConstants.storageTypePlain,
              contentPath: blockPath,
              charCount: chunk.length,
            ),
          );

          globalBlockIndex++;
        }
      }

      await _db.finalizeBookImport(
        bookId: bookId,
        chapterRows: chapterRows,
        blockRows: blockRows,
        totalChapters: chapterRows.length,
        totalBlocks: blockRows.length,
      );

      await ChunkBoundaryProcessor.processBook(_db, bookId);

      return ImportResult(
        bookId: bookId,
        title: title,
        totalChapters: chapterRows.length,
        totalBlocks: blockRows.length,
        firstBlockPath: firstBlockPath ?? '',
      );
    } catch (e, st) {
      await _paths.deleteBookDir(bookId);
      if (bookInserted) {
        await _db.markBookFailed(bookId);
      }
      if (e is ImportException) rethrow;
      throw ImportException('TXT 导入失败', cause: e is Error ? '$e\n$st' : e);
    }
  }

  List<String> _chunksForSegment(TxtChapterSegment segment) {
    if (segment.body.isEmpty) {
      return [''];
    }
    return splitByCharLimit(segment.body);
  }
}
