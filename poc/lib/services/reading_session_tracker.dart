import '../database/database.dart';

/// 阅读页前台时长累计：秒级累计，flush 时写入 [AppDatabase.incrementDailyMinutes]。
class ReadingSessionTracker {
  ReadingSessionTracker(
    this._db, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  String? _bookId;
  bool _active = false;
  bool _paused = false;
  DateTime? _segmentStart;
  final Map<String, int> _pendingSecondsByDate = {};

  void start(String bookId) {
    _bookId = bookId;
    _active = true;
    _paused = false;
    _segmentStart = _clock();
    _pendingSecondsByDate.clear();
  }

  void pause() {
    if (!_active || _paused) return;
    _accumulateCurrentSegment();
    _paused = true;
  }

  void resume() {
    if (!_active || !_paused) return;
    _paused = false;
    _segmentStart = _clock();
  }

  Future<void> flush() async {
    if (!_active) return;
    if (!_paused) {
      _accumulateCurrentSegment();
      _segmentStart = _clock();
    }

    final bookId = _bookId;
    for (final entry in _pendingSecondsByDate.entries.toList()) {
      final totalSeconds = entry.value;
      final minutes = totalSeconds ~/ 60;
      final remainder = totalSeconds % 60;
      if (minutes > 0) {
        await _db.incrementDailyMinutes(
          date: entry.key,
          deltaMinutes: minutes,
          bookId: bookId,
        );
      }
      if (remainder > 0) {
        _pendingSecondsByDate[entry.key] = remainder;
      } else {
        _pendingSecondsByDate.remove(entry.key);
      }
    }
  }

  void _accumulateCurrentSegment() {
    final start = _segmentStart;
    if (start == null) return;
    _addSecondsRange(start, _clock());
    _segmentStart = null;
  }

  void _addSecondsRange(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return;
    var cursor = start;
    while (cursor.isBefore(end)) {
      final dayEnd = DateTime(cursor.year, cursor.month, cursor.day)
          .add(const Duration(days: 1));
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final seconds = segmentEnd.difference(cursor).inSeconds;
      if (seconds > 0) {
        final key = AppDatabase.statsDateKey(cursor);
        _pendingSecondsByDate[key] =
            (_pendingSecondsByDate[key] ?? 0) + seconds;
      }
      cursor = segmentEnd;
    }
  }
}
