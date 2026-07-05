#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"
(ROOT / "lookup_variant_card_test.dart").write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/reader/lookup_panel.dart';
import 'package:multi_novel_reader/reader/lookup_variant_card.dart';
import 'package:multi_novel_reader/reader/word_detail_screen.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_lookup_result.dart';

const _beEntry = DictEntry(
  word: 'be',
  phonetic: '/bi:/',
  senses: const [
    DictSense(pos: 'vi.', meanings: ['是', '存在']),
    DictSense(pos: 'vt.', meanings: ['做', '成为']),
    DictSense(pos: 'aux.', meanings: ['助动词用法']),
    DictSense(pos: 'n.', meanings: ['字母 B']),
  ],
  examTags: const ['考研', '六级'],
);

const _wasLookupResult = DictLookupResult(
  tappedWord: 'was',
  entry: _beEntry,
  alias: DictAliasMeta(
    lemma: 'be',
    exchangeKey: 'p',
    phonetic: '/waz/',
  ),
);

void main() {
  LookupVariantCard buildCard({
    DictLookupResult lookupResult = _wasLookupResult,
    bool Function(String word)? isUnknownFor,
    Future<void> Function(LookupAction action, String activeWord)? onAction,
  }) {
    return LookupVariantCard(
      lookupResult: lookupResult,
      isUnknownFor: isUnknownFor ?? (_) => true,
      onAction: onAction ?? (_, __) async {},
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    DictLookupResult lookupResult = _wasLookupResult,
    bool Function(String word)? isUnknownFor,
    bool inDialog = false,
    Future<void> Function(LookupAction action, String activeWord)? onAction,
  }) async {
    final card = buildCard(
      lookupResult: lookupResult,
      isUnknownFor: isUnknownFor,
      onAction: onAction,
    );

    if (inDialog) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showGeneralDialog<void>(
                    context: context,
                    pageBuilder: (_, __, ___) => card,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    } else {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: card)),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to surface tab with grammar note and variant phonetic',
      (tester) async {
    await pumpCard(tester);

    expect(find.byKey(const Key('variant-tab-surface')), findsOneWidget);
    expect(find.byKey(const Key('variant-tab-lemma')), findsOneWidget);
    expect(find.text('was'), findsNWidgets(2));
    expect(find.text('be'), findsOneWidget);
    expect(find.textContaining('/waz/'), findsOneWidget);
    expect(find.textContaining('（be的过去式）'), findsOneWidget);
    expect(find.text('考研'), findsNothing);
    expect(find.text('六级'), findsNothing);
  });

  testWidgets('lemma tab shows multiple senses and exam tags', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byKey(const Key('variant-tab-lemma')));
    await tester.pumpAndSettle();

    expect(find.text('be'), findsNWidgets(2));
    expect(find.text('was'), findsOneWidget);
    expect(find.textContaining('/bi:/'), findsOneWidget);
    expect(find.textContaining('（be的过去式）'), findsNothing);
    expect(find.text('考研'), findsOneWidget);
    expect(find.text('六级'), findsOneWidget);
    expect(find.textContaining('存在'), findsOneWidget);
    expect(find.textContaining('成为'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
  });

  testWidgets('known toggle uses active tab word in callback', (tester) async {
    LookupAction? capturedAction;
    String? capturedWord;

    await pumpCard(
      tester,
      inDialog: true,
      onAction: (action, word) async {
        capturedAction = action;
        capturedWord = word;
      },
    );

    await tester.tap(find.byKey(const Key('known-toggle')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedAction, LookupAction.know);
    expect(capturedWord, 'was');
    expect(find.text('was'), findsNothing);
  });

  testWidgets('lemma tab know action passes lemma word', (tester) async {
    LookupAction? capturedAction;
    String? capturedWord;

    await pumpCard(
      tester,
      inDialog: true,
      onAction: (action, word) async {
        capturedAction = action;
        capturedWord = word;
      },
    );

    await tester.tap(find.byKey(const Key('variant-tab-lemma')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('known-toggle')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedAction, LookupAction.know);
    expect(capturedWord, 'be');
  });

  testWidgets('isUnknownFor reflects per-tab known state', (tester) async {
    await pumpCard(
      tester,
      isUnknownFor: (word) => word == 'was',
    );

    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.byKey(const Key('variant-tab-lemma')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('detail link opens WordDetailScreen with active tab word',
      (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('查看详细释义 >'));
    await tester.pumpAndSettle();

    expect(find.byType(WordDetailScreen), findsOneWidget);
    expect(find.text('was'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('variant-tab-lemma')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详细释义 >'));
    await tester.pumpAndSettle();

    expect(find.byType(WordDetailScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WordDetailScreen),
        matching: find.text('be'),
      ),
      findsWidgets,
    );
  });

  testWidgets('tab chip uses theme primary color', (tester) async {
    const testPrimary = Color(0xFF336699);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: testPrimary),
        ),
        home: Scaffold(body: Center(child: buildCard())),
      ),
    );
    await tester.pumpAndSettle();

    final surfaceChip = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('variant-tab-surface')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = surfaceChip.decoration! as BoxDecoration;
    expect(decoration.color, testPrimary.withValues(alpha: 0.12));
  });
}
''', encoding='utf-8')
print('wrote lookup_variant_card_test.dart')
