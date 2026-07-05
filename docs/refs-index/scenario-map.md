# POC 场景矩阵

将 POC1 / POC2 每个子任务映射到：**项目文档 → 索引文档 → 源码路径**。

---

## POC1 — 导入与分块（P0-05）

| 子任务 | 项目文档 | 索引 | 源码路径 |
|--------|----------|------|----------|
| EPUB 文件读取 | `poc-plan.md` POC1 | [epubx.md](./epubx.md) | `refs/epubx/lib/src/epub_reader.dart` |
| 解析元数据（书名/作者） | `data-model.md` §books | epubx.md | `refs/epubx/lib/src/ref_entities/epub_book_ref.dart` |
| 解析目录树 | `data-model.md` §chapters | epubx.md | `refs/epubx/lib/src/readers/chapter_reader.dart` |
| Manifest 资源分类 | `tech-stack.md` §3.5 | epubx.md | `refs/epubx/lib/src/readers/content_reader.dart` |
| 读取章节 HTML | `tech-stack.md` §3.2 | epubx.md | `refs/epubx/lib/src/ref_entities/epub_text_content_file_ref.dart` |
| 复制图片/CSS 到 assets | `tech-stack.md` §3.5 | epubx.md | `refs/epubx/lib/src/ref_entities/epub_byte_content_file_ref.dart` |
| HTML 路径重写 | `tech-stack.md` §3.5 | — | 自研（manifest `Href` 作参考） |
| 12000 字符子切 | `tech-stack.md` §8 | — | 自研（读 HTML 后按 `String.length` 切） |
| TXT 正则分章 | `tech-stack.md` §3.6 | — | 自研 |
| TXT 兜底切块 | `tech-stack.md` §3.6 | — | 自研 |
| 块文件写入私有目录 | `tech-stack.md` §5 | — | 自研（`path_provider`） |
| Drift 写 books/chapters/content_blocks | `data-model.md` §3 | [drift.md](./drift.md) | `refs/drift/examples/app/lib/database/tables.dart` |
| 初始化 parse_quota | `data-model.md` §parse_quota | drift.md | `refs/drift/examples/app/lib/database/database.dart` |
| 按块加载渲染（无高亮） | `poc-plan.md` POC1 | [fwfh.md](./fwfh.md) | `refs/flutter_widget_from_html/packages/core/lib/src/core_html_widget.dart` |
| 封面提取 | `data-model.md` §books.coverPath | epubx.md | `refs/epubx/lib/src/readers/book_cover_reader.dart` |

### POC1 推荐阅读顺序

1. `docs/tech-stack.md` §3.2、§3.5、§5
2. `docs/refs-index/epubx.md` → `epub_reader.dart` → `chapter_reader.dart` → `content_file_ref.dart`
3. `docs/refs-index/drift.md` → `tables.dart` → `database.dart`
4. `docs/refs-index/fwfh.md` → `core_html_widget.dart`（仅基础渲染）

---

## POC2 — 高亮、查词与解锁（P0-06）

| 子任务 | 项目文档 | 索引 | 源码路径 |
|--------|----------|------|----------|
| 词库加载到 Set | `tech-stack.md` §2 | drift.md | `refs/drift/examples/app/lib/database/database.dart` |
| HTML 文本节点遍历 | `tech-stack.md` §3.3 | — | 自研（可用 `html` 包解析 DOM） |
| 注入 span.word | `tech-stack.md` §6.3 | — | 自研 |
| HTML 渲染带高亮 | `tech-stack.md` §4 | [fwfh.md](./fwfh.md) | `refs/flutter_widget_from_html/packages/core/lib/src/core_html_widget.dart` |
| span 词点击 | `tech-stack.md` §4 | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/internal/ops/tag_a.dart` |
| 自定义 WidgetFactory | `tech-stack.md` §4 | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/core_widget_factory.dart` |
| 虚线下划线样式 | `tech-stack.md` §6.2 | fwfh.md | `refs/flutter_widget_from_html/packages/core/lib/src/internal/ops/style_text_decoration.dart` |
| TXT TextSpan 逐词 | `tech-stack.md` §3.6、§4 | — | 自研（Flutter `Text.rich`） |
| 词归一化 | `tech-stack.md` §6.1 | — | 自研 |
| 假词典 JSON 查词 | `tech-stack.md` §7 | — | 自研 |
| 查词面板 | `user-flow.md` | — | 自研（`showGeneralDialog` 居中查词卡 + `flutter_tts`） |
| 查词状态机四操作 | `data-model.md` §5 | — | 自研 |
| 标记已会后重绘当前块 | `poc-plan.md` POC2 | fwfh.md | `core_widget_factory.dart` |
| parse_quota 拦截 index>=40 | `data-model.md` §parse_quota | drift.md | `database.dart`（条件 select） |
| 假广告解锁 +100 | `PRD-v0.2.md` §5.4 | drift.md | `database.dart`（update） |

### POC2 推荐阅读顺序

1. `docs/tech-stack.md` §3.3、§4、§6
2. `docs/refs-index/fwfh.md` → `tag_a.dart` → `core_widget_factory.dart`
3. `docs/data-model.md` §5（状态机）
4. `docs/refs-index/drift.md` → DAO 查询/更新范例

---

## 跨管线共用

| 子任务 | 项目文档 | 索引 | 说明 |
|--------|----------|------|------|
| 块切换加载 | `poc-plan.md` 通过指标 | `data-model.md` §content_blocks | 按 `globalBlockIndex` 顺序取块 |
| 阅读进度持久化 | `data-model.md` §reading_progress | drift.md | `insertOnConflictUpdate` |
| 内存词库 Set | `tech-stack.md` §2 | drift.md | 启动时 `select(knownWords).get()` |
| 项目 vs refs 冲突 | `refs-context.mdc` | — | 以 `docs/` 为准 |

---

## 无直接参照（自研）汇总

以下逻辑在 `refs/` 中无对应实现，需按项目文档自行开发：

- HTML/TXT 按 12000 字符切块
- HTML 内 `src`/`href` 路径重写
- TXT 正则分章与兜底切块
- HTML DOM 遍历注入 `span.word`
- 词归一化（小写、去标点）
- TXT `TextSpan` 逐词点击
- 查词面板 UI 与状态机
- 假词典 JSON 与假广告解锁 UI

开发时仍可参照 refs 中的**相近模式**（如 `tag_a.dart` 的点击、`database.dart` 的事务）。
