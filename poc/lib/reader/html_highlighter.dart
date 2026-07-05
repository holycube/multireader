import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../debug/poc_metrics.dart';
import '../vocab/known_words_cache.dart';
import '../vocab/word_normalizer.dart';

/// 旁文件缓存版本前缀；结构变更时递增（v3：词库状态不烘焙进 HTML）。
const highlightCacheVersionPrefix = 'nr-highlight-v3\n';

const _skipSubtreeTags = {
  'script',
  'style',
  'textarea',
  'noscript',
  'template',
  'head',
  'title',
  'meta',
  'link',
  'base',
  'svg',
  'math',
  'iframe',
  'object',
};

const _inlineTagNames = {
  'span',
  'a',
  'em',
  'strong',
  'i',
  'b',
  'u',
  'small',
  'sub',
  'sup',
  'code',
  'abbr',
  'acronym',
  'cite',
  'dfn',
  'kbd',
  'samp',
  'var',
  'mark',
  'q',
};

/// HTML 块高亮结果。
class HtmlHighlightResult {
  const HtmlHighlightResult({
    required this.html,
    required this.elapsedMs,
    required this.wordCount,
    this.fromCache = false,
  });

  final String html;
  final int elapsedMs;
  final int wordCount;
  final bool fromCache;
}

/// EPUB 块 HTML 预处理：遍历文本节点注入 `span.word`。
abstract final class HtmlHighlighter {
  static const defaultSlowThresholdMs = 200;

  static final _brokenTagTail = RegExp(
    r'(?:^|>)\s*[\w-:;]+\s*">',
  );

  static String cachePathFor(String contentPath) =>
      '$contentPath.highlight.html';

