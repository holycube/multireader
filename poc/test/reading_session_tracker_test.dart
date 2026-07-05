import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/services/reading_session_tracker.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> aggregateMinutes(String dateKey) async {
    final sum = db.readingStatsDaily.minutes.sum();
    return (db.selectOnly(db.readingStatsDaily)
          ..addColumns([sum])
          ..where(db.readingStatsDaily.date.equals(dateKey))
          ..where(db.readingStatsDaily.bookId.isNull()))
        .map((row) => row.read(sum) ?? 0)
        .getSingle();
  }

  test('accumulates seconds into minutes on flush', () async {
    var now = DateTime(2026, 6, 28, 10, 0, 0);
    final tracker = ReadingSessionTracker(db, clock: () => now);
    final dateKey = AppDatabase.statsDateKey(now);

    tracker.start('book-1');
    now = now.add(const Duration(seconds: 125));
    await tracker.flush();

    expect(await aggregateMinutes(dateKey), 2);
  });

  test('multiple flush calls accumulate rather than overwrite', () async {
    var now = DateTime(2026, 6, 28, 10, 0, 0);
    final tracker = ReadingSessionTracker(db, clock: () => now);
    final dateKey = AppDatabase.statsDateKey(now);

    tracker.start('book-1');
    now = now.add(const Duration(seconds: 60));
    await tracker.flush();
    now = now.add(const Duration(seconds: 60));
    await tracker.flush();

    expect(await aggregateMinutes(dateKey), 2);
  });

  test('cross-day session splits minutes by local date', () async {
    var now = DateTime(2026, 6, 27, 23, 58, 0);
    final tracker = ReadingSessionTracker(db, clock: () => now);
    final day1 = AppDatabase.statsDateKey(now);
    final day2 = AppDatabase.statsDateKey(DateTime(2026, 6, 28));

    tracker.start('book-1');
    now = DateTime(2026, 6, 28, 0, 2, 0);
    await tracker.flush();

    expect(await aggregateMinutes(day1), 2);
    expect(await aggregateMinutes(day2), 2);
  });

  test('paused interval is not counted', () async {
    var now = DateTime(2026, 6, 28, 10, 0, 0);
    final tracker = ReadingSessionTracker(db, clock: () => now);
    final dateKey = AppDatabase.statsDateKey(now);

    tracker.start('book-1');
    now = now.add(const Duration(seconds: 30));
    tracker.pause();
    now = now.add(const Duration(minutes: 5));
    tracker.resume();
    now = now.add(const Duration(seconds: 90));
    await tracker.flush();

    expect(await aggregateMinutes(dateKey), 2);
  });
}
