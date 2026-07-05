import 'dart:convert';

import 'package:archive/archive.dart';

/// 构建最小可解析 EPUB（zip）供集成测试使用。
List<int> buildMinimalEpub({
  String title = 'Test Book',
  String author = 'Test Author',
  String chapterTitle = 'Chapter One',
  String bodyHtml = '<p>Hello world.</p>',
  String? imageFileName,
  List<int>? imageBytes,
  String? coverImageFileName,
  List<int>? coverImageBytes,
  bool coverViaManifestProperty = false,
}) {
  final chapterXhtml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>$chapterTitle</title></head>
<body>
$bodyHtml
</body>
</html>''';

  final manifestItems = StringBuffer()
    ..writeln('    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>')
    ..writeln(
      '    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>',
    );

  final manifestRefs = StringBuffer()
    ..writeln('    <itemref idref="chapter1"/>');

  if (imageFileName != null && imageBytes != null) {
    manifestItems.writeln(
      '    <item id="img1" href="$imageFileName" media-type="image/png"/>',
    );
  }

  if (coverImageFileName != null && coverImageBytes != null) {
    manifestItems.writeln(
      '    <item id="cover-image" href="$coverImageFileName" media-type="image/png" properties="cover-image"/>',
    );
    if (coverViaManifestProperty) {
      // cover-image property already set above
    }
  }

  final metadataExtra = coverViaManifestProperty && coverImageFileName != null
      ? '    <meta name="cover" content="cover-image"/>'
      : '';

  final contentOpf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:identifier id="BookId">urn:uuid:test-book</dc:identifier>
    <dc:language>en</dc:language>
$metadataExtra
  </metadata>
  <manifest>
$manifestItems
  </manifest>
  <spine toc="ncx">
$manifestRefs
  </spine>
</package>''';

  final tocNcx = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:test-book"/>
  </head>
  <docTitle><text>$title</text></docTitle>
  <navMap>
    <navPoint id="nav1" playOrder="1">
      <navLabel><text>$chapterTitle</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';

  final containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

  final archive = Archive();
  archive.addFile(
    ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip'))
      ..compress = false,
  );
  archive.addFile(
    ArchiveFile('META-INF/container.xml', containerXml.length, utf8.encode(containerXml)),
  );
  archive.addFile(
    ArchiveFile('OEBPS/content.opf', contentOpf.length, utf8.encode(contentOpf)),
  );
  archive.addFile(
    ArchiveFile('OEBPS/toc.ncx', tocNcx.length, utf8.encode(tocNcx)),
  );
  archive.addFile(
    ArchiveFile('OEBPS/chapter1.xhtml', chapterXhtml.length, utf8.encode(chapterXhtml)),
  );

  if (imageFileName != null && imageBytes != null) {
    archive.addFile(
      ArchiveFile('OEBPS/$imageFileName', imageBytes.length, imageBytes),
    );
  }

  if (coverImageFileName != null && coverImageBytes != null) {
    archive.addFile(
      ArchiveFile('OEBPS/$coverImageFileName', coverImageBytes.length, coverImageBytes),
    );
  }

  return ZipEncoder().encode(archive)!;
}

String longBodyHtml(int plainCharTarget) {
  const word = 'Lorem';
  final repeats = (plainCharTarget / word.length).ceil() + 1;
  final plain = List.filled(repeats, word).join(' ');
  return '<p>$plain</p>';
}
