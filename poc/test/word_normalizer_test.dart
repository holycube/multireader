import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/vocab/word_normalizer.dart';

void main() {
  group('normalizeWord', () {
    test('Unicode lowercase', () {
      expect(normalizeWord('Bright'), 'bright');
      expect(normalizeWord('WORD'), 'word');
    });

    test('strips leading and trailing punctuation', () {
      expect(normalizeWord('"word,"'), 'word');
      expect(normalizeWord('(hello)'), 'hello');
      expect(normalizeWord('"test"'), 'test');
    });

    test('preserves contractions as whole words', () {
      expect(normalizeWord("don't"), "don't");
      expect(normalizeWord("Don't"), "don't");
      expect(normalizeWord("'don't'"), "don't");
    });

    test('does not stem', () {
      expect(normalizeWord('brightly'), 'brightly');
      expect(normalizeWord('running'), 'running');
    });

    test('edge cases', () {
      expect(normalizeWord(''), '');
      expect(normalizeWord('!!!'), '');
      expect(normalizeWord("'"), '');
      expect(normalizeWord('??'), '');
      expect(normalizeWord('Hello??'), 'hello');
    });
  });
}
