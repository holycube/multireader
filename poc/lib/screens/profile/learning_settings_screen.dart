import 'package:flutter/material.dart';



import '../../app.dart';

import '../vocab_wizard/known_words_writer.dart';

import 'legal_document_screen.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_list_tile.dart';



/// 学习设置：重置词库与管理词库跳转。

class LearningSettingsScreen extends StatefulWidget {

  const LearningSettingsScreen({

    super.key,

    this.onSwitchTab,

  });



  final void Function(int tabIndex)? onSwitchTab;



  @override

  State<LearningSettingsScreen> createState() => _LearningSettingsScreenState();

}



class _LearningSettingsScreenState extends State<LearningSettingsScreen> {

  bool _resetting = false;



  Future<void> _resetVocab() async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('重置词库'),

        content: const Text(

          '将清空所有已知词，阅读时生词高亮会显著增多。\n'

          '重置后可在词库 Tab 重新设置词汇量。',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context, false),

            child: const Text('取消'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(context, true),

            child: const Text('确认重置'),

          ),

        ],

      ),

    );

    if (ok != true || !mounted) return;



    setState(() => _resetting = true);

    try {

      final scope = AppScope.of(context);

      final db = await scope.database();

      await clearKnownWords(db: db, cache: scope.knownWordsCache);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('词库已重置')),

      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('重置失败：$e')),

      );

    } finally {

      if (mounted) setState(() => _resetting = false);

    }

  }



  void _goVocabTab() {

    Navigator.of(context).pop();

    widget.onSwitchTab?.call(2);

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);



    return Scaffold(

      appBar: AppBar(title: const Text('学习设置')),

      backgroundColor: theme.colorScheme.surfaceContainerLow,

      body: ListView(

        padding: const EdgeInsets.all(16),

        children: [

          Text('词库', style: theme.textTheme.titleSmall),

          const SizedBox(height: 8),

          SettingsGroupCard(

            children: [

              SettingsListTile(

                leading: const Icon(Icons.library_books_outlined),

                title: '管理词库',

                subtitle: '查看进度、追加词汇量或导入词表',

                showChevron: true,

                onTap: _goVocabTab,

              ),

              SettingsListTile(

                leading: const Icon(Icons.menu_book_outlined),

                title: '词形查词说明',

                subtitle: '变形词查义、已会记录与高亮规则',

                showChevron: true,

                onTap: () => Navigator.of(context).push(

                  MaterialPageRoute<void>(

                    builder: (_) => const LegalDocumentScreen(

                      document: LegalDocument.wordVariantLookup,

                    ),

                  ),

                ),

              ),

              SettingsListTile(

                leading: Icon(

                  Icons.delete_outline,

                  color: theme.colorScheme.error,

                ),

                title: '重置词库',

                subtitle: '清空所有已知词',

                trailing: _resetting

                    ? const SizedBox(

                        width: 24,

                        height: 24,

                        child: CircularProgressIndicator(strokeWidth: 2),

                      )

                    : Icon(

                        Icons.chevron_right,

                        color: theme.colorScheme.error,

                      ),

                onTap: _resetting ? null : _resetVocab,

              ),

            ],

          ),

          const SizedBox(height: 16),

          Text(

            '日常词库管理请前往词库 Tab；此处仅提供重置与快捷跳转。',

            style: theme.textTheme.bodySmall?.copyWith(

              color: theme.colorScheme.onSurfaceVariant,

            ),

          ),

        ],

      ),

    );

  }

}

