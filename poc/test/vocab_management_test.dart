import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/profile/learning_settings_screen.dart';
import 'package:multi_novel_reader/screens/vocab_tab.dart';
import 'package:multi_novel_reader/screens/vocab_wizard/known_words_writer.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('词库 Tab 展示已知词数与管理入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertKnownWord(
      word: 'hello',
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insertKnownWord(
      word: 'world',
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: VocabTab()),
      ),
    );
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('词库'), findsOneWidget);
    expect(find.text('2 个'), findsOneWidget);
    expect(find.text('已知词数'), findsOneWidget);
    expect(find.text('生词本'), findsOneWidget);
    expect(find.text('重新选择词汇量'), findsOneWidget);
    expect(find.text('导入词表'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('学习设置页展示词库重置入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: LearningSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('学习设置'), findsOneWidget);
    expect(find.text('词库'), findsOneWidget);
    expect(find.text('管理词库'), findsOneWidget);
    expect(find.text('词形查词说明'), findsOneWidget);
  });

  test('clearKnownWords 会 bump revision', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    addTearDown(db.close);

    await db.insertKnownWord(
      word: 'alpha',
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await cache.load(db);
    expect(cache.revision, 0);
    expect(cache.isKnownNormalized('alpha'), isTrue);

    await clearKnownWords(db: db, cache: cache);
    expect(cache.revision, greaterThan(0));
    await cache.load(db);
    expect(cache.isKnownNormalized('alpha'), isFalse);
  });

  test('batchInsertKnownWords 会 bump revision', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cache = KnownWordsCache();
    addTearDown(db.close);

    await cache.load(db);
    final before = cache.revision;

    await batchInsertKnownWords(
      db: db,
      cache: cache,
      words: ['one', 'two'],
      source: 'test',
    );
    await cache.load(db);
    expect(cache.revision, greaterThan(before));
    expect(cache.isKnownNormalized('one'), isTrue);
    expect(cache.isKnownNormalized('two'), isTrue);
  });
}
