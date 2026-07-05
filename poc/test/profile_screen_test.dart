import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/screens/profile/learning_settings_screen.dart';
import 'package:multi_novel_reader/screens/profile/more_settings_screen.dart';
import 'package:multi_novel_reader/screens/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('个人页展示头部与设置入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('阅读者'), findsOneWidget);
    expect(find.text('点击查看阅读统计'), findsOneWidget);
    expect(find.textContaining('资源'), findsNothing);
    expect(find.textContaining('广告'), findsNothing);
    expect(find.text('主页外观'), findsOneWidget);
    expect(find.text('阅读外观'), findsOneWidget);
    expect(find.text('学习设置'), findsOneWidget);
    expect(find.text('更多设置'), findsOneWidget);
    expect(find.text('生词本'), findsOneWidget);
    expect(find.text('Anki'), findsOneWidget);
    expect(find.text('备份'), findsOneWidget);
    expect(find.text('解锁'), findsNothing);
    expect(find.text('广告'), findsNothing);
    expect(find.text('额度'), findsNothing);
  });

  testWidgets('更多设置页展示合规与匿名 ID', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: MoreSettingsScreen()),
      ),
    );
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('更多设置'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '找书与导入'), findsOneWidget);
    expect(find.text('清除缓存'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('服务条款'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('服务条款'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('隐私协议'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('隐私协议'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('ID:'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('ID:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('学习设置页展示词库管理入口', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      await wrapWithAppScope(
        db: db,
        child: const MaterialApp(home: LearningSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('学习设置'), findsOneWidget);
    expect(find.text('词库'), findsOneWidget);
    expect(find.text('管理词库'), findsOneWidget);
  });
}
