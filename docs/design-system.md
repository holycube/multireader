# 设计系统：AppDesignTokens + SoftCard

| 字段 | 内容 |
|------|------|
| 文档版本 | v0.2 |
| 状态 | Phase 1 已落地 |
| 最后更新 | 2026-06-28 |
| 关联文档 | [PRD v0.2](./PRD-v0.2.md)、[user-flow](./user-flow.md)、[tech-stack](./tech-stack.md) |
| 参考产品 | 不背单词（壳层卡片 / 统计）、微信读书（书架内容优先 / 极简导航） |

---

## 1. 设计目标

本规范为 **Tab 壳层**（书架、统计、词库、个人）与 **阅读器浮层**（查词卡、设置面板）提供统一的视觉语言，使后续页面与 AI 协作有明确约束。

### 1.1 核心气质

| 关键词 | 含义 |
|--------|------|
| **呼吸感** | 大间距、少元素、内容不挤 |
| **高级感** | 中性底色 + 少量强调色；信息靠排版分层，不靠线框 |
| **内容优先** | 书架封面、正文章节是主角；壳层 UI 退后 |
| **轻交互** | 可点区域明确，但不用粗按钮抢戏 |

### 1.2 设计原则（必须遵守）

1. **禁止硬边界**：壳层卡片不使用 `BorderSide`；组内列表不使用 Material 默认 `Divider`。
2. **层级靠底色差**：`页面底 → 卡片面 → 嵌套块` 最多三层，靠颜色与间距区分。
3. **强调色克制**：Accent 仅用于选中态、进度、链接、关键数字点缀；面积 < 5%。
4. **双轨排版**：区块标题可用衬线（文艺感）；正文与 UI 控件用系统无衬线（可读性）。
5. **阅读器独立**：阅读页背景/字号由 `ReaderPreferences` 控制，不强制套用壳层 Token。

---

## 2. 参考拆解

### 2.1 不背单词 → 借鉴范围

适用于：**统计 Tab、个人中心、词库成长卡片**

- 暖灰页面底 + 白色大圆角卡片
- 区块标题衬线、数据数字衬线
- 轻阴影或纯色差浮起
- 胶囊形次要按钮（换书、筛选）
- 顶部允许渐变 / 轻纹理（仅头部区域）

### 2.2 微信读书 → 借鉴范围

适用于：**书架网格、底部导航、全局搜索/筛选**

- 冷灰或纯白底，封面直接落底不加外框
- 全局无衬线，层次靠字重
- 选中态单一淡色（蓝或品牌色）
- 极简线型图标；`›` 暗示可点

### 2.3 本产品混配策略

```
壳层（统计 / 个人 / 词库）  →  不背单词式卡片 + 暖灰底
书架                        →  微信读书式内容优先
阅读器 + 查词浮层            →  极简、跟随阅读主题
```

---

## 3. AppDesignTokens

> 落地文件建议：`poc/lib/theme/app_design_tokens.dart`  
> 与现有 `ShellAppearancePreferences`、`ReaderPreferences` 并存：前者管壳层背景预设，后者管阅读页，本 Token 管壳层默认视觉与组件常量。

### 3.1 颜色

#### 3.1.1 中性层级（浅色壳层 · 默认）

| Token | 色值 | 用途 |
|-------|------|------|
| `shellBg` | `#F5F3EF` | 页面背景（暖灰，默认 preset 4） |
| `shellBgCool` | `#F7F7F7` | 备选冷灰底（preset 5，更接近微信读书） |
| `surface` | `#FFFFFF` | 卡片、浮层、底栏 |
| `surfaceNested` | `#F0EEEA` | 卡片内嵌块、筛选条未选中底 |
| `scrim` | `#000000` @ 40% | 模态遮罩 |

#### 3.1.2 文字

| Token | 色值 | 用途 |
|-------|------|------|
| `textPrimary` | `#1C1C1E` | 标题、正文 |
| `textSecondary` | `#8E8E93` | 副标题、说明、标签 |
| `textTertiary` | `#C7C7CC` | 占位、禁用、极弱提示 |
| `textOnAccent` | `#FFFFFF` | 强调色按钮上的字 |

#### 3.1.3 强调色（预览期三选一，默认墨绿）

