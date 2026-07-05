import 'package:flutter/material.dart';

import '../../app.dart';
import '../../services/app_theme_notifier.dart';
import '../../services/shell_appearance.dart';
import '../../theme/app_design_tokens.dart';
import 'widgets/settings_group_card.dart';

/// 主页外观：设计系统底色、Accent 与遗留背景预设。
class HomeAppearanceSettingsScreen extends StatefulWidget {
  const HomeAppearanceSettingsScreen({super.key});

  @override
  State<HomeAppearanceSettingsScreen> createState() =>
      _HomeAppearanceSettingsScreenState();
}

class _HomeAppearanceSettingsScreenState
    extends State<HomeAppearanceSettingsScreen> {
  AppThemePreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await AppThemePreferences.load();
    if (!mounted) return;
    setState(() => _prefs = prefs);
  }

  AppThemeNotifier get _notifier => AppScope.of(context).appThemeNotifier;

  Future<void> _setShellBg(int preset) async {
    await _notifier.setShellBgPreset(preset);
    if (mounted) setState(() => _prefs = _notifier.prefs);
  }

  Future<void> _setAccent(int preset) async {
    await _notifier.setAccentPreset(preset);
    if (mounted) setState(() => _prefs = _notifier.prefs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;

    if (prefs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('主页外观')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('主页外观')),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('设计系统底色', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    for (var i = 0;
                        i < AppThemePreferences.designSystemBgPresets.length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ColorPreviewChip(
                          label: AppThemePreferences
                              .designSystemBgPresets[i].label,
                          color: AppThemePreferences
                              .designSystemBgPresets[i].color,
                          selected: prefs.shellBgPreset ==
                              AppThemePreferences
                                  .designSystemBgPresets[i].preset,
                          onTap: () => _setShellBg(
                            AppThemePreferences
                                .designSystemBgPresets[i].preset,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('强调色', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    for (var i = 0;
                        i < AppThemePreferences.accentPresets.length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _AccentPreviewChip(
                          label: AppThemePreferences.accentPresets[i].label,
                          color: AppThemePreferences.accentPresets[i].color,
                          lightColor:
                              AppThemePreferences.accentPresets[i].light,
                          selected: prefs.accentPreset ==
                              AppThemePreferences.accentPresets[i].preset,
                          onTap: () => _setAccent(
                            AppThemePreferences.accentPresets[i].preset,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text('其他背景', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    for (var i = 0;
                        i < AppThemePreferences.legacyBgPresets.length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ColorPreviewChip(
                          label:
                              AppThemePreferences.legacyBgPresets[i].label,
                          color:
                              AppThemePreferences.legacyBgPresets[i].color,
                          selected: prefs.shellBgPreset ==
                              AppThemePreferences.legacyBgPresets[i].preset,
                          onTap: () => _setShellBg(
                            AppThemePreferences.legacyBgPresets[i].preset,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '主页背景作用于书架、统计、词库与个人 Tab 内容区；阅读器背景在「阅读外观」单独设置。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPreviewChip extends StatelessWidget {
  const _ColorPreviewChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.colorScheme.surface;
    final isDark = color != null && color!.computeLuminance() < 0.3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: displayColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (color == null)
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              )
            else
              Text(
                'Aa',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: color == null
                    ? theme.colorScheme.onSurfaceVariant
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPreviewChip extends StatelessWidget {
  const _AccentPreviewChip({
    required this.label,
    required this.color,
    required this.lightColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color lightColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
