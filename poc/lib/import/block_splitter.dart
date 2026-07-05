import 'import_constants.dart';

/// 按纯文本字符数切分，对齐 data-model charCount（String.length）。
List<String> splitByCharLimit(
  String text, [
  int limit = ImportConstants.blockCharLimit,
]) {
  if (text.isEmpty) return [''];
  if (text.length <= limit) return [text];

  final chunks = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = (start + limit).clamp(0, text.length);
    chunks.add(text.substring(start, end));
    start = end;
  }
  return chunks;
}
