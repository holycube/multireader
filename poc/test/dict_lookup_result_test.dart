import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/vocab/dict_entry.dart';
import 'package:multi_novel_reader/vocab/dict_loader.dart';
import 'package:multi_novel_reader/vocab/dict_lookup_result.dart';

final _ringEntry = DictEntry(
  word: 'ring',
  phonetic: '/rɪŋ/',
  senses: [
    DictSense(
      pos: 'n.',
      meanings: DictMeaning.listFromStrings(['戒指', '铃声']),
    ),
    DictSense(
      pos: 'v.',
      meanings: DictMeaning.listFromStrings(['响', '打电话']),
    ),
  ],
  examTags: ['四级'],
  exchange: 'i:ringing/p:ringed/d:ringed/s:rings/3:rings',
);

final _beEntry = DictEntry(
  word: 'be',
  phonetic: '/biː/',
  senses: [
    DictSense(
      pos: 'vi.',
      meanings: DictMeaning.listFromStrings(['是', '存在']),
    ),
    DictSense(
      pos: 'vt.',
      meanings: DictMeaning.listFromStrings(['做']),
    ),
  ],
  exchange: 'p:was/d:been/i:being/s:are/3:is',
);

void main() {
  setUp(() {
    DictLoader.instance.resetForTesting();
    DictLoader.instance.loadMapForTesting(
      {
        'ring': _ringEntry,
        'be': _beEntry,
      },
      aliases: {
        'ringing': const DictAliasMeta(
          lemma: 'ring',
          exchangeKey: 'i',
        ),
        'was': const DictAliasMeta(
          lemma: 'be',
          exchangeKey: 'p',
          phonetic: '/wəz/',
        ),
      },
    );
  });

  test('resolve returns direct hit without alias tab', () {
    final result = DictLoader.instance.resolve('ring');
    expect(result.tappedWord, 'ring');
    expect(result.entry?.word, 'ring');
    expect(result.alias, isNull);
    expect(result.hasVariantTabs, isFalse);
  });

  test('resolve falls back through alias to lemma entry', () {
    final result = DictLoader.instance.resolve('ringing');
    expect(result.tappedWord, 'ringing');
    expect(result.entry?.word, 'ring');
    expect(result.alias?.lemma, 'ring');
    expect(result.alias?.exchangeKey, 'i');
    expect(result.hasVariantTabs, isTrue);
  });

  test('resolve preserves optional alias phonetic', () {
    final result = DictLoader.instance.resolve('was');
    expect(result.alias?.phonetic, '/wəz/');
    expect(result.entry?.word, 'be');
    expect(result.hasVariantTabs, isTrue);
  });

  test('resolve returns miss without entry', () {
    final result = DictLoader.instance.resolve('not-a-real-word-xyz');
    expect(result.entry, isNull);
    expect(result.alias, isNull);
    expect(result.hasVariantTabs, isFalse);
  });

  test('lookup stays exact-match only', () {
    expect(DictLoader.instance.lookup('ringing'), isNull);
    expect(DictLoader.instance.lookup('ring'), isNotNull);
  });
}
