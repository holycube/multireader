import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../vocab/known_words_cache.dart';
import 'txt_highlighter.dart';
import 'word_tap_factory.dart';

/// 渲染带逐词点击的 TextSpan 树，并在 dispose / rebuild 时释放 recognizer。
class TxtHighlightedText extends StatefulWidget {
  const TxtHighlightedText({
    super.key,
    required this.text,
    required this.cache,
    this.highlightRevision = 0,
    this.onWordTap,
    this.textStyle,
    this.unknownHighlightColor,
    this.boundaries = const [],
    this.showChunkSeparators = false,
  });

  final String text;
  final KnownWordsCache cache;
  final int highlightRevision;
  final WordTapCallback? onWordTap;
  final TextStyle? textStyle;
  final Color? unknownHighlightColor;
  final List<int> boundaries;
  final bool showChunkSeparators;

  @override
  State<TxtHighlightedText> createState() => _TxtHighlightedTextState();
}

class _TxtHighlightedTextState extends State<TxtHighlightedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final result = TxtHighlighter.buildSpans(
      plainText: widget.text,
      cache: widget.cache,
      baseStyle: widget.textStyle ?? TxtHighlighter.defaultBaseStyle,
      unknownHighlightColor: widget.unknownHighlightColor,
      onWordTap: widget.onWordTap,
      boundaries: widget.boundaries,
      showChunkSeparators: widget.showChunkSeparators,
    );
    _recognizers.addAll(result.recognizers);

    return Text.rich(
      result.rootSpan,
      key: ValueKey('${widget.text.hashCode}_${widget.highlightRevision}'),
    );
  }
}
