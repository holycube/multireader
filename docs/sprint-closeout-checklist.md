# Sprint 收尾 Checklist（T5 文档同步）

> 代码集成与测试通过后再执行。单轨更新、逐项打勾，避免多 agent 并行改文档导致漏改。

关联：[mvp-plan.md](./mvp-plan.md) · [project-roadmap.mdc](../.cursor/rules/project-roadmap.mdc)

---

## 时机

- **开始**：T3 集成完成 + `flutter test` 全绿（或等价验收通过）
- **不要**：与实现并行写规格正文（产品决策可先写 `docs/<feature>.md`，但「已实现」状态须晚于代码）

---

## 必改（每个 Sprint）

- [ ] **`docs/mvp-plan.md`** — Sprint 总览表新增一行；必要时补详节；更新文档版本与「最后更新」
- [ ] **`.cursor/rules/project-roadmap.mdc`** — 「最近 Sprint」区更新 1 行摘要（勿在此堆历史，详史只在 mvp-plan）

---

## 按类型选改

| 若本 Sprint 涉及… | 同步文件 |
|-------------------|----------|
| UI / 查词卡 / 组件 | `docs/design-system.md` |
| 数据模型 / 状态机 | `docs/data-model.md` |
| 技术栈 / 管线 / 性能结论 | `docs/tech-stack.md` |
| 已验证的架构或性能基线 | `docs/poc-report.md` |
| 词典 / 预置资产 / 构建脚本 | `poc/assets/dict/README.md`、`poc/assets/presets/README.md` 等 |
| 新产品决策或功能边界 | 新建或更新 `docs/<feature>.md` |
| 用户可见说明 | `poc/assets/legal/*.md` + `legal_document_screen.dart` 入口 |
| 开源库 API 检索路径 | `docs/refs-index/*.md`（**不要**改 `.cursor/rules/refs-context.mdc` 关键词表） |
| 待定事项状态变化 | `project-roadmap.mdc`「仍待定」表 |

---

## 文档角色（写哪一份）

| 文档 | 写什么 |
|------|--------|
| `PRD-v0.2.md` | 做什么、为什么（少改） |
| `mvp-plan.md` | Sprint 何时做完、验收项、产出路径 |
| `docs/<feature>.md` | 单功能可执行规格：决策 + 边界 + 明确不改什么 |
| `design-system.md` | 视觉与组件规范 |
| `poc-report.md` | 已验证的技术结论与性能数字 |
| `assets/legal/` | 用户能看懂的话 |
| `.cursor/rules/` | AI 行为约束与导航链接（不堆规格正文） |

---

## 验收（grep 示例）

将 `N` 替换为本 Sprint 编号或关键词后执行：

```powershell
# 必改
rg "Sprint N" docs/mvp-plan.md .cursor/rules/project-roadmap.mdc

# 按类型（示例：词形查词）
rg "LookupVariantCard|resolve\(" docs/design-system.md docs/word-variant-lookup.md
rg "mvp_dict_aliases" poc/assets/dict/README.md
```

全部命中预期后，在 PR / 对话中勾选本 checklist。

---

## 历史参考

Sprint 10 曾同步 8 类文件，可作为复杂 Sprint 的模板：

1. `project-roadmap.mdc`、`mvp-plan.md`
2. `word-variant-lookup.md`、`future-stemming.md`、`tech-stack.md`、`data-model.md`
3. `poc/assets/dict/README.md`、`design-system.md`、`assets/legal/word_variant_lookup.md`
