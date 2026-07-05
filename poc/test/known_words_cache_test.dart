import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache cache;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
  });

  tearDown(() async {
    await db.close();
  });

  test('load populates Set and isKnown works', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertKnownWord(word: 'bright', addedAt: now);
    await db.insertKnownWord(word: 'hello', addedAt: now);

    await cache.load(db);

    expect(cache.isLoaded, isTrue);
    expect(cache.words, containsAll(['bright', 'hello']));
    expect(cache.isKnown('Bright'), isTrue);
    expect(cache.isKnown('unknown'), isFalse);
    expect(cache.isKnownNormalized('bright'), isTrue);
  });

  test('addKnown syncs DB and memory', () async {
    await cache.load(db);
    await cache.addKnown(db, 'World');

    expect(cache.isKnown('world'), isTrue);
    expect(await db.getAllKnownWords(), contains('world'));
  });

  test('removeKnown syncs DB and memory', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertKnownWord(word: 'temp', addedAt: now);
    await cache.load(db);

    await cache.removeKnown(db, 'temp');

    expect(cache.isKnown('temp'), isFalse);
    expect(await db.getAllKnownWords(), isNot(contains('temp')));
  });

  test('isKnown returns false before load', () {
    expect(cache.isKnown('anything'), isFalse);
  });

  test('load is idempotent', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertKnownWord(word: 'once', addedAt: now);

    await Future.wait([cache.load(db), cache.load(db)]);

    expect(cache.words, {'once'});
  });

  test('10k words load under 500ms', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch((batch) {
      for (var i = 0; i < 10000; i++) {
        batch.insert(
          db.knownWords,
          KnownWordsCompanion.insert(
            word: 'word$i',
            addedAt: now,
          ),
        );
      }
    });

    cache.resetForTesting();
    final stopwatch = Stopwatch()..start();
    await cache.load(db);
    stopwatch.stop();

    expect(cache.words.length, 10000);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('40k words load under 500ms', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch((batch) {
      for (var i = 0; i < 40000; i++) {
        batch.insert(
          db.knownWords,
          KnownWordsCompanion.insert(
            word: 'word${i.toString().padLeft(5, '0')}',
            addedAt: now,
          ),
        );
      }
    });

    cache.resetForTesting();
    final stopwatch = Stopwatch()..start();
    await cache.load(db);
    stopwatch.stop();

    expect(cache.words.length, 40000);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
    expect(cache.lastLoadDbMs, isNotNull);
    expect(cache.lastLoadSetMs, isNotNull);
  });
}
