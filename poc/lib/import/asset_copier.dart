import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:path/path.dart' as p;

import 'book_paths.dart';

/// 将 EPUB 内 Images/Css/Fonts 复制到 books/{bookId}/assets/。
class AssetCopier {
  /// 返回 manifest href（已 decode）→ `assets/文件名` 映射。
  static Future<Map<String, String>> copyAssets({
    required EpubBookRef bookRef,
    required BookPaths paths,
    required String bookId,
  }) async {
    final assetMap = <String, String>{};
    final assetsDir = paths.assetsDir(bookId);
    final usedNames = <String>{};

    final content = bookRef.Content;
    if (content == null) return assetMap;

    if (content.Css != null) {
      for (final entry in content.Css!.entries) {
        await _copyEntry(
          href: entry.key,
          readBytes: entry.value.readContentAsBytes,
          assetsDir: assetsDir,
          assetMap: assetMap,
          usedNames: usedNames,
        );
      }
    }
    if (content.Images != null) {
      for (final entry in content.Images!.entries) {
        await _copyEntry(
          href: entry.key,
          readBytes: entry.value.readContentAsBytes,
          assetsDir: assetsDir,
          assetMap: assetMap,
          usedNames: usedNames,
        );
      }
    }
    if (content.Fonts != null) {
      for (final entry in content.Fonts!.entries) {
        await _copyEntry(
          href: entry.key,
          readBytes: entry.value.readContentAsBytes,
          assetsDir: assetsDir,
          assetMap: assetMap,
          usedNames: usedNames,
        );
      }
    }

    return assetMap;
  }

  static Future<void> _copyEntry({
    required String href,
    required Future<List<int>> Function() readBytes,
    required String assetsDir,
    required Map<String, String> assetMap,
    required Set<String> usedNames,
  }) async {
    final decoded = Uri.decodeFull(href);
    final bytes = await readBytes();
    final fileName = _uniqueName(p.basename(decoded), usedNames);
    final dest = p.join(assetsDir, fileName);
    await File(dest).writeAsBytes(bytes);
    assetMap[decoded] = 'assets/$fileName';
    assetMap[href] = 'assets/$fileName';
  }

  static String _uniqueName(String baseName, Set<String> usedNames) {
    if (baseName.isEmpty) baseName = 'asset';
    if (!usedNames.contains(baseName)) {
      usedNames.add(baseName);
      return baseName;
    }
    final ext = p.extension(baseName);
    final stem = p.basenameWithoutExtension(baseName);
    var i = 1;
    while (true) {
      final candidate = ext.isEmpty ? '${stem}_$i' : '${stem}_$i$ext';
      if (!usedNames.contains(candidate)) {
        usedNames.add(candidate);
        return candidate;
      }
      i++;
    }
  }
}
