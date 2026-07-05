import '../../vocab/word_normalizer.dart';

/// 解析 txt/csv 词表：每行一词，或 CSV 的 `word` 列 / 首列。
List<String> parseWordList(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return const [];

  final words = <String>{};
  var startIndex = 0;

  final firstLine = lines.first.trim();
  if (firstLine.isNotEmpty && _looksLikeCsvHeader(firstLine)) {
    startIndex = 1;
  }

  for (var i = startIndex; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final token = _extractWordToken(line);
    final normalized = normalizeWord(token);
    if (normalized.isNotEmpty) {
      words.add(normalized);
    }
  }

  return words.toList()..sort();
}

bool _looksLikeCsvHeader(String line) {
  final lower = line.toLowerCase();
  return lower.contains('word') || lower == 'term' || lower.startsWith('word,');
}

String _extractWordToken(String line) {
  if (!line.contains(',')) return line;

  final parts = _splitCsvLine(line);
  if (parts.isEmpty) return '';

  if (parts.length == 1) return parts.first;

  final headerLike = parts.first.toLowerCase();
  if (headerLike == 'word' || headerLike == 'term') {
    return parts.length > 1 ? parts[1] : '';
  }

  final wordIndex = parts.indexWhere(
    (part) => part.toLowerCase() == 'word' || part.toLowerCase() == 'term',
  );
  if (wordIndex >= 0 && wordIndex + 1 < parts.length) {
    return parts[wordIndex + 1];
  }

  return parts.first;
}

List<String> _splitCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (char == ',' && !inQuotes) {
      result.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  result.add(buffer.toString().trim());
  return result;
}
