import 'block_splitter.dart';
import 'import_result.dart';

/// TXT 分章结果：标题 + 正文（不含标题行）。
class TxtChapterSegment {
  const TxtChapterSegment({required this.title, required this.body});

  final String title;
  final String body;
}

/// 英文章节标题正则，对齐 docs/tech-stack.md §3.6。
final RegExp _chapterHeaderPattern = RegExp(
  r'^\s*(chapter|ch\.?)\s+(\d{1,4}|[ivxlcdmIVXLCDM]+)\b',
  multiLine: true,
  caseSensitive: false,
);

/// 将 TXT 全文解析为章节列表；无章节标记时按 12000 字符兜底切块。
List<TxtChapterSegment> parseTxtChapters(String fullText) {
  final normalized = fullText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  if (normalized.trim().isEmpty) {
    throw ImportException('TXT 文件为空');
  }

  final matches = _chapterHeaderPattern.allMatches(normalized).toList();
  if (matches.isEmpty) {
    return _fallbackSegments(normalized);
  }

  return _splitByChapterHeaders(normalized, matches);
}

List<TxtChapterSegment> _fallbackSegments(String text) {
  final chunks = splitByCharLimit(text);
  return [
    for (var i = 0; i < chunks.length; i++)
      TxtChapterSegment(title: '第 ${i + 1} 段', body: chunks[i]),
  ];
}

List<TxtChapterSegment> _splitByChapterHeaders(
  String text,
  List<RegExpMatch> matches,
) {
  final segments = <TxtChapterSegment>[];
  final preamble = text.substring(0, matches.first.start).trim();

  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final headerLine = _lineAt(text, match.start);
    final bodyStart = _lineEndAfter(text, match.start);
    final bodyEnd =
        i + 1 < matches.length ? matches[i + 1].start : text.length;
    var body = text.substring(bodyStart, bodyEnd).trim();

    if (i == 0 && preamble.isNotEmpty) {
      body = '$preamble\n\n$body'.trim();
    }

    segments.add(TxtChapterSegment(title: headerLine, body: body));
  }

  if (segments.isEmpty) {
    return _fallbackSegments(text);
  }

  return segments;
}

String _lineAt(String text, int index) {
  var pos = index;
  while (pos < text.length && text[pos] == '\n') {
    pos++;
  }
  final lineStart = pos > 0 ? text.lastIndexOf('\n', pos - 1) + 1 : 0;
  final lineEnd = text.indexOf('\n', pos);
  final end = lineEnd < 0 ? text.length : lineEnd;
  return text.substring(lineStart, end).trim();
}

int _lineEndAfter(String text, int index) {
  var pos = index;
  while (pos < text.length && text[pos] == '\n') {
    pos++;
  }
  final lineEnd = text.indexOf('\n', pos);
  if (lineEnd == -1) {
    return text.length;
  }
  return lineEnd + 1;
}
