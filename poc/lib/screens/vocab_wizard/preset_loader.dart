import 'package:flutter/services.dart';

import 'vocab_wizard_constants.dart';
import 'word_list_parser.dart';

/// 从 assets 加载预置等级词表（高级叠加低级）。
Future<List<String>> loadPresetWords(PresetLevel level) async {
  final words = <String>{};
  for (final path in level.assetPaths) {
    final raw = await rootBundle.loadString(path);
    words.addAll(parseWordList(raw));
  }
  final list = words.toList()..sort();
  return list;
}
