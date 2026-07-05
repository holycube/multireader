import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';

void main() {
  group('DictMeaning', () {
    test('listFromStrings marks first as primary', () {
      final meanings = DictMeaning.listFromStrings(['a', 'b', 'c']);
      expect(meanings.length, 3);
      expect(meanings[0].text, 'a');
      expect(meanings[0].primary, isTrue);
      expect(meanings[1].primary, isFalse);
      expect(meanings[2].primary, isFalse);
    });

    test('fromJson reads object format', () {
      final m = DictMeaning.fromJson({'text': '走', 'primary': true});
      expect(m.text, '走');
      expect(m.primary, isTrue);
    });

    test('fromJson coerces string', () {
      final m = DictMeaning.fromJson('走');
      expect(m.text, '走');
      expect(m.primary, isFalse);
    });
  });

  group('DictSense.fromJson', () {
    test('accepts legacy string[] meanings', () {
      final sense = DictSense.fromJson({
        'pos': 'n.',
        'meanings': ['信贷', '赞扬'],
      });
      expect(sense.meaningTexts, ['信贷', '赞扬']);
      expect(sense.meanings[0].primary, isTrue);
      expect(sense.meanings[1].primary, isFalse);
    });

    test('accepts object meanings', () {
      final sense = DictSense.fromJson({
        'pos': 'v.',
        'meanings': [
          {'text': '走', 'primary': true},
          {'text': '散步'},
        ],
      });
      expect(sense.meaningTexts, ['走', '散步']);
      expect(sense.meanings[0].primary, isTrue);
      expect(sense.meanings[1].primary, isFalse);
    });
  });

  group('DictEntry.summaryForVocab', () {
    test('uses meaning texts only', () {
      final entry = DictEntry(
        word: 'credit',
        senses: [
          DictSense(
            pos: 'n.',
            meanings: DictMeaning.listFromStrings(['信贷', '赞扬']),
          ),
        ],
      );
      expect(entry.summaryForVocab(), 'n. 信贷；赞扬');
    });
  });
}
