import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../database/database.dart';
import '../../reader/lookup_panel.dart';
import '../../reader/word_detail_screen.dart';
import '../../reader/word_lookup_service.dart';
import '../../vocab/dict_entry.dart';
import '../../vocab/dict_loader.dart';
import '../../vocab/word_normalizer.dart';
import 'widgets/vocab_notebook_tile.dart';

/// 生词本：按最近更新展示收录词，点击可查看词条详情。
class VocabNotebookScreen extends StatefulWidget {
  const VocabNotebookScreen({super.key});

  @override
  State<VocabNotebookScreen> createState() => _VocabNotebookScreenState();
}

class _VocabNotebookScreenState extends State<VocabNotebookScreen> {
  AppDatabase? _db;
  WordLookupService? _lookupService;
  bool _dictReady = false;
  StreamSubscription<List<VocabEntry>>? _entriesSubscription;
  List<VocabEntry> _entries = const [];
  bool _entriesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    unawaited(_entriesSubscription?.cancel());
    super.dispose();
  }

  Future<void> _init() async {
    final scope = AppScope.of(context);
    final db = await scope.database();
    await _entriesSubscription?.cancel();
    _entriesSubscription = db.watchVocabEntries().listen((entries) {
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _entriesReady = true;
      });
    });
    if (!mounted) return;
    setState(() {
      _db = db;
      _lookupService = WordLookupService(
        db: db,
        knownWordsCache: scope.knownWordsCache,
      );
    });
    if (DictLoader.instance.isLoaded) {
      _dictReady = true;
    } else {
      unawaited(
        DictLoader.instance.load().then((_) {
          if (mounted) setState(() => _dictReady = true);
        }),
      );
    }
  }

  DictEntry? _dictEntryFor(String word) {
    if (!_dictReady) return null;
    return DictLoader.instance.resolve(normalizeWord(word)).entry;
  }

  String _definitionSnippet(VocabEntry entry) {
    final stored = entry.definition?.trim();
    if (stored != null && stored.isNotEmpty) {
      return vocabSnippetLine(stored);
    }
    final fromDict = _dictEntryFor(entry.word)?.summaryForVocab();
    if (fromDict != null && fromDict.isNotEmpty) {
      return vocabSnippetLine(fromDict);
    }
    return '暂无释义';
  }

  String? _contextSnippet(VocabEntry entry) {
    final stored = entry.context?.trim();
    if (stored == null || stored.isEmpty) return null;
    return vocabSnippetLine(stored, maxLen: 120);
  }

  Future<void> _handleLookupAction({
    required LookupAction action,
    required String word,
    required bool isUnknown,
    DictEntry? entry,
  }) async {
    final lookupService = _lookupService;
    if (lookupService == null) return;

    final definition = entry?.summaryForVocab();
    switch (action) {
      case LookupAction.dontKnow:
        if (!isUnknown) {
          await lookupService.addToVocab(
            rawWord: word,
            definition: definition,
          );
        }
        break;
      case LookupAction.know:
        if (isUnknown) {
          await lookupService.markKnown(word);
        } else {
          await lookupService.confirmKnown(word);
        }
        break;
    }
  }

  void _openWordDetail(VocabEntry entry) {
    final normalized = normalizeWord(entry.word);
    final dictEntry = _dictEntryFor(entry.word);
    final scope = AppScope.of(context);
    final isUnknown = !scope.knownWordsCache.isKnownNormalized(normalized);

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WordDetailScreen(
          word: entry.word,
          entry: dictEntry,
          isUnknown: isUnknown,
          onAction: (action) => _handleLookupAction(
            action: action,
            word: entry.word,
            isUnknown: isUnknown,
            entry: dictEntry,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.bookmark_border,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          '阅读时点击「不认识」，生词会收录在这里',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = _db;

    return Scaffold(
      appBar: AppBar(title: const Text('生词本')),
      body: db == null || !_entriesReady
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return VocabNotebookTile(
                      entry: entry,
                      definitionSnippet: _definitionSnippet(entry),
                      contextSnippet: _contextSnippet(entry),
                      onTap: () => _openWordDetail(entry),
                    );
                  },
                ),
    );
  }
}
