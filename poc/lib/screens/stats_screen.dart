import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../database/database.dart';
import '../services/reading_stats_helper.dart';
import '../theme/app_design_tokens.dart';
import '../theme/app_text_styles.dart';
import '../widgets/soft_card.dart';
import 'shell_appearance_mixin.dart';

/// 阅读统计：正在阅读快照 + 数据格 + 近 7 日柱状图 + 连续阅读日历条。
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.isTabActive = true});

  final bool isTabActive;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with ShellAppearanceMixin {
  bool _loading = true;
  List<DailyMinutesStat> _trend = const [];
  BookshelfItem? _lastBook;
  int _todayNewWords = 0;
  int _totalMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      onTabActivated();
    }
  }

  @override
  void onTabActivated() {
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final db = await AppScope.of(context).database();
    final results = await Future.wait([
      db.getDailyMinutesTrend(),
      db.getLastReadBook(),
      db.getTodayNewWords(),
      db.getTotalReadingMinutes(),
    ]);
    if (!mounted) return;
    setState(() {
      _trend = results[0] as List<DailyMinutesStat>;
      _lastBook = results[1] as BookshelfItem?;
      _todayNewWords = results[2] as int;
      _totalMinutes = results[3] as int;
      _loading = false;
    });
  }

  int get _todayReadingMinutes => _trend.isEmpty ? 0 : _trend.last.minutes;

  int get _consecutiveDays => ReadingStatsHelper.computeConsecutiveDays(_trend);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: shellScaffoldColor,
      appBar: AppBar(title: const Text('统计')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('正在阅读', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: AppSpacing.sm),
                  _CurrentReadingCard(book: _lastBook),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('我的数据', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: AppSpacing.sm),
                  _DataGrid(
                    todayNewWords: _todayNewWords,
                    todayMinutes: _todayReadingMinutes,
                    totalMinutes: _totalMinutes,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text(
                    '近 7 日阅读时长（分钟）',
                    style: AppTextStyles.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: _MinutesTrendChart(data: _trend),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text('连续阅读', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: AppSpacing.sm),
                  _StreakCard(
                    trend: _trend,
                    consecutiveDays: _consecutiveDays,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}

class _CurrentReadingCard extends StatelessWidget {
  const _CurrentReadingCard({required this.book});

  final BookshelfItem? book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (book == null) {
      return SoftCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.book_outlined, color: theme.colorScheme.primary),
          title: const Text('导入书籍开始阅读'),
          subtitle: const Text('在书架页面导入 EPUB 文件'),
        ),
      );
    }
    final b = book!.book;
    return SoftCard.tappable(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.reader,
          arguments: b.id,
        );
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: b.coverPath != null
                ? Image.file(
                    File(b.coverPath!),
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _CoverPlaceholder(b.title),
                  )
                : _CoverPlaceholder(b.title),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (b.author != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    b.author!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: book!.progressFraction.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book!.progressPercent}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title[0] : '?',
        style: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _DataGrid extends StatelessWidget {
  const _DataGrid({
    required this.todayNewWords,
    required this.todayMinutes,
    required this.totalMinutes,
  });

  final int todayNewWords;
  final int todayMinutes;
  final int totalMinutes;

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _StatCell(
              icon: Icons.add_circle_outline,
              label: '今日新词',
              value: '$todayNewWords',
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.schedule_outlined,
              label: '今日阅读',
              value: '${todayMinutes}m',
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.timelapse_outlined,
              label: '累计时长',
              value: _formatMinutes(totalMinutes),
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTextStyles.statValue(context)),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MinutesTrendChart extends StatelessWidget {
  const _MinutesTrendChart({required this.data});

  final List<DailyMinutesStat> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('暂无阅读记录')),
      );
    }

    final maxMinutes = data.fold<int>(
      0,
      (max, item) => item.minutes > max ? item.minutes : max,
    );
    final scaleMax = maxMinutes == 0 ? 1 : maxMinutes;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in data)
            Expanded(
              child: _BarColumn(
                minutes: item.minutes,
                scaleMax: scaleMax,
                label: _shortDateLabel(item.date),
              ),
            ),
        ],
      ),
    );
  }

  String _shortDateLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[1]}/${parts[2]}';
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.minutes,
    required this.scaleMax,
    required this.label,
  });

  final int minutes;
  final int scaleMax;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = minutes == 0 ? 4.0 : 120.0 * minutes / scaleMax;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (minutes > 0)
            Text(
              '$minutes',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            const SizedBox(height: 14),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: barHeight.clamp(4.0, 120.0),
              decoration: BoxDecoration(
                color: minutes == 0
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.trend, required this.consecutiveDays});

  final List<DailyMinutesStat> trend;
  final int consecutiveDays;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  String _weekdayLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '周${_weekdayLabels[date.weekday - 1]}';
    } catch (_) {
      return '';
    }
  }

  String _dayLabel(String dateStr) {
    final parts = dateStr.split('-');
    return parts.length == 3 ? parts[2] : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final emptyColor = theme.colorScheme.surfaceContainerHighest;

    final streakText = consecutiveDays == 0 ? '尚未开始' : '连续 $consecutiveDays 天';
    final streakColor = consecutiveDays > 0
        ? primaryColor
        : theme.colorScheme.onSurfaceVariant;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            streakText,
            style: theme.textTheme.titleSmall?.copyWith(
              color: streakColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in trend)
                Column(
                  children: [
                    Text(
                      _weekdayLabel(item.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.minutes > 0 ? primaryColor : emptyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dayLabel(item.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
