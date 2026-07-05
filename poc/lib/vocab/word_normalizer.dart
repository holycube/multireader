/// 词形归一化，对齐 docs/tech-stack.md §6.1。
///
/// 步骤：Unicode 小写 → 去除首尾标点（保留词内 `'`）→ 不做词干化。
String normalizeWord(String raw) {
  final lower = raw.toLowerCase();
  if (lower.isEmpty) return '';

  var start = 0;
  var end = lower.length;
  while (start < end && _isEdgePunctuation(lower[start])) {
    start++;
  }
  while (end > start && _isEdgePunctuation(lower[end - 1])) {
    end--;
  }
  return lower.substring(start, end);
}

/// 首尾可剥离字符：标点及作为引号的撇号；词内撇号（如 don't）保留。
bool _isEdgePunctuation(String char) {
  if (char == "'") return true;
  return !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char);
}
