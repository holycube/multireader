import 'package:flutter/material.dart';

import 'reader_preferences.dart';

/// 阅读设置内嵌浮层：亮度、字号、背景、行距。
class ReaderSettingsPanel extends StatelessWidget {
  const ReaderSettingsPanel({super.key, required this.preferences});

  final ReaderPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final onColor = preferences.chromeOnColor;
    final dividerColor = onColor.withValues(alpha: 0.08);

    return Material(
      color: preferences.settingsPanelColor,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrightnessRow(preferences: preferences, onColor: onColor),
          Divider(height: 1, color: dividerColor),
          _FontSizeRow(preferences: preferences, onColor: onColor),
          Divider(height: 1, color: dividerColor),
          _BackgroundRow(preferences: preferences, onColor: onColor),
          Divider(height: 1, color: dividerColor),
          _SpacingRow(preferences: preferences, onColor: onColor),
          Divider(height: 1, color: dividerColor),
          _ChunkSeparatorsRow(preferences: preferences, onColor: onColor),
        ],
      ),
    );
  }
}

class _BrightnessRow extends StatelessWidget {
  const _BrightnessRow({
    required this.preferences,
    required this.onColor,
  });

  final ReaderPreferences preferences;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: onColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: onColor.withValues(alpha: 0.6),
                inactiveTrackColor: onColor.withValues(alpha: 0.15),
                thumbColor: onColor,
                overlayColor: onColor.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: preferences.screenBrightness,
                min: 0.0,
                max: 1.0,
                onChanged: (value) => preferences.setScreenBrightness(value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({
    required this.preferences,
    required this.onColor,
  });

  final ReaderPreferences preferences;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final size = preferences.fontSize.round();
    final canDecrease = size > ReaderPreferences.minFontSize.round();
    final canIncrease = size < ReaderPreferences.maxFontSize.round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _StepButton(
            label: 'A-',
            onColor: onColor,
            enabled: canDecrease,
            onPressed: canDecrease
                ? () => preferences.setFontSize(size - 1.0)
                : null,
          ),
          Expanded(
            child: Text(
              '$size',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepButton(
            label: 'A+',
            onColor: onColor,
            enabled: canIncrease,
            onPressed: canIncrease
                ? () => preferences.setFontSize(size + 1.0)
                : null,
          ),
        ],
      ),
    );
  }
}

class _BackgroundRow extends StatelessWidget {
  const _BackgroundRow({
    required this.preferences,
    required this.onColor,
  });

  final ReaderPreferences preferences;
  final Color onColor;

  static const _presets = <({Color color, int preset})>[
    (color: Colors.white, preset: 0),
    (color: Color(0xFFF5EEDC), preset: 1),
    (color: Color(0xFF1E1E1E), preset: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _presets.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            _BgSwatch(
              color: _presets[i].color,
              selected: preferences.backgroundPreset == _presets[i].preset,
              ringColor: onColor,
              onTap: () => preferences.setBackgroundPreset(_presets[i].preset),
            ),
          ],
        ],
      ),
    );
  }
}

class _BgSwatch extends StatelessWidget {
  const _BgSwatch({
    required this.color,
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? ringColor : ringColor.withValues(alpha: 0.25),
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _SpacingRow extends StatelessWidget {
  const _SpacingRow({
    required this.preferences,
    required this.onColor,
  });

  final ReaderPreferences preferences;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final height = preferences.lineHeight;
    final canDecrease = height > ReaderPreferences.minLineHeight + 0.05;
    final canIncrease = height < ReaderPreferences.maxLineHeight - 0.05;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _StepButton(
            label: '−',
            onColor: onColor,
            enabled: canDecrease,
            onPressed: canDecrease
                ? () => preferences.setLineHeight(
                      double.parse((height - 0.1).toStringAsFixed(1)),
                    )
                : null,
          ),
          Expanded(
            child: Text(
              height.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepButton(
            label: '+',
            onColor: onColor,
            enabled: canIncrease,
            onPressed: canIncrease
                ? () => preferences.setLineHeight(
                      double.parse((height + 0.1).toStringAsFixed(1)),
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class _ChunkSeparatorsRow extends StatelessWidget {
  const _ChunkSeparatorsRow({
    required this.preferences,
    required this.onColor,
  });

  final ReaderPreferences preferences;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '语块分隔点',
                  style: TextStyle(color: onColor, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: onColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'beta',
                    style: TextStyle(
                      color: onColor.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: preferences.chunkSeparatorsEnabled,
            activeTrackColor: onColor.withValues(alpha: 0.35),
            activeThumbColor: onColor,
            onChanged: preferences.setChunkSeparatorsEnabled,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onColor,
    required this.enabled,
    this.onPressed,
  });

  final String label;
  final Color onColor;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Text(
        label,
        style: TextStyle(
          color: enabled ? onColor : onColor.withValues(alpha: 0.3),
          fontSize: label.length > 1 ? 16 : 22,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
