import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Calls the on-device Python (spaCy) chunker via a MethodChannel on Android.
/// On iOS or when an error occurs, returns an empty list (graceful degradation).
class ChunkerService {
  ChunkerService._();
  static final ChunkerService instance = ChunkerService._();

  static const _channel = MethodChannel('com.novelreader/chunker');

  /// Returns sorted character offsets where chunk boundaries begin.
  /// An empty list means no boundaries available (iOS, or processing failed).
  Future<List<int>> getBoundaries(String text) async {
    if (!Platform.isAndroid) return [];
    if (text.trim().isEmpty) return [];
    try {
      final json = await _channel.invokeMethod<String>(
        'getChunkBoundaries',
        {'text': text},
      );
      if (json == null || json == '[]') return [];
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<int>();
    } on PlatformException catch (e) {
      debugPrint('[ChunkerService] error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[ChunkerService] unexpected error: $e');
      return [];
    }
  }
}
