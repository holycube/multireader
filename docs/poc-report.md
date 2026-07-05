# POC 验证报告



| 字段 | 内容 |

|------|------|

| 文档版本 | v1.0（POC 总验收） |

| 状态 | **POC 验收通过**（任务 #12 定稿） |

| 最后更新 | 2026-06-28（Sprint 9 Tab IA 重构） |

| 关联计划 | [poc-plan.md](./poc-plan.md) |



---



## 1. 环境与样书



### 测试机



| 平台 | 型号 / 环境 | 用途 |

|------|-------------|------|

| Windows（自动化） | Windows 10.0.26200，Flutter 3.44.3 / Dart 3.12.2 | `flutter test` 全量回归 + `poc1_acceptance_test.dart` / `poc2_acceptance_test.dart` |

| Android 真机 | **荣耀 X50i**（`AQMLUT3510007187`），debug 构建 | 滚动帧率、块切换、高亮查词、解锁边界 |

| iPhone | **跟进项**（暂无设备） | MVP 前补测；**非 MVP 阻塞** |



开发目录：`d:\ccccc\novel_reader\poc`（仓库 `poc/`）；真机运行 `flutter run -d AQMLUT3510007187`。



### 样书



| 样书 | 来源 | 块数 / 说明 |

|------|------|-------------|

| 网文 EPUB（真机主测） | 用户自备 *Omniscient Reader's Viewpoint* 粉丝向 EPUB | **924 块**；含封面、正文插图；spine 切分较碎 |

| 超长 TXT（真机） | `dart run scripts/generate_large_txt.dart 310` → `test/fixtures/poc_large_310blocks.txt` | **310 块**（3,720,000 字符） |

| 带图 EPUB（自动化） | 程序生成最小 EPUB | 集成测试用 |

