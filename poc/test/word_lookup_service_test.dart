import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/word_lookup_service.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';

void main() {
  late AppDatabase db;
  late KnownWordsCache cache;
  late WordLookupService service;

  const wordContext = WordContext(
    bookId: 'book-1',
    chapterId: 'ch-1',
    blockId: 'blk-1',
    blockText: 'The quick brown fox jumps over the lazy dog.',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cache = KnownWordsCache();
    await cache.load(db);
    service = WordLookupService(db: db, knownWordsCache: cache);
  });

  tearDown(() async {
    await db.close();
  });

  test('markKnown inserts known_words and updates cache', () async {
    expect(cache.isKnown('fox'), isFalse);

    await service.markKnown('fox');

    expect(cache.isKnown('fox'), isTrue);
    expect((await db.getAllKnownWords()), contains('fox'));
  });

  test('starWord inserts vocab starred=true', () async {
    await service.starWord(
      rawWord: 'fox',
      definition: 'n. 狐狸',
      context: wordContext,
    );

    expect(cache.isKnown('fox'), isFalse);
    final vocab = await db.getVocabByWord('fox');
    expect(vocab, hasLength(1));
    expect(vocab.first.starred, isTrue);
    expect(vocab.first.definition, 'n. 狐狸');
    expect(vocab.first.context, isNotNull);
  });

  test('addToVocab removes known and inserts vocab starred=false', () async {
    await service.markKnown('dog');
    expect(cache.isKnown('dog'), isTrue);

    await service.addToVocab(
      rawWord: 'dog',
      definition: 'n. 狗',
      context: wordContext,
    );

    expect(cache.isKnown('dog'), isFalse);
    expect((await db.getAllKnownWords()), isNot(contains('dog')));

    final vocab = await db.getVocabByWord('dog');
    expect(vocab, hasLength(1));
    expect(vocab.first.starred, isFalse);
  });

  test('confirmKnown is idempotent', () async {
    await service.confirmKnown('lazy');
    await service.confirmKnown('lazy');

    expect(cache.isKnown('lazy'), isTrue);
    expect((await db.getAllKnownWords()).where((w) => w == 'lazy'), hasLength(1));
  });

  test('extractContextSnippet finds word with boundaries', () {
    final text = ('word ' * 20) + 'target ' + ('word ' * 20);
    final snippet = WordLookupService.extractContextSnippet(text, 'target');
    expect(snippet, isNotNull);
    expect(snippet!, contains('target'));
    expect(snippet, contains('…'));
  });
}
