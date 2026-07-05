import 'dart:io';



import 'package:drift/drift.dart';

import 'package:epubx/epubx.dart';

import 'package:image/image.dart' as img;

import 'package:path/path.dart' as p;

import 'package:uuid/uuid.dart';



import '../database/constants.dart';

import '../database/database.dart';

import 'asset_copier.dart';

import 'book_paths.dart';

import 'html_block_splitter.dart';

import 'html_path_rewriter.dart';

import 'chunk_boundary_processor.dart';
import 'import_result.dart';

import 'plain_text_utils.dart';



/// EPUB 导入管线：spine 遍历 → 资源复制 → 子切 → Drift 落表。

class EpubImporter {

  EpubImporter(this._db, this._paths);



  final AppDatabase _db;

  final BookPaths _paths;

  final _uuid = const Uuid();



  static Future<EpubImporter> create(AppDatabase db) async {

    final paths = await BookPaths.create();

    return EpubImporter(db, paths);

  }



  EpubImporter.withPaths(this._db, this._paths);



  Future<ImportResult> importFromFile(File epubFile) async {

    final bookId = _uuid.v4();

    final sourcePath = epubFile.path;

    final now = DateTime.now().millisecondsSinceEpoch;

    var bookInserted = false;



    try {

      final bytes = await epubFile.readAsBytes();

      final bookRef = await EpubReader.openBook(bytes);



      final title = (bookRef.Title?.trim().isNotEmpty ?? false)

          ? bookRef.Title!.trim()

          : p.basenameWithoutExtension(sourcePath);

      final author = bookRef.Author?.trim();



      await _db.insertBook(

        id: bookId,

        title: title,

        author: author?.isNotEmpty == true ? author : null,

        sourceFormat: DbConstants.sourceFormatEpub,

        sourcePath: sourcePath,

        importedAt: now,

      );

      bookInserted = true;



      await _paths.ensureBookDirs(bookId);



      final assetMap = await AssetCopier.copyAssets(

        bookRef: bookRef,

        paths: _paths,

        bookId: bookId,

      );



      final coverPath = await _saveCover(bookRef, bookId);



      final titleByHref = await _buildChapterTitleMap(bookRef);

      final spineHtmlItems = _collectSpineHtmlItems(bookRef);



      if (spineHtmlItems.isEmpty) {

        throw ImportException('EPUB 中未找到可导入的 HTML 章节');

      }



      final chapterRows = <ChaptersCompanion>[];

      final blockRows = <ContentBlocksCompanion>[];

      var globalBlockIndex = 0;

      String? firstBlockPath;



      for (var chapterOrder = 0; chapterOrder < spineHtmlItems.length; chapterOrder++) {

        final item = spineHtmlItems[chapterOrder];

        final chapterId = _uuid.v4();

        final chapterTitle = titleByHref[item.href] ??

            _fallbackChapterTitle(item.href, chapterOrder);



        var rawHtml = await item.readHtml();

        rawHtml = HtmlPathRewriter.rewrite(rawHtml, item.href, assetMap);



        final htmlChunks = splitHtmlByCharLimit(rawHtml);

        final blockCount = htmlChunks.length;



        chapterRows.add(

          ChaptersCompanion.insert(

            id: chapterId,

            bookId: bookId,

            orderIndex: chapterOrder,

            title: chapterTitle,

            blockCount: Value(blockCount),

          ),

        );



        for (var blockOrder = 0; blockOrder < htmlChunks.length; blockOrder++) {

          final blockId = _uuid.v4();

          final blockIndex = globalBlockIndex;

          final blockPath = _paths.blockPath(

            bookId,

            blockIndex,

            'html',

          );



          final htmlToSave = htmlChunks[blockOrder];

          final charCount = stripHtmlTagsForSplit(htmlToSave).length;



          await File(blockPath).writeAsString(htmlToSave, flush: true);

          firstBlockPath ??= blockPath;



          blockRows.add(

            ContentBlocksCompanion.insert(

              id: blockId,

              bookId: bookId,

              chapterId: chapterId,

              blockOrderInChapter: blockOrder,

              globalBlockIndex: blockIndex,

              storageType: DbConstants.storageTypeHtml,

              contentPath: blockPath,

              charCount: charCount,

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

        coverPath: coverPath,

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

      throw ImportException('EPUB 导入失败', cause: e is Error ? '$e\n$st' : e);

    }

  }



  Future<String?> _saveCover(EpubBookRef bookRef, String bookId) async {

    try {

      img.Image? coverImage;

      try {

        coverImage = await bookRef.readCover();

      } catch (_) {

        // readCover may throw on malformed cover meta; try fallback.

      }



      if (coverImage == null) {

        final bytes = await _resolveCoverImageBytes(bookRef);

        if (bytes == null) return null;

        coverImage = img.decodeImage(bytes);

        if (coverImage == null) return null;

      }



      final encoded = img.encodeJpg(coverImage);

      final path = _paths.coverPath(bookId);

      await File(path).writeAsBytes(encoded);

      return path;

    } catch (_) {

      return null;

    }

  }



  Future<List<int>?> _resolveCoverImageBytes(EpubBookRef bookRef) async {

    final fromMeta = await _coverBytesFromOpfMeta(bookRef);

    if (fromMeta != null) return fromMeta;



    final fromManifestProps = await _coverBytesFromManifestProperties(bookRef);

    if (fromManifestProps != null) return fromManifestProps;



    return _coverBytesFromImagesFilename(bookRef);

  }



  Future<List<int>?> _coverBytesFromOpfMeta(EpubBookRef bookRef) async {

    final metaItems = bookRef.Schema?.Package?.Metadata?.MetaItems;

    if (metaItems == null || metaItems.isEmpty) return null;



    final manifestItems = bookRef.Schema?.Package?.Manifest?.Items ?? [];



    for (final meta in metaItems) {

      final name = meta.Name?.toLowerCase();

      final property = meta.Property?.toLowerCase();

      final isCoverMeta = name == 'cover' || property == 'cover-image';

      if (!isCoverMeta) continue;



      final manifestId = meta.Content?.trim();

      if (manifestId == null || manifestId.isEmpty) continue;



      final manifest = _findManifestById(manifestItems, manifestId);

      if (manifest == null) continue;



      final bytes = await _readManifestImageBytes(bookRef, manifest);

      if (bytes != null) return bytes;

    }

    return null;

  }



  Future<List<int>?> _coverBytesFromManifestProperties(

    EpubBookRef bookRef,

  ) async {

    final manifestItems = bookRef.Schema?.Package?.Manifest?.Items ?? [];

    for (final item in manifestItems) {

      final props = item.Properties?.toLowerCase().split(RegExp(r'\s+')) ?? [];

      if (!props.contains('cover-image')) continue;



      final bytes = await _readManifestImageBytes(bookRef, item);

      if (bytes != null) return bytes;

    }

    return null;

  }



  Future<List<int>?> _coverBytesFromImagesFilename(EpubBookRef bookRef) async {

    final images = bookRef.Content?.Images;

    if (images == null || images.isEmpty) return null;



    for (final entry in images.entries) {

      if (!entry.key.toLowerCase().contains('cover')) continue;

      return entry.value.readContentAsBytes();

    }

    return null;

  }



  EpubManifestItem? _findManifestById(

    List<EpubManifestItem> items,

    String manifestId,

  ) {

    final lower = manifestId.toLowerCase();

    for (final item in items) {

      if (item.Id?.toLowerCase() == lower) return item;

    }

    return null;

  }



  Future<List<int>?> _readManifestImageBytes(

    EpubBookRef bookRef,

    EpubManifestItem manifest,

  ) async {

    final href = manifest.Href;

    if (href == null || href.isEmpty) return null;



    final images = bookRef.Content?.Images;

    if (images == null) return null;



    final decoded = Uri.decodeFull(href);

    final fileRef = images[href] ?? images[decoded];

    if (fileRef == null) return null;



    return fileRef.readContentAsBytes();

  }



  Future<Map<String, String>> _buildChapterTitleMap(EpubBookRef bookRef) async {

    final map = <String, String>{};

    final chapters = await bookRef.getChapters();

    _flattenChapterRefs(chapters, map);

    return map;

  }



  void _flattenChapterRefs(

    List<EpubChapterRef> refs,

    Map<String, String> map,

  ) {

    for (final ref in refs) {

      final fileName = ref.ContentFileName;

      final title = ref.Title?.trim();

      if (fileName != null && title != null && title.isNotEmpty) {

        final decoded = Uri.decodeFull(fileName);

        map.putIfAbsent(decoded, () => title);

        map.putIfAbsent(fileName, () => title);

      }

      if (ref.SubChapters != null && ref.SubChapters!.isNotEmpty) {

        _flattenChapterRefs(ref.SubChapters!, map);

      }

    }

  }



  List<_SpineHtmlItem> _collectSpineHtmlItems(EpubBookRef bookRef) {

    final package = bookRef.Schema?.Package;

    final manifestItems = package?.Manifest?.Items ?? [];

    final spineItems = package?.Spine?.Items ?? [];

    final htmlMap = bookRef.Content?.Html ?? {};



    final idToManifest = <String, EpubManifestItem>{

      for (final item in manifestItems)

        if (item.Id != null) item.Id!: item,

    };



    final result = <_SpineHtmlItem>[];

    for (final spineItem in spineItems) {

      final idRef = spineItem.IdRef;

      if (idRef == null) continue;



      final manifest = idToManifest[idRef];

      if (manifest == null || manifest.Href == null) continue;



      final href = Uri.decodeFull(manifest.Href!);

      final mediaType = (manifest.MediaType ?? '').toLowerCase();

      if (!mediaType.contains('html') && !mediaType.contains('xhtml')) {

        continue;

      }



      final htmlRef = htmlMap[href] ?? htmlMap[manifest.Href!];

      if (htmlRef == null) continue;



      result.add(_SpineHtmlItem(

        href: href,

        readHtml: () => htmlRef.readContentAsText(),

      ));

    }



    if (result.isNotEmpty) return result;



    // 无 spine 可解析项时，按 Html map 顺序降级。

    for (final entry in htmlMap.entries) {

      result.add(

        _SpineHtmlItem(

          href: Uri.decodeFull(entry.key),

          readHtml: () => entry.value.readContentAsText(),

        ),

      );

    }

    return result;

  }



  String _fallbackChapterTitle(String href, int orderIndex) {

    final stem = p.basenameWithoutExtension(href);

    if (stem.isNotEmpty && stem.toLowerCase() != 'index') {

      return stem;

    }

    return 'Chapter ${orderIndex + 1}';

  }

}



class _SpineHtmlItem {

  const _SpineHtmlItem({required this.href, required this.readHtml});



  final String href;

  final Future<String> Function() readHtml;

}
