import 'package:flutter/material.dart';

import '../vocab/dict_entry.dart';
import '../vocab/dict_lookup_result.dart';
import 'lookup_card_widgets.dart';
import 'lookup_panel.dart';
import 'reader_preferences.dart';
import 'word_detail_screen.dart';
import 'word_pronunciation.dart';

const _serifFamily = 'Georgia';

enum _VariantTab { surface, lemma }

/// 变形词双 Tab 查词卡：表面词形 | 原形，✓ 针对当前 Tab 词形。
class LookupVariantCard extends StatefulWidget {
  const LookupVariantCard({
    super.key,
    required this.lookupResult,
    required this.isUnknownFor,
    this.preferences,
    this.cardColor,
    this.cardOnColor,
    required this.onAction,
  });

  final DictLookupResult lookupResult;
  final bool Function(String word) isUnknownFor;
  final ReaderPreferences? preferences;
  final Color? cardColor;
  final Color? cardOnColor;
  final Future<void> Function(LookupAction action, String activeWord) onAction;

  @override
  State<LookupVariantCard> createState() => _LookupVariantCardState();
}

class _LookupVariantCardState extends State<LookupVariantCard> {
  static const _maxLemmaSenses = 3;

  _VariantTab _selectedTab = _VariantTab.surface;
  bool _busy = false;

  String get _surfaceWord => widget.lookupResult.tappedWord;
  String get _lemmaWord => widget.lookupResult.alias!.lemma;
  DictEntry? get _entry => widget.lookupResult.entry;
  DictAliasMeta get _alias => widget.lookupResult.alias!;

  String get _activeWord =>
      _selectedTab == _VariantTab.surface ? _surfaceWord : _lemmaWord;

  bool get _activeIsUnknown => widget.isUnknownFor(_activeWord);

