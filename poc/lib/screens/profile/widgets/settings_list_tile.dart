import 'package:flutter/material.dart';

import '../../../theme/app_design_tokens.dart';

/// 个人中心 / 更多设置统一行：标题、副标题、右侧值 / 开关 / 箭头。
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.showChevron = false,
    this.switchValue,
    this.onSwitchChanged,
    this.onTap,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingText;
  final bool showChevron;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnTap = switchValue != null
        ? null
        : (enabled ? onTap : null);

    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && switchValue != null) {
      effectiveTrailing = Switch(
        value: switchValue!,
        onChanged: enabled ? onSwitchChanged : null,
      );
    } else if (effectiveTrailing == null &&
        (trailingText != null || showChevron)) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (showChevron) ...[
            if (trailingText != null) const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.chevron(theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      minVerticalPadding: 0,
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: effectiveTrailing,
      onTap: effectiveOnTap,
      ),
    );
  }
}
