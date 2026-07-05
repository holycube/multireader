// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'preset_loader.dart';
import 'vocab_selection.dart';
import 'vocab_wizard_constants.dart';
import 'word_list_parser.dart';

/// 屏 2：预置等级或 txt/csv 词表导入。
class ChooseStep extends StatefulWidget {
  const ChooseStep({
    super.key,
    required this.onSelectionReady,
    required this.onBack,
  });

  final ValueChanged<VocabSelection> onSelectionReady;
  final VoidCallback onBack;

  @override
  State<ChooseStep> createState() => _ChooseStepState();
}

class _ChooseStepState extends State<ChooseStep> {
  String? _selectedPresetId;
  bool _loading = false;
  String? _error;

  Future<void> _selectPreset(PresetLevel level) async {
    setState(() {
      _selectedPresetId = level.id;
      _loading = true;
      _error = null;
    });

    try {
      final words = await loadPresetWords(level);
      if (!mounted) return;
      widget.onSelectionReady(
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

  Future<void> _importFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
    );
    if (picked == null || picked.files.single.path == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _selectedPresetId = null;
    });

    try {
      final raw = await File(picked.files.single.path!).readAsString();
      final words = parseWordList(raw);
      if (words.isEmpty) {
        throw StateError('未解析到有效词条');
      }
      if (!mounted) return;
      widget.onSelectionReady(
        VocabSelection(
          words: words,
          source: VocabWizardConstants.wordSourceImportFile,
          label: picked.files.single.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '导入失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _loading ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Text(
                '选择词汇量',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '选择与你水平最接近的等级（高级选项包含更低等级词汇）：',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...VocabWizardConstants.presetLevels.map(
                      (level) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          value: level.id,
                          groupValue: _selectedPresetId,
                          title: Text(level.label),
                          subtitle: Text('约 ${level.approximateCount} 词'),
                          onChanged: (_) => _selectPreset(level),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _importFile,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('从 txt / csv 导入词表'),
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
        ),
      ],
    );
  }
}
