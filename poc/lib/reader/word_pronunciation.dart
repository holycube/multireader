import 'package:flutter_tts/flutter_tts.dart';

/// 使用系统 TTS 朗读英文单词。
class WordPronunciation {
  WordPronunciation._();

  static final WordPronunciation instance = WordPronunciation._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    _configured = true;
  }

  Future<void> speak(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(trimmed);
  }
}
