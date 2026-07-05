import 'package:flutter/material.dart';

/// 屏 1：欢迎说明与跳过入口。
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            Icons.auto_stories_outlined,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            '设置你的词汇量',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '我们会根据你已掌握的词汇，在阅读时为生词添加虚线下划线。'
            '词库越准确，高亮越精准。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: onStart,
            child: const Text('开始设置'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: const Text('稍后再说'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