| 方案 | 主色 | 浅色底 | 气质 | 状态 |
|------|------|--------|------|------|
| **A 墨绿（默认）** | `#2D5A4A` | `#E8F0ED` | 安静、阅读、文艺 | 默认 |
| B 淡蓝 | `#4A7BF7` | `#EEF2FE` | 干净、偏微信读书 | 预览可选 |
| C 暖橙 | `#E8913A` | `#FDF3E7` | 活力、偏不背单词进度条 | 预览可选 |

「主页外观 → 强调色」可切换三种 Accent，全局 Tab 即时刷新（底栏、进度条、图标强调色跟随）。预览期结束后可收敛为单一方案（见 §10 DS-01）。

配套语义色（与 accent 无关，固定）：

| Token | 色值 | 用途 |
|-------|------|------|
| `success` | `#34C759` | 完成、打卡 |
| `warning` | `#FF9500` | 提醒 |
| `error` | `#FF3B30` | 错误、删除确认 |

#### 3.1.4 分隔与描边（极少使用）

| Token | 色值 | 用途 |
|-------|------|------|
| `hairline` | `#000000` @ 6% | 极特殊情况：列表行分割、底栏顶线 |
| `chevron` | `textSecondary` @ 70% | 列表右侧 `›` |

**禁止**：`outlineVariant` 40% 描边作为卡片外框（当前 `SettingsGroupCard` 做法）。

#### 3.1.5 深色壳层

| Token | 色值 | 用途 |
|-------|------|------|
| `shellBgDark` | `#121212` | 页面背景 |
| `surfaceDark` | `#1E1E1E` | 卡片 |
| `surfaceNestedDark` | `#2C2C2C` | 嵌套块 |
| `textPrimaryDark` | `#E5E5E5` | 主文字 |
| `textSecondaryDark` | `#8E8E93` | 副文字 |

与 `ShellAppearancePreferences.presetDark`（`#1E1E1E`）对齐；用户选深灰壳层时启用上表。

#### 3.1.6 与现有代码映射

| 现有 | 本规范 |
|------|--------|
| `ThemeData(colorScheme: fromSeed(0xFF2D3748))` | 保留 M3 生成，但壳层组件 **显式引用 Token**，不依赖 seed 自动色 |
| `ShellAppearancePreferences` 白/黄/深灰 | `shellBg` / 护眼 `#F5EEDC` / `shellBgDark` |
| `ReaderPreferences` 三套阅读背景 | **不改动**；查词卡继续 `lookupCardColor` |

---

### 3.2 间距（4pt 网格）

| Token | 值 | 用途 |
|-------|-----|------|
| `spaceXs` | 4 | 图标与文字间距 |
| `spaceSm` | 8 | 行内紧凑间距 |
| `spaceMd` | 12 | 卡片内小组件间距 |
| `spaceLg` | 16 | 页面水平边距、卡片内边距（默认） |
| `spaceXl` | 20 | 宽松卡片内边距 |
| `space2xl` | 24 | 区块之间 |
| `space3xl` | 32 | 大区块、头部下方 |

**页面边距**：水平 `spaceLg`（16）；区块间距 `space2xl`（24）。

---

### 3.3 圆角

| Token | 值 | 用途 |
|-------|-----|------|
| `radiusSm` | 8 | 封面缩略图、芯片内部 |
| `radiusMd` | 12 | 按钮、输入框、查词卡（阅读器） |
| `radiusLg` | **16** | **SoftCard 默认** |
| `radiusXl` | 20 | 大 hero 卡、底部 Sheet 顶角 |
| `radiusFull` | 999 | 胶囊按钮、头像 |

---

### 3.4 阴影与 elevation

**默认策略：无阴影，靠底色差。** 仅当卡片落在 **`surface` 同色底** 上时才加极轻阴影。

| Token | Flutter 参考 | 用途 |
|-------|--------------|------|
| `elevationNone` | `elevation: 0` | 绝大多数卡片 |
| `elevationSoft` | `blur: 16, offset: (0,4), color: #000 @ 5%` | 浮在白色上的白卡（可选） |

**禁止**：M3 默认 `Card` 带 tonal outline；`elevation: 2+` 的重阴影。

---

### 3.5 字体

#### 3.5.1 字体族

