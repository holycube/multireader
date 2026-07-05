import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/reader/lookup_card.dart';
import 'package:multi_novel_reader/reader/lookup_panel.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';

const _creditEntry = DictEntry(
  word: 'credit',
  phonetic: '/ˈkredɪt/',
  senses: [
    DictSense(
      pos: 'n.',
      meanings: [
        DictMeaning(text: '信贷', primary: true),
        DictMeaning(text: '赞扬'),
        DictMeaning(text: '信誉'),
      ],
    ),
    DictSense(
      pos: 'vt.',
      meanings: [
        DictMeaning(text: '把钱存入账户', primary: true),
        DictMeaning(text: '把…归功于'),
      ],
    ),
  ],
  examTags: ['考研', '四级'],
);

void main() {
  LookupCard buildCard({
    bool isUnknown = true,
    DictEntry? entry = _creditEntry,
    Future<void> Function(LookupAction action)? onAction,
  }) {
    return LookupCard(
      word: 'credit',
      entry: entry,
      isUnknown: isUnknown,
      onAction: onAction ?? (_) async {},
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    bool isUnknown = true,
    DictEntry? entry = _creditEntry,
    bool inDialog = false,
    Future<void> Function(LookupAction action)? onAction,
  }) async {
    final card = buildCard(
      isUnknown: isUnknown,
      entry: entry,
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

  testWidgets('shows exam tags inline with word, phonetic pill, and senses',
      (tester) async {
    await pumpCard(tester);

    expect(find.text('credit'), findsOneWidget);
    expect(find.text('考研'), findsOneWidget);
    expect(find.text('四级'), findsOneWidget);
    expect(find.text('美'), findsOneWidget);
    expect(find.textContaining('/ˈkredɪt/'), findsOneWidget);
    expect(find.textContaining('信贷'), findsOneWidget);
    expect(find.textContaining('把钱存入账户'), findsOneWidget);
    expect(find.text('查看详细释义 >'), findsOneWidget);
    expect(find.text('[美]'), findsNothing);
  });

  testWidgets('primary meanings render with semibold weight', (tester) async {
    await pumpCard(
      tester,
      entry: const DictEntry(
        word: 'bold',
        senses: [
          DictSense(
            pos: 'n.',
            meanings: [
              DictMeaning(text: '主释义', primary: true),
              DictMeaning(text: '次释义'),
            ],
          ),
        ],
      ),
    );

    TextSpan? findSpan(TextSpan span, String text) {
      if (span.text == text) return span;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) {
          final found = findSpan(child, text);
          if (found != null) return found;
        }
      }
      return null;
    }

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    TextSpan? primarySpan;
    TextSpan? secondarySpan;
    for (final rich in richTexts) {
      final root = rich.text;
      if (root is! TextSpan) continue;
      primarySpan ??= findSpan(root, '主释义');
      secondarySpan ??= findSpan(root, '次释义');
    }

    expect(primarySpan, isNotNull);
    expect(secondarySpan, isNotNull);
    expect(primarySpan!.style?.fontWeight, FontWeight.w600);
    expect(secondarySpan!.style?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('shows empty circle for unknown word', (tester) async {
    await pumpCard(tester, isUnknown: true);

    expect(find.byKey(const Key('known-toggle')), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('shows filled check for known word', (tester) async {
    await pumpCard(tester, isUnknown: false);

    expect(find.byKey(const Key('known-toggle')), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('toggle tap on unknown word closes dialog and fires know action',
      (tester) async {
    LookupAction? captured;
    await pumpCard(
      tester,
      isUnknown: true,
      inDialog: true,
      onAction: (action) async {
        captured = action;
      },
    );

    await tester.tap(find.byKey(const Key('known-toggle')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured, LookupAction.know);
    expect(find.text('credit'), findsNothing);
  });

  testWidgets('toggle tap on known word fires dontKnow action', (tester) async {
    LookupAction? captured;
    await pumpCard(
      tester,
      isUnknown: false,
      inDialog: true,
      onAction: (action) async {
        captured = action;
      },
    );

    await tester.tap(find.byKey(const Key('known-toggle')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured, LookupAction.dontKnow);
  });

  testWidgets('shows missing-definition placeholder', (tester) async {
    await pumpCard(tester, entry: null);

    expect(find.text('词典未收录该词'), findsOneWidget);
    expect(find.text('查看详细释义 >'), findsNothing);
  });
}
