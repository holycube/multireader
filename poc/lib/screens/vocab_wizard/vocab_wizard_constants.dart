/// 词库向导业务常量，对齐 docs/data-model.md §3.5 与 PRD §3.3。
abstract final class VocabWizardConstants {
  static const wordSourceImportFile = 'import_file';
  static const wordSourcePresetCet4 = 'preset_cet4';
  static const wordSourcePresetCet6 = 'preset_cet6';
  static const wordSourcePresetToefl = 'preset_toefl';
  static const wordSourcePresetAdvanced = 'preset_advanced';

  /// 预置等级：高级选项叠加加载更低等级词表。
  static const presetLevels = <PresetLevel>[
    PresetLevel(
      id: 'cet4',
      label: '高中 / 四级',
      approximateCount: 4500,
      source: wordSourcePresetCet4,
      assetPaths: ['assets/presets/cet4.txt'],
    ),
    PresetLevel(
      id: 'cet6',
      label: '六级',
      approximateCount: 6000,
      source: wordSourcePresetCet6,
      assetPaths: ['assets/presets/cet4.txt', 'assets/presets/cet6.txt'],
    ),
    PresetLevel(
      id: 'toefl',
      label: '托福 / 雅思',
      approximateCount: 8000,
      source: wordSourcePresetToefl,
      assetPaths: [
        'assets/presets/cet4.txt',
        'assets/presets/cet6.txt',
        'assets/presets/toefl.txt',
      ],
    ),
    PresetLevel(
      id: 'advanced',
      label: '熟练',
      approximateCount: 12000,
      source: wordSourcePresetAdvanced,
      assetPaths: [
        'assets/presets/cet4.txt',
        'assets/presets/cet6.txt',
        'assets/presets/toefl.txt',
        'assets/presets/advanced.txt',
      ],
    ),
  ];
}

final class PresetLevel {
  const PresetLevel({
    required this.id,
    required this.label,
    required this.approximateCount,
    required this.source,
    required this.assetPaths,
  });

  final String id;
  final String label;
  final int approximateCount;
  final String source;
  final List<String> assetPaths;
}
