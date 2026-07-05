import 'package:flutter/material.dart';



import '../../app.dart';

import '../../database/database.dart';

import '../../services/cache_manager.dart';

import 'widgets/settings_group_card.dart';

import 'widgets/settings_list_tile.dart';



/// 本地数据概览（替代账号信息）：书架与缓存摘要。

class LocalDataOverviewScreen extends StatefulWidget {

  const LocalDataOverviewScreen({super.key});



  @override

  State<LocalDataOverviewScreen> createState() => _LocalDataOverviewScreenState();

}



class _LocalDataOverviewScreenState extends State<LocalDataOverviewScreen> {

  bool _loading = true;

  int _bookCount = 0;

  int _cacheBytes = 0;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());

  }



  Future<void> _load() async {

    final db = await AppScope.of(context).database();

    final results = await Future.wait([

      db.watchBookshelfItems().first,

      CacheManager.calculateCacheBytes(),

    ]);

    if (!mounted) return;

    setState(() {

      _bookCount = (results[0] as List<BookshelfItem>).length;

      _cacheBytes = results[1] as int;

      _loading = false;

    });

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);



    return Scaffold(

      appBar: AppBar(title: const Text('本地数据概览')),

      body: _loading

          ? const Center(child: CircularProgressIndicator())

          : ListView(

              padding: const EdgeInsets.all(16),

              children: [

                Text(

                  '以下数据均保存在本机，不会上传至服务器。',

                  style: theme.textTheme.bodyMedium?.copyWith(

                    color: theme.colorScheme.onSurfaceVariant,

                  ),

                ),

                const SizedBox(height: 16),

                SettingsGroupCard(

                  children: [

                    SettingsListTile(

                      leading: const Icon(Icons.menu_book_outlined),

                      title: '书架册数',

                      trailingText: '$_bookCount 本',

                    ),

                    SettingsListTile(

                      leading: const Icon(Icons.storage_outlined),

                      title: '缓存占用',

                      trailingText: CacheManager.formatBytes(_cacheBytes),

                    ),

                  ],

                ),

              ],

            ),

    );

  }

}

