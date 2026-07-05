import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;

import '../database/constants.dart';
import '../vocab/known_words_cache.dart';
import 'block_loader.dart';
import 'html_reader_fixup.dart';
import 'html_highlighter.dart';
import 'txt_highlighted_text.dart';
import 'word_tap_factory.dart';

/// 单块渲染：HTML 用 HtmlWidget（带高亮 span），纯文本用 Text.rich。
class BlockView extends StatelessWidget {
  const BlockView({
    super.key,
    required this.loaded,
    this.knownWordsCache,
    this.highlightedHtml,
    this.highlightRevision = 0,
    this.htmlLayoutReady = false,
    this.loadError,
    this.onContentLayout,
    this.onHeightMeasured,
    this.onWordTap,
    this.textStyle,
    this.unknownHighlightColor,
    this.contentPadding,
    this.boundaries = const [],
    this.showChunkSeparators = false,
  });

  final LoadedBlock? loaded;
  final KnownWordsCache? knownWordsCache;
  final String? highlightedHtml;
  final int highlightRevision;
  final bool htmlLayoutReady;
  final String? loadError;
  final VoidCallback? onContentLayout;
  final ValueChanged<double>? onHeightMeasured;
  final WordTapCallback? onWordTap;
  final TextStyle? textStyle;
  final Color? unknownHighlightColor;
  final EdgeInsets? contentPadding;
  final List<int> boundaries;
  final bool showChunkSeparators;

  static String _colorToCss(Color color) {
    final value = color.toARGB32();
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '块加载失败：$loadError',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final block = loaded!;
    final padding = contentPadding ??
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final bodyStyle = textStyle ??
        const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87);

    Widget content;
    if (block.meta.storageType == DbConstants.storageTypeHtml) {
      final bookDir = p.dirname(block.meta.contentPath);
      var html = highlightedHtml ?? block.content;
      if (showChunkSeparators && boundaries.isNotEmpty) {
        html = HtmlHighlighter.insertChunkSeparators(html, boundaries);
      }
      final cache = knownWordsCache;
      final useSyncLayout = htmlLayoutReady;

      content = Padding(
        padding: padding,
        child: RepaintBoundary(
          child: HtmlWidget(
            prepareHtmlForReader(html),
            key: ValueKey(block.meta.id),
            baseUrl: Uri.file('$bookDir${p.separator}'),
            buildAsync: !useSyncLayout,
            enableCaching: useSyncLayout,
            renderMode: RenderMode.column,
            textStyle: bodyStyle,
            rebuildTriggers: [highlightRevision, showChunkSeparators],
            factoryBuilder: () => WordTapWidgetFactory(
              onWordTap: onWordTap,
              knownWordsCache: cache,
            ),
            customStylesBuilder: (element) {
              if (element.classes.contains('chunk-sep')) {
                final color = bodyStyle.color;
                if (color == null) return null;
                return {
                  'color': _colorToCss(color.withValues(alpha: 0.4)),
                };
              }
              if (!element.classes.contains('word')) return null;
              final word = element.attributes['data-word'];
              if (word == null ||
                  word.isEmpty ||
                  cache == null ||
                  !cache.isLoaded) {
                return null;
              }
              if (!cache.isKnownNormalized(word)) {
                final color = unknownHighlightColor ?? bodyStyle.color;
                return {
                  'text-decoration': 'underline',
                  'text-decoration-style': 'dashed',
                  if (color != null)
                    'text-decoration-color': _colorToCss(color),
                  'text-decoration-thickness': '1.5px',
                };
              }
              return null;
            },
            onLoadingBuilder: useSyncLayout
                ? null
                : (context, element, loadingProgress) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              loadingProgress == null
                                  ? '正在排版本章…'
                                  : '正在排版… ${(loadingProgress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ),
      );
    } else if (knownWordsCache != null) {
      content = Padding(
        padding: padding,
        child: TxtHighlightedText(
          text: block.content,
          cache: knownWordsCache!,
          highlightRevision: highlightRevision,
          onWordTap: onWordTap,
          textStyle: bodyStyle,
          unknownHighlightColor: unknownHighlightColor,
          boundaries: boundaries,
          showChunkSeparators: showChunkSeparators,
        ),
      );
    } else {
      content = Padding(
        padding: padding,
        child: Text.rich(
          TextSpan(text: block.content, style: bodyStyle),
        ),
      );
    }

    return _AfterLayout(
      onLayout: onContentLayout,
      child: _MeasureHeight(
        onHeightMeasured: onHeightMeasured,
        child: content,
      ),
    );
  }
}

class _MeasureHeight extends StatefulWidget {
  const _MeasureHeight({required this.child, this.onHeightMeasured});

  final Widget child;
  final ValueChanged<double>? onHeightMeasured;

  @override
  State<_MeasureHeight> createState() => _MeasureHeightState();
}

class _MeasureHeightState extends State<_MeasureHeight> {
  final _key = GlobalKey();
  double? _lastHeight;

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant _MeasureHeight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _report();
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final height = box.size.height;
      if (_lastHeight != null && (_lastHeight! - height).abs() < 1) return;
      _lastHeight = height;
      widget.onHeightMeasured?.call(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// 子树布局变化后通知阅读器复查是否该加载下一块。
class _AfterLayout extends StatefulWidget {
  const _AfterLayout({required this.child, this.onLayout});

  final Widget child;
  final VoidCallback? onLayout;

  @override
  State<_AfterLayout> createState() => _AfterLayoutState();
}

class _AfterLayoutState extends State<_AfterLayout> {
  @override
  void initState() {
    super.initState();
    _notify();
  }

  @override
  void didUpdateWidget(covariant _AfterLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notify();
  }

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLayout?.call();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
