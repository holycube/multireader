import 'package:flutter/material.dart';

/// Tab 壳层页面 Scaffold 背景：由 [ThemeData.scaffoldBackgroundColor] 提供。
mixin ShellAppearanceMixin<T extends StatefulWidget> on State<T> {
  Color? get shellScaffoldColor => Theme.of(context).scaffoldBackgroundColor;

  void onTabActivated() {}
}
