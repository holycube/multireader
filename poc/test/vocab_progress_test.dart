import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/screens/vocab_wizard/vocab_wizard_constants.dart';
import 'package:multi_novel_reader/vocab/vocab_progress.dart';

void main() {
  final cet4 = VocabWizardConstants.presetLevels[0];
  final cet6 = VocabWizardConstants.presetLevels[1];
  final advanced = VocabWizardConstants.presetLevels[3];

  Map<String, Set<String>> mockPresets({
    Set<String>? cet4Words,
    Set<String>? cet6Words,
    Set<String>? toeflWords,
    Set<String>? advancedWords,
  }) {
    return {
      'cet4': cet4Words ?? {'a', 'b', 'c', 'd'},
      'cet6': cet6Words ?? {'a', 'b', 'c', 'd', 'e', 'f'},
      'toefl': toeflWords ?? {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'},
      'advanced': advancedWords ??
          {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'},
    };
  }

  group('computeLevelProgress', () {
    test('targets first incomplete level with remaining count', () {
      final progress = computeLevelProgress(
        knownWords: {'a', 'b'},
        presetByLevelId: mockPresets(),
      );

      expect(progress.targetLevel.id, cet4.id);
      expect(progress.knownInLevel, 2);
      expect(progress.levelTotal, 4);
      expect(progress.progress, 0.5);
      expect(progress.remaining, 2);
      expect(progress.allLevelsComplete, isFalse);
      expect(progress.progressPercent, 50);
    });

    test('advances to next level when current is fully covered', () {
      final progress = computeLevelProgress(
        knownWords: {'a', 'b', 'c', 'd', 'e'},
        presetByLevelId: mockPresets(),
      );

      expect(progress.targetLevel.id, cet6.id);
      expect(progress.knownInLevel, 5);
      expect(progress.levelTotal, 6);
      expect(progress.remaining, 1);
      expect(progress.allLevelsComplete, isFalse);
    });

    test('reports all levels complete at 100% on advanced', () {
      final progress = computeLevelProgress(
        knownWords: {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'extra'},
        presetByLevelId: mockPresets(),
      );

      expect(progress.targetLevel.id, advanced.id);
      expect(progress.knownInLevel, 10);
      expect(progress.levelTotal, 10);
      expect(progress.progress, 1.0);
      expect(progress.remaining, 0);
      expect(progress.allLevelsComplete, isTrue);
    });

    test('normalizes known words before overlap', () {
      final progress = computeLevelProgress(
        knownWords: {'A', '"b"'},
        presetByLevelId: mockPresets(),
      );

      expect(progress.knownInLevel, 2);
    });
  });

  group('computeMilestoneProgress', () {
    test('unlocks milestones at thresholds', () {
      final progress = computeMilestoneProgress(750);

      expect(progress.milestones.length, 3);
      expect(progress.milestones[0].unlocked, isTrue);
      expect(progress.milestones[1].unlocked, isFalse);
      expect(progress.milestones[2].unlocked, isFalse);
      expect(progress.nextMilestone, 1000);
      expect(progress.deltaToNext, 250);
      expect(progress.allUnlocked, isFalse);
    });

    test('all unlocked when above highest threshold', () {
      final progress = computeMilestoneProgress(6000);

      expect(progress.milestones.every((m) => m.unlocked), isTrue);
      expect(progress.nextMilestone, isNull);
      expect(progress.deltaToNext, isNull);
      expect(progress.allUnlocked, isTrue);
    });

    test('first milestone pending for small vocab', () {
      final progress = computeMilestoneProgress(101);

      expect(progress.milestones[0].unlocked, isFalse);
      expect(progress.nextMilestone, 500);
      expect(progress.deltaToNext, 399);
    });
  });
}
