import 'package:path/path.dart' as p;

/// 将 HTML 内资源引用重写为 `assets/...` 相对路径。
class HtmlPathRewriter {
  /// [assetMap]：EPUB 内路径（decode 后或原始 key）→ `assets/xxx`
  static String rewrite(String html, String htmlFileHref, Map<String, String> assetMap) {
    if (assetMap.isEmpty) return html;

    return html.replaceAllMapped(
      RegExp(
        r'''(src|href)\s*=\s*(["'])(.*?)\2''',
        caseSensitive: false,
      ),
      (match) {
        final attr = match.group(1)!;
        final quote = match.group(2)!;
        final url = match.group(3)!.trim();
        final rewritten = _rewriteUrl(url, htmlFileHref, assetMap);
        return '$attr=$quote$rewritten$quote';
      },
    );
  }

  static String _rewriteUrl(
    String url,
    String htmlFileHref,
    Map<String, String> assetMap,
  ) {
    if (url.isEmpty) return url;
    if (url.startsWith('#')) return url;
    if (url.contains('://')) return url;
    if (url.startsWith('data:')) return url;

    final resolved = _resolveEpubPath(htmlFileHref, url);
    final decoded = Uri.decodeFull(resolved);

    if (assetMap.containsKey(decoded)) return assetMap[decoded]!;
    if (assetMap.containsKey(resolved)) return assetMap[resolved]!;

    final basename = p.basename(decoded);
    for (final entry in assetMap.entries) {
      if (p.basename(entry.key) == basename) {
        return entry.value;
      }
    }

    return url;
  }

  static String _resolveEpubPath(String baseHref, String relative) {
    if (relative.startsWith('/')) {
      return p.normalize(relative.substring(1)).replaceAll('\\', '/');
    }
    final baseDir = p.dirname(baseHref);
    return p.normalize(p.join(baseDir, relative)).replaceAll('\\', '/');
  }
}
