import 'package:flutter/material.dart';

import '../database/database.dart';

/// 章节目录抽屉：列出 [Chapter] 表，点击跳转章首块。
class ChapterDrawer extends StatelessWidget {
  const ChapterDrawer({
    super.key,
    required this.bookId,
    required this.db,
    this.currentChapterId,
    required this.onChapterSelected,
  });

  final String bookId;
  final AppDatabase db;
  final String? currentChapterId;
  final ValueChanged<Chapter> onChapterSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '目录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Chapter>>(
                future: db.getChaptersByBook(bookId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('加载目录失败：${snapshot.error}'));
                  }
                  final chapters = snapshot.data ?? [];
                  if (chapters.isEmpty) {
                    return const Center(child: Text('暂无章节'));
                  }
                  return ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      final selected = chapter.id == currentChapterId;
                      return ListTile(
                        selected: selected,
                        title: Text(
                          chapter.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: chapter.blockCount > 1
                            ? Text('${chapter.blockCount} 块')
                            : null,
                        onTap: () => onChapterSelected(chapter),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
