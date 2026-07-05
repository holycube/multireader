import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../../vocab/vocab_progress.dart';
import '../../../widgets/soft_card.dart';

/// 预置等级覆盖进度卡片。
class LevelProgressCard extends StatelessWidget {
  const LevelProgressCard({
    super.key,
    required this.progress,
    this.loading = false,
  });

  final VocabLevelProgress? progress;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('词汇等级', style: AppTextStyles.sectionTitle(context)),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (progress != null)
            _LevelProgressBody(progress: progress!),
        ],
      ),
    );
  }
}

class _LevelProgressBody extends StatelessWidget {
  const _LevelProgressBody({required this.progress});

  final VocabLevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;

    final title = p.allLevelsComplete
        ? '熟练词表已覆盖'
        : '${p.targetLevel.label}词表 · ${p.progressPercent}%';

    final subtitle = p.allLevelsComplete
        ? '四级预置词表已全部掌握'
        : '再掌握 ${p.remaining} 个词可达该等级覆盖';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!p.allLevelsComplete) ...[
          const SizedBox(height: 4),
          Text(
            '已覆盖 ${p.knownInLevel} / ${p.levelTotal} 词',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
