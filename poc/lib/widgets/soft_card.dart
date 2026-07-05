import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

enum _SoftCardKind { standard, flat, tappable, nested }

/// 壳层标准卡片：白底、大圆角、无描边、无默认分割线。
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.color,
    this.onTap,
    this.useShadow = false,
  }) : _kind = _SoftCardKind.standard;

  /// 无内边距，供设置列表组使用。
  const SoftCard.flat({
    super.key,
    required this.child,
    this.margin,
    this.radius = AppRadius.lg,
    this.color,
    this.useShadow = false,
  })  : padding = EdgeInsets.zero,
        onTap = null,
        _kind = _SoftCardKind.flat;

  /// 可点击卡片。
  const SoftCard.tappable({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.color,
    this.useShadow = false,
  }) : _kind = _SoftCardKind.tappable;

  /// 卡片内嵌块。
  const SoftCard.nested({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.useShadow = false,
  })  : radius = AppRadius.md,
        color = null,
        _kind = _SoftCardKind.nested;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool useShadow;
  final _SoftCardKind _kind;

  Color _resolveColor(BuildContext context) {
    if (color != null) return color!;
    if (_kind == _SoftCardKind.nested) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceNestedDark
          : AppColors.surfaceNested;
    }
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);

    final effectiveOnTap =
        _kind == _SoftCardKind.tappable ? onTap : null;
    if (effectiveOnTap != null) {
      content = InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: useShadow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: Material(
        color: _resolveColor(context),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
