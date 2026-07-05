import 'package:flutter/foundation.dart';

/// POC 验收用轻量性能埋点（仅 debug 构建生效）。
abstract final class PocMetrics {
  static int? lastBlockLoadMs;
  static int? lastBlockSwitchTotalMs;
  static int? lastBlockSwitchIoMs;
  static int? lastBlockSwitchHighlightMs;
  static int? lastHtmlHighlightMs;
  static int? lastTxtHighlightMs;
  static int? lastHtmlRedrawMs;
  static int? lastHtmlRedrawPreprocessMs;
  static String? lastHtmlRedrawPath;
  static int? lastBlockLayoutMs;
  static int? lastLookupMs;
  static int? lastLookupActionDbMs;
  static int? lastLookupActionRedrawMs;
  static String? lastMetricLabel;

  static void logBlockLoad(int ms, int globalIndex) {
    if (!kDebugMode) return;
    lastBlockLoadMs = ms;
    lastMetricLabel = 'load#$globalIndex';
    debugPrint('[POC1] block load index=$globalIndex ${ms}ms');
  }

  static void logBlockSwitch(int ms, int from, int to) {
    logBlockSwitchDetailed(
      ioMs: ms,
      highlightMs: 0,
      totalMs: ms,
      from: from,
      to: to,
    );
  }

  static void logBlockSwitchDetailed({
    required int ioMs,
    required int highlightMs,
    required int totalMs,
    required int from,
    required int to,
  }) {
    if (!kDebugMode) return;
    lastBlockSwitchIoMs = ioMs;
    lastBlockSwitchHighlightMs = highlightMs;
    lastBlockSwitchTotalMs = totalMs;
    lastMetricLabel = 'switch $from→$to';
    debugPrint(
      '[POC1] block switch $from→$to total=${totalMs}ms '
      'io=${ioMs}ms highlight=${highlightMs}ms',
    );
  }

  static void logHtmlHighlight(int ms, int wordCount) {
    if (!kDebugMode) return;
    lastHtmlHighlightMs = ms;
    lastMetricLabel = 'highlight $wordCount words';
    debugPrint('[POC2] html highlight words=$wordCount ${ms}ms');
  }

  static void logTxtHighlight(int ms, int wordCount) {
    if (!kDebugMode) return;
    lastTxtHighlightMs = ms;
    lastMetricLabel = 'txt highlight $wordCount words';
    debugPrint('[POC2] txt highlight words=$wordCount ${ms}ms');
  }

  static void logHtmlRedraw(int ms, String blockId) {
    logHtmlRedrawDetailed(
      totalMs: ms,
      preprocessMs: 0,
      blockId: blockId,
      path: 'legacy',
    );
  }

  static void logHtmlRedrawDetailed({
    required int totalMs,
    required int preprocessMs,
    required String blockId,
    required String path,
  }) {
    if (!kDebugMode) return;
    lastHtmlRedrawMs = totalMs;
    lastHtmlRedrawPreprocessMs = preprocessMs;
    lastHtmlRedrawPath = path;
    lastMetricLabel = 'redraw $blockId';
    debugPrint(
      '[POC2] html redraw block=$blockId total=${totalMs}ms '
      'preprocess=${preprocessMs}ms path=$path',
    );
  }

  static void logBlockLayout(int ms, int globalBlockIndex) {
    if (!kDebugMode) return;
    lastBlockLayoutMs = ms;
    lastMetricLabel = 'layout#$globalBlockIndex';
    debugPrint('[POC2] html layout index=$globalBlockIndex ${ms}ms');
  }

  static void logLookup(int ms, String word) {
    if (!kDebugMode) return;
    lastLookupMs = ms;
    lastMetricLabel = 'lookup $word';
    debugPrint('[POC2] dict lookup word=$word ${ms}ms');
  }

  static void logLookupAction({
    required int dbMs,
    required int redrawMs,
    required String blockId,
    required int mountedCount,
  }) {
    if (!kDebugMode) return;
    lastLookupActionDbMs = dbMs;
    lastLookupActionRedrawMs = redrawMs;
    lastMetricLabel = 'lookup action $blockId';
    debugPrint(
      '[POC2] lookup action block=$blockId db=${dbMs}ms '
      'redraw=${redrawMs}ms mounted=$mountedCount',
    );
  }

  static void reset() {
    lastBlockLoadMs = null;
    lastBlockSwitchTotalMs = null;
    lastBlockSwitchIoMs = null;
    lastBlockSwitchHighlightMs = null;
    lastHtmlHighlightMs = null;
    lastTxtHighlightMs = null;
    lastHtmlRedrawMs = null;
    lastHtmlRedrawPreprocessMs = null;
    lastHtmlRedrawPath = null;
    lastBlockLayoutMs = null;
    lastLookupMs = null;
    lastLookupActionDbMs = null;
    lastLookupActionRedrawMs = null;
    lastMetricLabel = null;
  }
}
