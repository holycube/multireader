import 'package:flutter/material.dart';

import '../database/database.dart';
import 'bookshelf_screen.dart';
import 'profile/profile_screen.dart';
import 'stats_screen.dart';
import 'vocab_tab.dart';

/// 四 Tab 主导航：书架（默认）/ 统计 / 词库 / 个人。
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.onDatabaseReady,
    this.initialTab = 0,
  });

  static const routeName = '/main';

  final void Function(AppDatabase db)? onDatabaseReady;
  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab.clamp(0, 3);
  final GlobalKey<BookshelfScreenState> _bookshelfKey =
      GlobalKey<BookshelfScreenState>();

  void _switchTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          BookshelfScreen(
            key: _bookshelfKey,
            onDatabaseReady: widget.onDatabaseReady,
            isTabActive: _index == 0,
          ),
          StatsScreen(isTabActive: _index == 1),
          VocabTab(isTabActive: _index == 2),
          ProfileScreen(
            onSwitchTab: _switchTab,
            isTabActive: _index == 3,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _switchTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '词库',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: '个人',
          ),
        ],
      ),
    );
  }
}
