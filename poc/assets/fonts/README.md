# Noto Serif SC（壳层衬线）

| 文件 | 字重 | 来源 |
|------|------|------|
| `NotoSerifSC-Regular.otf` | 400 | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) SubsetOTF/SC |
| `NotoSerifSC-SemiBold.otf` | 600 | 同上 |
| `OFL.txt` | — | [Google Fonts OFL](https://github.com/google/fonts/tree/main/ofl/notoserifsc) |

## 裁剪说明

使用 **Subset OTF（简体中文子集）**，非完整 CJK 65535 字形集，体积约 11 MB × 2。覆盖常用汉字与拉丁，满足壳层区块标题与统计数字。

## 使用范围

**仅 Tab 壳层**：统计区块标题、数据大数字、词库等级标题等（见 `poc/lib/theme/app_text_styles.dart`）。

**不用于**：阅读器正文、查词卡（仍用 `Georgia` / 系统 UI 字体）、词库向导。

## 许可证

SIL Open Font License 1.1（见 `OFL.txt`）。
