# Drift 参考索引

- **仓库**：`https://github.com/simolus3/drift`（本地 `refs/drift/`）
- **pub 包**：`drift`、`drift_flutter`、`drift_dev`（代码生成）
- **本项目用途**：POC1 写入八表元数据；POC2 词库查询、进度与 `parse_quota` 解锁

---

## 目录树（仅必要子树）

```
refs/drift/
├── examples/app/lib/database/   ★ Flutter 完整示例（首选参照）
│   ├── tables.dart              ★ Table 声明
│   ├── database.dart            ★ @DriftDatabase、迁移、DAO
│   ├── database.g.dart          ○ 生成产物范例
│   ├── database.steps.dart      ○ stepByStep 迁移辅助
│   ├── sql.drift                ○ 自定义 SQL 查询
│   └── connection/              ○ 平台连接（native / web）
└── drift/lib/src/               ○ Table/Column 底层 API（进阶）
```

★ = POC 直接相关　○ = 进阶/备选

---

## 本项目八表对照

参照 `docs/data-model.md`，Drift 声明模式如下：

| 本项目表 | 参照模式 | 参考文件 |
|----------|----------|----------|
| `books` | `Table` + `text()` 主键（UUID 不用 autoIncrement） | `tables.dart` |
| `chapters` | `text()` FK → `books.id`，`references(Books, #id)` | `tables.dart` |
| `content_blocks` | 复合排序字段 `orderIndex` / `globalBlockIndex` | `tables.dart` |
| `reading_progress` | `bookId` 作 PK（1:1） | `database.dart` DAO |
| `known_words` | `text()` 主键 `word`，无自增 | `tables.dart` |
| `vocab_entries` | `text()` PK + 可选 FK | `tables.dart` |
| `parse_quota` | `bookId` PK，`int` 额度字段 | `database.dart` |
| `reading_stats_daily` | 复合主键 `date` + `bookId` | `tables.dart` |

### Table 声明范例 — `tables.dart`

```dart
@DataClassName('TodoEntry')
class TodoEntries extends Table with AutoIncrementingPrimaryKey {
  TextColumn get description => text()();
  IntColumn get category => integer().nullable().references(Categories, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
}

mixin AutoIncrementingPrimaryKey on Table {
  IntColumn get id => integer().autoIncrement()();
}
```

本项目 `books.id` 用 `text()` 主键而非 `autoIncrement()`；`known_words.word` 同理。

### 数据库类 — `database.dart`

```dart
@DriftDatabase(tables: [TodoEntries, Categories], include: {'sql.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(
          name: 'todo-app',
          native: const DriftNativeOptions(
            databaseDirectory: getApplicationSupportDirectory,
          ),
        ));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.todoEntries, schema.todoEntries.dueDate);
      },
      // ...
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

---

## 常用 DAO 模式

### 查询 — `database.dart` L99-137

```dart
// 条件查询
Future<List<TodoEntryWithCategory>> search(String query) {
  return _search(query).map((row) => ...).get();
}

// 流式监听
Stream<List<CategoryWithCount>> categoriesWithCount() {
  return _categoriesWithCount().map((row) => ...).watch();
}

// JOIN + WHERE
Stream<List<TodoEntryWithCategory>> entriesInCategory(int? categoryId) {
  final query = select(todoEntries).join([
    leftOuterJoin(categories, categories.id.equalsExp(todoEntries.category))
  ]);
  query.where(categories.id.equals(categoryId));
  return query.map((row) => ...).watch();
}
```

### 本项目映射

| 操作 | Drift 模式 |
|------|-----------|
| 按 `bookId` 取块列表 | `select(contentBlocks)..where((b) => b.bookId.equals(id))..orderBy([(b) => OrderingTerm.asc(b.globalBlockIndex)])` |
| 加载全部 known_words | `select(knownWords).get()` → 转 `Set<String>` |
| 检查 parse_quota | `select(parseQuota)..where((q) => q.bookId.equals(id))` |
| 更新 reading_progress | `into(readingProgress).insertOnConflictUpdate(...)` |
| 批量插入 content_blocks | `batch((b) { b.insertAll(contentBlocks, [...]); })` |

---

## 迁移

| 概念 | 参照 |
|------|------|
| `schemaVersion` | `database.dart` L46 |
| `stepByStep` 增量迁移 | `database.dart` L51-66 |
| 生成迁移辅助 | `database.steps.dart`（`drift_dev make-migrations`） |
| 运行时校验 | `beforeOpen` → `validateDatabaseSchema` |

MVP 初版可 `schemaVersion = 1`，无 `onUpgrade`；后续加列参照 `from1To2` 范例。

---

## 连接初始化

POC 推荐使用 `drift_flutter`：

```dart
driftDatabase(
  name: 'novel-reader',
  native: const DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
  ),
)
```

平台分流见 `refs/drift/examples/app/lib/database/connection/`。

---

## 导入管线步骤映射

| 步骤 | 本项目动作 | Drift 参照 |
|------|-----------|------------|
| 导入开始 | 插入 `books`（importStatus=pending） | `into(books).insert(...)` |
| 写完章节 | 批量插入 `chapters` | `batch` + `insertAll` |
| 写完块 | 批量插入 `content_blocks` | `batch` + `insertAll` |
| 初始化额度 | 插入 `parse_quota`（freeAllowance=40） | `into(parseQuota).insert(...)` |
| 导入完成 | 更新 `books.importStatus=complete` | `update(books).replace(...)` |
| 打开块前 | 查 `globalBlockIndex` vs `unlockedBlockCount` | `select` + 条件判断 |

---

## 常见陷阱

| 问题 | 说明 |
|------|------|
| 忘记 `build_runner` | Table 变更后需 `dart run build_runner build` 生成 `*.g.dart` |
| 外键未启用 | `beforeOpen` 中执行 `PRAGMA foreign_keys = ON` |
| 大文本进 BLOB | 本项目 HTML/TXT 存文件，DB 只存 `contentPath`（见 `data-model.md`） |
| 示例用 autoIncrement | 本项目多表用 `text()` UUID 主键，勿照搬 `AutoIncrementingPrimaryKey` |

---

## 关联文档

- 八表字段：`docs/data-model.md` §3
- 块存储策略：`docs/tech-stack.md` §5
- 场景矩阵：`scenario-map.md` POC1/POC2 数据库子任务