  /// 高亮块 HTML；旁文件缓存带版本前缀，成功结果一律写入。
  static Future<HtmlHighlightResult> highlightBlock({
    required String rawHtml,
    required String contentPath,
    required KnownWordsCache cache,
    bool force = false,
    int slowThresholdMs = defaultSlowThresholdMs,
  }) async {
    if (!force) {
      final cached = await _tryReadCache(contentPath);
      if (cached != null) {
        return HtmlHighlightResult(
          html: cached,
          elapsedMs: 0,
          wordCount: _countWordSpans(cached),
          fromCache: true,
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    final highlighted = _highlightHtml(rawHtml, cache);
    stopwatch.stop();

    final wordCount = _countWordSpans(highlighted);
    PocMetrics.logHtmlHighlight(stopwatch.elapsedMilliseconds, wordCount);

    if (_isValidHighlightOutput(highlighted)) {
      await _writeCache(contentPath, highlighted);
    }

    return HtmlHighlightResult(
      html: highlighted,
      elapsedMs: stopwatch.elapsedMilliseconds,
      wordCount: wordCount,
    );
  }

  static Future<String?> _tryReadCache(String contentPath) async {
    final source = File(contentPath);
    if (!await source.exists()) return null;

    final cacheFile = File(cachePathFor(contentPath));
    if (!await cacheFile.exists()) return null;

    final sourceModified = await source.lastModified();
    final cacheModified = await cacheFile.lastModified();
    if (cacheModified.isBefore(sourceModified)) return null;

    final raw = await cacheFile.readAsString();
    if (!raw.startsWith(highlightCacheVersionPrefix)) return null;

    final html = raw.substring(highlightCacheVersionPrefix.length);
    if (!_isValidHighlightOutput(html)) return null;
    return html;
  }

  static Future<void> _writeCache(String contentPath, String html) async {
    final cacheFile = File(cachePathFor(contentPath));
    await cacheFile.writeAsString(
      '$highlightCacheVersionPrefix$html',
      flush: true,
    );
  }

  static bool _isValidHighlightOutput(String html) {
    if (html.trim().isEmpty) return false;
    return !_brokenTagTail.hasMatch(html);
  }

  static String _highlightHtml(String rawHtml, KnownWordsCache cache) {
    if (rawHtml.trim().isEmpty) return rawHtml;

    try {
      final doc = html_parser.parse(rawHtml);
      final body = doc.body;
      if (body == null) return rawHtml;

      _processNode(body, cache);
      _wrapOrphanInlines(body);

      return _serializeHighlightedHtml(rawHtml, doc, body);
    } catch (_) {
      return rawHtml;
    }
  }

  static String _serializeHighlightedHtml(
    String rawHtml,
    dom.Document doc,
    dom.Element body,
  ) {
    final trimmed = rawHtml.trimLeft().toLowerCase();
    if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
      return doc.outerHtml;
    }
    if (trimmed.startsWith('<body')) {
      return body.outerHtml;
    }

    final buffer = StringBuffer();
    final head = doc.head;
    if (head != null && head.nodes.isNotEmpty) {
      buffer.write(head.outerHtml);
    }
    buffer.write(body.innerHtml);
    return buffer.toString();
  }

  static void _processNode(dom.Node node, KnownWordsCache cache) {
    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      if (tag != null && _skipSubtreeTags.contains(tag)) {
        return;
      }
    }

    if (node is dom.Text) {
      if (_isInsideSkippedSubtree(node)) return;
      _replaceTextNode(node, cache);
      return;
    }

    final children = List<dom.Node>.from(node.nodes);
    for (final child in children) {
      _processNode(child, cache);
    }
  }

  static bool _isInsideSkippedSubtree(dom.Node node) {
    var parent = node.parent;
    while (parent != null) {
      final tag = parent.localName?.toLowerCase();
      if (tag != null && _skipSubtreeTags.contains(tag)) {
        return true;
      }
      parent = parent.parent;
    }
    return false;
  }

  static void _replaceTextNode(dom.Text textNode, KnownWordsCache cache) {
    final text = textNode.text;
    if (text.isEmpty) return;

    final parts = _splitText(text);
    if (parts.every((part) => part.isWhitespace)) return;

    final fragment = dom.DocumentFragment();
    for (final part in parts) {
      if (part.isWhitespace) {
        fragment.nodes.add(dom.Text(part.value));
        continue;
      }

      final normalized = normalizeWord(part.value);
      if (normalized.isEmpty) {
        fragment.nodes.add(dom.Text(part.value));
        continue;
      }

      final span = dom.Element.tag('span')
        ..classes.add('word')
        ..attributes['data-word'] = normalized;

      span.nodes.add(dom.Text(part.value));
      fragment.nodes.add(span);
    }

    if (_needsBlockWrapper(textNode.parent)) {
      final wrapper = dom.Element.tag('p')..classes.add('nr-word-wrap');
      wrapper.nodes.addAll(fragment.nodes);
      textNode.replaceWith(wrapper);
    } else {
      textNode.replaceWith(fragment);
    }
  }

  static bool _needsBlockWrapper(dom.Node? parent) {
    if (parent is! dom.Element) return false;
    final name = parent.localName?.toLowerCase();
    return name == 'body';
  }

  static void _wrapOrphanInlines(dom.Element container) {
    final children = List<dom.Node>.from(container.nodes);
    if (children.isEmpty) return;

    container.nodes.clear();
    final inlineBuffer = <dom.Node>[];

    void flushInline() {
      if (inlineBuffer.isEmpty) return;
      final wrapper = dom.Element.tag('p')..classes.add('nr-word-wrap');
      wrapper.nodes.addAll(inlineBuffer);
      container.nodes.add(wrapper);
      inlineBuffer.clear();
    }

    for (final child in children) {
      if (_isOrphanInline(child)) {
        inlineBuffer.add(child);
      } else {
        flushInline();
        container.nodes.add(child);
      }
    }
    flushInline();
  }

  static bool _isOrphanInline(dom.Node node) {
    if (node is dom.Text) {
      return node.text.trim().isNotEmpty;
    }
    if (node is dom.Element) {
      final name = node.localName?.toLowerCase();
      return name != null && _inlineTagNames.contains(name);
    }
    return false;
  }

  static List<_TextPart> _splitText(String text) {
    final parts = <_TextPart>[];
    final pattern = RegExp(r'\S+|\s+');
    for (final match in pattern.allMatches(text)) {
      final value = match.group(0)!;
      parts.add(
        _TextPart(
          value: value,
          isWhitespace: value.trim().isEmpty,
        ),
      );
    }
    return parts;
  }

  static int _countWordSpans(String html) {
    return 'class="word'.allMatches(html).length;
  }

  /// Inserts visual chunk separators at plain-text character offsets.
  /// Applied at render time (not cached with word highlights).
  static String insertChunkSeparators(String html, List<int> boundaries) {
    if (boundaries.isEmpty) return html;

    final sorted = List<int>.from(boundaries)
      ..removeWhere((b) => b <= 0)
      ..sort();
    if (sorted.isEmpty) return html;

    try {
      final doc = html_parser.parse(html);
      final body = doc.body;
      if (body == null) return html;

      final textNodes = <_TextNodeOffset>[];
      _collectTextNodeOffsets(body, textNodes, 0);

      for (final bound in sorted.reversed) {
        final target = _findTextNodeAtOffset(textNodes, bound);
        if (target == null) continue;

        final localPos = bound - target.start;
        final node = target.node;
        final parent = node.parent;
        if (parent == null) continue;

        final sep = dom.Element.tag('span')..classes.add('chunk-sep');
        sep.nodes.add(dom.Text(' · '));

        if (localPos <= 0) {
          final index = parent.nodes.indexOf(node);
          if (index < 0) continue;
          parent.nodes.insert(index, sep);
          continue;
        }

        final text = node.text;
        if (localPos >= text.length) continue;

        final before = text.substring(0, localPos);
        final after = text.substring(localPos);
        node.text = before;
        final index = parent.nodes.indexOf(node);
        parent.nodes.insert(index + 1, sep);
        if (after.isNotEmpty) {
          parent.nodes.insert(index + 2, dom.Text(after));
        }
      }

      return _serializeHighlightedHtml(html, doc, body);
    } catch (_) {
      return html;
    }
  }

  static int _collectTextNodeOffsets(
    dom.Node node,
    List<_TextNodeOffset> out,
    int offset,
  ) {
    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      if (tag != null && _skipSubtreeTags.contains(tag)) return offset;
    }

    if (node is dom.Text) {
      if (_isInsideSkippedSubtree(node)) return offset;
      final text = node.text;
      if (text.isEmpty) return offset;
      out.add(_TextNodeOffset(node, offset));
      return offset + text.length;
    }

    var current = offset;
    for (final child in List<dom.Node>.from(node.nodes)) {
      current = _collectTextNodeOffsets(child, out, current);
    }
    return current;
  }

  static _TextNodeOffset? _findTextNodeAtOffset(
    List<_TextNodeOffset> nodes,
    int offset,
  ) {
    for (final entry in nodes) {
      final end = entry.start + entry.node.text.length;
      if (offset >= entry.start && offset <= end) {
        return entry;
      }
    }
    return null;
  }
}

class _TextNodeOffset {
  const _TextNodeOffset(this.node, this.start);

  final dom.Text node;
  final int start;
}

class _TextPart {
  const _TextPart({required this.value, required this.isWhitespace});

  final String value;
  final bool isWhitespace;
}
