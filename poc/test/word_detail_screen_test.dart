import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/reader/lookup_panel.dart';
import 'package:multi_novel_reader/reader/word_detail_screen.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';

final _detailEntry = DictEntry(
  word: 'walk',
  phonetic: '/wɔːk/',
  senses: [
    DictSense(
      pos: 'n.',
      meanings: DictMeaning.listFromStrings(['步行', '小路']),
    ),
    DictSense(
      pos: 'v.',
      meanings: DictMeaning.listFromStrings(['走', '散步']),
    ),
  ],
  examTags: ['四级'],
  englishDefinition: 'n. a journey on foot\nv. move at a regular pace',
  exchange: 'p:walked/d:walked/i:walking/3:walks/s:walks',
  collins: 5,
  oxford3000: true,
);

const _defaultEntrySentinel = Object();

Future<void> pumpDetail(
  WidgetTester tester, {
  Object? entry = _defaultEntrySentinel,
  bool isUnknown = true,
}) async {
  final DictEntry? resolvedEntry =
      identical(entry, _defaultEntrySentinel) ? _detailEntry : entry as DictEntry?;
  await tester.pumpWidget(
    MaterialApp(
      home: WordDetailScreen(
        word: 'walk',
        entry: resolvedEntry,
        isUnknown: isUnknown,
        onAction: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows full senses, badges, and exchange', (tester) async {
    await pumpDetail(tester);

    expect(find.text('walk'), findsWidgets);
    expect(find.text('四级'), findsOneWidget);
    expect(find.textContaining('步行'), findsOneWidget);
    expect(find.textContaining('散步'), findsOneWidget);
    expect(find.textContaining('Collins 5'), findsOneWidget);
    expect(find.textContaining('Oxford 3000'), findsOneWidget);
    expect(find.textContaining('walked'), findsWidgets);
    expect(find.textContaining('journey on foot'), findsOneWidget);
  });

  testWidgets('toggles english definition section', (tester) async {
    await pumpDetail(tester);

    expect(find.textContaining('journey on foot'), findsOneWidget);

    await tester.tap(find.text('英文释义'));
    await tester.pumpAndSettle();

    expect(find.textContaining('journey on foot'), findsNothing);

    await tester.tap(find.text('英文释义'));
    await tester.pumpAndSettle();

    expect(find.textContaining('journey on foot'), findsOneWidget);
  });

  testWidgets('shows placeholder when entry is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WordDetailScreen(
          word: 'walk',
          entry: null,
          isUnknown: true,
          onAction: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无详细释义'), findsOneWidget);
    expect(find.text('不认识'), findsOneWidget);
    expect(find.text('已会'), findsOneWidget);
  });

  testWidgets('已会按钮 fires know action', (tester) async {
    LookupAction? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: WordDetailScreen(
          word: 'walk',
          entry: _detailEntry,
          isUnknown: true,
          onAction: (action) async {
            captured = action;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('已会'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(captured, LookupAction.know);
  });
}
