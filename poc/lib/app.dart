import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'database/database.dart';
import 'reader/reader_screen.dart';
import 'screens/main_shell.dart';
import 'screens/vocab_wizard/vocab_wizard_screen.dart';
import 'services/app_theme_notifier.dart';
import 'theme/app_theme.dart';
import 'vocab/dict_loader.dart';
import 'vocab/known_words_cache.dart';

/// 命名路由表（Sprint 0 骨架；Wave 2 扩展启动路由）。
abstract final class AppRoutes {
  static const startup = '/';
  static const vocabWizard = VocabWizardScreen.routeName;
  static const mainShell = MainShell.routeName;
  static const reader = '/reader';
}

/// 全局依赖：数据库工厂与词库缓存。
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.database,
    required this.knownWordsCache,
    required this.appThemeNotifier,
    this.togglePerfOverlay,
    required super.child,
  });

  final Future<AppDatabase> Function() database;
  final KnownWordsCache knownWordsCache;
  final AppThemeNotifier appThemeNotifier;
  final VoidCallback? togglePerfOverlay;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      knownWordsCache != oldWidget.knownWordsCache ||
      appThemeNotifier != oldWidget.appThemeNotifier ||
      togglePerfOverlay != oldWidget.togglePerfOverlay;
}

/// MVP 产品壳入口。
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _showPerfOverlay = false;
  final KnownWordsCache _knownWordsCache = KnownWordsCache();
  AppDatabase? _db;
  AppThemeNotifier? _themeNotifier;

  Future<AppDatabase> _database() async => _db ??= AppDatabase();

  void _rememberDatabase(AppDatabase db) => _db = db;

  @override
  void initState() {
    super.initState();
    _initTheme();
  }

  Future<void> _initTheme() async {
    final notifier = await AppThemeNotifier.load();
    if (!mounted) return;
    setState(() => _themeNotifier = notifier);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = _themeNotifier;
    if (themeNotifier == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AppScope(
      database: _database,
      knownWordsCache: _knownWordsCache,
      appThemeNotifier: themeNotifier,
      togglePerfOverlay:
          kDebugMode ? () => setState(() => _showPerfOverlay = !_showPerfOverlay) : null,
      child: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) {
          return MaterialApp(
            title: '小说阅读器',
            debugShowCheckedModeBanner: false,
            showPerformanceOverlay: kDebugMode && _showPerfOverlay,
            theme: buildAppTheme(themeNotifier.prefs),
            initialRoute: AppRoutes.startup,
            routes: {
              AppRoutes.startup: (_) => _StartupGate(onDatabaseReady: _rememberDatabase),
              AppRoutes.vocabWizard: (_) => const VocabWizardScreen(),
              AppRoutes.mainShell: (_) => MainShell(onDatabaseReady: _rememberDatabase),
            },
            onGenerateRoute: (settings) {
              if (settings.name != AppRoutes.reader) return null;
              final bookId = settings.arguments as String?;
              if (bookId == null || bookId.isEmpty) return null;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => _ReaderRouteLoader(bookId: bookId),
              );
            },
          );
        },
      ),
    );
  }
}

/// 启动闸门：词库为空时进入向导，否则进入主导航。
class _StartupGate extends StatefulWidget {
  const _StartupGate({this.onDatabaseReady});

  final void Function(AppDatabase db)? onDatabaseReady;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  double? _downloadProgress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRoute());
  }

  Future<void> _resolveRoute() async {
    if (!mounted) return;

    DictLoader.instance.clearPendingLoad();

    setState(() {
      _errorMessage = null;
      _downloadProgress = kReleaseMode ? 0 : null;
    });

    final scope = AppScope.of(context);
    final dbFuture = scope.database();

    try {
      await DictLoader.instance.load(
        onProgress: kReleaseMode
            ? (value) {
                if (mounted) {
                  setState(() => _downloadProgress = value);
                }
              }
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _downloadProgress = null;
      });
      return;
    }

    final db = await dbFuture;
    widget.onDatabaseReady?.call(db);

    final words = await db.getKnownWordStrings();
    if (!mounted) return;

    final route = words.isEmpty ? AppRoutes.vocabWizard : AppRoutes.mainShell;
    await Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '词典下载失败',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _resolveRoute,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (kReleaseMode && _downloadProgress != null && _downloadProgress! < 1) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '正在下载词典…',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Text('${(_downloadProgress! * 100).round()}%'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ReaderRouteLoader extends StatelessWidget {
  const _ReaderRouteLoader({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FutureBuilder<AppDatabase>(
      future: scope.database(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('无法打开阅读器')),
          );
        }
        return ReaderScreen(
          bookId: bookId,
          db: snapshot.data!,
          knownWordsCache: scope.knownWordsCache,
        );
      },
    );
  }
}
