# MVP 迭代计划

| 字段 | 内容 |
|------|------|
| 文档版本 | v2.0 |
| 状态 | **Sprint 12 已完成**（v1.0 上架准备）；MVP Sprint 0–12 已完成 |
| 最后更新 | 2026-06-28（Sprint 12 词典拆包 + multireader 品牌 + Play 清单） |
| 关联 | [monetization.md](./monetization.md)、[PRD v0.3](./PRD-v0.3.md)、[poc-report §14](./poc-report.md#14-mvp-差距清单poc--mvp)、[user-flow](./user-flow.md)、[Sprint 收尾 checklist](./sprint-closeout-checklist.md) |

---

## 工程策略

- 在现有 [`poc/`](../poc/) 上扩展产品壳；Flutter 工程路径 `d:\ccccc\novel_reader\poc`
- 可选短路径 junction：`D:\novel-poc` → `d:\ccccc\novel_reader\poc`（`mklink /J`，非必须）
- 复用 `import/`、`reader/`、`database/`、`vocab/`；不重写 POC 核心管线
- HTML「已会」乐观 UI / 仅生词 span → v1.1（不阻塞 MVP）

---

## Sprint 总览

| Sprint | 目标 | Task 映射 | 状态 |
|--------|------|-----------|------|
| **0** | 产品壳骨架：`app.dart`、路由、`main.dart` 瘦身 | — | ✅ 已完成 |
| **1** | P0 核心：书架、阅读器增量、词库向导 | #13、#14、#15 | ✅ 已完成 |
| **2** | 主导航 + 启动路由 | #16 | ✅ 已完成（初版五 Tab；**Sprint 9 精简为四 Tab**） |
| **3** | P1 页面：统计、资源、设置 | #17、#18、#19 | ✅ 已完成 |
| **4** | 变现占位、书架删除、Release 准备、文档收尾 | P1-09、删除 UI | ✅ 已完成 |
| **5** | 阅读体验与查词交互：顶底栏悬浮、居中查词卡、TTS、阅读设置、封面 fallback | Task A–E | ✅ 已完成 |
| **5.1** | 查词卡双按钮、主题高亮、chrome 章节导航 | Track A/B + Wave 2 | ✅ 已完成 |
| **5.2** | 统计 Tab 四段式仪表盘 | — | ✅ 已完成 |
| **5.3** | 阅读设置 UI 重构（内嵌浮层 + 亮度 + chrome 配色） | — | ✅ 已完成 |
| **6** | 词典扩充与查词体验（8k–10k ECDICT、详情页） | P1-01 | ✅ 已完成 |
| **9.7** | 查词操作性能：即时关窗、单块重绘、分段埋点 | — | ✅ 已完成 |
| **10** | 词形查词双 Tab：别名 JSON、`resolve()`、`LookupVariantCard` | 方案 B | ✅ 已完成 |
| **11** | v1.0 体验闭环：去广告/全书可读、阅读时长埋点、生词本列表、变现文档 | monetization | ✅ 已完成 |
| **12** | v1.0 上架准备：词典 CDN 拆包、品牌 multireader、Release AAB + Play 封闭测试 | P1-02 | ✅ 已完成 |

---

## Sprint 0 — 产品壳骨架

**目标**：POC 首页替换为可扩展 App 入口，不破坏现有测试。

| 产出 | 路径 |
|------|------|
| App 入口 | `poc/lib/app.dart` |
| 精简 main | `poc/lib/main.dart` → `runApp(App())` |
| 书架占位 | `poc/lib/screens/bookshelf_screen.dart` |
| 主导航占位 | `poc/lib/screens/main_shell.dart` |

**验收**

- [x] `flutter test` 全绿
- [x] `flutter run` 启动新壳
- [x] `ReaderScreen` 仍可通过路由进入
- [x] debug「写入 40k」移入 `kDebugMode` 菜单

---

## Sprint 1 — P0 核心三模块

### #13 书架列表 UI

| 文件 | 说明 |
|------|------|
| `lib/screens/bookshelf_screen.dart` | 列表、导入、空状态 |
| `lib/widgets/book_card.dart` | 封面 48×72、进度%、相对时间 |
| `lib/widgets/empty_bookshelf.dart` | 引导导入 / 前往资源 |
| `database.dart` | `watchBookshelfItems` 按 `reading_progress.updatedAt` 降序 |

**验收**：导入后书架可见；排序正确；点击 → `ReaderScreen(bookId)`

### #14 阅读器增量

| 文件 | 说明 |
|------|------|
| `lib/reader/reader_screen.dart` | 沉浸顶底栏、进度保存 |
| `lib/reader/chapter_drawer.dart` | 章节目录 → 章首块 |

**验收**：目录跳转正确；重开恢复进度；单击非词区切换栏

### #15 词库冷启动向导

| 文件 | 说明 |
|------|------|
| `lib/screens/vocab_wizard/` | welcome / choose / confirm 三步 |
| `assets/presets/` | ECDICT 生成的分层词表（cet4 / cet6 / toefl / advanced） |

**验收**：首次空词库显示向导；四级词写入；跳过进书架；`KnownWordsCache.load`

---

## Sprint 2 — 主导航（#16）

| 文件 | 说明 |
|------|------|
| `lib/screens/main_shell.dart` | 初版五 Tab `IndexedStack`（书架 / 统计 / 词库 / **资源** / 个人） |
| `lib/app.dart` | 启动路由：`known_words` 空 → 向导，否则 → `MainShell` |

**Tab（初版）**：书架（默认）/ 统计 / 词库 / 资源 / 个人

> **Sprint 9 变更**：资源 Tab 移出底栏；当前为四 Tab（书架 / 统计 / 词库 / 个人）。资源页改为 push 入口（书架空状态 + 个人 → 更多设置 → 找书与导入）。

**验收**：Tab 可切换；书架为首页；向导仅首次

---

## Sprint 3 — P1 页面

### #17 阅读统计

| 文件 | 说明 |
|------|------|
| `lib/screens/stats_screen.dart` | 四段式仪表盘（Sprint 5.2 增强） |
| `database.dart` | `reading_stats_daily` 聚合；`getLastReadBook` / `getTodayNewWords` / `getTotalReadingMinutes` / `getDailyMinutesTrend` |

> Sprint 3 初版为词库概览 + 近 7 日柱状图；Sprint 5.2 升级为完整仪表盘，见下文。

### #18 资源页

| 文件 | 说明 |
|------|------|
| `lib/screens/resources_screen.dart` | 静态链接 + `url_launcher` + 导入教程 |

### #19 学习设置与词库管理

| 文件 | 说明 |
|------|------|
| `lib/screens/profile/learning_settings_screen.dart` | 重置/重选词库（自原 `settings_screen` 迁移） |
| `lib/screens/vocab_tab.dart` | 词库 Tab 入口（追加/导入，双入口保留） |

**验收**：各 Tab 有实质内容；重置词库后高亮变化；资源链接可打开

---

## Sprint 4 — 变现与发布

| 项 | 说明 | 状态 |
|----|------|------|
| P1-09 广告 SDK | `RewardedAdService` 接口 + `MockRewardedAdService`（3s）；真 SDK 待 Key | ✅ MVP 占位 |
| 书架删除 | `deleteBookCascade` + 长按/菜单确认 UI | ✅ 已完成 |
| Release | `applicationId`=`com.novelreader.poc.novel_reader_poc`；debug 埋点已 `kDebugMode` 守卫；`flutter build apk --release` 已通过（`build/app/outputs/flutter-apk/app-release.apk`，约 64.6 MB） | ✅ 已完成 |
| 文档 | 本文件 Sprint 状态、roadmap 阶段⑧、poc-report §14 | ✅ 已同步 |

---

## Sprint 5 — 阅读体验与查词交互

**目标**：修复顶底栏切换时正文跳动；查词面板改为居中卡片并增强操作反馈；阅读偏好持久化；EPUB 封面 manifest fallback。词典 JSON 扩充**不纳入本轮**，单列 Sprint 6。

### Task A — 顶底栏悬浮（`reader_screen.dart`）

| 改动 | 说明 |
|------|------|
| 固定正文边距 | 删除随 `_chromeVisible` 变化的 `Padding`；`CustomScrollView` 视口高度不变 |
| 动画 overlay | 顶底栏 `AnimatedSlide` + `AnimatedOpacity`（~200ms）悬浮于正文之上 |

**验收**：连续切换顶底栏，同一段落滚动位置与 HTML 排版不跳变。

### Task B — 居中查词卡 + TTS + 操作反馈

| 文件 | 说明 |
|------|------|
| `lib/reader/lookup_card.dart` | 居中卡片 UI（替代 bottom sheet 主体） |
| `lib/reader/word_pronunciation.dart` | `flutter_tts` 封装，`speak(word)` |
| `lib/reader/lookup_panel.dart` | `showGeneralDialog` + 半透明 barrier；宽约 88% 屏宽、垂直居中 |

- 布局：词 + 喇叭 + 释义 + 右上星标 + 底部「已会」「收藏」
- 打开时读取 `knownWordsCache` / `vocab_entries.starred` 初始态
- 点击收藏/已会：图标填充 + 主色，延迟 ~250ms 后关闭（或 SnackBar 反馈）
- 无释义时显示「词典未收录该词」，TTS 仍可读单词
- 依赖：`flutter_tts: ^4.x`

### Task C — EPUB 封面 Fallback（`epub_importer.dart`）

`readCover()` 失败后按 OPF `meta cover` → `properties="cover-image"` → `Images` 含 `cover` 文件名依次 fallback。已导入无封面书籍需**重新导入**（本轮不做「修复封面」工具）。

### Task D — 文档草稿（本 Wave 1 并行产出）

同步 PRD §3.4、tech-stack §4、user-flow、data-flow、poc-report §14、roadmap。

### Task E — 阅读设置（Wave 2，串行于 A）

| 文件 | 说明 |
|------|------|
| `lib/reader/reader_preferences.dart` | `SharedPreferences`：`fontSize`(14–24)、`lineHeight`(1.4–2.0)、背景色预设、`paddingH` |
| `lib/reader/reader_settings_panel.dart` | 内嵌浮层：亮度滑块 + 字号/行距步进 + 背景圆点 |
| `lib/reader/block_view.dart` | 接收动态 `TextStyle`，替换硬编码字号 |
| `lib/reader/reader_chrome.dart` | 顶栏 `Icons.text_fields` 入口 |

依赖：`shared_preferences: ^2.x`。验收：调字号后当前块重绘；偏好重启后保留。

**手测清单**（Wave 3）：顶底栏不跳、居中查词卡 + TTS、星标/已会反馈、阅读设置持久化、封面 re-import、`flutter test` 全绿。

---

## Sprint 5.1 — 阅读器 UX 改进

**目标**：简化查词卡为「不认识 / 已会」双按钮；主题感知高亮与查词卡配色；顶底栏 chrome 重构（章节导航 + 三图标底栏）。

### Track A — 查词卡简化

| 文件 | 说明 |
|------|------|
| `lookup_panel.dart` | `LookupAction` 简化为 `dontKnow` / `know`；Stack 遮罩点击关闭 |
| `lookup_card.dart` | 移除星标 UI；全宽「不认识」「已会」；`ReaderPreferences` 主题色 |
| `reader_screen.dart` | `_handleLookupAction` 按 `isUnknown` 映射四操作；移除 `getVocabByWord` 预读 |

**操作映射**（UI 两按钮 → 原四操作）：

| 按钮 | 生词 | 熟词 |
|------|------|------|
| 不认识 | 无 DB 操作 | `addToVocab` |
| 已会 | `markKnown` | `confirmKnown` |

`WordLookupService.starWord` API 保留，供后续生词本入口使用。

### Track B — 主题与高亮

| 文件 | 说明 |
|------|------|
| `reader_preferences.dart` | `chromeColor`、`unknownHighlightColor`、`lookupCardColor`、`toggleNightMode()` |
| `txt_highlighter.dart` | `decorationColor` + `decorationThickness: 1.5` |
| `block_view.dart` | HTML `text-decoration-color` 动态注入 |

### Wave 2 — Chrome 重构

| 组件 | 说明 |
|------|------|
| `ReaderTopBar` | 仅返回 + 书名/章标题；`chromeColor` |
| `ReaderBottomBar` | 上层：上一章 \| 章 pill \| 下一章 + 进度%；下层：目录 \| 设置 \| 夜间（3 图标，无 TTS） |
| `reader_screen.dart` | 缓存 `_chapters`；`_goToAdjacentChapter(delta)` |

**验收**：overlay 不改变正文 padding；夜间切换高亮/查词卡/ chrome 同步变色；`flutter test` 全绿。

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 5.2 — 统计 Tab 仪表盘

**目标**：将统计 Tab 从「词库概览 + 柱状图」升级为激励型仪表盘，参考「任务上下文 + 成长数据」布局；与书架职责分离（书架管列表，统计管续读快照与成长感）。

### 布局（四段）

| 段 | 内容 | 数据来源 |
|----|------|----------|
| A 正在阅读 | 最近一书封面 + 书名/作者 + 进度条 + 生词本词数；无书时引导导入 | `getLastReadBook()`、`countVocabEntries()` |
| B 我的数据 | 2×2：今日新词 / 累计已知 / 今日阅读 / 累计时长 | `getTodayNewWords()`、`countKnownWords()`、`getDailyMinutesTrend()`、`getTotalReadingMinutes()` |
| C 近 7 日 | 阅读分钟柱状图（保留） | `getDailyMinutesTrend(days:7)` |
| D 连续阅读 | 7 天圆点 + 「连续 N 天」/「尚未开始」 | 由 `_trend` 计算；今天有记录则计入，今天无记录不打断 streak |

### 文件

| 文件 | 说明 |
|------|------|
| `lib/screens/stats_screen.dart` | 四段式 UI；点击正在阅读卡 → `AppRoutes.reader` |
| `lib/database/database.dart` | 新增 `getLastReadBook()`、`getTodayNewWords()`、`getTotalReadingMinutes()` |
| `test/stats_screen_test.dart` | 仪表盘 widget 测试 |

**验收**

- [x] 六路查询 `Future.wait` 并行加载，支持下拉刷新
- [x] 正在阅读卡点击跳转阅读器
- [x] `flutter test test/stats_screen_test.dart` 全绿

**跟进（非本 Sprint）**

- 阅读器会话时长自动写入 `reading_stats_daily.minutes`（当前仅测试/手写入库有数据）
- 生词本列表页、统计页跳转词库 Tab（P2）

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 5.3 — 阅读设置 UI 重构

**目标**：将阅读设置从 modal bottom sheet 改为底栏上方内嵌浮层；补充系统亮度调节；修复顶底栏与正文背景色不一致。

### 布局（4 行浮层）

| 行 | 控件 |
|----|------|
| 亮度 | 太阳图标 + 水平滑块（0.0–1.0） |
| 字号 | A− / 当前值 / A+（14–24，步进 1） |
| 背景 | 3 圆形色块（白 / 米黄 / 夜间）+ 选中描边 |
| 间距 | − / 当前行距 / +（1.4–2.0，步进 0.1） |

### 文件

| 文件 | 说明 |
|------|------|
| `lib/reader/reader_settings_panel.dart` | 内嵌浮层 UI（替代 `reader_settings_sheet.dart`） |
| `lib/reader/reader_preferences.dart` | `screenBrightness` + `chromeColor` = `backgroundColor` + `settingsPanelColor` |
| `lib/reader/reader_chrome.dart` | `elevation: 0`、分割线、设置图标激活态 |
| `lib/reader/reader_screen.dart` | `_settingsPanelVisible` toggle；Stack 接入浮层 |
| `pubspec.yaml` | `screen_brightness: ^2.x` |

**验收**

- [x] 点「设置」在底栏上方展开/收起浮层，不再弹出 modal sheet
- [x] 三档背景切换时顶栏、底栏、正文、设置面板背景一致
- [x] 亮度滑块读写 OS 亮度 + SharedPreferences 记忆
- [x] 字号 / 行距步进调节，当前块即时重绘
- [x] 夜间快捷切换仍可用；`flutter test` / `flutter analyze` 无新增问题

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 6 — 词典扩充与查词体验 ✅

| 项 | 交付 |
|----|------|
| 数据源 | ECDICT 裁剪（MIT，回填 P1-01）；`build_mvp_dict.py` + `bootstrap_mvp_dict.py` |
| 规模 | `mvp_dict.json` **10k** 词条（ECDICT 裁剪），约 **6.0MB**（schema v2 义项对象） |
| 模型 | `DictEntry` / `DictSense` / `DictMeaning`（`text` + `primary`）；`DictLoader.lookup()` → `DictEntry?`；`fromJson` 兼容旧 string[] meanings |
| 查词卡 | 词头衬线、考试标签 chip、音标、分词性释义（`LookupMeaningsText` 主释义 w600，最多 3 sense）、「查看详细释义 >」 |
| 详情页 | `WordDetailScreen`：完整释义、英文释义折叠、词形变化、Collins/Oxford 徽章 |
| 启动 | `_StartupGate` 并行 `DictLoader.load()`；JSON 解析可选 `compute()` isolate |
| 词干化 | **方案 B 已落地**（Sprint 10 exchange 别名 + 双 Tab）；**方案 A** 词干化仍 P2；见 `docs/future-stemming.md` |
| 测试 | `dict_loader_test`：`entryCount >= 8000`；`credit` 多 sense + tags |

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 7 — 个人中心与更多设置 ✅

| 项 | 交付 |
|----|------|
| 导航 | Tab 4「设置」→「个人」；`ProfileScreen` + `onSwitchTab` |
| 个人主页 | 渐变头部、装备卡四快捷入口、外观/学习/更多设置菜单 |
| 学习设置 | 迁移原 `settings_screen` 词库三块逻辑 |
| 外观设置 | `ReaderPreferences` 全局默认；`AppPreferences.wallpaperFollowsReader` |
| 更多设置 | 本地数据概览、合规静态页、清除缓存、版本号、匿名 ID |
| 壁纸随动 | 书架/统计页可选跟随阅读背景预设 |
| 静态资源 | `assets/legal/*.md` × 10；`package_info_plus` |
| 删除 | `lib/screens/settings_screen.dart` |

**验收**：

- [x] 底部第 5 Tab 显示「个人」，图标为 person
- [x] 个人主页：头部 + 装备卡 + 三个菜单项
- [x] 学习设置行为与原设置页一致
- [x] 外观设置修改后新打开阅读器生效
- [x] 更多设置条目齐全（无登录/注销）；合规页可打开
- [x] 清除缓存、版本号、页脚匿名 ID
- [x] `flutter test` 全绿

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 8 — 词库成长激励 ✅

**目标**：词库 Tab 从配置页升级为词汇成长仪表盘；统计 Tab 去掉「累计已知」避免重复。

| 项 | 交付 |
|----|------|
| 等级进度 | 预置四级词表覆盖进度条 + 剩余词数（`vocab_progress.dart` + `preset_words_cache.dart`） |
| 里程碑 | 500 / 1000 / 5000 词徽章 + 下一档提示 |
| 词库 UI | `LevelProgressCard`、`MilestoneCard`；`vocab_tab.dart` 集成 |
| 统计去重 | `stats_screen.dart` 我的数据改为单行 3 卡（今日新词 / 今日阅读 / 累计时长） |

**验收**：

- [x] 词库 Tab 展示词汇等级进度与成长里程碑
- [x] 统计 Tab 不再展示「累计已知」
- [x] `vocab_progress_test.dart` + 相关 widget 测试全绿

**状态**：✅ 已完成（2026-06-27）

---

## Sprint 9 — Tab IA 重构 ✅

**目标**：主导航五 Tab 精简为四 Tab；消除统计 / 词库 / 个人之间的数字重复；装备卡升级为能力勋章墙；资源页移入 push 入口。

| 项 | 交付 |
|----|------|
| 统计去重 | 在读卡片移除「生词本 X 词」 |
| 词库生词本 | `vocab_tab` 生词本 Card + `VocabNotebookScreen` 占位页 |
| 个人头部 | `ProfileHeader` 状态语，无连续/累计数字 |
| 勋章墙 | `CapabilityBadgeWall` 替换 `EquipmentCard` |
| 资源迁移 | 更多设置「找书与导入」+ 书架空状态 push `ResourcesScreen` |
| 四 Tab 壳层 | `main_shell.dart` 移除资源 Tab；个人 index 3 |

**验收**：

- [x] 底栏仅 4 项（书架 / 统计 / 词库 / 个人）
- [x] 生词本词数主展示在词库 Tab；个人勋章墙为次要数字
- [x] 个人头部无连续天数 / 累计分钟
- [x] 资源页可通过书架空状态与更多设置进入
- [x] `flutter test` 全绿

**状态**：✅ 已完成（2026-06-28）

---

## Sprint 9.7 — 查词操作性能

**目标**：消除查词卡「认识/不认识」点击卡顿；点击即时关窗；一词操作仅重绘当前 ContentBlock。

### Wave 1 — 交互流水线

| 文件 | 变更 |
|------|------|
| `lookup_card.dart` / `word_detail_screen.dart` | 移除 250ms 延迟；`pop` 后 `onAction` 后台执行 |
| `lookup_panel.dart` | 新增 `lookupActionNeedsRedraw()` |
| `reader_screen.dart` | 无视觉变化时跳过重绘；修复 switch fall-through |

### Wave 2 — 单块精准重绘

| 文件 | 变更 |
|------|------|
| `block_view.dart` | `rebuildTriggers: [highlightRevision]`（废弃全局 `cache.revision`） |
| `known_words_cache.dart` | `addKnown`/`removeKnown` 不再 `notifyListeners` |
| `reader_screen.dart` | `_redrawBlock` 统一 bump revision，去掉 TXT 冗余 span 构建 |

### Wave 3 — 埋点与测试

| 产出 | 说明 |
|------|------|
| `PocMetrics.logLookupAction` | debug 分段 `db` / `redraw` / `mounted` |
| `lookup_action_redraw_test.dart` | 重绘策略四场景 |
| `html_widget_revision_test.dart` | per-block revision 性能 + 非目标块跳过 |

**手测清单**：

- [ ] EPUB：点击 √ 关窗无明显等待；当前词下划线即时消失/出现
- [ ] TXT：同上
- [ ] 确认已会（已是熟词）：无多余重绘卡顿
- [ ] debug 日志 `[POC2] lookup action` 中 `redraw` < 300ms
- [x] `flutter test` 全绿

**状态**：✅ 已完成（2026-06-28）

---

## Sprint 10 — 词形查词双 Tab ✅

**目标**：点击变形词（如 `ringing`、`was`）不再显示「词典未收录该词」；查词卡展示表面词形 | 原形双 Tab；高亮与 `known_words` 仍按表面词形精确匹配。规格见 [word-variant-lookup.md](./word-variant-lookup.md)。

| 项 | 交付 |
|----|------|
| 别名资产 | `poc/assets/dict/mvp_dict_aliases.json`（与 `mvp_dict.json` 分离；`lemma` + `exchangeKey` + 可选 `phonetic`） |
| 构建 | `build_mvp_dict.py --include-exchange-aliases --aliases-output poc/assets/dict/mvp_dict_aliases.json`；`validate_mvp_dict.py` 校验 alias 引用 |
| 查词 API | `DictLookupResult` + `DictLoader.resolve()`（精确 → 别名 → miss；`lookup()` 不变） |
| 语法注 | `formatVariantGrammarNote()`（如「ring的现在分词」） |
| UI | `LookupVariantCard`：Chip Tab + 变形/原形双视图 + `KnownToggle`；`LookupPanel` 按 `hasVariantTabs` 分支 |
| 原形路径 | 直接点原形仍走 `LookupCard`，零视觉变化 |
| 集成 | `ReaderScreen`：`isUnknownFor(activeWord)`；✓ 按当前 Tab 词形写入 `known_words` |
| 测试 | `dict_lookup_result_test.dart`、`lookup_variant_card_test.dart`；`lookup_card_test` 回归全绿 |

**构建命令**（与 `poc/assets/dict/README.md` 一致）：

```bash
python poc/scripts/build_mvp_dict.py \
  --input poc/data/ecdict-extracted/stardict.db \
  --output poc/assets/dict/mvp_dict.json \
  --include-exchange-aliases \
  --aliases-output poc/assets/dict/mvp_dict_aliases.json

python poc/scripts/validate_mvp_dict.py \
  poc/assets/dict/mvp_dict.json \
  poc/assets/dict/mvp_dict_aliases.json
```

**验收**：

- [x] 点 `ringing` → 双 Tab；变形 Tab 有语法注；原形 Tab 完整义项
- [x] 点 `ring` → 无 Tab，UI 与 Sprint 9.7 一致
- [x] Tab 切换后 ✓ 仅作用于 `activeWord`；高亮不随原形联动
- [x] `flutter test` 全绿

**状态**：✅ 已完成（2026-06-28）

---

## Sprint 11 — v1.0 体验闭环（去广告）

**目标**：落实 [monetization.md](./monetization.md) 决策——v1.0 **无广告、无 40 块墙**；统计时长真实写入；生词本从占位升级为可用列表。Pro / IAP / 词典拆包留 **Sprint 12+**。

**规格**：[monetization.md §3–4](./monetization.md) · [PRD-v0.3-changelog.md](./PRD-v0.3-changelog.md)

### Wave 1 — 取消阅读墙与广告代码

| 文件 | 任务 | 验收 |
|------|------|------|
| `poc/lib/database/constants.dart` | 新增 `unlimitedBlockQuota` 或文档化 v1.0 策略常量 | 常量单一来源 |
| `poc/lib/database/database.dart` | `initParseQuota`：导入后 `unlockedBlockCount = book.totalBlocks`（或 `isBlockUnlocked` 恒 `true`） | index ≥40 可加载块 |
| `poc/lib/database/database.dart` | `unlockAfterAd` 标记 `@Deprecated` 或删除；`lastAdUnlockAt` 不再写入 | 无广告解锁路径 |
| `poc/lib/reader/reader_screen.dart` | 删除 `_navigateToUnlock` 调用链、`_unlockGateActive` 门闩 | 滚至任意块不弹解锁页 |
| `poc/lib/reader/unlock_screen.dart` | 删除文件，或保留仅 `@visibleForTesting` | 生产路由无引用 |
| `poc/lib/reader/reader.dart` | 移除 `unlock_screen` export | — |
| `poc/lib/ads/rewarded_ad_service.dart` | 删除或移入 `test/` / `deprecated/` | 无生产 import |
| `poc/lib/ads/mock_rewarded_ad_service.dart` | 同上 | 同上 |
| `poc/test/database_test.dart` | 解锁用例改为「全书可读」 | 测试通过 |
| `poc/test/poc2_acceptance_test.dart` | 删除或改写 `unlock boundary` / `ad +100` 用例 | 测试通过 |
| `poc/test/epub_importer_test.dart` | `parse_quota` 断言：`unlockedBlockCount == totalBlocks` | 测试通过 |
| `poc/test/txt_importer_test.dart` | 同上 | 测试通过 |

**手测**：导入长篇 EPUB → 连续滚过原 index 40 → 无全屏解锁页；块高亮查词正常。

### Wave 2 — 阅读时长统计埋点

> **说明**：「今日新词」已由 `getTodayNewWords()` 读 `known_words.addedAt`，**无需**重复写 `reading_stats_daily.newWordsCount`。本 Wave 只补 **minutes**。

| 文件 | 任务 | 验收 |
|------|------|------|
| `poc/lib/services/reading_session_tracker.dart` | **新建**：`start(bookId)` / `pause()` / `flush()`；累计秒 → 分钟 | 可单测 |
| `poc/lib/services/reading_session_tracker.dart` | `flush` 调用 `db.incrementDailyMinutes(date, bookId?, deltaMinutes)` | 写入 `reading_stats_daily` |
| `poc/lib/database/database.dart` | **新建** `incrementDailyMinutes`：对 `bookId IS NULL` 合计行与可选 per-book 行 UPSERT **累加** | 多次 flush 不覆盖 |
| `poc/lib/database/database.dart` | 日期键 `_statsDateKey` 与 `getDailyMinutesTrend` 一致 | 7 日图对齐 |
| `poc/lib/reader/reader_screen.dart` | `initState`/`dispose` + `WidgetsBindingObserver`：`paused`/`resumed` 触发 tracker | 切后台暂停计时 |
| `poc/lib/reader/reader_screen.dart` | 退出阅读器 `pop` 前 `flush` | 单次会话计入 |
| `poc/test/reading_session_tracker_test.dart` | **新建**：累加、跨日、pause 不计时 | 测试通过 |
| `poc/test/stats_screen_test.dart` | 用 `incrementDailyMinutes` 种子数据 | 仪表盘有柱高 |

**手测**：阅读 2–3 分钟 → 统计 Tab「今日时长」>0；7 日图当日柱非零。

### Wave 3 — 生词本列表

| 文件 | 任务 | 验收 |
|------|------|------|
| `poc/lib/database/database.dart` | `watchVocabEntries()` Stream + `getVocabEntriesPage(limit, offset)` 按 `updatedAt DESC` | Drift 查询 |
| `poc/lib/screens/vocab/vocab_notebook_screen.dart` | 占位改为 `ListView`：词、释义摘要、例句 snippet、相对时间 | 非空可浏览 |
| `poc/lib/screens/vocab/widgets/vocab_notebook_tile.dart` | **新建**（可选）：列表行组件 | 对齐 design-system |
| `poc/lib/screens/vocab/vocab_notebook_screen.dart` | 点击行 → `WordDetailScreen` 或查词详情（复用已有） | 可查看释义 |
| `poc/lib/screens/vocab/vocab_notebook_screen.dart` | 空状态保留现有引导文案 | 0 词时 UX 不变 |
| `poc/lib/screens/vocab_tab.dart` | 入口词数与列表一致（已有 `countVocabEntries`） | — |
| `poc/lib/screens/profile/widgets/capability_badge_wall.dart` | push 仍进 `VocabNotebookScreen` | — |
| `poc/test/vocab_notebook_screen_test.dart` | 更新：列表渲染、空态、点击 | 测试通过 |

**手测**：阅读中点「不认识」→ 生词本出现该词 + 例句；词库 Tab 词数 +1。

### Wave 4 — 文档与合规同步

| 文件 | 任务 |
|------|------|
| `docs/monetization.md` | ✅ 已定稿（本 Sprint 前置产出） |
| `docs/PRD-v0.3-changelog.md` | ✅ 已定稿 |
| `docs/PRD-v0.2.md` → `docs/PRD-v0.3.md` | 按变更清单合入正文 |
| `docs/user-flow.md` | 删除 §7 广告解锁；阅读流程去 quota 分支 |
| `docs/data-model.md` §3.7 | v1.0 全书可读；`lastAdUnlockAt` 废弃说明 |
| `docs/tech-stack.md` | 移除广告 SDK；注明 v1.1 `in_app_purchase` 预备 |
| `docs/poc-report.md` §14.3 | P1-09 标记「已取消—改 Pro 买断」 |
| `docs/mvp-plan.md` | Sprint 11 状态 ✅ |
| `.cursor/rules/project-roadmap.mdc` | 最近 Sprint + 讨论顺序 |
| `README.md` | 链接 monetization；更新 MVP 状态 |
| `poc/assets/legal/privacy_policy.md` | 确认无广告第三方 SDK 表述 |

### Sprint 11 总验收

- [x] `flutter test` 全绿
- [x] 无 `UnlockScreen` / `MockRewardedAd` 生产引用（`rg` 验证）
- [x] 长篇阅读无块数硬墙
- [x] 统计 Tab 时长有真实数据
- [x] 生词本可列表浏览
- [x] PRD v0.3 + user-flow + data-model 与代码一致

**Wave 依赖**：Wave 1 ∥ Wave 2 可并行；Wave 3 独立；Wave 4 在 T3 集成后执行（[sprint-closeout-checklist.md](./sprint-closeout-checklist.md)）。

**状态**：✅ 已完成（2026-06-28）

---

## Sprint 12 — v1.0 上架准备

**目标**：词典混合拆包（Release CDN / Debug bundled）、品牌 ID `com.novelreader.multireader`、Release AAB + Google Play 封闭测试清单。

**规格**：[dict-pack-delivery.md](./dict-pack-delivery.md) · [play-closed-testing-checklist.md](./play-closed-testing-checklist.md)

### Wave 1 — 词典 CDN 混合加载（P1-02）

| 产出 | 路径 |
|------|------|
| 交付规格 | `docs/dict-pack-delivery.md` |
| 下载服务 | `poc/lib/services/dict_pack_service.dart` |
| 加载分支 | `poc/lib/vocab/dict_loader.dart`（`kReleaseMode`） |
| 启动 UI | `poc/lib/app.dart` `_StartupGate` 进度 + 重试 |
| manifest 模板 | `poc/assets/dict/manifest.json`（**v2**：义项 `{text, primary}`；`mvp_dict.json` ~6.0MB） |
| 迁移脚本 | `poc/scripts/migrate_dict_meanings.py`（string[] → object[]） |
| 发布脚本 | `poc/scripts/publish_dict_pack.ps1` |
| 测试 | `poc/test/dict_pack_service_test.dart`、`dict_loader_test.dart` |

### Wave 2 — 品牌 multireader

| 层 | 值 |
|----|-----|
| applicationId / Bundle ID | `com.novelreader.multireader` |
| Dart 包名 | `multi_novel_reader` |
| 显示名 | 小说阅读器 |
| 版本 | `1.0.0+1` |

### Wave 3 — Release 构建

| 产出 | 路径 |
|------|------|
| 签名模板 | `poc/android/key.properties.example` |
| Release 脚本 | `poc/scripts/build_release.ps1`（剔除 dict assets → test → AAB） |
| Play 清单 | `docs/play-closed-testing-checklist.md` |

### Sprint 12 总验收

- [x] `flutter test` 全绿（Debug 无 CDN）
- [x] `rg novel_reader_poc poc/` 无残留
- [x] Release 构建脚本可运行（`-SkipAab` 无 keystore 时）
- [ ] Play Console arm64 download size 实测（待上传 AAB）
- [ ] 生产 CDN URL 替换占位（`DICT_PACK_MANIFEST_URL`）

**状态**：✅ 已完成（2026-06-28）

---

## 任务对照表

| Task ID | 模块 | Sprint |
|---------|------|--------|
| #20 | mvp-plan + 数据流图 | 文档闸门 |
| — | Sprint 0 骨架 | 0 |
| #13 | 书架 | 1 |
| #14 | 阅读器 | 1 |
| #15 | 词库向导 | 1 |
| #16 | 主导航 | 2（初版五 Tab；Sprint 9 改为四 Tab） |
| #17 | 统计 | 3 |
| #18 | 资源 | 3 |
| #19 | 学习设置 | 3 / 7 |
| P1-09 | ~~真广告~~ → **已取消**（见 monetization.md） | 4 / 11 |
| — | 顶底栏悬浮 + 居中查词卡 + TTS | 5（Task A/B） |
| — | 阅读设置 + SharedPreferences | 5（Task E） |
| — | EPUB 封面 fallback | 5（Task C） |
| — | 查词卡双按钮 + 主题高亮 + chrome 重构 | 5.1 |
| — | 统计 Tab 四段式仪表盘 | 5.2 |
| — | Tab IA 重构（四 Tab + 勋章墙 + 数字去重） | 9 ✅ |
| — | 查词操作性能（即时关窗 + 单块重绘） | 9.7 ✅ |
| — | 词形查词双 Tab（exchange 别名 + `LookupVariantCard`） | 10 ✅ |
| P1-01 | ECDICT 裁剪 `mvp_dict.json` | 6 ✅ |
| — | 去广告 + 全书可读 + 时长埋点 + 生词本列表 | 11 ✅ |
| P1-02 | 词典 CDN 拆包 + multireader 品牌 + Release AAB | 12 ✅ |

---

## Android 构建环境（Windows）

| 项 | 建议 |
|----|------|
| 工程路径 | 使用 ASCII 路径 `d:\ccccc\novel_reader\poc`（避免中文目录导致 JNI/AOT 失败） |
| `PUB_CACHE` | 用户环境变量设为 `D:\pub-cache`（规避 `C:\Users\…` 中文用户目录下 `jni` CMake 乱码） |
| Gradle 代理 | Clash **TUN** 时注释 `poc/android/gradle.properties` 与 `~/.gradle/gradle.properties` 中 `127.0.0.1:7897`；工程内已保留空值覆盖 |
| 构建命令 | `flutter test` → `poc/scripts/build_release.ps1`（Release AAB，剔除 dict assets） |

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 预置词表 P1-04 | ECDICT tag 裁剪词表（MIT），见 `poc/assets/presets/README.md` |
| 多 Agent 改同一文件 | 按 Wave 文件所有权隔离 |
| Windows 中文路径 / Gradle 代理 | 见上节「Android 构建环境」 |
| P1-09 广告 | **已取消** → Pro 买断，见 [monetization.md](./monetization.md) |
| v1.0 包体 ~64MB | Sprint 12 词典拆包 + AAB |
