import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/import/html_block_splitter.dart';
import 'package:multi_novel_reader/import/import_constants.dart';
import 'package:multi_novel_reader/import/plain_text_utils.dart';
import 'package:multi_novel_reader/reader/html_reader_fixup.dart';

void main() {
  test('prepareHtmlForReader injects paragraph spacing style', () {
    const html = '<p>Hello</p>';
    final result = prepareHtmlForReader(html);
    expect(result, contains('margin-bottom: 0.75em'));
    expect(result, contains(html));
  });

  test('splitHtmlByCharLimit keeps original html when under limit', () {
    const html = '<p>short</p>';
    expect(splitHtmlByCharLimit(html), [html]);
  });

  test('splitHtmlByCharLimit splits at paragraph boundaries', () {
    final paragraph = '<p>${'a' * 6000}</p>';
    final html = '$paragraph$paragraph$paragraph';
    final chunks = splitHtmlByCharLimit(html, 12000);
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(chunk, contains('<p>'));
    }
    expect(
      stripHtmlTagsForSplit(chunks.join()).replaceAll('\n', '').length,
      18000,
    );
  });

  test('splitHtmlByCharLimit respects ImportConstants.blockCharLimit', () {
    final html = '<p>${'x' * ImportConstants.blockCharLimit}</p>';
    final chunks = splitHtmlByCharLimit(html);
    expect(chunks.length, 1);

    final long = '<p>${'y' * (ImportConstants.blockCharLimit + 1)}</p>';
    final split = splitHtmlByCharLimit(long);
    expect(split.length, greaterThan(1));
  });
}
