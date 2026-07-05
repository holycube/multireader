import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/constants.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/bookshelf_screen.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('书架删除书籍需确认并从列表移除', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    const bookId = 'book-delete-ui';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertBook(
      id: bookId,
      title: '待删书籍',
      sourceFormat: DbConstants.sourceFormatTxt,
      sourcePath: '/tmp/delete.txt',
      importedAt: now,
    );
    await db.markBookComplete(
      id: bookId,
      totalChapters: 1,
      totalBlocks: 1,
    );
    await db.initParseQuota(bookId, totalBlocks: 1);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(
          home: BookshelfScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('待删书籍'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').first);
    await tester.pumpAndSettle();

    expect(find.text('删除书籍'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('待删书籍'), findsNothing);
    expect(await db.getBookById(bookId), isNull);
    expect(find.text('已删除「待删书籍」'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });
}
