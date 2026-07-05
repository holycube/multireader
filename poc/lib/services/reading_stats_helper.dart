import '../database/database.dart';

/// 阅读统计衍生指标（连续天数等）。
abstract final class ReadingStatsHelper {
  /// 从昨天往前数连续有阅读记录的天数；若今天也有记录则加 1。
  static int computeConsecutiveDays(List<DailyMinutesStat> trend) {
    if (trend.isEmpty) return 0;
    var count = 0;
    for (var i = trend.length - 2; i >= 0; i--) {
      if (trend[i].minutes > 0) {
        count++;
      } else {
        break;
      }
    }
    if (trend.last.minutes > 0) count++;
    return count;
  }
}
