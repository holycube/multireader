import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../database/constants.dart';
import '../database/database.dart';
import '../debug/poc_metrics.dart';
import '../services/reading_session_tracker.dart';
import '../vocab/dict_entry.dart';
import '../vocab/dict_loader.dart';
import '../vocab/known_words_cache.dart';
import 'block_highlight_cache.dart';
import 'block_loader.dart';
import 'block_view.dart';
import 'chapter_drawer.dart';
import 'lookup_panel.dart';
import 'reader_chrome.dart';
import 'reader_preferences.dart';
import 'reader_settings_panel.dart';
import 'reading_offset.dart';
import 'txt_highlighter.dart';
import 'word_lookup_service.dart';

/// POC 阅读页：按块连续滚动，HTML 块带词高亮、窗口挂载与预取。
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.db,
    required this.knownWordsCache,
  });

  final String bookId;
  final AppDatabase db;
  final KnownWordsCache knownWordsCache;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  static const _loadThreshold = 200.0;
  static const _maxAutoChain = 5;
  static const _maxMountedBlocks = 7;
  static const _mountMargin = 1;
  static const _minLayoutHeight = 120.0;

  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _loader = BlockLoader();
  final _highlightCache = BlockHighlightCache();
  late final WordLookupService _lookupService;
  late final ReadingSessionTracker _sessionTracker;
  ReaderPreferences? _readerPrefs;
  Timer? _saveProgressTimer;

  String? _title;
  String? _currentChapterId;
  String? _currentChapterTitle;
  final Map<String, String> _chapterTitles = {};
  List<Chapter> _chapters = [];
  int? _pendingCharOffset;
  bool _chromeVisible = true;
  bool _settingsPanelVisible = false;
  int _totalBlocks = 0;
  final List<_BlockEntry> _entries = [];
  bool _isLoadingNext = false;
  bool _reachedEnd = false;
  bool _initializing = true;
  String? _initError;
  String? _debugMetricHint;
  int _autoChainLoads = 0;

  final Map<String, Stopwatch> _layoutStopwatches = {};
  final Set<String> _layoutReportedKeys = {};
  int? _lastSwitchFromIndex;
  int? _lastSwitchToIndex;
  int _lastSwitchTotalMs = 0;
  int _lastSwitchHighlightMs = 0;
  int? _firstBlockLoadMs;
  bool _awaitingFirstBlockLayout = false;

  @override
  void initState() {
    super.initState();
    _sessionTracker = ReadingSessionTracker(widget.db);
    _sessionTracker.start(widget.bookId);
    WidgetsBinding.instance.addObserver(this);
    _lookupService = WordLookupService(
      db: widget.db,
      knownWordsCache: widget.knownWordsCache,
    );
    _loadReaderPrefs();
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  Future<void> _loadReaderPrefs() async {
    final prefs = await ReaderPreferences.load();
    prefs.addListener(_onReaderPrefsChanged);
    if (!mounted) return;
    setState(() => _readerPrefs = prefs);
  }

  void _onReaderPrefsChanged() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _entries.length; i++) {
        final entry = _entries[i];
        if (entry.loaded == null) continue;
        _entries[i] = entry.copyWith(
          highlightRevision: entry.highlightRevision + 1,
        );
      }
    });
  }

  void _openReaderSettings() {
    if (_readerPrefs == null) return;
    setState(() {
      _settingsPanelVisible = !_settingsPanelVisible;
      if (_settingsPanelVisible) {
        _chromeVisible = true;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _sessionTracker.pause();
      case AppLifecycleState.resumed:
        _sessionTracker.resume();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_sessionTracker.flush());
    WidgetsBinding.instance.removeObserver(this);
    _readerPrefs?.removeListener(_onReaderPrefsChanged);
    _saveProgressTimer?.cancel();
    _saveCurrentProgress();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _loader.evictAll();
    _highlightCache.invalidateAll();
    super.dispose();
  }

  void _toggleChrome() {
    setState(() {
      _settingsPanelVisible = false;
      _chromeVisible = !_chromeVisible;
    });
  }

  void _openChapterDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _toggleNightMode() async {
    await _readerPrefs?.toggleNightMode();
  }

  int? _currentChapterIndex() {
    if (_currentChapterId == null || _chapters.isEmpty) return null;
    final idx = _chapters.indexWhere((c) => c.id == _currentChapterId);
    return idx >= 0 ? idx : null;
  }

  Future<void> _goToAdjacentChapter(int delta) async {
    final idx = _currentChapterIndex();
    if (idx == null) return;
    final targetIdx = idx + delta;
    if (targetIdx < 0 || targetIdx >= _chapters.length) return;
    await _onChapterSelected(_chapters[targetIdx]);
  }

  void _updateChapterFromBlock(ContentBlock block) {
    _currentChapterId = block.chapterId;
    _currentChapterTitle = _chapterTitles[block.chapterId];
  }

  int? _readingProgressPercent() {
    if (_totalBlocks <= 0 || !_scrollController.hasClients) return null;
    final pos = _resolveReadingPosition();
    final block = pos.block;
    if (block == null) return null;
    final charCount = block.charCount > 0 ? block.charCount : 1;
    final fraction =
        (block.globalBlockIndex + pos.charOffset / charCount) / _totalBlocks;
    return (fraction.clamp(0.0, 1.0) * 100).round();
  }

  ({ContentBlock? block, int charOffset}) _resolveReadingPosition() {
    if (!_scrollController.hasClients) {
      return (block: null, charOffset: 0);
    }
    return resolveReadingPosition(
      scrollTop: _scrollController.position.pixels,
      blocks: [
        for (final entry in _entries)
          (
            block: entry.loaded?.meta,
            height: entry.layoutHeight,
          ),
      ],
    );
  }

  void _scheduleProgressSave() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer(const Duration(milliseconds: 500), () {
      _saveCurrentProgress();
    });
  }

  Future<void> _saveCurrentProgress() async {
    if (_entries.isEmpty || _initializing) return;
    final pos = _resolveReadingPosition();
    final block = pos.block;
    if (block == null) return;

    await widget.db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: widget.bookId,
        chapterId: block.chapterId,
        blockId: block.id,
        charOffset: Value(pos.charOffset),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _tryRestoreCharOffset() {
    final offset = _pendingCharOffset;
    if (offset == null || offset <= 0 || _entries.isEmpty) return;

    final entry = _entries.first;
    final block = entry.loaded?.meta;
    final height = entry.measuredHeight;
    if (block == null || height == null || height <= 0) return;

    final targetY = scrollOffsetForChar(
      charOffset: offset,
      charCount: block.charCount,
      blockHeight: height,
    );
    if (!_scrollController.hasClients) return;

    _scrollController.jumpTo(
      targetY.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
    _pendingCharOffset = null;
  }

  Future<void> _jumpToBlock(ContentBlock meta, {int charOffset = 0}) async {
    _loader.evictAll();
    _highlightCache.invalidateAll();
    _saveProgressTimer?.cancel();

    final loaded = await _loader.load(meta);
    final prepared = await _prepareEntry(loaded);
    if (!mounted) return;

    setState(() {
      _entries
        ..clear()
        ..add(prepared.entry);
      _reachedEnd = meta.globalBlockIndex >= _totalBlocks - 1;
      _isLoadingNext = false;
      _autoChainLoads = 0;
      _pendingCharOffset = charOffset > 0 ? charOffset : null;
      _updateChapterFromBlock(meta);
      if (kDebugMode) {
        _awaitingFirstBlockLayout = true;
        _startLayoutStopwatch(prepared.entry);
      }
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    await widget.db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: widget.bookId,
        chapterId: meta.chapterId,
        blockId: meta.id,
        charOffset: Value(charOffset),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    _prefetchAdjacent(meta.globalBlockIndex);
    _scheduleExtentCheck();
    _updateMountState();
    if (charOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestoreCharOffset());
    }
  }

  Future<void> _onChapterSelected(Chapter chapter) async {
    Navigator.of(context).pop();

    final block = await widget.db.getFirstBlockOfChapter(chapter.id);
    if (block == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该章暂无内容')),
      );
      return;
    }

    await _jumpToBlock(block);
  }

  Future<({_BlockEntry entry, int highlightMs})> _prepareEntry(
    LoadedBlock loaded, {
    bool forceHighlight = false,
  }) async {
    final boundaries = await widget.db.getChunkBoundaries(loaded.meta.id);

    if (loaded.meta.storageType == DbConstants.storageTypePlain) {
      final result = TxtHighlighter.buildSpans(
        plainText: loaded.content,
        cache: widget.knownWordsCache,
        unknownHighlightColor: _readerPrefs?.unknownHighlightColor,
        boundaries: boundaries,
        showChunkSeparators: _readerPrefs?.chunkSeparatorsEnabled ?? false,
      );
      return (
        entry: _BlockEntry(loaded: loaded, isMounted: true, boundaries: boundaries),
        highlightMs: result.elapsedMs,
      );
    }

    if (loaded.meta.storageType != DbConstants.storageTypeHtml) {
      return (
        entry: _BlockEntry(loaded: loaded, isMounted: true, boundaries: boundaries),
        highlightMs: 0,
      );
    }

    final result = await _highlightCache.getOrHighlight(
      loaded: loaded,
      cache: widget.knownWordsCache,
      force: forceHighlight,
    );

    if (!mounted) {
      return (
        entry: _BlockEntry(loaded: loaded, isMounted: true, boundaries: boundaries),
        highlightMs: 0,
      );
    }

    return (
      entry: _BlockEntry(
        loaded: loaded,
        highlightedHtml: result.html,
        isMounted: true,
        htmlLayoutReady: false,
        boundaries: boundaries,
      ),
      highlightMs: result.fromCache ? 0 : result.elapsedMs,
    );
  }

  Future<void> _initialize() async {
    final loadStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    try {
      await Future.wait([
        widget.knownWordsCache.load(widget.db),
        DictLoader.instance.load(),
      ]);

      final book = await widget.db.getBookById(widget.bookId);
      if (book == null) {
        setState(() {
          _initError = '书籍不存在';
          _initializing = false;
        });
        return;
      }

      final chapters = await widget.db.getChaptersByBook(widget.bookId);
      _chapters = chapters;
      for (final ch in chapters) {
        _chapterTitles[ch.id] = ch.title;
      }

      ContentBlock? startBlock;
      var startCharOffset = 0;

      final progress = await widget.db.getProgress(widget.bookId);
      if (progress != null) {
        final saved = await widget.db.getBlockById(progress.blockId);
        if (saved != null) {
          startBlock = saved;
          startCharOffset = progress.charOffset;
        }
      }

      startBlock ??= await widget.db.getBlockByGlobalIndex(widget.bookId, 0);
      if (startBlock == null) {
        setState(() {
          _initError = '未找到内容块';
          _initializing = false;
        });
        return;
      }

      final loaded = await _loader.load(startBlock);
      final prepared = await _prepareEntry(loaded);
      _title = book.title;
      _totalBlocks = book.totalBlocks;
      _updateChapterFromBlock(startBlock);
      if (startCharOffset > 0) {
        _pendingCharOffset = startCharOffset;
      }
      _entries.add(prepared.entry);
      if (kDebugMode) {
        _awaitingFirstBlockLayout = true;
        _startLayoutStopwatch(prepared.entry);
      }

      if (!mounted) return;
      setState(() => _initializing = false);
      if (loadStopwatch != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          loadStopwatch.stop();
          final loadMs = loadStopwatch.elapsedMilliseconds;
          PocMetrics.logBlockLoad(loadMs, 0);
          if (mounted) {
            setState(() {
              _firstBlockLoadMs = loadMs;
              _debugMetricHint = '首块 总${loadMs}ms';
            });
          }
        });
      }
      _prefetchAdjacent(startBlock.globalBlockIndex);
      _scheduleExtentCheck();
      _updateMountState();
      if (startCharOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestoreCharOffset());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  void _onScroll() {
    _checkShouldLoadMore();
    _updateMountState();
    _scheduleProgressSave();
  }

  void _checkShouldLoadMore() {
    if (!_scrollController.hasClients ||
        _isLoadingNext ||
        _reachedEnd) {
      return;
    }

    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final nearBottom =
        position.pixels >= position.maxScrollExtent - _loadThreshold;
    final contentTooShort = position.maxScrollExtent < viewport * 0.5;

    if (nearBottom) {
      _autoChainLoads = 0;
      _loadNextBlock();
      return;
    }

    if (contentTooShort && _autoChainLoads < _maxAutoChain) {
      _autoChainLoads++;
      _loadNextBlock();
    }
  }

  void _scheduleExtentCheck({int retries = 4}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkShouldLoadMore();
      _updateMountState();
      if (retries > 1) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _scheduleExtentCheck(retries: retries - 1);
        });
      }
    });
  }

  void _updateMountState() {
    if (!_scrollController.hasClients || _entries.isEmpty) return;

    final scrollTop = _scrollController.position.pixels;
    final viewportBottom =
        scrollTop + _scrollController.position.viewportDimension;
    final viewportCenter = scrollTop +
        _scrollController.position.viewportDimension / 2;

    final ranges = <int, ({double start, double end})>{};
    var y = 0.0;
    for (var i = 0; i < _entries.length; i++) {
      final h = _entries[i].layoutHeight;
      ranges[i] = (start: y, end: y + h);
      y += h;
    }

    final visible = <int>[];
    for (var i = 0; i < _entries.length; i++) {
      final range = ranges[i]!;
      if (range.end > scrollTop && range.start < viewportBottom) {
        visible.add(i);
      }
    }

    final candidates = <int>{};
    for (final i in visible) {
      for (
        var j = i - _mountMargin;
        j <= i + _mountMargin;
        j++
      ) {
        if (j >= 0 && j < _entries.length) {
          candidates.add(j);
        }
      }
    }

    if (candidates.isEmpty && _entries.isNotEmpty) {
      candidates.add(_entries.length - 1);
    }

    final sorted = candidates.toList()
      ..sort((a, b) {
        final centerA = (ranges[a]!.start + ranges[a]!.end) / 2;
        final centerB = (ranges[b]!.start + ranges[b]!.end) / 2;
        final da = (centerA - viewportCenter).abs();
        final db = (centerB - viewportCenter).abs();
        return da.compareTo(db);
      });

    final mounted = sorted.take(_maxMountedBlocks).toSet();
    mounted.add(_entries.length - 1);

    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      final wasMounted = _entries[i].isMounted;
      final shouldMount = mounted.contains(i);
      if (_entries[i].isMounted != shouldMount) {
        _entries[i] = _entries[i].copyWith(isMounted: shouldMount);
        changed = true;
        if (shouldMount && !wasMounted) {
          _startLayoutStopwatch(_entries[i]);
        }
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  void _onEntryHeightMeasured(int entryIndex, double height) {
    if (entryIndex < 0 || entryIndex >= _entries.length) return;
    final entry = _entries[entryIndex];
    if (entry.measuredHeight != null &&
        (entry.measuredHeight! - height).abs() < 1) {
      return;
    }
    final isHtml =
        entry.loaded?.meta.storageType == DbConstants.storageTypeHtml;
    _entries[entryIndex] = entry.copyWith(
      measuredHeight: height,
      htmlLayoutReady: isHtml ? true : entry.htmlLayoutReady,
    );
    _completeLayoutMetric(entryIndex, height);
    _tryRestoreCharOffset();
    _updateMountState();
  }

  String _layoutReportKey(_BlockEntry entry) {
    return '${entry.loaded!.meta.id}_${entry.highlightRevision}';
  }

  void _startLayoutStopwatch(_BlockEntry entry) {
    if (!kDebugMode) return;
    final blockId = entry.loaded?.meta.id;
    if (blockId == null) return;
    final key = _layoutReportKey(entry);
    if (_layoutReportedKeys.contains(key)) return;
    _layoutStopwatches[blockId]?.stop();
    _layoutStopwatches[blockId] = Stopwatch()..start();
  }

  void _clearLayoutReportForEntry(_BlockEntry entry) {
    if (!kDebugMode) return;
    final blockId = entry.loaded?.meta.id;
    if (blockId == null) return;
    _layoutReportedKeys.remove(_layoutReportKey(entry));
    _layoutStopwatches.remove(blockId)?.stop();
  }

  void _completeLayoutMetric(int entryIndex, double height) {
    if (!kDebugMode || height < _minLayoutHeight) return;
    final entry = _entries[entryIndex];
    final blockId = entry.loaded?.meta.id;
    if (blockId == null) return;
    final key = _layoutReportKey(entry);
    if (_layoutReportedKeys.contains(key)) return;

    final stopwatch = _layoutStopwatches.remove(blockId);
    if (stopwatch == null) return;
    stopwatch.stop();
    final layoutMs = stopwatch.elapsedMilliseconds;
    _layoutReportedKeys.add(key);

    final globalIndex = entry.loaded!.meta.globalBlockIndex;
    PocMetrics.logBlockLayout(layoutMs, globalIndex);

    if (!mounted) return;
    setState(() {
      if (_awaitingFirstBlockLayout &&
          globalIndex == 0 &&
          _firstBlockLoadMs != null) {
        _debugMetricHint =
            '首块 总${_firstBlockLoadMs}ms 排版${layoutMs}ms';
        _awaitingFirstBlockLayout = false;
      } else if (globalIndex == _lastSwitchToIndex &&
          _lastSwitchFromIndex != null) {
        _debugMetricHint =
            '切换 $_lastSwitchFromIndex→$_lastSwitchToIndex '
            '总${_lastSwitchTotalMs}ms '
            '高亮${_lastSwitchHighlightMs}ms '
            '排版${layoutMs}ms';
      }
    });
  }

  Future<void> _appendBlockMeta(
    ContentBlock meta, {
    required int switchFromIndex,
  }) async {
    final switchStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final ioStopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    final loaded = await _loader.load(meta);
    if (ioStopwatch != null) ioStopwatch.stop();

    final prepared = await _prepareEntry(loaded);
    if (!mounted) return;

    if (switchStopwatch != null) {
      switchStopwatch.stop();
      PocMetrics.logBlockSwitchDetailed(
        ioMs: ioStopwatch?.elapsedMilliseconds ?? 0,
        highlightMs: prepared.highlightMs,
        totalMs: switchStopwatch.elapsedMilliseconds,
        from: switchFromIndex,
        to: loaded.meta.globalBlockIndex,
      );
    }

    setState(() {
      _entries.add(prepared.entry);
      _isLoadingNext = false;
      _updateChapterFromBlock(loaded.meta);
      if (loaded.meta.globalBlockIndex >= _totalBlocks - 1) {
        _reachedEnd = true;
      }
      if (switchStopwatch != null) {
        _lastSwitchFromIndex = switchFromIndex;
        _lastSwitchToIndex = loaded.meta.globalBlockIndex;
        _lastSwitchTotalMs = switchStopwatch.elapsedMilliseconds;
        _lastSwitchHighlightMs = prepared.highlightMs;
        _debugMetricHint =
            '切换 $switchFromIndex→${loaded.meta.globalBlockIndex} '
            '总${switchStopwatch.elapsedMilliseconds}ms '
            '高亮${prepared.highlightMs}ms';
      }
    });

    if (kDebugMode) {
      _startLayoutStopwatch(prepared.entry);
    }

    _prefetchAdjacent(loaded.meta.globalBlockIndex);
    _scheduleExtentCheck();
    _updateMountState();
  }

  Future<void> _loadNextBlock() async {
    if (_isLoadingNext || _reachedEnd || _entries.isEmpty) {
      return;
    }

    final lastLoaded = _entries.last.loaded;
    if (lastLoaded == null) return;

    final lastIndex = lastLoaded.meta.globalBlockIndex;
    if (lastIndex >= _totalBlocks - 1) {
      if (!_reachedEnd && mounted) {
        setState(() => _reachedEnd = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已读至全书末尾')),
        );
      }
      return;
    }

    setState(() => _isLoadingNext = true);

    try {
      final nextMeta = await widget.db.getNextBlock(widget.bookId, lastIndex);
      if (nextMeta == null) {
        if (mounted) {
          setState(() {
            _reachedEnd = true;
            _isLoadingNext = false;
          });
        }
        return;
      }

      await _appendBlockMeta(nextMeta, switchFromIndex: lastIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entries.add(_BlockEntry(error: e.toString(), isMounted: true));
        _isLoadingNext = false;
      });
    }
  }

  Future<void> _onWordTap(String blockId, String normalized, bool isUnknown) async {
    final index = _entries.indexWhere((e) => e.loaded?.meta.id == blockId);
    if (index < 0) return;
    final loaded = _entries[index].loaded;
    if (loaded == null) return;

    final lookupSw = Stopwatch()..start();
    final lookupResult = DictLoader.instance.resolve(normalized);
    lookupSw.stop();
    PocMetrics.logLookup(lookupSw.elapsedMilliseconds, normalized);
    final wordContext = WordContext(
      bookId: loaded.meta.bookId,
      chapterId: loaded.meta.chapterId,
      blockId: loaded.meta.id,
      blockText: loaded.content,
    );

    if (!mounted) return;
    await LookupPanel.show(
      context: context,
      lookupResult: lookupResult,
      isUnknownFor: (word) =>
          !widget.knownWordsCache.isKnownNormalized(word),
      preferences: _readerPrefs,
      onAction: (action, activeWord) => _handleLookupAction(
        action: action,
        word: activeWord,
        entry: lookupResult.entry,
        context: wordContext,
        blockId: blockId,
        isUnknown: !widget.knownWordsCache.isKnownNormalized(activeWord),
      ),
    );
  }

  Future<void> _handleLookupAction({
    required LookupAction action,
    required String word,
    required DictEntry? entry,
    required WordContext context,
    required String blockId,
    required bool isUnknown,
  }) async {
    final definition = entry?.summaryForVocab();
    var needsRedraw = lookupActionNeedsRedraw(action, isUnknown);
    final dbSw = kDebugMode ? (Stopwatch()..start()) : null;

    switch (action) {
      case LookupAction.dontKnow:
        if (!isUnknown) {
          await _lookupService.addToVocab(
            rawWord: word,
            definition: definition,
            context: context,
          );
        }
        break;
      case LookupAction.know:
        if (isUnknown) {
          await _lookupService.markKnown(word);
        } else {
          await _lookupService.confirmKnown(word);
        }
        break;
    }

    if (dbSw != null) {
      dbSw.stop();
    }

    var redrawMs = 0;
    if (needsRedraw) {
      final redrawSw = kDebugMode ? (Stopwatch()..start()) : null;
      await _redrawBlock(blockId);
      if (redrawSw != null) {
        redrawSw.stop();
        redrawMs = redrawSw.elapsedMilliseconds;
      }
    }

    if (kDebugMode && dbSw != null) {
      final mountedCount =
          _entries.where((e) => e.isMounted && e.loaded != null).length;
      PocMetrics.logLookupAction(
        dbMs: dbSw.elapsedMilliseconds,
        redrawMs: redrawMs,
        blockId: blockId,
        mountedCount: mountedCount,
      );
    }
  }

  Future<void> _redrawBlock(String blockId) async {
    final index = _entries.indexWhere((e) => e.loaded?.meta.id == blockId);
    if (index < 0) return;

    final entry = _entries[index];
    final loaded = entry.loaded;
    if (loaded == null) return;

    if (!mounted) return;

    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final isHtml = loaded.meta.storageType == DbConstants.storageTypeHtml;

    if (stopwatch != null) {
      stopwatch.stop();
      if (isHtml) {
        PocMetrics.logHtmlRedrawDetailed(
          totalMs: stopwatch.elapsedMilliseconds,
          preprocessMs: 0,
          blockId: blockId,
          path: 'per-block',
        );
      } else {
        PocMetrics.logHtmlRedraw(stopwatch.elapsedMilliseconds, blockId);
      }
    }

    if (kDebugMode) {
      _clearLayoutReportForEntry(entry);
    }

    setState(() {
      _entries[index] = entry.copyWith(
        highlightRevision: entry.highlightRevision + 1,
        isMounted: true,
      );
      if (kDebugMode && stopwatch != null) {
        _debugMetricHint = isHtml
            ? '重绘 ${stopwatch.elapsedMilliseconds}ms (per-block)'
            : '重绘 ${stopwatch.elapsedMilliseconds}ms';
      }
    });
    if (kDebugMode) {
      _startLayoutStopwatch(_entries[index]);
    }
    _updateMountState();
  }

  void _prefetchHighlight(LoadedBlock loaded) {
    if (loaded.meta.storageType == DbConstants.storageTypeHtml) {
      _highlightCache.prefetch(
        loaded: loaded,
        cache: widget.knownWordsCache,
      );
      return;
    }
    if (loaded.meta.storageType == DbConstants.storageTypePlain) {
      TxtHighlighter.buildSpans(
        plainText: loaded.content,
        cache: widget.knownWordsCache,
        unknownHighlightColor: _readerPrefs?.unknownHighlightColor,
      );
    }
  }

  Future<void> _prefetchAdjacent(int centerIndex) async {
    _loader.setCurrentIndex(centerIndex);
    await _loader.prefetchAdjacentAsync(
      resolveMeta: (index) =>
          widget.db.getBlockByGlobalIndex(widget.bookId, index),
    );

    for (final offset in [1, -1]) {
      final index = centerIndex + offset;
      if (index < 0) continue;

      final cached = _loader.getCached(index);
      if (cached != null) {
        _prefetchHighlight(cached);
        continue;
      }

      final meta = await widget.db.getBlockByGlobalIndex(widget.bookId, index);
      if (meta == null) continue;

      _loader.load(meta).then((loaded) {
        if (!mounted) return;
        _prefetchHighlight(loaded);
      }).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _readerPrefs?.backgroundColor ?? Colors.white,
      drawer: ChapterDrawer(
        bookId: widget.bookId,
        db: widget.db,
        currentChapterId: _currentChapterId,
        onChapterSelected: _onChapterSelected,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleChrome,
              behavior: HitTestBehavior.translucent,
              child: _buildBody(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _chromeVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: ReaderTopBar(
                    bookTitle: _title ?? '阅读',
                    chapterTitle: _currentChapterTitle,
                    debugHint: _debugMetricHint,
                    preferences: _readerPrefs,
                  ),
                ),
              ),
            ),
          ),
          if (_chromeVisible &&
              _settingsPanelVisible &&
              _readerPrefs != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: kReaderBottomBarHeight,
              child: ReaderSettingsPanel(preferences: _readerPrefs!),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              offset: _chromeVisible ? Offset.zero : const Offset(0, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _chromeVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: ReaderBottomBar(
                    chapterTitle: _currentChapterTitle,
                    chapterIndex: _currentChapterIndex(),
                    chapterCount:
                        _chapters.isEmpty ? null : _chapters.length,
                    progressPercent: _readingProgressPercent(),
                    preferences: _readerPrefs,
                    settingsActive: _settingsPanelVisible,
                    onPrevChapter: () => _goToAdjacentChapter(-1),
                    onNextChapter: () => _goToAdjacentChapter(1),
                    onOpenToc: _openChapterDrawer,
                    onOpenSettings: _openReaderSettings,
                    onToggleNightMode: _toggleNightMode,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initError != null) {
      return Center(child: Text(_initError!));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _checkShouldLoadMore();
          _updateMountState();
          _scheduleProgressSave();
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          for (var i = 0; i < _entries.length; i++)
            SliverToBoxAdapter(
              key: ValueKey(
                '${_entries[i].loaded?.meta.id ?? _entries[i].error}_'
                '${_entries[i].isMounted}',
              ),
              child: _buildEntryWidget(i, _entries[i]),
            ),
          if (_isLoadingNext)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: LinearProgressIndicator()),
              ),
            ),
          if (_reachedEnd)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '— 全书完 —',
                    style: TextStyle(
                      color: _readerPrefs?.textColor.withValues(alpha: 0.45) ??
                          Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryWidget(int index, _BlockEntry entry) {
    if (!entry.isMounted) {
      return SizedBox(
        height: entry.layoutHeight,
        key: ValueKey('placeholder_${entry.loaded?.meta.id ?? entry.error}'),
      );
    }

    return BlockView(
      loaded: entry.loaded,
      knownWordsCache: widget.knownWordsCache,
      highlightedHtml: entry.highlightedHtml,
      highlightRevision: entry.highlightRevision,
      htmlLayoutReady: entry.htmlLayoutReady,
      loadError: entry.error,
      textStyle: _readerPrefs?.bodyTextStyle,
      unknownHighlightColor: _readerPrefs?.unknownHighlightColor,
      boundaries: entry.boundaries,
      showChunkSeparators: _readerPrefs?.chunkSeparatorsEnabled ?? false,
      onContentLayout: _scheduleExtentCheck,
      onHeightMeasured: (height) => _onEntryHeightMeasured(index, height),
      onWordTap: entry.loaded == null
          ? null
          : (normalized, isUnknown) => _onWordTap(
                entry.loaded!.meta.id,
                normalized,
                isUnknown,
              ),
    );
  }
}

class _BlockEntry {
  _BlockEntry({
    this.loaded,
    this.error,
    this.highlightedHtml,
    this.highlightRevision = 0,
    this.htmlLayoutReady = false,
    this.measuredHeight,
    this.isMounted = false,
    this.boundaries = const [],
  }) : assert(loaded != null || error != null);

  static const estimatedBlockHeight = 600.0;

  final LoadedBlock? loaded;
  final String? error;
  final String? highlightedHtml;
  final int highlightRevision;
  final bool htmlLayoutReady;
  final double? measuredHeight;
  final bool isMounted;
  final List<int> boundaries;

  double get layoutHeight => measuredHeight ?? estimatedBlockHeight;

  _BlockEntry copyWith({
    LoadedBlock? loaded,
    String? error,
    String? highlightedHtml,
    int? highlightRevision,
    bool? htmlLayoutReady,
    double? measuredHeight,
    bool? isMounted,
    List<int>? boundaries,
  }) {
    return _BlockEntry(
      loaded: loaded ?? this.loaded,
      error: error ?? this.error,
      highlightedHtml: highlightedHtml ?? this.highlightedHtml,
      highlightRevision: highlightRevision ?? this.highlightRevision,
      htmlLayoutReady: htmlLayoutReady ?? this.htmlLayoutReady,
      measuredHeight: measuredHeight ?? this.measuredHeight,
      isMounted: isMounted ?? this.isMounted,
      boundaries: boundaries ?? this.boundaries,
    );
  }
}
