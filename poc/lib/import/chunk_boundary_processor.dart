import 'dart:io';

import '../database/constants.dart';
import '../database/database.dart';
import '../services/chunker_service.dart';
import 'plain_text_utils.dart';

/// Post-import syntactic chunk boundary analysis; failures are silently skipped.
class ChunkBoundaryProcessor {
  const ChunkBoundaryProcessor._();

  static Future<void> processBook(AppDatabase db, String bookId) async {
    final blocks = await db.getContentBlocksByBook(bookId);
    for (final block in blocks) {
      try {
        final file = File(block.contentPath);
        if (!await file.exists()) continue;

        final raw = await file.readAsString();
        final plainText = block.storageType == DbConstants.storageTypeHtml
            ? stripHtmlTagsForSplit(raw)
            : raw;
        if (plainText.trim().isEmpty) continue;

        final boundaries =
            await ChunkerService.instance.getBoundaries(plainText);
        await db.saveChunkBoundaries(block.id, boundaries);
      } catch (_) {
        // Silent skip — do not block import success.
      }
    }
  }
}