| 角色 | 字体 | 备注 |
|------|------|------|
| `fontUi` | 系统默认（`Roboto` / `PingFang SC` / `Noto Sans`） | 正文、列表、按钮 |
| `fontDisplay` | `Noto Serif SC`（`poc/assets/fonts/`） | 仅壳层区块标题、统计大数字 |

**Phase 1（当前）**：`NotoSerifSC` 已打包进 assets（Regular 400 + SemiBold 600），通过 `AppTextStyles.sectionTitle` / `statValue` 用于统计、词库卡片标题；**查词卡词头与释义用 Georgia**；词库向导仍用系统无衬线。

**Phase 2+**：扩展字重/字号阶梯，按需裁剪字体子集。

#### 3.5.2 字号阶梯

| Token | 大小 | 行高 | 字重 | 用途 |
|-------|------|------|------|------|
| `textDisplay` | 28 | 1.2 | 600 | 统计大数字 |
| `textTitleLg` | 20 | 1.3 | 600 | 页面级标题 |
| `textTitleMd` | 17 | 1.35 | 600 | 区块标题（衬线可选） |
| `textBody` | 15 | 1.5 | 400 | 列表标题、正文 |
| `textBodySm` | 13 | 1.45 | 400 | 副标题、说明 |
| `textCaption` | 11 | 1.4 | 400 | 标签、时间戳 |

阅读器正文字号 **不在此表**，由 `ReaderPreferences.fontSize`（14–24）控制。

---

### 3.6 图标

| 规则 | 值 |
|------|-----|
| 风格 | Material Symbols **Outlined**；选中态可用 filled |
| 列表 leading | 22–24px，可包在 32px 圆角方块彩色底上 |
| 底栏 | 24px |
| 颜色 | 默认 `textSecondary`；选中 `accent`；彩色底图标用对应语义色 |

---

### 3.7 动效

| 场景 | 时长 | 曲线 |
|------|------|------|
| 按钮 / 列表点击 | 120ms | `easeOut` |
| 浮层出现 | 200ms | `easeOutCubic` |
| 主题切换 | 250ms | `easeInOut` |

避免弹跳、过度 parallax。

---

## 4. 核心组件：SoftCard

### 4.1 定义

`SoftCard` 是壳层唯一标准卡片容器：白底、大圆角、无描边、无默认分割线，通过页面底色 `#F5F3EF` 产生浮起感。

### 4.2 API 草案

```dart
/// 路径建议：poc/lib/widgets/soft_card.dart
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,      // 16
    this.color,                       // 默认 surface
    this.onTap,
    this.useShadow = false,           // 默认 false
  });
}
```

### 4.3 视觉规则

| 属性 | 值 |
|------|-----|
| `color` | `surface`（`#FFFFFF`） |
| `border` | **none** |
| `borderRadius` | `radiusLg`（16） |
| `padding` | 默认 `spaceLg`（16）；数据格可用 `spaceXl`（20） |
| `margin` | 水平由父级 `Padding` 控制；卡片之间 `spaceMd`–`spaceLg` |
| 子列表分割 | **不用 Divider**；用 `spaceLg` 行高 + 可选 `hairline` 或纯留白 |

### 4.4 变体

| 变体 | 说明 | 示例 |
|------|------|------|
| `SoftCard` | 标准内容卡 | 统计「正在阅读」 |
| `SoftCard.flat` | 无内边距，供列表组 | 设置 `SettingsGroupCard` 替代 |
| `SoftCard.tappable` | 包 `InkWell`，圆角裁剪 | 可点统计卡 |
| `SoftCard.nested` | `surfaceNested` 底色，圆角 `radiusMd` | 卡片内 2×2 数据格 |

### 4.5 反模式（不要这样做）

```dart
// ❌ 描边卡片
Card(shape: RoundedRectangleBorder(side: BorderSide(...)))

// ❌ 组内硬分割线
Divider(height: 1)

// ❌ 在灰色底上用灰色卡片（对比不足）
color: Colors.grey.shade100  // 与 shellBg 糊在一起
```

---

## 5. 其他标准组件

### 5.1 SectionTitle（区块标题）

用于统计、词库等分段标题，位于卡片 **上方**，与卡片间距 `spaceSm`。

```
正在阅读                    [换书]  ← 可选胶囊按钮
┌─────────────────────────────┐
│  SoftCard                   │
└─────────────────────────────┘
```

