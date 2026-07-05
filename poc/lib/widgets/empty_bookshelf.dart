import 'package:flutter/material.dart';

/// 书架空状态：引导导入或打开找书指南（push 资源页）。
class EmptyBookshelf extends StatelessWidget {
  const EmptyBookshelf({
    super.key,
    required this.onImport,
    this.onOpenResourcesGuide,
    this.importing = false,
  });

  final VoidCallback? onImport;
  final VoidCallback? onOpenResourcesGuide;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              '书架还是空的',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '导入 EPUB 或 TXT 开始阅读',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: importing ? null : onImport,
              icon: importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(importing ? '导入中…' : '导入书籍'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onOpenResourcesGuide,
              child: const Text('打开找书指南'),
            ),
          ],
        ),
      ),
    );
  }
}
