import 'package:flutter/material.dart';

import '../vocab/dict_entry.dart';
import 'lookup_card_widgets.dart';
import 'lookup_panel.dart';
import 'reader_preferences.dart';
import 'word_detail_screen.dart';
import 'word_pronunciation.dart';

const _serifFamily = 'Georgia';

/// 屏幕居中查词卡：词形、标签、音标、分词性释义与「已会」切换。
class LookupCard extends StatefulWidget {
  const LookupCard({
    super.key,
    required this.word,
    required this.entry,
    required this.isUnknown,
    this.preferences,
    this.cardColor,
    this.cardOnColor,
    required this.onAction,
  });

  final String word;
  final DictEntry? entry;
  final bool isUnknown;
  final ReaderPreferences? preferences;
  final Color? cardColor;
  final Color? cardOnColor;
  final Future<void> Function(LookupAction action) onAction;

  @override
  State<LookupCard> createState() => _LookupCardState();
}

class _LookupCardState extends State<LookupCard> {
  static const _maxCardSenses = 3;

  bool _busy = false;

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

  void _toggleKnown() {
    if (_busy) return;
    _runAction(
      widget.isUnknown ? LookupAction.know : LookupAction.dontKnow,
    );
  }

  void _openDetail() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WordDetailScreen(
          word: widget.word,
          entry: widget.entry,
          isUnknown: widget.isUnknown,
          preferences: widget.preferences,
          onAction: widget.onAction,
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
    final entry = widget.entry;
    final hasContent = entry?.hasContent ?? false;
    final senses = entry?.senses ?? const <DictSense>[];
    final visibleSenses = senses.take(_maxCardSenses).toList();
    final hasMoreSenses = senses.length > _maxCardSenses;
    final width = MediaQuery.sizeOf(context).width - 32;
    final wordStyle = _serifWord(theme.textTheme, accentColor);
    final bodyStyle = _serifBody(theme.textTheme, onColor);
    final posStyle = _serifBody(theme.textTheme, onColor, fontWeight: FontWeight.w600);

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
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(widget.word, style: wordStyle),
                          if (entry != null)
                            for (final tag in entry.examTags)
                              LookupExamTag(
                                label: tag,
                                mutedColor: mutedColor,
                                onColor: onColor,
                              ),
                        ],
                      ),
                    ),
                    LookupKnownToggle(
                      key: const Key('known-toggle'),
                      isUnknown: widget.isUnknown,
                      accentColor: accentColor,
                      mutedColor: mutedColor,
                      busy: _busy,
                      onTap: _toggleKnown,
                    ),
                  ],
                ),
                if (entry?.phonetic != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      LookupPhoneticPill(
                        mutedColor: mutedColor,
                        onColor: onColor,
                        onSpeak: () =>
                            WordPronunciation.instance.speak(widget.word),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry!.phonetic!,
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
                    child: hasContent
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final sense in visibleSenses)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (sense.pos.isNotEmpty)
                                        Text(
                                          '${sense.pos} ',
                                          style: posStyle,
                                        ),
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
                                  style: _serifBody(
                                    theme.textTheme,
                                    onColor,
                                    alpha: 0.6,
                                  ),
                                ),
                            ],
                          )
                        : Text(
                            '词典未收录该词',
                            style: _serifBody(
                              theme.textTheme,
                              onColor,
                              alpha: 0.5,
                            ),
                          ),
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
