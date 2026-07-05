/// 向导屏 2 选定、待屏 3 确认写入的词表。
class VocabSelection {
  const VocabSelection({
    required this.words,
    required this.source,
    required this.label,
  });

  final List<String> words;
  final String source;
  final String label;
}
