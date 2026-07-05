#!/usr/bin/env python3
"""Rewrite Sprint 12 test files with proper UTF-8 Chinese strings."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"

FILES = {
    "main_shell_test.dart": r'''import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/main_shell.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('主导航显示四 Tab 标签', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.length, 4);
    expect(
      destinations.map((d) => d.label).toList(),
      ['书架', '统计', '词库', '个人'],
    );
    expect(find.text('资源'), findsNothing);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
''',
    "profile_screen_test.dart": r'''import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/profile/learning_settings_screen.dart';
import 'package:multi_novel_reader/screens/profile/more_settings_screen.dart';
import 'package:multi_novel_reader/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('个人页展示头部与设置入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('阅读者'), findsOneWidget);
    expect(find.text('点击查看阅读统计'), findsOneWidget);
    expect(find.textContaining('资源'), findsNothing);
    expect(find.textContaining('广告'), findsNothing);
    expect(find.text('主页外观'), findsOneWidget);
    expect(find.text('阅读外观'), findsOneWidget);
    expect(find.text('学习设置'), findsOneWidget);
    expect(find.text('更多设置'), findsOneWidget);
    expect(find.text('生词本'), findsOneWidget);
    expect(find.text('Anki'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
    expect(find.text('解锁'), findsNothing);
    expect(find.text('广告'), findsNothing);
    expect(find.text('额度'), findsNothing);
  });

  testWidgets('更多设置页展示合规与匿名 ID', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: MoreSettingsScreen()),
      ),
    );
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('更多设置'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '找书与导入'), findsOneWidget);
    expect(find.text('清除缓存'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('服务条款'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('服务条款'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('隐私协议'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('隐私协议'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('ID:'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('ID:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('学习设置页展示词库管理入口', (tester) async {
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
  });
}
''',
    "stats_screen_test.dart": r'''import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/stats_screen.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('统计页展示阅读数据与近7日图表', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.now().millisecondsSinceEpoch;
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    await db.insertBook(
      id: 'book-1',
      title: 'Test Novel',
      author: 'Author',
      sourceFormat: 'txt',
      sourcePath: '/tmp/test.txt',
      importedAt: now,
    );
    await db.markBookComplete(
      id: 'book-1',
      totalChapters: 1,
      totalBlocks: 10,
    );
    await db.upsertProgress(
      ReadingProgressCompanion.insert(
        bookId: 'book-1',
        chapterId: 'ch-1',
        blockGlobalIndex: 0,
        charOffset: 0,
        updatedAt: now,
      ),
    );
    await db.insertKnownWord(word: 'alpha', addedAt: now);
    await db.insertKnownWord(word: 'beta', addedAt: now);
    await db.upsertVocabEntry(
      word: 'gamma',
      definition: 'test',
      starred: false,
    );
    await db.incrementDailyMinutes(
      date: todayKey,
      deltaMinutes: 25,
    );

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('正在阅读'), findsOneWidget);
    expect(find.text('我的数据'), findsOneWidget);
    expect(find.text('今日新词'), findsOneWidget);
    expect(find.text('近 7 日阅读时长（分钟）'), findsOneWidget);
    expect(find.text('连续阅读'), findsOneWidget);
    expect(find.text('25m'), findsNWidgets(2));
    expect(find.textContaining('7'), findsWidgets);
    expect(find.text('累计时长'), findsOneWidget);
    expect(find.text('Test Novel'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
''',
    "resources_screen_test.dart": r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/screens/resources_screen.dart';

void main() {
  testWidgets('资源页展示公版书渠道与导入步骤', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResourcesScreen()),
    );

    expect(find.text('资源'), findsOneWidget);
    expect(find.text('公版书渠道'), findsOneWidget);
    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('Standard Ebooks'), findsOneWidget);
    expect(find.text('如何从浏览器下载并导入'), findsOneWidget);
    expect(find.text('下载 EPUB'), findsOneWidget);
    expect(find.text('导入到本 App'), findsOneWidget);
    expect(find.text('开始阅读'), findsOneWidget);
  });
}
''',
    "vocab_management_test.dart": r'''import 'package:drift/native.dart';
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
''',
}

if __name__ == "__main__":
    for name, content in FILES.items():
        path = ROOT / name
        path.write_text(content, encoding="utf-8")
        print("wrote", path)
