import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../vocab/preset_words_cache.dart';
import '../vocab/vocab_level_picker_sheet.dart';
import '../vocab/vocab_progress.dart';
import 'shell_appearance_mixin.dart';
import 'vocab/vocab_notebook_screen.dart';
import 'vocab/widgets/level_progress_card.dart';
import 'vocab/widgets/milestone_card.dart';
import 'vocab_wizard/known_words_writer.dart';
import 'vocab_wizard/vocab_selection.dart';
import 'vocab_wizard/vocab_wizard_constants.dart';
import 'vocab_wizard/word_list_parser.dart';

final _presetWordsCache = PresetWordsCache();

/// 词库 Tab：已知词数、等级进度、里程碑、重选等级（追加）、导入词表。
class VocabTab extends StatefulWidget {
  const VocabTab({super.key, this.isTabActive = true});

  final bool isTabActive;

  @override
  State<VocabTab> createState() => _VocabTabState();
}

class _VocabTabState extends State<VocabTab> with ShellAppearanceMixin {
  int? _knownCount;
  int _vocabEntryCount = 0;
  VocabLevelProgress? _levelProgress;
  VocabMilestoneProgress? _milestoneProgress;
  bool _progressLoading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  @override
  void didUpdateWidget(covariant VocabTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      onTabActivated();
    }
  }

  Future<void> _loadProgress() async {
    if (!mounted) return;
    setState(() => _progressLoading = true);

    final scope = AppScope.of(context);
    final db = await scope.database();
    final results = await Future.wait([
      db.getKnownWordStrings(),
      db.countVocabEntries(),
      _presetWordsCache.loadAllLevels(),
    ]);
    if (!mounted) return;

    final words = results[0] as List<String>;
    final vocabCount = results[1] as int;
    final presets = results[2] as Map<String, Set<String>>;
    final knownSet = words.toSet();
    final count = words.length;

    setState(() {
      _knownCount = count;
      _vocabEntryCount = vocabCount;
      _levelProgress = computeLevelProgress(
        knownWords: knownSet,
        presetByLevelId: presets,
      );
      _milestoneProgress = computeMilestoneProgress(count);
      _progressLoading = false;
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _loadProgress();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _appendSelection(VocabSelection selection) async {
    final scope = AppScope.of(context);
    final db = await scope.database();
    await batchInsertKnownWords(
      db: db,
      cache: scope.knownWordsCache,
      words: selection.words,
      source: selection.source,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已追加 ${selection.words.length} 个已知词')),
    );
  }

  Future<void> _confirmAppend(VocabSelection selection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('追加词库'),
        content: Text(
          '将追加 ${selection.words.length} 个词为「已会」\n来源：${selection.label}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认追加'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runBusy(() => _appendSelection(selection));
  }

  Future<void> _pickLevel() async {
    final selection = await showVocabLevelPickerSheet(context);
    if (selection == null || !mounted) return;
    await _confirmAppend(selection);
  }

  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
    );
    if (picked == null || picked.files.single.path == null) return;

    try {
      final raw = await File(picked.files.single.path!).readAsString();
      final words = parseWordList(raw);
      if (words.isEmpty) {
        throw StateError('未解析到有效词条');
      }
      if (!mounted) return;
      await _confirmAppend(
        VocabSelection(
          words: words,
          source: VocabWizardConstants.wordSourceImportFile,
          label: picked.files.single.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = _knownCount == null ? '加载中…' : '${_knownCount!} 个';

    return Scaffold(
      backgroundColor: shellScaffoldColor,
      appBar: AppBar(title: const Text('词库')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已知词数', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    countLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '词库全局共享，标记为已会的词在所有书中不再高亮。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('生词本'),
              subtitle: const Text('阅读中标记的不认识词'),
              trailing: Text(
                _progressLoading ? '…' : '$_vocabEntryCount 词',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _progressLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocabNotebookScreen(),
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(height: 8),
          LevelProgressCard(
            progress: _levelProgress,
            loading: _progressLoading,
          ),
          const SizedBox(height: 8),
          MilestoneCard(
            milestoneProgress: _milestoneProgress,
            loading: _progressLoading,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('重新选择词汇量'),
            subtitle: const Text('选择等级后追加合并到当前词库'),
            trailing: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _pickLevel,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('导入词表'),
            subtitle: const Text('支持 txt / csv，追加到已知词库'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _importFile,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
