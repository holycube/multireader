import 'package:flutter/material.dart';



import '../shell_appearance_mixin.dart';

import 'home_appearance_settings_screen.dart';

import 'learning_settings_screen.dart';

import 'more_settings_screen.dart';

import 'reader_appearance_settings_screen.dart';

import 'widgets/capability_badge_wall.dart';

import 'widgets/profile_header.dart';

import 'widgets/settings_group_card.dart';

import 'widgets/settings_list_tile.dart';



/// 个人 Tab 根页：渐变头部、能力勋章墙、三个设置入口。

class ProfileScreen extends StatefulWidget {

  const ProfileScreen({

    super.key,

    this.onSwitchTab,

    this.isTabActive = true,

  });



  /// 供头部与学习设置跳转统计 / 词库等 Tab。

  final void Function(int tabIndex)? onSwitchTab;



  final bool isTabActive;



  @override

  State<ProfileScreen> createState() => _ProfileScreenState();

}



class _ProfileScreenState extends State<ProfileScreen>

    with ShellAppearanceMixin {

  bool _loading = true;

  final _badgeWallKey = GlobalKey<CapabilityBadgeWallState>();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());

  }



  @override

  void didUpdateWidget(covariant ProfileScreen oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.isTabActive && !oldWidget.isTabActive) {

      onTabActivated();

    }

  }



  Future<void> _load() async {

    setState(() => _loading = true);

    await _badgeWallKey.currentState?.reload();

    if (!mounted) return;

    setState(() => _loading = false);

  }



  void _switchTab(int index) => widget.onSwitchTab?.call(index);



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: shellScaffoldColor,

      body: RefreshIndicator(

        onRefresh: _load,

        child: ListView(

          padding: const EdgeInsets.only(bottom: 24),

          children: [

            ProfileHeader(

              loading: _loading,

              onTap: () => _switchTab(1),

            ),

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),

              child: CapabilityBadgeWall(key: _badgeWallKey),

            ),

            const SizedBox(height: 20),

            Padding(

              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: SettingsGroupCard(

                children: [

                  SettingsListTile(

                    leading: const Icon(Icons.wallpaper_outlined),

                    title: '主页外观',

                    showChevron: true,

                    onTap: () => Navigator.of(context).push(

                      MaterialPageRoute<void>(

                        builder: (_) => const HomeAppearanceSettingsScreen(),

                      ),

                    ),

                  ),

                  SettingsListTile(

                    leading: const Icon(Icons.menu_book_outlined),

                    title: '阅读外观',

                    showChevron: true,

                    onTap: () => Navigator.of(context).push(

                      MaterialPageRoute<void>(

                        builder: (_) => const ReaderAppearanceSettingsScreen(),

                      ),

                    ),

                  ),

                  SettingsListTile(

                    leading: const Icon(Icons.school_outlined),

                    title: '学习设置',

                    showChevron: true,

                    onTap: () => Navigator.of(context).push(

                      MaterialPageRoute<void>(

                        builder: (_) => LearningSettingsScreen(

                          onSwitchTab: widget.onSwitchTab,

                        ),

                      ),

                    ),

                  ),

                  SettingsListTile(

                    leading: const Icon(Icons.settings_outlined),

                    title: '更多设置',

                    showChevron: true,

                    onTap: () => Navigator.of(context).push(

                      MaterialPageRoute<void>(

                        builder: (_) => const MoreSettingsScreen(),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

}


