import 'package:flutter/material.dart';
import 'package:multi_novel_reader/app.dart';
import 'package:multi_novel_reader/database/database.dart';
import 'package:multi_novel_reader/services/app_theme_notifier.dart';
import 'package:multi_novel_reader/vocab/known_words_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ??? AppScope ?????? Notifier??
Future<Widget> wrapWithAppScope({
  required AppDatabase db,
  required Widget child,
  KnownWordsCache? knownWordsCache,
}) async {
  SharedPreferences.setMockInitialValues({});
  final themeNotifier = await AppThemeNotifier.load();
  return AppScope(
    database: () async => db,
    knownWordsCache: knownWordsCache ?? KnownWordsCache(),
    appThemeNotifier: themeNotifier,
    child: child,
  );
}