| 属性 | 规范 |
|------|------|
| 字体 | Phase 1: `textTitleMd` + w600；Phase 2: `fontDisplay` |
| 与卡片间距 | `spaceSm`（8） |
| 与上一区块间距 | `space2xl`（24） |
| 右侧操作 | `PillButton.secondary`（见 5.4） |

### 5.2 SettingsListTile（设置行）

在 `SoftCard.flat` 内使用；沿用 `poc/lib/screens/profile/widgets/settings_list_tile.dart`，调整：

| 属性 | 规范 |
|------|------|
| 行高 | ≥ 52px（`contentPadding: vertical 14`） |
| leading | 24px 图标，或 32px 圆角色块底 + 图标 |
| trailing | 灰色 `chevron_right`；**不用**粗箭头 |
| 分割 | 行与行之间 **无 Divider**；依赖行高与点击态 |
| 字色 | title `textPrimary`；subtitle `textSecondary` |

### 5.3 DataStatCell（数据格）

用于统计「我的数据」2×2 网格。

| 元素 | 规范 |
|------|------|
| 布局 | `SoftCard` 内 `Grid` 2 列，格间 `spaceLg` |
| 图标 | 20–24px，彩色（黄/红/青各一，低饱和） |
| 标签 | `textCaption`，`textSecondary` |
| 数值 | `textDisplay` 或 `textTitleLg`；Phase 2 衬线 |

### 5.4 PillButton（胶囊按钮）

| 类型 | 背景 | 文字 | 用途 |
|------|------|------|------|
| `secondary` | `accentLight` @ 15% 或 `surfaceNested` | `accent` 或 `textPrimary` | 换书、换一批 |
| `ghost` | transparent | `textSecondary` | 非首要操作 |

高度 28–32，水平 padding `spaceMd`–`spaceLg`，圆角 `radiusFull`。

### 5.5 ProfileHeader（个人头部）

沿用渐变思路，对齐 Token：

| 属性 | 规范 |
|------|------|
| 渐变 | `accentLight` → `#FFF8E7` → `surface`（现 `ProfileHeader` 相近） |
| 头像 | 72px 圆，`accent` @ 15% 底 |
| 与下方内容 | `spaceLg` 后开始卡片 |

### 5.5.1 CapabilityBadgeWall（能力勋章墙）

个人 Tab 三格横排快捷能力入口，复用 `SoftCard` + `InkWell`。

| 属性 | 规范 |
|------|------|
| 布局 | `Row` 三等分；`padding: vertical 16, horizontal 8` |
| 解锁态 | 彩色图标（`primary`）+ `bodySmall` 标签 |
| 锁定态 | `Icons.lock_outline` + `onSurfaceVariant` @ 50%；点击 SnackBar 占位 |
| 次要数字 | 生词本词数用 `labelSmall` + `onSurfaceVariant`（仅解锁项） |
| 交互 | 生词本 push `VocabNotebookScreen`（`VocabNotebookTile` 列表 + `WordDetailScreen`）；Anki/备份暂锁定 |

> **废弃**：`EquipmentCard`（词库/书架/导入 Tab 跳转）已由勋章墙取代，不再使用。

### 5.5.2 VocabNotebookTile（生词本列表行）

`VocabNotebookScreen` 内 `ListView.separated` 使用 Material `Card` + `InkWell` 行组件。

| 属性 | 规范 |
|------|------|
| 布局 | 左栏词形 + 释义/例句摘要；右栏相对时间（`formatRelativeReadTime`） |
| 词形 | `titleMedium` + Georgia + `primary` + w600 |
| 释义摘要 | `bodyMedium`，最多 2 行；来自 `vocab_entries.definition` 或词典回落 |
| 例句 snippet | `bodySmall` + `onSurfaceVariant` + 斜体，最多 2 行 |
| 间距 | 行间距 8dp（`separatorBuilder`）；卡片内 padding 16×14 |
| 圆角 | Card / InkWell `borderRadius: 12` |
| 交互 | 整行点击 → `WordDetailScreen` |
| 空状态 | 居中 `bookmark_border` 图标 + 引导文案（无列表行） |

### 5.6 书架 BookCard（内容优先）

**不用 SoftCard 包裹整行。**

