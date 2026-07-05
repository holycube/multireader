/// EPUB/TXT 导入结果。
class ImportResult {
  const ImportResult({
    required this.bookId,
    required this.title,
    required this.totalChapters,
    required this.totalBlocks,
    required this.firstBlockPath,
  });

  final String bookId;
  final String title;
  final int totalChapters;
  final int totalBlocks;
  final String firstBlockPath;
}

/// 导入失败异常。
class ImportException implements Exception {
  ImportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
