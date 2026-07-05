import 'package:flutter/material.dart';

import '../screens/vocab_wizard/preset_loader.dart';
import '../screens/vocab_wizard/vocab_selection.dart';
import '../screens/vocab_wizard/vocab_wizard_constants.dart';

/// 弹出词汇量等级选择 Sheet，返回 [VocabSelection] 或 null。
Future<VocabSelection?> showVocabLevelPickerSheet(BuildContext context) {
  return showModalBottomSheet<VocabSelection>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const VocabLevelPickerSheet(),
  );
}

/// 词汇量等级选择（复用向导预置与解析逻辑）。
class VocabLevelPickerSheet extends StatefulWidget {
  const VocabLevelPickerSheet({super.key});

  @override
  State<VocabLevelPickerSheet> createState() => _VocabLevelPickerSheetState();
}

class _VocabLevelPickerSheetState extends State<VocabLevelPickerSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _selectPreset(PresetLevel level) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await loadPresetWords(level);
      if (!mounted) return;
      Navigator.pop(
        context,
        VocabSelection(
          words: words,
          source: level.source,
          label: level.label,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载预置词表失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择词汇量等级',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(
                        '高级选项包含更低等级词汇，选定后将追加到当前词库：',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...VocabWizardConstants.presetLevels.map(
                        (level) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(level.label),
                            subtitle: Text('约 ${level.approximateCount} 词'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectPreset(level),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