| 属性 | 规范 |
|------|------|
| 布局 | 封面 + 标题落 `shellBg` / 白色底，无外包框 |
| 封面圆角 | `radiusSm`（8） |
| 间距 | 行间距 `spaceLg`，封面与标题 `spaceSm` |
| 交互 | 整行 `InkWell`；删除等次要操作长按 |

### 5.7 底栏 NavigationBar

| 属性 | 规范 |
|------|------|
| 背景 | `surface`，顶线 `hairline`（可选） |
| 选中 | `accent` 图标 + 标签 |
| 未选中 | `textSecondary` |
| elevation | 0 |

### 5.8 阅读器浮层（查词卡 / 设置面板）

| 组件 | 规范 |
|------|------|
| `LookupCard` | 宽度 `screenWidth - 32`（左右各 16dp）；圆角 `radiusLg`（16）；色跟随 `ReaderPreferences` |
| `LookupCard` 结构 | 词头（Georgia + accent）+ 考试标签 inline；音标灰色胶囊（`美` + 喇叭）；释义 Georgia 衬线（**主释义 w600**）；左下「查看详细释义 >」 |
| `LookupMeaningsText` | 义项 `{text, primary}` 渲染；`primary: true` → `FontWeight.w600`；义项间 `；` 分隔 |
| `LookupCard` 已会切换 | 右上角细圈 √（未会空心圆 1.5px；已会 accent 填充 + 白 √）；缩放弹跳动画与关窗并行；无 scrim、无底部大按钮 |
| `LookupCard` 交互预算 | 点击 → 关窗 **< 100ms**；DB 写入与块重绘后台完成 |
| `LookupVariantCard` | 变形词路径；布局 / 圆角 / 交互预算与 `LookupCard` 一致；**双视图**随 Tab 切换 |
| `LookupVariantCard` Chip Tab | 顶部 `surfaceWord` \| `lemmaWord` 两枚 Chip；选中：`primary` 12% 底 + **`primary` 字 w600**；未选：透明底 + 0.4α 描边 + 次要字；圆角 6、间距 6 |
| `LookupVariantCard` 变形 Tab | 仅首条 sense + `formatVariantGrammarNote` 括号注；不展示 examTags |
| `LookupVariantCard` 原形 Tab | 与 `LookupCard` 一致：最多 3 条 senses + examTags inline |
| `LookupVariantCard` 词头 | 当前 Tab 词形 Georgia 22px **`primary` accent**；音标胶囊复用 `LookupPhoneticPill` |
| `LookupVariantCard` 已会 | 右上角 `LookupKnownToggle`；✓ 针对当前 Tab 词形（`isUnknownFor(activeWord)`） |
| `ReaderSettingsPanel` | 半透明 `settingsPanelColor`；无壳层 `shellBg` |
| 原则 | 查词卡布局参考不背单词小卡；配色跟阅读主题，不强制壳层 Token |

---

## 6. 页面布局模式

### 6.1 壳层 Tab 通用

```
Scaffold(
  backgroundColor: shellBg,           // 或用户壳层预设
  body: ListView(
    padding: horizontal spaceLg,
    children: [
      SectionTitle(...),
      SoftCard(...),
      SizedBox(height: space2xl),
      ...
    ],
  ),
)
```

`AppBar`：默认无阴影（`elevation: 0`），背景与 `shellBg` 一致或使用 `surface`。

### 6.2 各 Tab 策略

| Tab | 卡片策略 | 备注 |
|-----|----------|------|
| 书架 | 无卡，封面网格/列表 | 微信读书式 |
| 统计 | 全套 SoftCard + SectionTitle | 不背单词式 |
| 词库 | SoftCard（等级、里程碑、生词本入口） | 可带轻渐变 hero |
| 个人 | Header 渐变 + SoftCard + CapabilityBadgeWall | 勋章墙三格横排 |

### 6.3 设置子页

- 分组 = 一个 `SoftCard.flat` + 多行 `SettingsListTile`
- 组与组间距 `spaceLg`
- 页底留白 ≥ `space2xl`

---

## 7. 无障碍与对比度

| 检查项 | 要求 |
|--------|------|
| 正文对比度 | `textPrimary` on `surface` ≥ 4.5:1 |
| 次要文字 | `textSecondary` 仅用于非关键信息 |
| 触控区域 | 可点行高 ≥ 48dp |
| 色盲 | 状态不只靠颜色；配合图标或文案 |

