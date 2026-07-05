/// 阅读器 HTML 预处理：覆盖 EPUB 内联 CSS 对段落的 margin:0 重置。
String prepareHtmlForReader(String html) {
  if (html.trim().isEmpty) return html;

  const style = '''
<style type="text/css">
p {
  margin-top: 0.75em !important;
  margin-bottom: 0.75em !important;
  display: block !important;
}
</style>
''';

  // 避免重复注入
  if (html.contains('novel-reader-poc-paragraph-fix')) {
    return html;
  }

  return '$style<!-- novel-reader-poc-paragraph-fix -->$html';
}
