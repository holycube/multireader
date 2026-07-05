import 'import_constants.dart';
import 'plain_text_utils.dart';

/// 按纯文本长度切分 HTML，尽量在 `</p>` 边界断开；无法切分时回退字符硬切。
List<String> splitHtmlByCharLimit(
  String html, [
  int limit = ImportConstants.blockCharLimit,
]) {
  final plainLen = stripHtmlTagsForSplit(html).length;
  if (plainLen <= limit) return [html];

  final paragraphEnds = RegExp(r'</p\s*>', caseSensitive: false).allMatches(html);
  if (paragraphEnds.isNotEmpty) {
    final byParagraph = _splitAtParagraphEnds(html, paragraphEnds, limit);
    if (byParagraph != null) return byParagraph;
  }

  // 无 <p> 结构：按纯文本硬切后包裹为段落 HTML
  final plainChunks = _splitPlainText(stripHtmlTagsForSplit(html), limit);
  return plainChunks.map(wrapPlainTextAsHtml).toList();
}

List<String>? _splitAtParagraphEnds(
  String html,
  Iterable<RegExpMatch> paragraphEnds,
  int limit,
) {
  final boundaries = <int>[0];
  for (final match in paragraphEnds) {
    boundaries.add(match.end);
  }
  if (boundaries.last < html.length) {
    boundaries.add(html.length);
  }

  final segments = <String>[];
  for (var i = 1; i < boundaries.length; i++) {
    final segment = html.substring(boundaries[i - 1], boundaries[i]);
    if (segment.trim().isNotEmpty) {
      segments.add(segment);
    }
  }

  if (segments.isEmpty) return null;

  final chunks = <String>[];
  final buffer = StringBuffer();
  var bufferLen = 0;

  void flush() {
    if (buffer.isEmpty) return;
    chunks.add(buffer.toString());
    buffer.clear();
    bufferLen = 0;
  }

  for (final segment in segments) {
    final segLen = stripHtmlTagsForSplit(segment).length;
    if (segLen > limit) {
      flush();
      final plainChunks = _splitPlainText(stripHtmlTagsForSplit(segment), limit);
      chunks.addAll(plainChunks.map(wrapPlainTextAsHtml));
      continue;
    }
    if (bufferLen + segLen > limit && buffer.isNotEmpty) {
      flush();
    }
    buffer.write(segment);
    bufferLen += segLen;
  }
  flush();

  return chunks.isEmpty ? null : chunks;
}

List<String> _splitPlainText(String text, int limit) {
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