---

## 8. 落地路线图

### Phase 1 — Token + SoftCard ✅

- [x] 新增 `app_design_tokens.dart`
- [x] 新增 `soft_card.dart`
- [x] `app.dart` 的 `ThemeData` 引用 Token 构建 `ColorScheme`
- [x] 替换 `SettingsGroupCard` 为 SoftCard 体系；`EquipmentCard` 已由 `CapabilityBadgeWall` 取代
- [x] `stats_screen` 统一 SectionTitle + SoftCard
- [x] 打包 `Noto Serif SC`，壳层区块标题与统计数字衬线化
- [x] 「主页外观」暖灰/冷灰 + 三色 Accent 预览切换

### Phase 2 — 书架与导航

- [x] `BookCard` 间距微调（Phase 1 最小改动）
- [x] `NavigationBar` 配色对齐 Token（`navigationBarTheme`）
- [x] `AppThemePreferences` 与 `shellBg` 枚举对齐文档

### Phase 3 — 衬线与细节

- [x] 引入 `Noto Serif SC` 用于壳层 `fontDisplay`（Phase 1 已完成）
- [ ] 扩展字重/字号、深色壳层全量验收

### 现有文件改造对照

| 文件 | 改造要点 |
|------|----------|
| `settings_group_card.dart` | 去 `BorderSide` + `Divider` → `SoftCard.flat` |
| `equipment_card.dart` | **已废弃**（Sprint 9 由 `capability_badge_wall.dart` 取代） |
| `stats_screen.dart` | `Card` → `SoftCard`；`_SectionTitle` 对齐 5.1 |
| `profile_header.dart` | 渐变颜色改引 Token |
| `milestone_card.dart` / `level_progress_card.dart` | 统一圆角 16、无描边 |
| `shell_appearance.dart` | 预设值与 3.1 色表对齐 |

---

## 9. AI 协作提示模板

### 9.1 新页面

```text
请按 docs/design-system.md 实现 [页面名]：
- 页面底 shellBg #F5F3EF，水平边距 16
- 内容用 SoftCard，圆角 16，禁止 BorderSide 和 Divider
- 区块标题在卡片上方，间距 8
- 强调色用 accent 方案 A 墨绿 #2D5A4A
- 列出用到的 Token 名称
```

### 9.2 改造旧组件

```text
请将 [文件路径] 对齐 design-system.md §4 SoftCard：
- 移除 outlineVariant 描边与 Divider
- 卡片间距与内边距按 §3.2
- 保持现有业务逻辑不变
```

### 9.3 设计评审

```text
对照 docs/design-system.md 评审 [截图/文件]：
1. 是否存在硬边界
2. Token 是否一致
3. 强调色是否过量
按严重/建议/可选分级输出
```

---

## 10. 待定项

| ID | 事项 | 说明 |
|----|------|------|
| DS-01 | Accent 最终方案 | A 墨绿 / B 淡蓝 / C 暖橙 — **预览期可在「主页外观」切换**；默认 A |
| DS-02 | 壳层默认底色 | 暖灰 `#F5F3EF` vs 冷灰 `#F7F7F7` — **预览期可切换**；默认暖灰 preset 4 |
| DS-03 | 衬线字体扩展 | Phase 1 已落地壳层衬线；后续按需扩展字重/裁剪体积 |
| DS-04 | 阴影策略 | 默认无阴影；是否在白底预设下启用 `elevationSoft` |

---

## 附录 A：Token 速查表

```
颜色    shellBg #F5F3EF | surface #FFF | textPrimary #1C1C1E | textSecondary #8E8E93
强调    accent #2D5A4A（推荐）| accentLight #E8F0ED
间距    页面16 | 区块24 | 卡片内16
圆角    卡片16 | 封面8 | 胶囊999
禁止    卡片描边 | 组内Divider | 重阴影
```

## 附录 B：与 Material 3 的关系

- 保留 `useMaterial3: true`，但壳层关键组件 **显式指定** Token，避免 `ColorScheme.fromSeed` 自动色漂移。
- `ThemeData.cardTheme` 设为：`elevation: 0`、`shape: RoundedRectangleBorder(borderRadius: 16)`、**无 side**。
- `dividerTheme`：`color: hairline`，但组件规范中仍优先不用 Divider。
