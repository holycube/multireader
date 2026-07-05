/// 数据库业务常量，对齐 docs/data-model.md §8。
abstract final class DbConstants {
  /// v1.0+：导入后 `parse_quota.unlocked_block_count` 等于 `books.total_blocks`（全书可读）。
  static const String parseQuotaPolicyFullBook = 'full_book';

  /// 旧版免费额度（40 块墙）；仅表 schema 默认值与迁移对照，新代码勿引用。
  @Deprecated('v1.0 全书可读；使用 initParseQuota(bookId, totalBlocks: n)')
  static const int defaultFreeAllowance = 40;

  @Deprecated('v1.0 已移除广告解锁')
  static const int adUnlockIncrement = 100;

  // books.importStatus
  static const String importStatusPending = 'pending';
  static const String importStatusComplete = 'complete';
  static const String importStatusFailed = 'failed';

  // books.sourceFormat
  static const String sourceFormatEpub = 'epub';
  static const String sourceFormatTxt = 'txt';

  // content_blocks.storageType
  static const String storageTypeHtml = 'html';
  static const String storageTypePlain = 'plain';

  // content_blocks.parseStatus
  static const String parseStatusPending = 'pending';
  static const String parseStatusProcessing = 'processing';
  static const String parseStatusDone = 'done';
  static const String parseStatusFailed = 'failed';

  // known_words.source
  static const String wordSourceUser = 'user';
}
