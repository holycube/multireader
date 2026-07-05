import '../database/database.dart';

/// 根据滚动位置估算块内字符偏移（与字体/设备无关）。
int charOffsetFromScroll({
  required double scrollTop,
  required double blockTop,
  required double blockHeight,
  required int charCount,
}) {
  if (charCount <= 0 || blockHeight <= 0) return 0;
  final intoBlock = (scrollTop - blockTop).clamp(0.0, blockHeight);
  final ratio = intoBlock / blockHeight;
  return (ratio * charCount).round().clamp(0, charCount);
}

/// 根据字符偏移估算块内滚动像素。
double scrollOffsetForChar({
  required int charOffset,
  required int charCount,
  required double blockHeight,
}) {
  if (charCount <= 0 || blockHeight <= 0 || charOffset <= 0) return 0;
  final ratio = charOffset / charCount;
  return (ratio * blockHeight).clamp(0.0, blockHeight);
}

/// 从已加载块列表与滚动位置解析当前阅读进度。
({ContentBlock? block, int charOffset}) resolveReadingPosition({
  required double scrollTop,
  required List<({ContentBlock? block, double height})> blocks,
}) {
  if (blocks.isEmpty) return (block: null, charOffset: 0);

  var y = 0.0;
  for (final item in blocks) {
    final block = item.block;
    if (block == null) continue;

    final h = item.height;
    if (scrollTop < y + h) {
      return (
        block: block,
        charOffset: charOffsetFromScroll(
          scrollTop: scrollTop,
          blockTop: y,
          blockHeight: h,
          charCount: block.charCount,
        ),
      );
    }
    y += h;
  }

  final last = blocks.last.block;
  return (block: last, charOffset: last?.charCount ?? 0);
}
