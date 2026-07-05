# POC1 验收样书（本地生成，不提交 git）

| 文件 | 用途 | 生成方式 |
|------|------|----------|
| `poc_large_310blocks.txt` | 300+ 块导入与内存测试 | `dart run scripts/generate_large_txt.dart 310` |
| `alice_gutenberg.epub` | 带图 EPUB 测试 | 从 [Gutenberg #11](https://www.gutenberg.org/ebooks/11) 下载 `.epub.images` 版 |

验收测试 `poc1_acceptance_test.dart` 会在运行时自动生成 TXT；EPUB 优先使用本目录下的 `alice_gutenberg.epub`，否则回退到程序生成的带图最小 EPUB。
