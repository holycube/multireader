import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/reader/reading_offset.dart';

void main() {
  test('charOffsetFromScroll estimates proportionally', () {
    expect(
      charOffsetFromScroll(
        scrollTop: 150,
        blockTop: 100,
        blockHeight: 200,
        charCount: 1000,
      ),
      250,
    );
  });

  test('scrollOffsetForChar inverts char offset', () {
    expect(
      scrollOffsetForChar(
        charOffset: 250,
        charCount: 1000,
        blockHeight: 200,
      ),
      50,
    );
  });

  test('resolveReadingPosition picks block at scroll top', () {
    final block = ContentBlock(
      id: 'b1',
      bookId: 'book',
      chapterId: 'ch1',
      blockOrderInChapter: 0,
      globalBlockIndex: 2,
      storageType: 'plain',
      contentPath: '/tmp',
      charCount: 500,
      parseStatus: 'done',
      parsedAt: null,
    );

    final result = resolveReadingPosition(
      scrollTop: 750,
      blocks: [
        (block: null, height: 100),
        (block: block, height: 400),
      ],
    );

    expect(result.block?.id, 'b1');
    expect(result.charOffset, greaterThan(0));
  });
}
