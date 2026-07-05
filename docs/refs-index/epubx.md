# epubx 参考索引

- **仓库**：`https://github.com/ScerIO/epubx.dart`（本地 `refs/epubx/`）
- **pub 包**：`epubx`
- **本项目用途**：POC1 EPUB 导入管线 — 解压、读 spine/目录、按 manifest 分类资源、懒加载 HTML/图片

---

## 目录树（lib 层）

```
refs/epubx/lib/src/
├── epub_reader.dart          ★ 入口：openBook / readBook
├── readers/
│   ├── chapter_reader.dart   ★ 目录树（NavMap → EpubChapterRef）
│   ├── content_reader.dart   ★ manifest 分类（Html/Css/Images/Fonts）
│   ├── package_reader.dart   ○ OPF 包解析
│   ├── schema_reader.dart    ○ 元数据与 Schema
│   └── book_cover_reader.dart ○ 封面读取
├── ref_entities/             ★ 懒加载引用（POC1 首选，省内存）
│   ├── epub_book_ref.dart
│   ├── epub_chapter_ref.dart
│   ├── epub_content_file_ref.dart
│   ├── epub_text_content_file_ref.dart
│   └── epub_byte_content_file_ref.dart
├── schema/
│   ├── opf/                  ★ EpubPackage / EpubSpine / EpubManifest
│   └── navigation/           ★ EpubNavigation（目录 NCX/nav）
├── entities/                 ○ readBook 全量实体（POC1 可不使用）
└── utils/
    └── zip_path_utils.dart   ○ ZIP 内路径处理
```

★ = POC 直接相关　○ = 进阶/备选

---

## 核心 API

### 入口 — `epub_reader.dart`

```dart
// 轻量：元数据 + Content Map，不一次性加载全部正文（推荐 POC1）
EpubBookRef bookRef = await EpubReader.openBook(bytes);

// 全量：一次性读入所有章节内容（大书慎用）
EpubBook book = await EpubReader.readBook(bytes);
```

### 书籍引用 — `epub_book_ref.dart`

```dart
bookRef.Title                    // 书名
bookRef.Author                   // 作者
bookRef.Schema                   // EpubSchema（含 Package、Navigation）
bookRef.Content                  // EpubContentRef（Html/Css/Images/Fonts 映射）
bookRef.EpubArchive()            // 原始 ZIP Archive（按需读文件）

List<EpubChapterRef> chapters = await bookRef.getChapters();
Image? cover = await bookRef.readCover();
```

### 内容映射 — `content_reader.dart` 产出 `EpubContentRef`

```dart
bookRef.Content!.Html            // Map<String, EpubTextContentFileRef>  XHTML
bookRef.Content!.Css             // Map<String, EpubTextContentFileRef>  样式
bookRef.Content!.Images          // Map<String, EpubByteContentFileRef>  图片
bookRef.Content!.Fonts           // Map<String, EpubByteContentFileRef>  字体
bookRef.Content!.AllFiles        // 全部 manifest 项
```

### 读取文件内容 — `epub_content_file_ref.dart`

```dart
Future<String> readContentAsText()    // HTML / CSS 字符串
Future<Uint8List> readContentAsBytes() // 图片 / 字体字节
```

`EpubTextContentFileRef` 另有 `ReadContentAsync()`，内部调用 `readContentAsText()`。

### 章节 — `epub_chapter_ref.dart`

```dart
chapterRef.Title                 // 目录标题
chapterRef.ContentFileName       // manifest href（需 Uri.decodeFull）
chapterRef.Anchor                // 页内锚点（# 后部分）
chapterRef.SubChapters           // 子章节列表
chapterRef.otherTextContentFileRefs  // 拆章多文件时的其余 HTML

// 读取章节 HTML（含拆章合并）
Future<EpubChapter> readChapter() // 见 epub_chapter_ref.dart 后半部
```

### Spine / Manifest — `schema/opf/`

```dart
bookRef.Schema!.Package!.Spine!.Items       // List<EpubSpineItemRef>
bookRef.Schema!.Package!.Manifest!.Items     // List<EpubManifestItem>
bookRef.Schema!.Navigation!.NavMap!.Points   // 目录点（chapter_reader 使用）
```

---

## 导入管线步骤映射

对照 `docs/tech-stack.md` §3.2：

| 步骤 | 本项目动作 | epubx 参照 |
|------|-----------|------------|
| 1. 读 EPUB 字节 | `File.readAsBytes()` | `EpubReader.openBook(bytes)` |
| 2. 取元数据 | 写 `books` 表 title/author | `bookRef.Title`, `bookRef.Author` |
| 3. 取目录 | 写 `chapters` 表 | `bookRef.getChapters()` → 递归 `SubChapters` |
| 4. 遍历 spine/manifest | 确定 HTML 文件列表 | `Content.Html` keys 或 `Schema.Package.Spine` |
| 5. 读章节 HTML | 保存 `block_xxxx.html` | `EpubTextContentFileRef.readContentAsText()` |
| 6. 复制图片/CSS | 写入 `books/{id}/assets/` | `Content.Images` / `Content.Css` → `readContentAsBytes()` |
| 7. 路径重写 | HTML 内 src/href → `assets/...` | 自研逻辑；manifest `Href` 作原始路径参考 |
| 8. 超长子切 | >12000 字符拆多块 | 自研；读 HTML 后按 `String.length` 切 |
| 9. 写块元数据 | `content_blocks` 表 | 无直接 API |

---

## 最小调用示例

见 `refs/epubx/test/epub_reader_tests.dart`：

```dart
import 'package:epubx/epubx.dart';

List<int> bytes = await file.readAsBytes();
EpubBookRef epubRef = await EpubReader.openBook(bytes);
var chapters = await epubRef.getChapters();
```

---

## 常见陷阱

| 问题 | 说明 |
|------|------|
| 应用 `readBook` 导入大书 | 会一次性加载全部内容，内存峰值高；POC1 用 `openBook` + 按需 `readContentAsText` |
| href 未解码 | manifest `Href` 可能含 `%20` 等，需 `Uri.decodeFull` |
| 无 Navigation | `getChapters()` 返回空列表，需降级用 spine 顺序遍历 `Content.Html` |
| 类名大小写 | epubx 部分属性为大写开头（`Title`、`Author`），与常规 Dart 风格不同 |

---

## 关联文档

- 产品策略：`docs/tech-stack.md` §3（EPUB 路线 C）
- 数据写入：`docs/data-model.md` §books / chapters / content_blocks
- 场景矩阵：`scenario-map.md` POC1 各子任务
