import '../screens/vocab_wizard/vocab_wizard_constants.dart';
import 'word_normalizer.dart';

/// 里程碑阈值（累计已知词数）。
const vocabMilestoneThresholds = [500, 1000, 5000];

/// 预置等级覆盖进度。
class VocabLevelProgress {
  const VocabLevelProgress({
    required this.targetLevel,
    required this.knownInLevel,
    required this.levelTotal,
    required this.progress,
    required this.remaining,
    required this.allLevelsComplete,
  });

  final PresetLevel targetLevel;
  final int knownInLevel;
  final int levelTotal;
  final double progress;
  final int remaining;
  final bool allLevelsComplete;

  int get progressPercent => (progress * 100).round().clamp(0, 100);
}

/// 单个里程碑状态。
class VocabMilestone {
  const VocabMilestone({
    required this.threshold,
    required this.unlocked,
  });

  final int threshold;
  final bool unlocked;
}

/// 里程碑汇总。
class VocabMilestoneProgress {
  const VocabMilestoneProgress({
    required this.totalKnown,
    required this.milestones,
    this.nextMilestone,
    this.deltaToNext,
  });

  final int totalKnown;
  final List<VocabMilestone> milestones;
  final int? nextMilestone;
  final int? deltaToNext;

  bool get allUnlocked =>
      milestones.isNotEmpty && milestones.every((m) => m.unlocked);
}

Set<String> _normalizeKnownWords(Set<String> knownWords) {
  return {
    for (final w in knownWords)
      if (normalizeWord(w).isNotEmpty) normalizeWord(w),
  };
}

int _countOverlap(Set<String> known, Set<String> levelWords) {
  var count = 0;
  for (final word in levelWords) {
    if (known.contains(word)) count++;
  }
  return count;
}

/// 根据已知词与各等级预置词表计算覆盖进度。
///
/// [presetByLevelId] 键为 [PresetLevel.id]，值为该等级累积词表。
VocabLevelProgress computeLevelProgress({
  required Set<String> knownWords,
  required Map<String, Set<String>> presetByLevelId,
}) {
  final known = _normalizeKnownWords(knownWords);
  const levels = VocabWizardConstants.presetLevels;

  for (final level in levels) {
    final levelWords = presetByLevelId[level.id] ?? const {};
    final levelTotal = levelWords.length;
    if (levelTotal == 0) {
      continue;
    }

    final knownInLevel = _countOverlap(known, levelWords);
    final progress = knownInLevel / levelTotal;

    if (progress < 1.0) {
      return VocabLevelProgress(
        targetLevel: level,
        knownInLevel: knownInLevel,
        levelTotal: levelTotal,
        progress: progress,
        remaining: levelTotal - knownInLevel,
        allLevelsComplete: false,
      );
    }
  }

  final advanced = levels.last;
  final advancedWords = presetByLevelId[advanced.id] ?? const {};
  final advancedTotal = advancedWords.length;
  final knownInAdvanced =
      advancedTotal == 0 ? 0 : _countOverlap(known, advancedWords);

  return VocabLevelProgress(
    targetLevel: advanced,
    knownInLevel: knownInAdvanced,
    levelTotal: advancedTotal,
    progress: 1.0,
    remaining: 0,
    allLevelsComplete: true,
  );
}

/// 根据累计已知词数计算里程碑状态。
VocabMilestoneProgress computeMilestoneProgress(int totalKnown) {
  final milestones = [
    for (final threshold in vocabMilestoneThresholds)
      VocabMilestone(
        threshold: threshold,
        unlocked: totalKnown >= threshold,
      ),
  ];

  int? next;
  int? delta;
  for (final threshold in vocabMilestoneThresholds) {
    if (totalKnown < threshold) {
      next = threshold;
      delta = threshold - totalKnown;
      break;
    }
  }

  return VocabMilestoneProgress(
    totalKnown: totalKnown,
    milestones: milestones,
    nextMilestone: next,
    deltaToNext: delta,
  );
}
