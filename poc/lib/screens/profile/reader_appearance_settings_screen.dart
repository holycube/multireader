import 'package:flutter/material.dart';

import '../../reader/reader_preferences.dart';

/// 阅读外观：全局默认字号、行距与背景预设。
class ReaderAppearanceSettingsScreen extends StatefulWidget {
  const ReaderAppearanceSettingsScreen({super.key});

  @override
  State<ReaderAppearanceSettingsScreen> createState() =>
      _ReaderAppearanceSettingsScreenState();
}

class _ReaderAppearanceSettingsScreenState
    extends State<ReaderAppearanceSettingsScreen> {
  ReaderPreferences? _readerPrefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reader = await ReaderPreferences.load();
    if (!mounted) return;
    setState(() => _readerPrefs = reader);
    reader.addListener(_onReaderChanged);
  }

  @override
  void dispose() {
    _readerPrefs?.removeListener(_onReaderChanged);
    super.dispose();
  }

  void _onReaderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = _readerPrefs;

    if (reader == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读外观')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fontSize = reader.fontSize.round();

    return Scaffold(
      appBar: AppBar(title: const Text('阅读外观')),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('阅读默认', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _FontSizeTile(reader: reader, fontSize: fontSize),
                const Divider(height: 1),
                _LineHeightTile(reader: reader),
                const Divider(height: 1),
                _BackgroundPreviewTile(reader: reader),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '阅读器内设置浮层与此处共用同一套偏好；新打开阅读器时生效。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeTile extends StatelessWidget {
  const _FontSizeTile({required this.reader, required this.fontSize});

  final ReaderPreferences reader;
  final int fontSize;

  @override
  Widget build(BuildContext context) {
    final canDecrease = fontSize > ReaderPreferences.minFontSize.round();
    final canIncrease = fontSize < ReaderPreferences.maxFontSize.round();

    return ListTile(
      leading: const Icon(Icons.format_size),
      title: const Text('默认字号'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: canDecrease
                ? () => reader.setFontSize(fontSize - 1.0)
                : null,
          ),
          Text('$fontSize'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: canIncrease
                ? () => reader.setFontSize(fontSize + 1.0)
                : null,
          ),
        ],
      ),
    );
  }
}

class _LineHeightTile extends StatelessWidget {
  const _LineHeightTile({required this.reader});

  final ReaderPreferences reader;

  @override
  Widget build(BuildContext context) {
    final value = reader.lineHeight;
    final label = value.toStringAsFixed(1);

    return ListTile(
      leading: const Icon(Icons.format_line_spacing),
      title: const Text('默认行距'),
      subtitle: Slider(
        value: value,
        min: ReaderPreferences.minLineHeight,
        max: ReaderPreferences.maxLineHeight,
        divisions: 6,
        label: label,
        onChanged: (v) => reader.setLineHeight(v),
      ),
      trailing: Text(label),
    );
  }
}

class _BackgroundPreviewTile extends StatelessWidget {
  const _BackgroundPreviewTile({required this.reader});

  final ReaderPreferences reader;

  static const _presets = <({String label, Color color, int preset})>[
    (label: '默认白', color: Colors.white, preset: 0),
    (label: '护眼黄', color: Color(0xFFF5EEDC), preset: 1),
    (label: '夜间黑', color: Color(0xFF1E1E1E), preset: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: theme.colorScheme.onSurface),
              const SizedBox(width: 16),
              Text('默认背景', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _BgPreview(
                    label: _presets[i].label,
                    color: _presets[i].color,
                    selected: reader.backgroundPreset == _presets[i].preset,
                    onTap: () =>
                        reader.setBackgroundPreset(_presets[i].preset),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BgPreview extends StatelessWidget {
  const _BgPreview({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = color.computeLuminance() < 0.3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Aa',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
