import 'package:flutter/gestures.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../vocab/known_words_cache.dart';

typedef WordTapCallback = void Function(String normalized, bool isUnknown);

/// 扩展 [WidgetFactory]：为预处理注入的 `span.word` 注册点击手势。
class WordTapWidgetFactory extends WidgetFactory {
  WordTapWidgetFactory({
    this.onWordTap,
    this.knownWordsCache,
  });

  final WordTapCallback? onWordTap;
  final KnownWordsCache? knownWordsCache;

  BuildOp? _wordOp;

  @override
  void parse(BuildTree meta) {
    if (meta.element.localName == 'span' &&
        meta.element.classes.contains('word')) {
      meta.register(_wordOp ??= _buildWordOp());
    }
    super.parse(meta);
  }

  bool _isUnknown(String normalized) {
    final cache = knownWordsCache;
    if (cache == null || !cache.isLoaded) return true;
    return !cache.isKnownNormalized(normalized);
  }

  BuildOp _buildWordOp() {
    return BuildOp(
      alwaysRenderBlock: false,
      debugLabel: 'span.word',
      onParsed: (tree) {
        final callback = onWordTap;
        if (callback == null) return tree;

        final normalized = tree.element.attributes['data-word'];
        if (normalized == null || normalized.isEmpty) return tree;

        final isUnknown = _isUnknown(normalized);
        final recognizer = buildGestureRecognizer(
          tree,
          onTap: () => callback(normalized, isUnknown),
        );
        if (recognizer == null) return tree;

        if (tree.isInline == true) {
          for (final bit in tree.bits) {
            if (bit is WidgetBit && bit.isInline == false) {
              bit.child.wrapWith((context, child) {
                return buildGestureDetector(tree, child, recognizer);
              });
            }
          }
        }

        return tree
          ..inherit(_recognizerBuilder, recognizer)
          ..setNonInheritedRecognizer(recognizer);
      },
      onRenderBlock: (tree, placeholder) {
        final recognizer = tree.nonInheritedRecognizer;
        if (recognizer != null) {
          placeholder.wrapWith((context, child) {
            if (child == widget0) return null;
            return buildGestureDetector(tree, child, recognizer);
          });
        }
        return placeholder;
      },
    );
  }

  static InheritedProperties _recognizerBuilder(
    InheritedProperties resolving,
    GestureRecognizer value,
  ) =>
      resolving.copyWith<GestureRecognizer>(value: value);
}

extension _WordTapBuildTree on BuildTree {
  void setNonInheritedRecognizer(GestureRecognizer recognizer) =>
      setNonInherited<GestureRecognizer>(recognizer);

  GestureRecognizer? get nonInheritedRecognizer => getNonInherited();
}
