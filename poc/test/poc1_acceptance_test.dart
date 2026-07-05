import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/import/book_paths.dart';
import 'package:multi_novel_reader/import/epub_importer.dart';
import 'package:multi_novel_reader/import/import_constants.dart';
import 'package:multi_novel_reader/import/txt_importer.dart';
import 'package:multi_novel_reader/reader/block_loader.dart';

import 'helpers/import_spotcheck.dart';
import 'helpers/minimal_epub.dart';

/// POC1 ??????Drift ???? + ????????
/// ???flutter test test/poc1_acceptance_test.dart
void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late BookPaths paths;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('poc1_acceptance_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    paths = BookPaths.forRoot('${tempRoot.path}/books');
  });

  tearDown(() async {
    await db.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('POC1 acceptance', () {
    test('EPUB with image: drift spotcheck and block load < 800ms', () async {
      final epubFile = File('${tempRoot.path}/illustrated.epub');
      final imageBytes = List<int>.generate(64, (i) => i);
      await epubFile.writeAsBytes(
        buildMinimalEpub(
          title: "Alice's Adventures in Wonderland",
          author: 'Lewis Carroll',
          chapterTitle: 'Down the Rabbit-Hole',
          bodyHtml:
              '<p>Illustrated test.</p><img src="images/test.png" alt="test"/>',
          imageFileName: 'images/test.png',
          imageBytes: imageBytes,
        ),
      );

      final importer = EpubImporter.withPaths(db, paths);
      final sw = Stopwatch()..start();
      final result = await importer.importFromFile(epubFile);
      sw.stop();

      expect(result.totalBlocks, greaterThan(0));
      await assertImportSpotcheck(
        db: db,
        paths: paths,
        bookId: result.bookId,
        expectedBlocks: result.totalBlocks,
      );

      final blocks = await db.getContentBlocksByBook(result.bookId);
      final htmlBlock = blocks.firstWhere(
        (b) => b.storageType == DbConstants.storageTypeHtml,
      );
      expect(htmlBlock.contentPath, contains('block_'));
      expect(await File(htmlBlock.contentPath).readAsString(), contains('<img'));

      final assetsDir = Directory(paths.assetsDir(result.bookId));
      expect(await assetsDir.exists(), isTrue);

      final loader = BlockLoader();
      final loadSw = Stopwatch()..start();
      await loader.load(htmlBlock);
      loadSw.stop();

      // ignore: avoid_print
      print('[POC1] EPUB import ${sw.elapsedMilliseconds}ms, '
          'first block load ${loadSw.elapsedMilliseconds}ms');

      expect(loadSw.elapsedMilliseconds, lessThan(800));
    });

    test('TXT 310 blocks: import spotcheck, memory, 50-block load', () async {
      const blockCount = 310;
      final txtFile = File('${tempRoot.path}/large.txt');
      final charCount = blockCount * ImportConstants.blockCharLimit;
      await txtFile.writeAsString('x' * charCount);

      final rssBefore = ProcessInfo.currentRss;
      final importer = TxtImporter.withPaths(db, paths);
      final importSw = Stopwatch()..start();
      final result = await importer.importFromFile(txtFile);
      importSw.stop();
      final rssAfterImport = ProcessInfo.currentRss;

      expect(result.totalBlocks, blockCount);
      await assertImportSpotcheck(
        db: db,
        paths: paths,
        bookId: result.bookId,
        expectedBlocks: blockCount,
      );

      final loader = BlockLoader();
      final switchTimes = <int>[];
      var prevIndex = -1;

      for (var i = 0; i < 50; i++) {
        final meta = await db.getBlockByGlobalIndex(result.bookId, i);
        expect(meta, isNotNull);
        final sw = Stopwatch()..start();
        await loader.load(meta!);
        sw.stop();
        if (prevIndex >= 0) {
          switchTimes.add(sw.elapsedMilliseconds);
        }
        prevIndex = i;
      }

      final rssAfter50 = ProcessInfo.currentRss;
      final switchMedian = _median(switchTimes);

      // ignore: avoid_print
      print('[POC1] TXT import ${importSw.elapsedMilliseconds}ms, '
          'blocks=$blockCount, '
          'RSS before=${_mb(rssBefore)}MB '
          'afterImport=${_mb(rssAfterImport)}MB '
          'after50=${_mb(rssAfter50)}MB, '
          'block switch median=${switchMedian}ms');

      expect(switchMedian, lessThan(500));
      // ?????????????Android ????< 200MB / 150MB
      expect(_mb(rssAfterImport), lessThan(400));
      expect(_mb(rssAfter50), lessThan(400));
      expect(loader.getCached(49), isNotNull);
      expect(loader.getCached(0), isNull, reason: 'LRU ??????');
    });
  });
}

double _mb(int bytes) => bytes / (1024 * 1024);

int _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  return sorted[sorted.length ~/ 2];
}
