# 参考库索引 — 总导航

本目录是可版本管理的**检索入口**；完整源码在本地 `refs/`（不进 git，只读参照）。

## 三库对照

| 本地目录 | pub 包名 | 用途 | 详细索引 |
|----------|----------|------|----------|
| `refs/epubx/` | `epubx` | EPUB 解压、spine、目录、HTML/资源读取 | [epubx.md](./epubx.md) |
| `refs/flutter_widget_from_html/` | `flutter_widget_from_html` / `flutter_widget_from_html_core` | HTML 渲染、WidgetFactory 扩展、词 span 点击 | [fwfh.md](./fwfh.md) |
| `refs/drift/` | `drift` / `drift_flutter` | SQLite Schema、DAO、迁移 | [drift.md](./drift.md) |

> **注意**：`flutter_widget_from_html_core` 的物理路径是 `refs/flutter_widget_from_html/packages/core/`，不是 `packages/flutter_widget_from_html_core/`。

## 使用流程

1. 根据开发任务查下方 **POC 速查表**，确定索引文档
2. 读对应索引文档，定位 1–3 个源码文件
3. 打开 `refs/` 中文件核对真实 API（禁止编造类名/方法）
4. 业务规则以 `docs/tech-stack.md`、`docs/data-model.md` 为准

完整场景矩阵见 [scenario-map.md](./scenario-map.md)。

## POC 速查表

| POC 任务 | 索引文档 | 首要源码路径 |
|----------|----------|--------------|
| EPUB 解压与元数据 | [epubx.md](./epubx.md) | `refs/epubx/lib/src/epub_reader.dart` |
| Spine / 目录 / 章节树 | epubx.md | `refs/epubx/lib/src/readers/chapter_reader.dart` |
| Manifest 资源分类（HTML/CSS/图片） | epubx.md | `refs/epubx/lib/src/readers/content_reader.dart` |
| 读取章节 HTML 与图片字节 | epubx.md | `refs/epubx/lib/src/ref_entities/epub_content_file_ref.dart` |
| Drift 八表 Schema | [drift.md](./drift.md) | `refs/drift/examples/app/lib/database/tables.dart` |
| 数据库连接 / 迁移 | drift.md | `refs/drift/examples/app/lib/database/database.dart` |
| HTML 渲染入口 | [fwfh.md](./fwfh.md) | `refs/flutter_widget_from_html/packages/core/lib/src/core_html_widget.dart` |
| 自定义 span 点击 / 下划线 | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/core_widget_factory.dart` |
| 链接点击范例（可类比 span.word） | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/internal/ops/tag_a.dart` |
| 虚线下划线样式 | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/internal/ops/style_text_decoration.dart` |
| POC1/POC2 全场景对照 | [scenario-map.md](./scenario-map.md) | — |

## 检索关键词

> **唯一维护处**：增删关键词只改本节；`.cursor/rules/refs-context.mdc` 仅链接到本文档。

| 关键词（中/英） | 查 |
|-----------------|-----|
| EPUB、spine、目录、manifest、章节、导入 | [epubx.md](./epubx.md) |
| HTML 渲染、span、高亮、点击、WidgetFactory、下划线 | [fwfh.md](./fwfh.md) |
| Drift、Table、DAO、迁移、SQLite、词库、quota | [drift.md](./drift.md) |
| POC1、POC2、分块、解锁、查词 | [scenario-map.md](./scenario-map.md) |

## 禁止事项

- 不修改 `refs/` 内任何文件
- 不把 `refs/` 提交到版本库
- API 以 `refs/` 源码为准；产品与 Schema 以 `docs/` 为准
