# 词干化支线（方案 A 仍 P2）

> **方案 B ✅ 已完成（Sprint 10，2026-06-28）** — ECDICT `exchange` 别名表 `mvp_dict_aliases.json` + `DictLoader.resolve()` + `LookupVariantCard` 双 Tab 查词卡。  
> **方案 A 仍为 P2** — 运行时 **无** Porter / 规则词干化；当前查词路径：精确命中 → 别名回落 → miss。

## 背景

MVP 词典 `mvp_dict.json` 约 8k–10k 词条，覆盖考试标签词与高频词，但**不包含**所有屈折变形（如 `walked` → `walk`）作为独立词条键。Sprint 10 通过 `mvp_dict_aliases.json`（~14k 别名）解决常见变形查词。

## 候选方案

### A. Porter / 规则词干化（运行时）— P2

- 查词 miss 后，对词形做 Porter stemmer 或规则后缀剥离（`-ed`、`-ing`、`-s` 等），再查一次词典。
- **优点**：无需扩充 JSON 体积；覆盖未收录变形。
- **缺点**：误匹配（如 `better` → `bet`）；多语言扩展难。
- **开关占位**：`ReaderPreferences.stemmingEnabled`（默认 `false`，P2 接入）。

### B. ECDICT `exchange` 别名（构建时）— ✅ Sprint 10

- 构建脚本 `build_mvp_dict.py --include-exchange-aliases`：将 `walked` 等变形映射到原形词条键，写入 `mvp_dict_aliases.json`。
- **优点**：精确、可预期；与 ECDICT 数据一致。
- **缺点**：JSON 体积增大（~0.65MB 别名文件）；需离线构建步骤。
- **已接入**：`DictLoader.resolve()` 第二级回落；`LookupVariantCard` 双 Tab UI。

### C. 混合（P2）

- 先精确查词 → 再 exchange 别名（已默认启用）→ 最后词干化（若用户打开开关）。

## 推荐顺序（P2 剩余）

1. ~~优先 **方案 B**~~ ✅ 已完成。
2. 用户可选开启 **方案 A** 作为补充（覆盖别名未收录的变形）。
3. 设置页增加「智能词形匹配」开关，默认关闭。

## 相关文件

| 文件 | 说明 |
|------|------|
| `poc/lib/vocab/dict_loader.dart` | `lookup()` 精确查找；`resolve()` 含别名层 |
| `poc/assets/dict/mvp_dict_aliases.json` | 变形别名运行时资产 |
| `poc/scripts/build_mvp_dict.py` | `exchange` 展开；`generate_aliases_from_dict.py` 无 ECDICT 时重建 |
| `poc/lib/reader/reader_preferences.dart` | 未来 `stemmingEnabled` 字段 |

## 产品约束（查词 vs 已会）

详见 **[word-variant-lookup.md](./word-variant-lookup.md)**。

- **查词**：别名回落 + 双 Tab（当前词形 | 原形），用户可在 Tab 间切换并分别操作。
- **已会 / 高亮**：仅记录表面词形，**不**随原形联动；不提供「同时标记原形」开关。
- **说明**：用户向文案放个人 → 学习设置 → 词形查词说明，不在查词卡内常驻提示。

## 不在范围

- 词根、近义词、派生词 Tab（需额外数据源）
- 词典 CDN 按需下载（P1-02）
- 查词卡「同时标记原形」勾选（Tab 直达即可）
