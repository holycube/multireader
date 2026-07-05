# 沉浸式外语小说阅读器

面向中文用户、专为长篇英文小说设计的本地沉浸式阅读器。

## 文档

- [产品需求文档 v0.3](./docs/PRD-v0.3.md)（当前版本）
- [变现策略](./docs/monetization.md)
- [技术选型](./docs/tech-stack.md)
- [数据模型](./docs/data-model.md)
- [用户流程](./docs/user-flow.md)
- [POC 验证报告](./docs/poc-report.md)
- [MVP 迭代计划](./docs/mvp-plan.md)
- [PRD v0.2（历史）](./docs/PRD-v0.2.md)

## 产品一句话

用户自带书，App 负责书之后的一切——解析、高亮、查词、词库管理、进度统计、数据备份。

## 已敲定决策（摘要）

| 决策项 | 结论 |
|--------|------|
| 框架 | Flutter |
| 数据库 | Drift + 内存词库 Set |
| EPUB | 路线 C：保留 HTML，预处理 span |
| TXT | Text.rich + TextSpan 双管线 |
| 数据模型 | Chapter + ContentBlock 两表分离 |
| 阅读额度 | v1.0 全书可读（无 40 块墙、无广告） |
| 商业模式 | v1.0 免费无广告；Pro 永久买断（v1.1+）见 monetization |
| 查词状态机 | 高亮仅由 known_words 决定；见 data-model §9 |
| 词库向导 | 3 步，4 档叠加，txt/csv 导入 |
| 书架 | 列表，最近阅读，默认首页 |
| 词典 MVP | 内置 JSON 10k 词（ECDICT 裁剪） |
| MVP 状态 | Sprint 0–12 已完成；Play 封闭测试见 [play-closed-testing-checklist](./docs/play-closed-testing-checklist.md) |

## POC / MVP 工程

Flutter 工程位于 [`poc/`](./poc/)（路径 `d:\ccccc\novel_reader\poc`）。首次运行：

```powershell
cd poc
.\scripts\bootstrap.ps1
flutter run
```

构建 Release AAB（剔除词典 assets、跑测试）：

```powershell
cd poc
.\scripts\build_release.ps1          # 需 key.properties + keystore
.\scripts\build_release.ps1 -SkipAab # 仅跑测试、不打包
```

Debug 本地运行：`flutter run`（词典内置，无需联网）。
