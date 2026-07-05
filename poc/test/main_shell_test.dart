import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/main_shell.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('主导航显示四 Tab 标签', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.length, 4);
    expect(
      destinations.map((d) => d.label).toList(),
      ['书架', '统计', '词库', '个人'],
    );
    expect(find.text('资源'), findsNothing);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
