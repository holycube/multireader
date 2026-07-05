import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../../vocab/vocab_progress.dart';
import '../../../widgets/soft_card.dart';

/// 累计已知词里程碑徽章卡片。
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({
    super.key,
    required this.milestoneProgress,
    this.loading = false,
  });

  final VocabMilestoneProgress? milestoneProgress;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('成长里程碑', style: AppTextStyles.sectionTitle(context)),
          const SizedBox(height: 16),
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
          else if (milestoneProgress != null)
            _MilestoneBody(progress: milestoneProgress!),
        ],
      ),
    );
  }
}

class _MilestoneBody extends StatelessWidget {
  const _MilestoneBody({required this.progress});

  final VocabMilestoneProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final subtitle = progress.allUnlocked
        ? '全部里程碑已达成'
        : '距离 ${progress.nextMilestone} 词还差 ${progress.deltaToNext} 个';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < progress.milestones.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _MilestoneBadge(milestone: progress.milestones[i]),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge({required this.milestone});

  final VocabMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = milestone.unlocked;
    final colorScheme = theme.colorScheme;

    return SoftCard.nested(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            size: 22,
            color: unlocked
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            '${milestone.threshold}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: unlocked
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '词',
            style: theme.textTheme.labelSmall?.copyWith(
              color: unlocked
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
