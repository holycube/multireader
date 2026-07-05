import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// 书架列表卡片：封面 48×72、进度%、相对阅读时间。
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.title,
    this.author,
    this.coverPath,
    required this.progressPercent,
    this.lastReadAt,
    required this.onTap,
    this.onDelete,
  });

  final String title;
  final String? author;
  final String? coverPath;
  final int progressPercent;
  final int? lastReadAt;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  static const _coverWidth = 48.0;
  static const _coverHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relativeTime = formatRelativeReadTime(lastReadAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookCover(title: title, coverPath: coverPath),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (author != null && author!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progressPercent / 100,
                        minHeight: 3,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$progressPercent%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (relativeTime.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            relativeTime,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        '删除',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.title,
    this.coverPath,
  });

  final String title;
  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final path = coverPath;
    final hasCover =
        path != null && path.isNotEmpty && File(path).existsSync();

    if (hasCover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(
          File(path),
          width: BookCard._coverWidth,
          height: BookCard._coverHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PlaceholderCover(title: title),
        ),
      );
    }

    return _PlaceholderCover(title: title);
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = title.trim().isEmpty ? '?' : title.trim().characters.first;

    return Container(
      width: BookCard._coverWidth,
      height: BookCard._coverHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 将 [updatedAtMs] 格式化为 PRD 规定的相对阅读时间。
String formatRelativeReadTime(int? updatedAtMs) {
  if (updatedAtMs == null) return '';

  final then = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
  final now = DateTime.now();

  if (now.difference(then).inMinutes < 1) return '刚刚';

  final today = DateTime(now.year, now.month, now.day);
  final readDay = DateTime(then.year, then.month, then.day);
  final dayDiff = today.difference(readDay).inDays;

  if (dayDiff == 0) return '今天';
  if (dayDiff == 1) return '昨天';
  return '$dayDiff天前';
}
