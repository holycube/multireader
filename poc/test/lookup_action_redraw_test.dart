import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/reader/lookup_panel.dart';

void main() {
  group('lookupActionNeedsRedraw', () {
    test('dontKnow on unknown word skips redraw', () {
      expect(
        lookupActionNeedsRedraw(LookupAction.dontKnow, true),
        isFalse,
      );
    });

    test('dontKnow on known word needs redraw', () {
      expect(
        lookupActionNeedsRedraw(LookupAction.dontKnow, false),
        isTrue,
      );
    });

    test('know on unknown word needs redraw', () {
      expect(
        lookupActionNeedsRedraw(LookupAction.know, true),
        isTrue,
      );
    });

    test('confirm know on known word skips redraw', () {
      expect(
        lookupActionNeedsRedraw(LookupAction.know, false),
        isFalse,
      );
    });
  });
}
