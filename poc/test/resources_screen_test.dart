import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_novel_reader/screens/resources_screen.dart';

void main() {
  testWidgets('资源页展示公版书渠道与导入步骤', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResourcesScreen()),
    );

    expect(find.text('资源'), findsOneWidget);
    expect(find.text('公版书渠道'), findsOneWidget);
    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('Standard Ebooks'), findsOneWidget);
    expect(find.text('如何从浏览器下载并导入'), findsOneWidget);
    expect(find.text('下载 EPUB'), findsOneWidget);
    expect(find.text('导入到本 App'), findsOneWidget);
    expect(find.text('开始阅读'), findsOneWidget);
  });
}
