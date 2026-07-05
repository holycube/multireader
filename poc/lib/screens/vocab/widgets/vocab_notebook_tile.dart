import 'package:flutter/material.dart';

import '../../../database/database.dart';
import '../../../widgets/book_card.dart';

/// 生词本列表行：词形、释义/例句摘要、最近更新时间。
class VocabNotebookTile extends StatelessWidget {
  const VocabNotebookTile({
    super.key,
    required this.entry,
    required this.definitionSnippet,
    this.contextSnippet,
    this.onTap,
  });

  final VocabEntry entry;
  final String definitionSnippet;
  final String? contextSnippet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relativeTime = formatRelativeReadTime(entry.updatedAt);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.word,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (definitionSnippet.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        definitionSnippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                    if (contextSnippet != null &&
                        contextSnippet!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contextSnippet!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (relativeTime.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  relativeTime,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 将多行文本压成单行摘要。
String vocabSnippetLine(String text, {int maxLen = 96}) {
  final line = text.replaceAll('\n', ' ').trim();
  if (line.isEmpty) return '';
  if (line.length <= maxLen) return line;
  return '${line.substring(0, maxLen)}…';
}
