import '../screens/vocab_wizard/preset_loader.dart';
import '../screens/vocab_wizard/vocab_wizard_constants.dart';

/// 预置等级词表内存缓存，按 level.id 懒加载。
class PresetWordsCache {
  PresetWordsCache();

  final Map<String, Set<String>> _cache = {};

  /// 返回指定等级的累积词表（已归一化小写）。
  Future<Set<String>> wordsForLevel(PresetLevel level) async {
    final cached = _cache[level.id];
    if (cached != null) return cached;

    final list = await loadPresetWords(level);
    final set = list.toSet();
    _cache[level.id] = set;
    return set;
  }

  /// 预加载全部预置等级词表。
  Future<Map<String, Set<String>>> loadAllLevels() async {
    final result = <String, Set<String>>{};
    for (final level in VocabWizardConstants.presetLevels) {
      result[level.id] = await wordsForLevel(level);
    }
    return result;
  }

  void clear() => _cache.clear();
}
