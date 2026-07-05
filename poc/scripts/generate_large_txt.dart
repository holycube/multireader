// 生成 POC1 验收用超长 TXT（无 Chapter 头，触发 12000 字兜底切块）。
// 用法：dart run scripts/generate_large_txt.dart [块数，默认 310]
import 'dart:io';

void main(List<String> args) {
  final blockCount = int.tryParse(args.isNotEmpty ? args.first : '') ?? 310;
  if (blockCount < 1) {
    stderr.writeln('块数须为正整数');
    exit(1);
  }

  final charCount = blockCount * 12000;
  final buffer = StringBuffer();
  for (var i = 0; i < charCount; i++) {
    buffer.write('a');
    if ((i + 1) % 100 == 0) buffer.write(' ');
    if ((i + 1) % 800 == 0) buffer.writeln();
  }

  final outDir = Directory('test/fixtures');
  outDir.createSync(recursive: true);
  final outFile = File('${outDir.path}/poc_large_${blockCount}blocks.txt');
  outFile.writeAsStringSync(buffer.toString());

  stdout.writeln('已生成 ${outFile.path}');
  stdout.writeln('字符数：$charCount（预期 $blockCount 块）');
}
