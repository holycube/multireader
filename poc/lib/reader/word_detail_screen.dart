import 'package:flutter/material.dart';

import '../vocab/dict_entry.dart';
import 'lookup_card_widgets.dart';
import 'lookup_panel.dart';
import 'reader_preferences.dart';
import 'word_pronunciation.dart';

/// 全屏词条详情：完整释义、英文释义、词形变化与查词操作。
class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.word,
    required this.entry,
    required this.isUnknown,
    this.preferences,
    required this.onAction,
  });

  final String word;
  final DictEntry? entry;
  final bool isUnknown;
  final ReaderPreferences? preferences;
  final Future<void> Function(LookupAction action) onAction;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  bool _busy = false;
  bool _englishExpanded = true;

  void _runAction(LookupAction action) {
    if (_busy) return;
    setState(() => _busy = true);

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();

    if (action == LookupAction.know && rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('已标记为已会'), duration: Duration(seconds: 1)),
      );
    } else if (action == LookupAction.dontKnow &&
        !widget.isUnknown &&
        rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('已加入生词本'), duration: Duration(seconds: 1)),
      );
    }

    widget.onAction(action).catchError((Object e) {
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(content: Text('操作失败：$e'), duration: const Duration(seconds: 2)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = widget.preferences;
    final bgColor =
        prefs?.lookupCardColor ?? theme.colorScheme.surface;
    final onColor =
        prefs?.lookupCardOnColor ?? theme.colorScheme.onSurface;
    final entry = widget.entry;
    final hasContent = entry?.hasContent ?? false;
    final exchangeItems = formatExchange(entry?.exchange);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: onColor,
        elevation: 0,
        title: Text(
          widget.word,
          style: const TextStyle(fontFamily: 'Georgia'),
        ),
        actions: [
          IconButton(
            tooltip: '朗读',
            onPressed: () => WordPronunciation.instance.speak(widget.word),
            icon: Icon(Icons.volume_up_outlined, color: onColor),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.word,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (entry?.phonetic != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('🇺🇸', style: TextStyle(fontSize: 16, color: onColor)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry!.phonetic!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: onColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entry != null && entry.examTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.examTags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              labelStyle: theme.textTheme.labelSmall,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: onColor.withValues(alpha: 0.08),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (entry != null &&
                      (entry.collins != null || entry.oxford3000)) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (entry.collins != null)
                          _BadgeChip(
                            label: 'Collins ${entry.collins}',
                            onColor: onColor,
                          ),
                        if (entry.oxford3000)
                          _BadgeChip(label: 'Oxford 3000', onColor: onColor),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    '中文释义',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: onColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasContent && entry != null)
                    ...entry.senses.map(
                      (sense) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sense.pos.isNotEmpty)
                              Text(
                                '${sense.pos} ',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: onColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            Expanded(
                              child: LookupMeaningsText(
                                meanings: sense.meanings,
                                style: theme.textTheme.bodyLarge!.copyWith(
                                  color: onColor,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      '暂无详细释义',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onColor.withValues(alpha: 0.5),
                      ),
                    ),
                  if (entry?.englishDefinition?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () =>
                          setState(() => _englishExpanded = !_englishExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '英文释义',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: onColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _englishExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: onColor.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_englishExpanded)
                      Text(
                        entry!.englishDefinition!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onColor.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                  ],
                  if (exchangeItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '词形变化',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: onColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...exchangeItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _runAction(LookupAction.dontKnow),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: onColor,
                  ),
                  child: const Text('不认识'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _busy ? null : () => _runAction(LookupAction.know),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('已会'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.onColor});

  final String label;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor),
      ),
    );
  }
}
