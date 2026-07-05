import 'package:flutter/material.dart';



import '../../../app.dart';

import '../../../widgets/soft_card.dart';

import '../../vocab/vocab_notebook_screen.dart';



/// 能力勋章墙：生词本 / Anki / 备份 三格横排。

class CapabilityBadgeWall extends StatefulWidget {

  const CapabilityBadgeWall({super.key});



  @override

  CapabilityBadgeWallState createState() => CapabilityBadgeWallState();

}



class CapabilityBadgeWallState extends State<CapabilityBadgeWall> {

  bool _loading = true;

  int _vocabEntryCount = 0;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => reload());

  }



  Future<void> reload() async {

    final db = await AppScope.of(context).database();

    final count = await db.countVocabEntries();

    if (!mounted) return;

    setState(() {

      _vocabEntryCount = count;

      _loading = false;

    });

  }



  void _openVocabNotebook() {

    if (_loading) return;

    Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => const VocabNotebookScreen(),

      ),

    );

  }



  void _showComingSoon(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message)),

    );

  }



  @override

  Widget build(BuildContext context) {

    return SoftCard(

      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),

      child: Row(

        children: [

          Expanded(

            child: _BadgeItem(

              icon: Icons.bookmark_outline,

              label: '生词本',

              count: _loading ? null : _vocabEntryCount,

              onTap: _openVocabNotebook,

            ),

          ),

          Expanded(

            child: _BadgeItem(

              icon: Icons.lock_outline,

              label: 'Anki',

              locked: true,

              onTap: () => _showComingSoon('Anki 导出即将上线'),

            ),

          ),

          Expanded(

            child: _BadgeItem(

              icon: Icons.lock_outline,

              label: '备份',

              locked: true,

              onTap: () => _showComingSoon('备份功能即将上线'),

            ),

          ),

        ],

      ),

    );

  }

}



class _BadgeItem extends StatelessWidget {

  const _BadgeItem({

    required this.icon,

    required this.label,

    this.count,

    this.locked = false,

    this.onTap,

  });



  final IconData icon;

  final String label;

  final int? count;

  final bool locked;

  final VoidCallback? onTap;



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final iconColor = locked

        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)

        : theme.colorScheme.primary;



    return InkWell(

      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: Padding(

        padding: const EdgeInsets.symmetric(vertical: 4),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(icon, color: iconColor, size: 26),

            const SizedBox(height: 6),

            Text(

              label,

              style: theme.textTheme.bodySmall?.copyWith(

                fontWeight: FontWeight.w500,

                color: locked ? theme.colorScheme.onSurfaceVariant : null,

              ),

            ),

            if (count != null) ...[

              const SizedBox(height: 2),

              Text(

                '$count',

                style: theme.textTheme.labelSmall?.copyWith(

                  color: theme.colorScheme.onSurfaceVariant,

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }

}


