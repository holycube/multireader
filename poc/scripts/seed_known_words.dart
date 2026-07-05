// ??Drift ???????????? POC2 ?? 40k Set ???????
//
// ???? poc ????
//   dart run scripts/seed_known_words.dart [??????40000] --db-path=C:\path\to\novel-reader.sqlite
//
// Android ???? DB ???? USB ????
//   adb shell run-as com.novelreader.multireader ls files/
//   adb exec-out run-as com.novelreader.multireader cat files/novel-reader.sqlite > novel-reader.sqlite
//   dart run scripts/seed_known_words.dart 40000 --db-path=novel-reader.sqlite
//   adb push novel-reader.sqlite /data/local/tmp/
//   adb shell run-as com.novelreader.multireader cp /data/local/tmp/novel-reader.sqlite files/novel-reader.sqlite
//
// ????debug ?????????40k ????????????????
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:multi_novel_reader/database/database.dart';

void main(List<String> args) async {
  final count = _parseCount(args);
  final dbPath = _parseDbPath(args);
  if (dbPath == null) {
    stderr.writeln(
      '??: dart run scripts/seed_known_words.dart [??] --db-path=<sqlite ????>',
    );
    stderr.writeln('?? App debug ????????40k ???????????);
    exit(1);
  }

  final file = File(dbPath);
  if (!await file.exists()) {
    stderr.writeln('????????: $dbPath');
    exit(1);
  }

  final db = AppDatabase(NativeDatabase(file));
  try {
    final sw = Stopwatch()..start();
    final total = await db.seedKnownWords(count: count);
    sw.stop();
    stdout.writeln('????$count ??????$total ????? ${sw.elapsedMilliseconds}ms');
    stdout.writeln('???????? App????????????????);
  } finally {
    await db.close();
  }
}

int _parseCount(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--')) continue;
    final n = int.tryParse(arg);
    if (n != null && n > 0) return n;
  }
  return 40000;
}

String? _parseDbPath(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--db-path=')) {
      return arg.substring('--db-path='.length);
    }
  }
  return null;
}
