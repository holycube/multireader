import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../debug/poc_metrics.dart';
import '../vocab/known_words_cache.dart';
import '../vocab/word_normalizer.dart';
import 'word_tap_factory.dart';

/// 纯文本切分片段。
class TxtTextPart {
  const TxtTextPart({required this.value, required this.isWhitespace});

  final String value;
  final bool isWhitespace;
}

/// TXT 块高亮结果。
class TxtHighlightResult {
  const TxtHighlightResult({
    required this.rootSpan,
    required this.elapsedMs,
    required this.wordCount,
    required this.recognizers,
  });

  final TextSpan rootSpan;
  final int elapsedMs;
  final int wordCount;
  final List<TapGestureRecognizer> recognizers;
}

/// TXT 块 TextSpan 预处理：按空白切词、比对词库、unknown 虚线下划线。
abstract final class TxtHighlighter {
  static const defaultBaseStyle = TextStyle(
    fontSize: 17,
    height: 1.6,
    color: Colors.black87,
  );

  static TextStyle unknownStyle(
    TextStyle baseStyle, {
    Color? highlightColor,
  }) =>
      baseStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dashed,
        decorationColor: highlightColor ?? baseStyle.color ?? Colors.black87,
        decorationThickness: 1.5,
      );

  /// 按空白切分纯文本，保留原样显示文本与空白段。
  static List<TxtTextPart> tokenizePlain(String text) {
    final parts = <TxtTextPart>[];
    final pattern = RegExp(r'\S+|\s+');
    for (final match in pattern.allMatches(text)) {
      final value = match.group(0)!;
      parts.add(
        TxtTextPart(
          value: value,
          isWhitespace: value.trim().isEmpty,
        ),
      );
    }
    return parts;
  }

  /// 构建带高亮与点击手势的 TextSpan 树。
  static TxtHighlightResult buildSpans({
    required String plainText,
    required KnownWordsCache cache,
    TextStyle baseStyle = defaultBaseStyle,
    Color? unknownHighlightColor,
    WordTapCallback? onWordTap,
    List<int> boundaries = const [],
    bool showChunkSeparators = false,
  }) {
    final stopwatch = Stopwatch()..start();
    final recognizers = <TapGestureRecognizer>[];
    var wordCount = 0;

    final children = <InlineSpan>[];
    final sepStyle = baseStyle.copyWith(
      color: baseStyle.color?.withValues(alpha: 0.4),
    );

    if (showChunkSeparators && boundaries.isNotEmpty) {
      final sorted = List<int>.from(boundaries)..sort();
      var start = 0;
      for (final bound in sorted) {
        if (bound <= start || bound > plainText.length) continue;
        final segment = _buildSegmentSpans(
          plainText: plainText.substring(start, bound),
          cache: cache,
          baseStyle: baseStyle,
          unknownHighlightColor: unknownHighlightColor,
          onWordTap: onWordTap,
          recognizers: recognizers,
        );
        children.addAll(segment.children);
        wordCount += segment.wordCount;
        children.add(TextSpan(text: ' · ', style: sepStyle));
        start = bound;
      }
      if (start < plainText.length) {
        final tail = _buildSegmentSpans(
          plainText: plainText.substring(start),
          cache: cache,
          baseStyle: baseStyle,
          unknownHighlightColor: unknownHighlightColor,
          onWordTap: onWordTap,
          recognizers: recognizers,
        );
        children.addAll(tail.children);
        wordCount += tail.wordCount;
      }
    } else {
      final segment = _buildSegmentSpans(
        plainText: plainText,
        cache: cache,
        baseStyle: baseStyle,
        unknownHighlightColor: unknownHighlightColor,
        onWordTap: onWordTap,
        recognizers: recognizers,
      );
      children.addAll(segment.children);
      wordCount = segment.wordCount;
    }

    stopwatch.stop();
    PocMetrics.logTxtHighlight(stopwatch.elapsedMilliseconds, wordCount);

    return TxtHighlightResult(
      rootSpan: TextSpan(style: baseStyle, children: children),
      elapsedMs: stopwatch.elapsedMilliseconds,
      wordCount: wordCount,
      recognizers: recognizers,
    );
  }

  static ({List<InlineSpan> children, int wordCount}) _buildSegmentSpans({
    required String plainText,
    required KnownWordsCache cache,
    required TextStyle baseStyle,
    Color? unknownHighlightColor,
    WordTapCallback? onWordTap,
    required List<TapGestureRecognizer> recognizers,
  }) {
    final children = <InlineSpan>[];
    var wordCount = 0;
    final highlightColor = unknownHighlightColor ?? baseStyle.color;

    for (final part in tokenizePlain(plainText)) {
      if (part.isWhitespace) {
        children.add(TextSpan(text: part.value, style: baseStyle));
        continue;
      }

      final normalized = normalizeWord(part.value);
      if (normalized.isEmpty) {
        children.add(TextSpan(text: part.value, style: baseStyle));
        continue;
      }

      wordCount++;
      final isKnown = cache.isKnownNormalized(normalized);
      final style = isKnown
          ? baseStyle
          : unknownStyle(baseStyle, highlightColor: highlightColor);

      TapGestureRecognizer? recognizer;
      if (onWordTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onWordTap(normalized, !isKnown);
        recognizers.add(recognizer);
      }

      children.add(
        TextSpan(
          text: part.value,
          style: style,
          recognizer: recognizer,
        ),
      );
    }

    return (children: children, wordCount: wordCount);
  }
}
