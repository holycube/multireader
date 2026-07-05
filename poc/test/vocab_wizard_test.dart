import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/screens/vocab_wizard/vocab_wizard_screen.dart';
import 'package:multi_novel_reader/screens/vocab_wizard/word_list_parser.dart';

void main() {
  group('parseWordList', () {
    test('parses plain txt one word per line', () {
      final words = parseWordList('Hello\nworld\n  test  \n');
      expect(words, ['hello', 'test', 'world']);
    });

    test('skips comments and blank lines', () {
      final words = parseWordList('# header\n\napple\n# comment\nbanana\n');
      expect(words, ['apple', 'banana']);
    });

    test('parses csv with word column header', () {
      final raw = 'word,definition\nApple,fruit\nBanana,yellow\n';
      final words = parseWordList(raw);
      expect(words, ['apple', 'banana']);
    });

    test('parses csv first column without header', () {
      final raw = 'cat,feline\ndog,canine\n';
      final words = parseWordList(raw);
      expect(words, ['cat', 'dog']);
    });

    test('normalizes edge punctuation', () {
      final words = parseWordList('"Hello,"\n(world)\n');
      expect(words, ['hello', 'world']);
    });
  });

  testWidgets('词库向导首屏显示欢迎文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VocabWizardScreen()),
    );

    expect(find.text('设置你的词汇量'), findsOneWidget);
    expect(find.text('开始设置'), findsOneWidget);
  });
}
