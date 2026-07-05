import 'dart:convert';

/// 从 HTML 提取纯文本，用于 charCount 与子切阈值（折叠空白）。
String stripHtmlTags(String html) {
  return _stripHtmlInternal(html, preserveBlocks: false);
}

/// 保留段落/换行边界，用于子切计数与纯文本回退分块。
String stripHtmlTagsForSplit(String html) {
  return _stripHtmlInternal(html, preserveBlocks: true);
}

String _stripHtmlInternal(String html, {required bool preserveBlocks}) {
  var text = html;
  text = text.replaceAll(
    RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
    ' ',
  );
  text = text.replaceAll(
    RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
    ' ',
  );

  if (preserveBlocks) {
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
  }

  text = text.replaceAll(RegExp(r'<[^>]+>'), preserveBlocks ? '' : ' ');

  if (preserveBlocks) {
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  } else {
    text = text.replaceAll(RegExp(r'\s+'), ' ');
  }

  return _decodeHtmlEntities(text.trim());
}

String _decodeHtmlEntities(String text) {
  return text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}

/// 将纯文本包裹为可渲染 HTML，保留段落空行。
String wrapPlainTextAsHtml(String plainText) {
  final paragraphs = plainText.split(RegExp(r'\n\n+'));
  if (paragraphs.length <= 1) {
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(plainText);
    return '<p>$escaped</p>';
  }

  final buf = StringBuffer();
  for (final paragraph in paragraphs) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) continue;
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(trimmed);
    buf.write('<p>$escaped</p>');
  }
  final result = buf.toString();
  return result.isEmpty ? '<p></p>' : result;
}
