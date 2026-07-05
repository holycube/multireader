import 'package:flutter/material.dart';

import '../../app.dart';
import 'known_words_writer.dart';
import 'vocab_selection.dart';

/// 屏 3：确认词数并批量写入 known_words。
class ConfirmStep extends StatefulWidget {
  const ConfirmStep({
    super.key,
    required this.selection,
    required this.onComplete,
    required this.onBack,
  });

  final VocabSelection selection;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  @override
  State<ConfirmStep> createState() => _ConfirmStepState();
}

class _ConfirmStepState extends State<ConfirmStep> {
  bool _writing = false;
  double _progress = 0;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _writing = true;
      _progress = 0;
      _error = null;
    });

    try {
      final scope = AppScope.of(context);
      final db = await scope.database();
      await batchInsertKnownWords(
        db: db,
        cache: scope.knownWordsCache,
        words: widget.selection.words,
        source: widget.selection.source,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _progress = done / total);
        },
      );
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _writing = false;
        _error = '写入失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.selection.words.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _writing ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                '确认词库',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.fact_check_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            '将标记 $count 个词为「已会」',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '来源：${widget.selection.label}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_writing) ...[
            const SizedBox(height: 32),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 8),
            Text(
              '写入中… ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: _writing ? null : _confirm,
            child: Text(_writing ? '写入中…' : '确认并进入书架'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
