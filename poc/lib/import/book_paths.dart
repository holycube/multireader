import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 书籍块文件与 assets 的私有目录路径。
class BookPaths {
  BookPaths(this._booksRoot);

  final String _booksRoot;

  static Future<BookPaths> create() async {
    final docs = await getApplicationDocumentsDirectory();
    return BookPaths(p.join(docs.path, 'books'));
  }

  /// 测试用：指定根目录。
  BookPaths.forRoot(String booksRoot) : _booksRoot = booksRoot;

  String get booksRoot => _booksRoot;

  String bookDir(String bookId) => p.join(_booksRoot, bookId);

  String assetsDir(String bookId) => p.join(bookDir(bookId), 'assets');

  String coverPath(String bookId) => p.join(bookDir(bookId), 'cover.jpg');

  String blockFileName(int globalBlockIndex, String ext) {
    return 'block_${globalBlockIndex.toString().padLeft(4, '0')}.$ext';
  }

  String blockPath(String bookId, int globalBlockIndex, String ext) {
    return p.join(bookDir(bookId), blockFileName(globalBlockIndex, ext));
  }

  Future<void> ensureBookDirs(String bookId) async {
    await Directory(bookDir(bookId)).create(recursive: true);
    await Directory(assetsDir(bookId)).create(recursive: true);
  }

  Future<void> deleteBookDir(String bookId) async {
    final dir = Directory(bookDir(bookId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
