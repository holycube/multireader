# MVP 词典资产

## 文件

| 文件 | 说明 |
|------|------|
| `mvp_dict.json` | 运行时内置词典（**ECDICT 裁剪**，10k 词条，约 **6.0MB**，manifest v2） |
| `mvp_dict_aliases.json` | 变形别名表（Sprint 10，~14k 条，约 0.65MB）；查词 alias 回落用 |
| `poc_dict.json` | 已废弃（Sprint 6 删除） |

**本地备份**（`poc/data/backups/`，不进 git）：

| 文件 | 说明 |
|------|------|
| `mvp_dict.ecdict.json` | ECDICT 裁剪版副本（与当前运行时资产一致） |
| `mvp_dict.bootstrap.json` | 开发兜底版（`bootstrap_mvp_dict.py` 生成，8k 占位） |

## JSON Schema

根对象为 `Record<normalizedWord, DictEntry>`，key 为小写词形。

```json
{
  "credit": {
    "word": "credit",
    "phonetic": "/ˈkredɪt/",
    "senses": [
      {
        "pos": "n.",
        "meanings": [
          { "text": "信贷", "primary": true },
          { "text": "赞扬" },
          { "text": "信誉" },
          { "text": "学分" }
        ]
      },
      {
        "pos": "vt.",
        "meanings": [
          { "text": "把钱存入账户", "primary": true },
          { "text": "把…归功于" }
        ]
      }
    ],
    "examTags": ["考研", "四级"],
    "englishDefinition": "n. ...\nvt. ...",
    "fullTranslation": "n. 信贷\n...",
    "exchange": "d:credited/p:credited/3:credits",
    "collins": 4,
    "oxford3000": true
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `word` | string | 是 | 词条原形 |
| `phonetic` | string | 否 | IPA 音标 |
| `senses` | array | 是 | 按词性分组的中文义项 |
| `senses[].pos` | string | 否 | 如 `n.`、`vt.` |
| `senses[].meanings` | object[] | 是 | 同词性下的中文义项；`{ "text": string, "primary"?: bool }`，每 sense 首条默认主释义 |
| `examTags` | string[] | 否 | 本地化标签：考研 / 四级 / 六级 / 雅思 |
| `englishDefinition` | string | 否 | 英文释义原文（详情页） |
| `fullTranslation` | string | 否 | 中文释义原文（详情页） |
| `exchange` | string | 否 | ECDICT 词形变化 |
| `collins` | int | 否 | 柯林斯星级 1–5 |
| `oxford3000` | bool | 否 | 是否牛津 3000 核心词 |

### 别名 Schema（`mvp_dict_aliases.json`）

根对象为 `Record<variantWord, AliasMeta>`，key 为变形小写词形（非 lemma 键）。

```json
{
  "ringing": { "lemma": "ring", "exchangeKey": "i" },
  "was": { "lemma": "be", "exchangeKey": "p", "phonetic": "/wəz/" }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `lemma` | string | 是 | 回落原形键（须存在于 `mvp_dict.json`） |
| `exchangeKey` | string | 是 | ECDICT 键：`p`/`d`/`i`/`3`/`r`/`t`/`s` |
| `phonetic` | string | 否 | 变形独立音标；无则 UI 回落 lemma 音标 |

## 构建

数据来源：[ECDICT](https://github.com/skywind3000/ecdict)（MIT License）。

### Release vs Debug（Sprint 12）

| 模式 | 词典来源 |
|------|----------|
| Debug / `flutter test` | 本目录 `mvp_dict.json` + `mvp_dict_aliases.json`（`pubspec.yaml` assets） |
| Release AAB | **不随包**；首次启动 CDN 下载 → `{ApplicationSupport}/dict/v1/` |

```powershell
# 生成 manifest + SHA256 + 上传目录
.\scripts\publish_dict_pack.ps1

# Release AAB（临时剔除 dict assets、跑测试、打 bundle）
.\scripts\build_release.ps1
# 无 keystore：.\scripts\build_release.ps1 -SkipAab
```

规格：[dict-pack-delivery.md](../../docs/dict-pack-delivery.md)

### 本地数据目录（`poc/data/`，不进 git）

`.gitignore` 忽略 `poc/data/`，需在本地自行下载 ECDICT。典型目录树：

```
poc/data/
├── ecdict-sqlite.zip              # 原始压缩包（~207 MB）
├── ecdict-extracted/
│   └── stardict.db                # 解压后的 SQLite（~812 MB，推荐 --input）
├── stardict.db                    # 同上库的副本（任选其一）
├── ecdict.mini.csv                # 仅 53 行样例，不可用于全量构建
└── backups/
    ├── mvp_dict.ecdict.json       # 裁剪版本地备份
    └── mvp_dict.bootstrap.json    # bootstrap 兜底版
```

ECDICT 数据库中的 `pos` 字段记录的是**语料频率统计**（如 `n:46/v:54`），**不会**写入 `mvp_dict.json` 的 `senses[].pos`；词性仅从 `translation` 中文释义行解析（`n.`、`vt.`、`[计]` 等）。

```bash
# 1. 下载 ECDICT SQLite release
#    https://github.com/skywind3000/ECDICT/releases → ecdict-sqlite-28.zip
#    解压至 poc/data/ecdict-extracted/stardict.db

# 2. 跑单元测试
python poc/scripts/test_build_mvp_dict.py

# 3. 生成 mvp_dict.json（推荐输入路径）
python poc/scripts/build_mvp_dict.py \
  --input poc/data/ecdict-extracted/stardict.db \
  --output poc/assets/dict/mvp_dict.json \
  --include-exchange-aliases \
  --aliases-output poc/assets/dict/mvp_dict_aliases.json

# 从旧 string[] 格式迁移（一次性）
python poc/scripts/migrate_dict_meanings.py poc/assets/dict/mvp_dict.json

# 无 ECDICT 时：从现有 mvp_dict.json 重建别名
python poc/scripts/generate_aliases_from_dict.py poc/assets/dict/mvp_dict.json

# 开发兜底（无 ECDICT 时，8k 结构化占位 + credit/hello）
python poc/scripts/bootstrap_mvp_dict.py

# 4. 校验（含语料统计型 pos 扫描 + 别名 lemma 存在性）
python poc/scripts/validate_mvp_dict.py poc/assets/dict/mvp_dict.json poc/assets/dict/mvp_dict_aliases.json

# 从旧版 string[] meanings 迁移到 object 格式（一次性）
python poc/scripts/migrate_dict_meanings.py poc/assets/dict/mvp_dict.json

# 5. 同步本地备份（可选）
#    cp poc/assets/dict/mvp_dict.json poc/data/backups/mvp_dict.ecdict.json
```

选词策略见 `poc/scripts/build_mvp_dict.py` 顶部注释。

## 授权（P1-01）

- 数据源：ECDICT（MIT）
- 裁剪与格式化由本项目 `build_mvp_dict.py` 完成
- 随 APK 分发 `mvp_dict.json` + `mvp_dict_aliases.json` 裁剪版，非完整 ECDICT 数据库

## Release 构建（Sprint 12）

| 构建类型 | 词典来源 |
|----------|----------|
| Debug / `flutter test` | `pubspec.yaml` 内置 assets（本目录 JSON） |
| Release AAB | **不含** dict JSON；首次启动 CDN 下载 → 见 [dict-pack-delivery.md](../../docs/dict-pack-delivery.md) |

```powershell
# 生成 CDN 上传包（SHA256 + manifest.json）
.\scripts\publish_dict_pack.ps1

# Release AAB（临时从 pubspec 剔除 dict 两行）
.\scripts\build_release.ps1 -ManifestUrl https://your-cdn/dict/v1/manifest.json
```
