import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../database/database.dart';
import '../import/epub_importer.dart';
import '../import/import_result.dart';
import '../import/txt_importer.dart';
import '../vocab/dict_loader.dart';
import '../vocab/known_words_cache.dart';
import '../widgets/book_card.dart';
import '../widgets/empty_bookshelf.dart';
import 'resources_screen.dart';
import 'shell_appearance_mixin.dart';

/// 书架首页：列表、导入、空状态，按最近阅读排序。
class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({
    super.key,
    this.onDatabaseReady,
    this.isTabActive = true,
  });

  final void Function(AppDatabase db)? onDatabaseReady;
  final bool isTabActive;

  @override
  State<BookshelfScreen> createState() => BookshelfScreenState();
}

class BookshelfScreenState extends State<BookshelfScreen>
    with ShellAppearanceMixin {
  bool _importing = false;
  StreamSubscription<List<BookshelfItem>>? _shelfSubscription;
  List<BookshelfItem> _items = const [];
  bool _shelfReady = false;

  @override
  void didUpdateWidget(covariant BookshelfScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      onTabActivated();
    }
  }

  KnownWordsCache get _knownWordsCache => AppScope.of(context).knownWordsCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initShelf());
      unawaited(_warmCaches());
    });
  }

  @override
  void dispose() {
    unawaited(_shelfSubscription?.cancel());
    super.dispose();
  }

  Future<void> _initShelf() async {
    final db = await _database();
    await _shelfSubscription?.cancel();
    _shelfSubscription = db.watchBookshelfItems().listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _shelfReady = true;
      });
    });
  }

  Future<void> _warmCaches() async {
    final db = await _database();
    final cacheSw = Stopwatch()..start();
    await Future.wait([
      _knownWordsCache.load(db),
      DictLoader.instance.load(),
    ]);
    cacheSw.stop();
    if (kDebugMode) {
      debugPrint(
        '[POC2] cache warm known=${_knownWordsCache.words.length} '
        'dict=${DictLoader.instance.entryCount} '
        'db=${_knownWordsCache.lastLoadDbMs}ms '
        'set=${_knownWordsCache.lastLoadSetMs}ms '
        'total=${_knownWordsCache.lastLoadTotalMs}ms',
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _seedKnownWordsForAcceptance() async {
    if (!kDebugMode) return;
    final db = await _database();
    setState(() => _importing = true);
    try {
      final sw = Stopwatch()..start();
      final total = await db.seedKnownWords(count: 40000);
      sw.stop();
      _knownWordsCache.invalidate();
      final loadSw = Stopwatch()..start();
      await _knownWordsCache.load(db);
      loadSw.stop();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已写入 40k 词（库内 $total）；冷加载 ${loadSw.elapsedMilliseconds}ms。'
            '请杀进程后冷启动复测。',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      debugPrint(
        '[POC2] seed 40k write=${sw.elapsedMilliseconds}ms '
        'reload=${loadSw.elapsedMilliseconds}ms '
        'db=${_knownWordsCache.lastLoadDbMs}ms '
        'set=${_knownWordsCache.lastLoadSetMs}ms',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('写入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<AppDatabase>? _dbFuture;

  Future<AppDatabase> _database() {
    return _dbFuture ??= _openDatabase();
  }

  Future<AppDatabase> _openDatabase() async {
    final db = await AppScope.of(context).database();
    widget.onDatabaseReady?.call(db);
    return db;
  }

  Future<void> importBook() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub', 'txt'],
    );
    if (picked == null || picked.files.single.path == null) return;

    final path = picked.files.single.path!;
    final ext = path.split('.').last.toLowerCase();

    setState(() => _importing = true);

    try {
      final db = await _database();
      final ImportResult result;
      if (ext == 'epub') {
        final importer = await EpubImporter.create(db);
        result = await importer.importFromFile(File(path));
      } else if (ext == 'txt') {
        final importer = await TxtImporter.create(db);
        result = await importer.importFromFile(File(path));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持 EPUB 或 TXT 文件')),
        );
        return;
      }

      widget.onDatabaseReady?.call(db);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入成功：${result.title}')),
      );
    } on ImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openReader(String bookId) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: bookId,
    );
  }

  Future<void> _confirmDeleteBook(BookshelfItem item) async {
    final book = item.book;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定从书架删除「${book.title}」？\n阅读进度与生词关联将一并清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final db = await _database();
      await db.deleteBookCascade(book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除「${book.title}」')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  void _openResourcesGuide() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ResourcesScreen(),
      ),
    );
  }

  void _onDevMenuSelected(String value) {
    final scope = AppScope.of(context);
    switch (value) {
      case 'perf':
        scope.togglePerfOverlay?.call();
      case 'seed40k':
        unawaited(_seedKnownWordsForAcceptance());
    }
  }

  @override
  Widget build(BuildContext context) {
    final devToggle = AppScope.of(context).togglePerfOverlay;

    return Scaffold(
      backgroundColor: shellScaffoldColor,
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            tooltip: '导入书籍',
            onPressed: _importing ? null : importBook,
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
          if (kDebugMode && devToggle != null)
            PopupMenuButton<String>(
              tooltip: '开发菜单',
              onSelected: _onDevMenuSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'perf',
                  child: Text('切换性能叠加层（fps）'),
                ),
                PopupMenuItem(
                  value: 'seed40k',
                  child: Text('写入 40k 词库（验收）'),
                ),
              ],
              icon: const Icon(Icons.developer_mode_outlined),
            ),
        ],
      ),
      body: !_shelfReady
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? EmptyBookshelf(
                  importing: _importing,
                  onImport: importBook,
                  onOpenResourcesGuide: _openResourcesGuide,
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final book = item.book;
                    return BookCard(
                      title: book.title,
                      author: book.author,
                      coverPath: book.coverPath,
                      progressPercent: item.progressPercent,
                      lastReadAt: item.lastReadAt,
                      onTap: () => _openReader(book.id),
                      onDelete: () => unawaited(_confirmDeleteBook(item)),
                    );
                  },
                ),
    );
  }
}