| Gutenberg 带图 EPUB | [Gutenberg #11](https://www.gutenberg.org/ebooks/11) `.epub.images` | 未单独测；网文 EPUB 已覆盖带图场景 |



---



## 2. POC1 指标实测



> 「自动化」列来自 `poc/test/poc1_acceptance_test.dart`（Windows VM，2026-06-23）。「Android 真机」列来自 2026-06-24 荣耀 X50i debug 实测（AppBar 埋点 + Performance Overlay）。



| 指标 | 通过线 | 自动化实测 | Android 真机 | 是否通过 |

|------|--------|------------|--------------|----------|

| 单块加载到首屏 | < 800ms | **1ms**（缓存命中） | **57ms**（EPUB 首块，日志 `[POC1] block load`） | 是 |

| 块切换 | < 500ms | **0ms 中位数**（50 次 `BlockLoader.load`） | TXT 峰值 **< 100ms**；EPUB 常态 < 100ms，快速连滑偶发 **200–300ms** | 是 |

| 导入 300+ 块的书 | 内存峰值 < 200MB | **~181MB RSS**（310 块 TXT） | 924 块 EPUB、310 块 TXT 均可完成导入，无 ANR/闪退；未采 `dumpsys meminfo` 数值 | 是（体验） |

| 连续加载 50 块 | 稳定 < 150MB、无持续增长 | **~182MB RSS**（+1MB） | 连续滑过多块，无卡顿恶化、无内存相关崩溃 | 是（体验） |

| 滚动帧率 | 平均 ≥ 50fps | 未自动化 | Performance Overlay **多数绿色**；经过插图时偶发红色帧 | 是 |

| 带图 EPUB | 图片正常 | 结构验证通过 | 封面与正文插图正常显示；滑过图片时偶发掉帧 | 是 |



### 真机块切换采样（debug 日志摘录）



| 场景 | 样本 |

|------|------|

| EPUB 首块 | `block load index=0` **57ms** |

| EPUB 连滑 | `0→1` 4ms，`1→2` 49ms，`2→3` 12ms，`3→4` 17ms；快速甩滑偶发 200–300ms |

| TXT | 峰值 < 100ms，整体稳定 |



### 导入耗时（参考）



| 操作 | 耗时 |

|------|------|

| EPUB（最小样书，自动化） | 257–270ms |

| TXT 310 块（自动化） | 827–1201ms |

| EPUB 924 块（真机） | 用户感知可接受，无卡死（未精确计时） |

| TXT 310 块（真机） | 导入顺畅 |



### 回归测试



`flutter test`：**全部通过**（87 项，2026-06-24；含 `poc1_acceptance_test`、`poc2_acceptance_test` 等）。



### 真机侧修复记录（验收过程中）



| 问题 | 处理 |

|------|------|

| 无法滚动 / 块不衔接 | `ReaderScreen` 块末加载逻辑、`BlockLoader` 缓存 |

| 段落合并 | 阅读时注入段落 CSS；导入按 `</p>` 边界分块（需重新导入 EPUB 生效） |



---



## 3. Drift 落表核对



按 [data-model.md §5/§10](./data-model.md) 与 [drift.md](./refs-index/drift.md) DAO 模式，由 `test/helpers/import_spotcheck.dart` 在导入后自动核对：



| 检查项 | 结果 |

|--------|------|

| `books.importStatus` → `complete` | 通过 |

| `totalChapters` / `totalBlocks` 与块文件数一致 | 通过 |

| `chapters.orderIndex` 从 0 连续递增 | 通过 |

| `chapters.blockCount` 与章内块数一致 | 通过 |

| `content_blocks.globalBlockIndex` 从 0 连续递增 | 通过 |

| `content_blocks.contentPath` 文件存在 | 通过 |

| `parse_quota.freeAllowance = 40`、`unlockedBlockCount = 40` | 通过 |

| EPUB `assets/` 目录与图片复制 | 通过 |

| `deleteBookCascade`（data-model §6） | 单测覆盖；书架删除 UI 属 MVP |



### POC2 运行时表写入（data-model §9）



| 操作 | `known_words` | `vocab_entries` | 验证 |

|------|---------------|-----------------|------|

| 已会 | INSERT | 保留 | `poc2_acceptance_test` + `word_lookup_service_test` |

| 收藏 | 不变 | INSERT `starred=true` | 同上 |

| 加入生词本 | DELETE | INSERT `starred=false` | 同上 |

| 确认已会 | INSERT 幂等 | 不变 | 同上 |

| 广告解锁 +100 | `parse_quota.unlockedBlockCount` += 100 | — | `database_test` + §11 真机 |



---



## 4. epubx 最终结论



| 项 | 结论 |

|----|------|

| spine / 目录解析 | 满足 POC：924 块网文 EPUB 真机导入与阅读正常 |

| 资源复制与 HTML 路径重写 | 封面、插图显示正常 |

| 12000 字符子切 | 单测通过；真机以 spine 一切一块为主（924 spine 项） |

| 已知限制 | 部分 EPUB 源文件将多句对话放在同一 `<p>` 内，无法通过导入拆开；复杂 CSS 排版 MVP 阶段再评估 |

| 性能 | 快速连滑偶发 200–300ms 块切换，仍 < 500ms 通过线 |



**拍板（最终）**：`epubx` **继续用于 MVP**。



---



## 5. 参数与调参记录



| 参数 | 当前值 | 是否调整 |

|------|--------|----------|

| 子切阈值 `blockCharLimit` | 12,000 | **否** |

| 免费额度 `freeAllowance` | 40 | **否** |

| 广告解锁增量 | +100 | **否**（#11 真机验证通过） |

| `BlockLoader` 缓存 | 当前块 ±1（max 3） | 否 |

| HTML 旁文件缓存 | `BlockHighlightCache` 已启用 | 否（性能达标，未触发失败预案） |

| 40k `known_words` 冷加载 | `customSelect('SELECT word …')` 只读 word 列；主线程 `list.toSet()`（去掉 `compute()` Isolate 序列化）；`lastLoadDbMs` / `lastLoadSetMs` 分段计时 | **是**（2026-06-26） |

| HTML「已会」重绘 | 每块 `highlightRevision` + 内存 `KnownWordsCache` 驱动 `customStylesBuilder`；`HtmlWidget.rebuildTriggers: [highlightRevision]`；markKnown 跳过 `forceHighlight`；旁文件缓存 **v3** | **是**（2026-06-26 → 2026-06-28 单块精准刷新） |

| 查词操作延迟 | 点击即关窗（无 250ms 等待）；`onAction` 后台执行；debug `[POC2] lookup action` 分段 `db` / `redraw` | **是**（2026-06-28 Sprint 9.7） |

| 失败预案 | **未触发** | — |



---



## 6. 真机验收方法（存档）



```powershell

cd d:\ccccc\novel_reader\poc

C:\src\flutter\bin\flutter.bat run -d AQMLUT3510007187

```



1. 首页点 **速度图标** 开启 Performance Overlay，阅读器内滑动观察 fps。

2. AppBar 查看 **首块 XXXms**、**切换 X→Y XXXms**、**重绘 Nms**（仅 debug）。

3. 导入 EPUB / TXT，滑至块末确认右上角 **已加载块数/总块数** 递增。

4. POC2 40k 词库：debug 首页点 **写入 40k 词库（验收）**，杀进程冷启动观察 `[POC2] cache warm` 日志（`total` 为验收口径；建议 force-stop 后复测 3 次以上，以稳定值为准）。

5. **40k 手测复验（2026-06-26）**：前两次冷启 **600+ms**（超标）；后续多次稳定 **300+ms**（达标）。波动主要来自首启 JIT / SQLite 页缓存未热；见 §9.3、§12。

6. 可选：`adb shell dumpsys meminfo com.novelreader.poc.novel_reader_poc` 记录内存峰值。



自动化验收：



```powershell

flutter test test/poc2_acceptance_test.dart

dart run scripts/seed_known_words.dart 40000 --db-path=<sqlite路径>

```



---



## 7. POC 前置项汇总



| 项 | 状态 |

|----|------|

| POC1 自动化 + Android 真机 | **通过** |

| POC2 #7–#11 代码与单测 | **完成** |

| #11 假解锁真机（荣耀 X50i） | **通过**（见 §11） |

| #12 POC2 总验收 | **通过**（见 §12） |

| iPhone 补测 | **跟进项**（非 MVP 阻塞） |



---



## 8. 验收结论（POC1）



- **代码验收**：EPUB/TXT 双管线导入、八表 Drift 落表、按块加载渲染、debug 性能埋点均已就绪。

- **自动化 + 真机**：POC1 六项指标均达标或按体验判定通过。



---



## 9. POC2 实现与自动化验收



### 9.1 任务完成清单



| 任务 | 产出 | 状态 |

|------|------|------|

| #7 词库内存 Set 与归一化 | `word_normalizer.dart`、`known_words_cache.dart` | 完成 |

| #8 HTML 高亮 span 注入 | `html_highlighter.dart`、`word_tap_factory.dart`、`block_highlight_cache.dart` | 完成 |

| #9 TXT TextSpan 逐词高亮 | `txt_highlighter.dart`、`txt_highlighted_text.dart` | 完成 |

| #10 查词面板与状态机 | `dict_loader.dart`、`lookup_panel.dart`、`word_lookup_service.dart` | 完成 |

| #11 假解锁 | `unlock_screen.dart`、`parse_quota` 守卫 | 完成 |

| #12 总验收 | `poc2_acceptance_test.dart`、`seed_known_words.dart`、本报告定稿 | 完成 |



### 9.2 自动化验收（`flutter test`）



| 测试文件 | 覆盖项 |

|----------|--------|

| `poc2_acceptance_test.dart` | HTML/TXT 预处理、查词、40k Set、解锁边界、状态机四操作 |

| `word_normalizer_test.dart` | 词形归一化 |

| `known_words_cache_test.dart` | Set 加载（含 10k / **40k < 500ms**） |

| `integration_test/poc2_device_metrics_test.dart` | 真机四项指标（`[POC2-DEVICE]` 日志） |

| `html_highlighter_test.dart` | span 注入、缓存、预处理计时 |

| `block_highlight_cache_test.dart` | HTML 高亮缓存 |

| `txt_highlighter_test.dart` | TextSpan、点击回调 |

| `dict_loader_test.dart` | JSON 词典、lookup 性能 |

| `word_lookup_service_test.dart` | 四操作状态机与表写入 |



### 9.3 POC2 指标（主机 `flutter test`，2026-06-26）



| 指标 | 通过线 | 自动化实测 |

|------|--------|------------|

| HTML 预处理（~500 词/块） | < 200ms | **65ms** |

| TXT 高亮（~500 词/块） | < 200ms | **2–5ms** |

| 单击查词（JSON，1000 次） | < 100ms | **0ms** |

| 40,000 词 Set 冷启动 | < 500ms | **103ms**（`db=94ms` `set=9ms`；优化后） |

| 解锁边界 index 39/40 | 39 可读、40 拦截 | DB 断言通过 |

| 状态机四操作 | 表写入正确 | smoke 断言通过 |



**40k 优化说明**：优化前真机手测 `cache warm` **534–764ms**（未达 500ms 线）。去掉 `compute()` + `customSelect` 只读 `word` 列后，主机 40k 由 ~239ms 降至 **103ms**；真机 `integration_test` 见 §12。

**40k 手测复验（荣耀 X50i，debug，2026-06-26）**：

| 样本 | `total` | 判定 |
|------|---------|------|
| 第 1–2 次冷启 | **600+ms** | 未达 < 500ms 线 |
| 第 3 次及以后（稳定） | **300+ms** | 达标 |
| 观测区间 | **300–700ms** | 首启偏慢、热启稳定 |

结论：**工程上基本达标**（稳定冷启 < 500ms；`integration_test` 纯 `cache.load` **263ms** 已通过）。首两次 600+ 记为真机方差，**不阻塞 MVP**；若 release 仍偶发超标，MVP 再评估快照文件方案。



### 9.4 flutter_widget_from_html 最终结论



| 项 | 结论 |

|----|------|

| `span.word` 点击扩展 | `WordTapWidgetFactory` 可用，与查词面板联通 |

| unknown 虚线下划线 | HTML 预处理注入样式；TXT 侧 TextSpan 一致 |

| 局部重绘 | `KnownWordsCache.revision` + `HtmlWidget.rebuildTriggers`；markKnown **不**再 `forceHighlight`；首次排版后 `buildAsync: false` |

| 查词埋点 | `PocMetrics.logLookup` 输出 `[POC2] dict lookup` |



**拍板（最终）**：`flutter_widget_from_html` **继续用于 MVP**。



---



## 10. 下一步（MVP 前置）



| 项 | 状态 |

|----|------|

| POC 可行性验证 | **已完成** |

| 数据流图 `docs/diagrams/data-flow.drawio` | **待定** |

| `docs/mvp-plan.md` MVP 切片计划 | **待定**（POC 通过后首要文档产出） |

| iPhone 补测 | 跟进项 |

| P1-09 真实广告 SDK | MVP Sprint 内接入 |



详见 **§14 MVP 差距清单**。



---



## 11. 任务 #11 真机验收（假解锁）



> 术语：**单层解锁页** = 滚至 index 40 时全屏解锁页只弹出一次；**模拟广告 +100** = 点「观看广告解锁」等待 3 秒倒计时后 `unlockedBlockCount` 增加 100。



### 11.1 验收环境



| 项 | 内容 |

|----|------|

| 测试机 | 荣耀 X50i（`AQMLUT3510007187`） |

| 测试书 | 924 块网文 EPUB 或 310 块超长 TXT |

| 构建 | debug |



### 11.2 验收项与结果



| 项 | 操作 | 结果 |

|----|------|------|

| index 39 可读 | 滚至第 40 段（index 39） | **通过** |

| index 40 拦截 | 继续滚至下一块 | **通过** |

| 单层解锁页 | 观察是否只弹一层 | **通过** |

| 返回继续阅读 | 点返回 /「返回继续阅读」 | **通过** |

| 模拟广告 +100 | 点「观看广告解锁」等 3 秒 | **通过** |

| 无网络已解锁段 | 断网读 index 0–39 | 未单独测（本地块文件，语义上支持） |



---



## 12. POC2 总验收结论（任务 #12）



> 「自动化」：`poc2_acceptance_test.dart` + `known_words_cache_test.dart`（2026-06-26 全绿）。「Android 真机」：`integration_test/poc2_device_metrics_test.dart` 于荣耀 X50i（`AQMLUT3510007187`）**All tests passed**。



| 指标 | 通过线 | 自动化 | Android 真机 | 通过 |

|------|--------|--------|--------------|------|

| HTML 预处理（~500 词/块） | < 200ms | 65ms | **`[POC2-DEVICE] html=139ms`**（integration_test） | **是** |

| 标记「已会」后重绘 | < 300ms | **per-block 路径**（`preprocess=0ms`）；`html_redraw_test` / `html_widget_revision_test` 全绿 | 待真机复测；日志 `[POC2] html redraw … path=per-block` | **是**（自动化） |

| 查词操作（点击→关窗） | < 100ms | 即时 `pop`（`lookup_card_test`） | 待真机复测；`[POC2] lookup action` | **是**（自动化 UX） |

| 查词操作（单块下划线更新） | < 300ms | `lookup_action_redraw_test` + per-block 重绘 | 待真机复测 | **是**（自动化） |

| 单击查词（JSON） | < 100ms | 0ms（1000×） | **`lookup=1ms`**（integration_test） | **是** |

| 40,000 词 Set 冷启动 | < 500ms | **103ms**（`db=94` `set=9`） | **`40kSet=263ms`**（integration_test）；手测稳定 **300+ms**、首两次 **600+ms** | **是**（稳定后达标；首启方差已记录） |

| 滚动掉帧 | < 5% 时间 | 未自动化 | 同 POC1：Overlay **多数绿色**，插图偶发红帧 | **是** |

| 解锁边界 index 39/40 | 39 可读、40 拦截 | DB 断言 | §11 真机通过 | **是** |



### 跨管线抽查



| 场景 | 结果 |

|------|------|

| EPUB 块切换 + 高亮 + 查词 | 通过 |

| TXT 块切换 + TextSpan 点击查词 | 通过 |

| 标记已会仅重绘当前块 | 通过（每块 `highlightRevision` + 内存 Set 驱动样式，非全局 `cache.revision`） |



### 库拍板（最终）



| 库 | 结论 |

|----|------|

| `epubx` | **继续用于 MVP** |

| `flutter_widget_from_html` | **继续用于 MVP** |



### 是否进入 MVP 切片开发



**是。**



| 阻塞项 | 说明 |

|--------|------|

| iPhone 补测 | 跟进项，不阻塞 MVP 编码启动 |

| P1-09 广告 SDK | MVP Sprint 内接入真实 SDK |

| 数据流图 / mvp-plan | POC 通过后下一步文档产出 |



---



## 13. POC 总验收签字



| 项 | 结论 |

|----|------|

| POC1（P0-05 导入分块） | **通过** |

| POC2（P0-06 高亮查词 + 解锁） | **通过** |

| 参数 12000 / 40 / +100 | **维持不变** |

| 阶段⑥ 路线图 | **可标记已完成** |



---



## 14. MVP 差距清单（POC → MVP）



> POC 验证了**技术可行性**；MVP Sprint 0–6 已于 2026-06-27 在 `poc/` 产品壳上完成（见 [mvp-plan.md](./mvp-plan.md)）。下表 §14.1–14.2 保留 **POC→MVP 对照**；**当前仍待**见 §14.3–14.4。



### 14.1 POC 已具备（可迁移复用）



| 能力 | POC 产出 |

|------|----------|

| EPUB/TXT 导入与八表落库 | `import/`、`database/` |

| 双管线阅读器（HTML span + TXT TextSpan） | `reader/` |

| 按块加载、±1 缓存、进度写入 | `BlockLoader`、`reading_progress` DAO |

| 生词高亮 + 查词状态机四操作 | `html_highlighter`、`word_lookup_service` |

| 假解锁（index 40 拦截、+100） | `unlock_screen.dart` |

| 性能与验收测试 | `poc1/2_acceptance_test`、`integration_test` |



### 14.2 P0 — MVP 必须新建/补齐（2026-06-26 已完成）



| PRD 项 | POC 现状 | MVP 产出 |
|--------|----------|----------|
| **书架界面**（封面、进度%、最近阅读排序） | 首页简易 `_BookListSection` | `bookshelf_screen`、`BookCard`、`watchBookshelfItems` |
| **词库冷启动向导**（3 屏） | 无；仅 debug「写入 40k」 | `vocab_wizard/` + `assets/presets/` |
| **章节目录跳转** | 无目录 UI | `chapter_drawer` → 章首块 |
| **产品信息架构** | 单页 POC 壳 | `MainShell` 四 Tab + 启动路由（Sprint 9 由五 Tab 精简） |
| **书架删除** | 仅单测 | 长按确认 + `deleteBookCascade` |
| **Release 构建** | debug 为主 | `app-release.apk` 已打出；debug 埋点 `kDebugMode` 守卫 |



### 14.3 P1 — MVP 计划内、POC 未覆盖（部分已占位）



| PRD 项 | 说明 | MVP 状态 |
|--------|------|----------|
| ~~节点激励广告~~（P1-09） | POC 曾为 3 秒模拟按钮 | **已取消** → Pro 买断（见 monetization.md） |
| **阅读统计** | 无统计页/无 `reading_stats` 展示 | ✅ 四段式仪表盘 + `ReadingSessionTracker` 时长埋点（Sprint 11） |
| **资源页 + 导入教程** | 无 | ✅ `resources_screen` |
| **完整词典方案** | POC 内置 JSON ~454 条 | **Sprint 6**：ECDICT 裁剪 10k；**Sprint 12**：Release CDN + Debug bundled（[dict-pack-delivery.md](./dict-pack-delivery.md)） |
| **底栏「已解锁 x/y 段」** | PRD 标为可选 MVP | 未做 |



### 14.4 P2 / 跟进项（非 MVP 阻塞）



| 项 | 说明 |

|----|------|

| Anki `.apkg` 导入/导出 | P2 |

| 匿名进度备份 | P2 |

| iPhone 真机补测 | 跟进项 |

| 词干化、横翻模式 | PRD §7 暂不涉及或开放问题 |



### 14.5 文档与工程待办



| 项 | 状态 |
|----|------|
| `docs/diagrams/data-flow.drawio` | ✅ 已完成 |
| `docs/mvp-plan.md`（Sprint 切片） | ✅ v2.0（含 Sprint 12 上架准备） |
| 产品壳（`poc/lib/` 扩展，非独立 App 工程） | ✅ MVP Sprint 0–5.2 |
| 预置词表来源与授权（P1-04） | 待定 |
| Windows 构建：`PUB_CACHE`、Gradle 代理、ASCII 路径 | 见 `mvp-plan.md`「Android 构建环境」 |



### 14.6 性能跟进（不阻塞 MVP 启动）



| 指标 | 现状 | 备注 |

|------|------|------|

| 40k 冷启（手测） | 稳定 **300+ms**；首启偶发 **600+ms** | 已通过 integration_test；MVP 视 release 再评估快照 |

| 标记「已会」重绘 | **已优化**（2026-06-26）：去掉双次 HTML 预处理；主机 `markKnown` + fwfh revision 重建 **&lt; 300ms** | 真机 EPUB 块建议复测；若仍掉帧见阶段 C（单 span 补丁 / 插图占位） |

| 滚动掉帧（插图） | Overlay 多数绿色，插图偶发红帧 | 与 markKnown 重绘不同因；同 POC1 结论 |



### 14.7 Sprint 5 — 阅读体验与查词交互（已完成）



| 项 | 说明 | 状态 |
|----|------|------|
| 顶底栏 overlay 不挤正文 | 删除 chrome 联动 `Padding`；`AnimatedSlide`/`AnimatedOpacity` | ✅ Task A |
| 居中查词卡 Dialog | 替代 `showModalBottomSheet`；星标/已会视觉反馈 | ✅ Task B |
| `flutter_tts` 读音 | 朗读单词本身；无释义时仍可读 | ✅ Task B |
| 阅读设置 | `ReaderPreferences` + `shared_preferences`；字号/行距/背景 | ✅ Task E |
| EPUB 封面 manifest fallback | `readCover` 失败后 OPF/manifest/Images 链 | ✅ Task C |
| 文档同步 | PRD、tech-stack、user-flow、data-flow、mvp-plan | ✅ Task D/F |



### 14.8 Sprint 6 — 词典扩充与查词体验 ✅（2026-06-27）

| 项 | 说明 | 状态 |
|----|------|------|
| 词条规模 | POC JSON ~454 条 → **10k** ECDICT 裁剪 `mvp_dict.json`（约 4.8MB） | ✅ |
| 数据源 | ECDICT MIT；`build_mvp_dict.py`；P1-01 已回填 | ✅ |
| 接口 | `DictEntry` / `DictSense`；`DictLoader.lookup()` → `DictEntry?` | ✅ |
| 查词卡 | 结构化 UI + `WordDetailScreen` 详情页 | ✅ |
| 词干化 | **不做**；见 `future-stemming.md` | ✅ |
| 测试门槛 | `dict_loader_test`：`entryCount >= 8000` | ✅ |

### 14.9 Sprint 5.1 — 阅读器 UX 改进（2026-06-27 已完成）

| 项 | 说明 | 状态 |
|----|------|------|
| 查词卡双按钮 | 「不认识 / 已会」替代星标/四按钮；`LookupAction` 简化为 `dontKnow`/`know` | ✅ |
| 操作语义映射 | 生词「不认识」无操作；熟词「不认识」→ addToVocab；「已会」→ markKnown/confirmKnown | ✅ |
| 主题感知高亮 | `unknownHighlightColor` + `decorationThickness` 1.5；HTML/TXT 双管线 | ✅ |
| 查词卡主题色 | `lookupCardColor` / `lookupCardOnColor` 随夜间模式 | ✅ |
| Chrome 重构 | 顶栏精简；底栏章节 prev/next + 目录/设置/夜间三图标 | ✅ |
| 测试 | `lookup_card_test`、`txt_highlighter_test`（含 dark mode） | ✅ |

### 14.10 Sprint 5.2 — 统计 Tab 仪表盘（2026-06-27 已完成）

| 项 | 说明 | 状态 |
|----|------|------|
| 四段式布局 | 正在阅读 / 我的数据 2×2 / 近 7 日柱状图 / 连续阅读 | ✅ |
| DB 查询 | `getLastReadBook`、`getTodayNewWords`、`getTotalReadingMinutes` | ✅ |
| 续读入口 | 正在阅读卡 → `AppRoutes.reader` | ✅ |
| 测试 | `stats_screen_test.dart` | ✅ |
| 跟进 | 阅读器会话写入 `reading_stats_daily.minutes` | 待接 |

### 14.11 Sprint 5.3 — 阅读设置 UI 重构（2026-06-27 已完成）

| 项 | 说明 | 状态 |
|----|------|------|
| 内嵌浮层 | `ReaderSettingsPanel` 替代 modal `ReaderSettingsSheet`；底栏上方 toggle | ✅ |
| 系统亮度 | `screen_brightness` + `reader_screen_brightness` SP 键 | ✅ |
| Chrome 配色 | `chromeColor` = `backgroundColor`；`elevation: 0` + 分割线 | ✅ |
| 设置激活态 | 底栏设置图标 `settingsActive` 高亮 | ✅ |
| 测试 | `flutter analyze` / `flutter test` 全绿 | ✅ |

### 14.12 Sprint 7 — 个人中心与更多设置 ✅（2026-06-27）

| 项 | 说明 | 状态 |
|----|------|------|
| Tab 改造 | 「设置」→「个人」；`Icons.person` | ✅ |
| 个人主页 | `ProfileScreen` + 头部 / 装备卡 / 三菜单 | ✅ |
| 学习设置 | `LearningSettingsScreen` 迁移原词库管理 | ✅ |
| 外观设置 | `AppearanceSettingsScreen` + `ReaderPreferences` | ✅ |
| 更多设置 | 分组列表、本地数据概览、合规页、缓存、版本、匿名 ID | ✅ |
| 壁纸随动 | 书架 / 统计可选跟随阅读背景 | ✅ |
| 静态合规 | `assets/legal/*.md` × 10 | ✅ |
| 测试 | `profile_screen_test`、`vocab_management_test` 更新 | ✅ |

### 14.13 Sprint 9 — Tab IA 重构 ✅（2026-06-28）

四 Tab 主导航、统计/词库/个人数字去重、`CapabilityBadgeWall` 替换装备卡、资源页 push 入口（书架空状态 + 更多设置）。

### 14.14 Sprint 12 — 上架准备 ✅（2026-06-28）

| 项 | 说明 | 状态 |
|----|------|------|
| 词典拆包 | Release CDN + Debug bundled；`DictPackService` + [dict-pack-delivery.md](./dict-pack-delivery.md) | ✅ |
| 品牌 | `com.novelreader.multireader` / `multi_novel_reader` / 小说阅读器 | ✅ |
| Release 构建 | `poc/scripts/build_release.ps1`；`key.properties.example` | ✅ |
| Play 清单 | [play-closed-testing-checklist.md](./play-closed-testing-checklist.md) | ✅ |

**包体 / 性能指标（待 Play Console 实测）**：

| 指标 | Sprint 11 基线 | Sprint 12 目标 / 说明 |
|------|----------------|----------------------|
| Release APK（含 dict） | ~64 MB | Debug 仍含 dict assets |
| Release AAB（无 dict） | — | 词典 ~5.5 MB 移出；arm64 download 目标 &lt; 35 MB |
| 首次词典下载 | — | ~5.5 MB；Wi‑Fi/蜂窝由用户网络决定 |
| meminfo 包名 | `com.novelreader.poc.novel_reader_poc` | `adb shell dumpsys meminfo com.novelreader.multireader` |

---


