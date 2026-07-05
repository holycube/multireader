import 'package:flutter/material.dart';

import '../vocab/dict_entry.dart';

/// 查词卡内联考试标签（考研、四级等）。
class LookupExamTag extends StatelessWidget {
  const LookupExamTag({
    super.key,
    required this.label,
    required this.mutedColor,
    required this.onColor,
  });

  final String label;
  final Color mutedColor;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: mutedColor,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 查词卡义项行：主释义 [FontWeight.w600]，次释义常规字重，分号分隔。
class LookupMeaningsText extends StatelessWidget {
  const LookupMeaningsText({
    super.key,
    required this.meanings,
    required this.style,
    this.suffix,
    this.suffixStyle,
    this.maxLines,
    this.overflow,
  });

  final List<DictMeaning> meanings;
  final TextStyle style;
  final String? suffix;
  final TextStyle? suffixStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (meanings.isEmpty && (suffix == null || suffix!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final primaryStyle = style.copyWith(fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[];
    for (var i = 0; i < meanings.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: '；', style: style));
      }
      final meaning = meanings[i];
      spans.add(
        TextSpan(
          text: meaning.text,
          style: meaning.primary ? primaryStyle : style,
        ),
      );
    }
    if (suffix != null && suffix!.isNotEmpty) {
      spans.add(TextSpan(text: suffix, style: suffixStyle ?? style));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

/// 查词卡音标胶囊（美 🔊），供 [LookupCard] 与 [LookupVariantCard] 复用。
class LookupPhoneticPill extends StatelessWidget {
  const LookupPhoneticPill({
    super.key,
    required this.mutedColor,
    required this.onColor,
    required this.onSpeak,
  });

  final Color mutedColor;
  final Color onColor;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onSpeak,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '美',
                style: TextStyle(
                  fontSize: 10,
                  color: mutedColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.volume_up_outlined,
                size: 12,
                color: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 查词卡「已会」圆形切换按钮。
class LookupKnownToggle extends StatefulWidget {
  const LookupKnownToggle({
    super.key,
    required this.isUnknown,
    required this.accentColor,
    required this.mutedColor,
    required this.busy,
    required this.onTap,
  });

  final bool isUnknown;
  final Color accentColor;
  final Color mutedColor;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<LookupKnownToggle> createState() => _LookupKnownToggleState();
}

class _LookupKnownToggleState extends State<LookupKnownToggle>
    with SingleTickerProviderStateMixin {
  static const _size = 22.0;

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.88)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.busy) return;
    _scaleController.forward(from: 0).then((_) {
      if (mounted) _scaleController.reset();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isKnown = !widget.isUnknown;

    return GestureDetector(
      onTap: widget.busy ? null : _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isKnown ? widget.accentColor : Colors.transparent,
            border: isKnown
                ? null
                : Border.all(color: widget.mutedColor, width: 1.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isKnown
                ? Icon(
                    Icons.check,
                    key: const ValueKey('known'),
                    size: 14,
                    color: Colors.white,
                  )
                : const SizedBox.shrink(key: ValueKey('unknown')),
          ),
        ),
      ),
    );
  }
}

