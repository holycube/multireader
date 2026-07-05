import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'reader_preferences.dart';

/// 底栏内容区近似高度（不含 SafeArea），用于浮层定位参考。
const kReaderBottomBarHeight = 112.0;

/// 阅读器顶栏：返回、书名与章标题。
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.bookTitle,
    this.chapterTitle,
    this.debugHint,
    this.preferences,
    this.onBack,
  });

  final String bookTitle;
  final String? chapterTitle;
  final String? debugHint;
  final ReaderPreferences? preferences;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = preferences?.chromeColor ??
        theme.colorScheme.surface.withValues(alpha: 0.96);
    final onColor =
        preferences?.chromeOnColor ?? theme.colorScheme.onSurface;

    return Material(
      elevation: 0,
      color: barColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    icon: Icon(Icons.arrow_back, color: onColor),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: onColor),
                        ),
                        if (chapterTitle != null && chapterTitle!.isNotEmpty)
                          Text(
                            chapterTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onColor.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (kDebugMode && debugHint != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        debugHint!,
                        style:
                            theme.textTheme.labelSmall?.copyWith(color: onColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: onColor.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

/// 阅读器底栏：章节导航 + 工具图标。
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    this.chapterTitle,
    this.chapterIndex,
    this.chapterCount,
    this.progressPercent,
    this.preferences,
    this.settingsActive = false,
    this.onPrevChapter,
    this.onNextChapter,
    this.onOpenToc,
    this.onOpenSettings,
    this.onToggleNightMode,
  });

  final String? chapterTitle;
  final int? chapterIndex;
  final int? chapterCount;
  final int? progressPercent;
  final ReaderPreferences? preferences;
  final bool settingsActive;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onOpenToc;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onToggleNightMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = preferences?.chromeColor ??
        theme.colorScheme.surface.withValues(alpha: 0.96);
    final onColor =
        preferences?.chromeOnColor ?? theme.colorScheme.onSurface;
    final hasPrev = chapterIndex != null && chapterIndex! > 0;
    final hasNext = chapterIndex != null &&
        chapterCount != null &&
        chapterIndex! < chapterCount! - 1;
    final pillLabel = chapterTitle?.isNotEmpty == true
        ? chapterTitle!
        : (chapterIndex != null && chapterCount != null
            ? '第 ${chapterIndex! + 1}/$chapterCount 章'
            : '章节');
    final settingsColor = settingsActive
        ? theme.colorScheme.primary
        : onColor;

    return Material(
      elevation: 0,
      color: barColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: onColor.withValues(alpha: 0.08)),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '上一章',
                        icon: Icon(Icons.skip_previous, color: onColor),
                        onPressed: hasPrev ? onPrevChapter : null,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: onColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pillLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: onColor),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '下一章',
                        icon: Icon(Icons.skip_next, color: onColor),
                        onPressed: hasNext ? onNextChapter : null,
                      ),
                      if (progressPercent != null)
                        Text(
                          '$progressPercent%',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: onColor),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BarIcon(
                        tooltip: '目录',
                        icon: Icons.menu_book_outlined,
                        color: onColor,
                        onPressed: onOpenToc,
                      ),
                      _BarIcon(
                        tooltip: '设置',
                        icon: Icons.text_fields,
                        color: settingsColor,
                        active: settingsActive,
                        onPressed: onOpenSettings,
                      ),
                      _BarIcon(
                        tooltip:
                            preferences?.isNightMode == true ? '日间' : '夜间',
                        icon: preferences?.isNightMode == true
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: onColor,
                        onPressed: onToggleNightMode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.active = false,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: color,
        weight: active ? 700 : 400,
      ),
      onPressed: onPressed,
    );
  }
}
