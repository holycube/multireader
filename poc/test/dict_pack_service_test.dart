import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:multi_novel_reader/services/dict_pack_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dictContent;
  late String aliasesContent;
  late String dictSha;
  late String aliasesSha;
  late String manifestJson;
  const manifestUrl = 'https://test.example.com/dict/v1/manifest.json';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dict_pack_test_');
    DictPackService.resetInstanceForTesting(
      manifestUrlOverride: manifestUrl,
    );
    DictPackService.debugCacheRoot = tempDir;

    dictContent =
        '{"hello":{"word":"hello","senses":[{"pos":"int.","meanings":[{"text":"hi","primary":true}]}]}}';
    aliasesContent = '{"greetings":{"lemma":"hello","exchangeKey":"s"}}';
    dictSha = sha256.convert(utf8.encode(dictContent)).toString();
    aliasesSha = sha256.convert(utf8.encode(aliasesContent)).toString();
    manifestJson = jsonEncode({
      'version': '1',
      'dict': {
        'url': 'https://test.example.com/dict/v1/mvp_dict.json',
        'sha256': dictSha,
        'sizeBytes': dictContent.length,
      },
      'aliases': {
        'url': 'https://test.example.com/dict/v1/mvp_dict_aliases.json',
        'sha256': aliasesSha,
        'sizeBytes': aliasesContent.length,
      },
    });
  });

  tearDown(() async {
    DictPackService.instance.dispose();
    DictPackService.debugCacheRoot = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  http.Client buildMockClient() {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.url.toString() == manifestUrl) {
        return http.Response(manifestJson, 200);
      }
      if (path.endsWith('/mvp_dict.json')) {
        return http.Response.bytes(utf8.encode(dictContent), 200);
      }
      if (path.endsWith('/mvp_dict_aliases.json')) {
        return http.Response.bytes(utf8.encode(aliasesContent), 200);
      }
      return http.Response('not found', 404);
    });
  }

  test('ensureInstalled downloads files and writes manifest', () async {
    DictPackService.resetInstanceForTesting(
      client: buildMockClient(),
      manifestUrlOverride: manifestUrl,
    );
    DictPackService.debugCacheRoot = tempDir;
    final service = DictPackService.instance;

    final progress = <double>[];
    await service.ensureInstalled(onProgress: progress.add);

    expect(await service.isCacheValid(), isTrue);
    expect(progress.last, 1.0);

    final dir = await service.cacheDirectory();
    expect(await service.dictFile(dir).readAsString(), dictContent);
    expect(await service.aliasesFile(dir).readAsString(), aliasesContent);
    expect(await service.manifestFile(dir).readAsString(), manifestJson);
  });

  test('ensureInstalled is idempotent when cache is valid', () async {
    DictPackService.resetInstanceForTesting(
      client: buildMockClient(),
      manifestUrlOverride: manifestUrl,
    );
    DictPackService.debugCacheRoot = tempDir;
    final service = DictPackService.instance;
    await service.ensureInstalled();

    var requestCount = 0;
    DictPackService.resetInstanceForTesting(
      client: MockClient((request) async {
        requestCount++;
        return http.Response('unexpected', 500);
      }),
      manifestUrlOverride: manifestUrl,
    );
    DictPackService.debugCacheRoot = tempDir;

    await DictPackService.instance.ensureInstalled();
    expect(requestCount, 0);
    expect(await DictPackService.instance.isCacheValid(), isTrue);
  });

  test('ensureInstalled rejects bad sha256', () async {
    final badClient = MockClient((request) async {
      if (request.url.toString() == manifestUrl) {
        return http.Response(manifestJson, 200);
      }
      if (request.url.path.endsWith('/mvp_dict.json')) {
        return http.Response.bytes(utf8.encode('corrupted'), 200);
      }
      if (request.url.path.endsWith('/mvp_dict_aliases.json')) {
        return http.Response.bytes(utf8.encode(aliasesContent), 200);
      }
      return http.Response('not found', 404);
    });

    DictPackService.resetInstanceForTesting(
      client: badClient,
      manifestUrlOverride: manifestUrl,
    );
    DictPackService.debugCacheRoot = tempDir;

    expect(
      () => DictPackService.instance.ensureInstalled(),
      throwsA(isA<DictPackException>()),
    );

    final dir = await DictPackService.instance.cacheDirectory();
    expect(await DictPackService.instance.dictFile(dir).exists(), isFalse);
    expect(
      await File('${DictPackService.instance.dictFile(dir).path}.part').exists(),
      isFalse,
    );
  });

  test('ensureInstalled requires manifest url', () async {
    DictPackService.resetInstanceForTesting(manifestUrlOverride: '');

    expect(
      () => DictPackService.instance.ensureInstalled(),
      throwsA(
        isA<DictPackException>().having(
          (e) => e.message,
          'message',
          contains('DICT_PACK_MANIFEST_URL'),
        ),
      ),
    );
  });

  test('DictPackManifest parses dict and aliases format', () {
    final manifest = DictPackManifest.parse(manifestJson);
    expect(manifest.version, '1');
    expect(manifest.fileFor(DictPackService.dictFileName)?.sha256, dictSha);
    expect(
      manifest.fileFor(DictPackService.aliasesFileName)?.sha256,
      aliasesSha,
    );
  });
}
