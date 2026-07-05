import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/word_detail_screen.dart';
import 'package:multi_novel_reader/screens/vocab/vocab_notebook_screen.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_loader.dart';

import 'test_helpers.dart';

void main() {
  setUp(() {
    DictLoader.instance.resetForTesting();
    DictLoader.instance.loadMapForTesting({
      'hello': DictEntry(
        word: 'hello',
        senses: [
          DictSense(
            pos: 'int.',
            meanings: DictMeaning.listFromStrings(['你好']),
          ),
        ],
      ),
      'ephemeral': DictEntry(
        word: 'ephemeral',
        senses: [
          DictSense(
            pos: 'adj.',
            meanings: DictMeaning.listFromStrings(['短暂的']),
          ),
        ],
      ),
    });
  });

  Future<void> pumpNotebook(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: VocabNotebookScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> disposeNotebook(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('空生词本显示引导文案', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpNotebook(tester, db);

    expect(find.text('生词本'), findsOneWidget);
    expect(
      find.textContaining('阅读时点击「不认识」'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await disposeNotebook(tester);
  });

  testWidgets('列表展示生词与词典摘要', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertVocabEntry(
      word: 'hello',
      definition: 'int. 你好',
      context: 'She said hello to everyone.',
      starred: false,
    );

    await pumpNotebook(tester, db);

    expect(find.text('hello'), findsOneWidget);
    expect(find.textContaining('你好'), findsOneWidget);
    expect(find.textContaining('said hello'), findsOneWidget);

    await disposeNotebook(tester);
  });

  testWidgets('点击词条进入详情页', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertVocabEntry(
      word: 'ephemeral',
      definition: 'adj. 短暂的',
      starred: true,
    );

    await pumpNotebook(tester, db);

    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    expect(find.byType(WordDetailScreen), findsOneWidget);
    expect(find.textContaining('短暂'), findsWidgets);

    await disposeNotebook(tester);
  });
}
