# 预置词汇量等级词表

词库向导与词库 Tab「重新选择词汇量」使用的分层词表，按 PRD 四级累积加载。

## 文件

| 文件 | 增量词数 | 累积词数 | ECDICT `tag` |
|------|----------|----------|--------------|
| `cet4.txt` | 4,500 | 4,500 | `gk`, `cet4` |
| `cet6.txt` | 1,500 | 6,000 | `cet6` |
| `toefl.txt` | 2,000 | 8,000 | `ielts`, `toefl` |
| `advanced.txt` | 4,000 | 12,000 | `ky`, `gre`（不足时按 oxford / collins / frq 补齐） |

运行时由 [`preset_loader.dart`](../../lib/screens/vocab_wizard/preset_loader.dart) 按等级叠加加载（高级选项包含更低等级词汇）。

## 数据来源与授权

- 数据源：[ECDICT](https://github.com/skywind3000/ecdict)（MIT License）
- 裁剪脚本：[`poc/scripts/build_preset_wordlists.py`](../../scripts/build_preset_wordlists.py)
- 随 APK 分发的是按考试标签裁剪的**词形列表**，非完整 ECDICT 数据库

## 重建

需本地 ECDICT SQLite（与 [`assets/dict/README.md`](../dict/README.md) 相同）：

```bash
python poc/scripts/build_preset_wordlists.py \
  --input poc/data/ecdict-extracted/stardict.db \
  --output-dir poc/assets/presets/

python poc/scripts/test_build_preset_wordlists.py
```

选词规则：词形小写归一化 → 按 `frq` 升序（高频优先）→ 每级仅写入增量词 → 累积达到 PRD 目标词数。