  String? get _activePhonetic {
    if (_selectedTab == _VariantTab.surface) {
      return _alias.phonetic ?? _entry?.phonetic;
    }
    return _entry?.phonetic;
  }

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
        !_activeIsUnknown &&
        rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('已加入生词本'), duration: Duration(seconds: 1)),
      );
    }

    widget.onAction(action, _activeWord).catchError((Object e) {
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(content: Text('操作失败：$e'), duration: const Duration(seconds: 2)),
        );
      }
    });
  }

  void _toggleKnown() {
    if (_busy) return;
    _runAction(
      _activeIsUnknown ? LookupAction.know : LookupAction.dontKnow,
    );
  }

  void _openDetail() {
    final activeWord = _activeWord;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WordDetailScreen(
          word: activeWord,
          entry: _entry,
          isUnknown: widget.isUnknownFor(activeWord),
          preferences: widget.preferences,
          onAction: (action) => widget.onAction(action, activeWord),
        ),
      ),
    );
  }

  TextStyle _serifWord(TextTheme theme, Color accentColor) {
    return theme.titleLarge!.copyWith(
      fontFamily: _serifFamily,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      color: accentColor,
    );
  }

  TextStyle _serifBody(
    TextTheme theme,
    Color onColor, {
    FontWeight fontWeight = FontWeight.w400,
    double? alpha,
  }) {
    return theme.bodyMedium!.copyWith(
      fontFamily: _serifFamily,
      color: alpha != null ? onColor.withValues(alpha: alpha) : onColor,
      fontWeight: fontWeight,
      height: 1.45,
    );
  }

  Widget _buildTabChip({
    Key? key,
    required String label,
    required bool selected,
    required Color accentColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: selected
                ? null
                : Border.all(color: mutedColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? accentColor : mutedColor,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceContent(TextTheme textTheme, Color onColor) {
    final entry = _entry;
    final bodyStyle = _serifBody(textTheme, onColor);
    final posStyle = _serifBody(textTheme, onColor, fontWeight: FontWeight.w600);

    if (entry == null || entry.senses.isEmpty) {
      return Text(
        '词典未收录该词',
        style: _serifBody(textTheme, onColor, alpha: 0.5),
      );
    }

    final sense = entry.senses.first;
    final grammarNote =
        formatVariantGrammarNote(_lemmaWord, _alias.exchangeKey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sense.pos.isNotEmpty)
          Text('${sense.pos} ', style: posStyle),
        Expanded(
          child: LookupMeaningsText(
            meanings: sense.meanings,
            style: bodyStyle,
            suffix: grammarNote,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLemmaContent(TextTheme textTheme, Color onColor) {
    final entry = _entry;
    final bodyStyle = _serifBody(textTheme, onColor);
    final posStyle = _serifBody(textTheme, onColor, fontWeight: FontWeight.w600);
    final senses = entry?.senses ?? const <DictSense>[];
    final visibleSenses = senses.take(_maxLemmaSenses).toList();
    final hasMoreSenses = senses.length > _maxLemmaSenses;

    if (entry == null || !entry.hasContent) {
      return Text(
        '词典未收录该词',
        style: _serifBody(textTheme, onColor, alpha: 0.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sense in visibleSenses)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sense.pos.isNotEmpty)
                  Text('${sense.pos} ', style: posStyle),
                Expanded(
                  child: LookupMeaningsText(
                    meanings: sense.meanings,
                    style: bodyStyle,
                  ),
                ),
              ],
            ),
          ),
        if (hasMoreSenses)
          Text(
            '…',
            style: _serifBody(textTheme, onColor, alpha: 0.6),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = widget.preferences;
    final cardColor =
        widget.cardColor ?? prefs?.lookupCardColor ?? theme.colorScheme.surface;
    final onColor = widget.cardOnColor ??
        prefs?.lookupCardOnColor ??
        theme.colorScheme.onSurface;
    final isDark = prefs?.lookupCardIsDark ?? false;
    final borderColor = prefs?.lookupCardBorderColor ?? Colors.transparent;
    final accentColor = theme.colorScheme.primary;
    final mutedColor = onColor.withValues(alpha: 0.55);
    final entry = _entry;
    final width = MediaQuery.sizeOf(context).width - 32;
    final wordStyle = _serifWord(theme.textTheme, accentColor);
    final activeWord = _activeWord;
    final phonetic = _activePhonetic;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 480),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: borderColor, width: 0.5)
                : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildTabChip(
                            key: const Key('variant-tab-surface'),
                            label: _surfaceWord,
                            selected: _selectedTab == _VariantTab.surface,
                            accentColor: accentColor,
                            mutedColor: mutedColor,
                            onTap: () => setState(
                              () => _selectedTab = _VariantTab.surface,
                            ),
                          ),
                          _buildTabChip(
                            key: const Key('variant-tab-lemma'),
                            label: _lemmaWord,
                            selected: _selectedTab == _VariantTab.lemma,
                            accentColor: accentColor,
                            mutedColor: mutedColor,
                            onTap: () => setState(
                              () => _selectedTab = _VariantTab.lemma,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LookupKnownToggle(
                      key: const Key('known-toggle'),
                      isUnknown: _activeIsUnknown,
                      accentColor: accentColor,
                      mutedColor: mutedColor,
                      busy: _busy,
                      onTap: _toggleKnown,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(activeWord, style: wordStyle),
                          if (_selectedTab == _VariantTab.lemma && entry != null)
                            for (final tag in entry.examTags)
                              LookupExamTag(
                                label: tag,
                                mutedColor: mutedColor,
                                onColor: onColor,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (phonetic != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      LookupPhoneticPill(
                        mutedColor: mutedColor,
                        onColor: onColor,
                        onSpeak: () =>
                            WordPronunciation.instance.speak(activeWord),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phonetic,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: _serifFamily,
                            color: mutedColor,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: _selectedTab == _VariantTab.surface
                        ? _buildSurfaceContent(theme.textTheme, onColor)
                        : _buildLemmaContent(theme.textTheme, onColor),
                  ),
                ),
                if (entry != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _openDetail,
                      style: TextButton.styleFrom(
                        foregroundColor: onColor.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('查看详细释义 >'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
