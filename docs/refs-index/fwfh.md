# flutter_widget_from_html 参考索引

- **仓库**：`https://github.com/daohoangson/flutter_widget_from_html`（本地 `refs/flutter_widget_from_html/`）
- **pub 包**：`flutter_widget_from_html`（聚合包）、`flutter_widget_from_html_core`（核心）
- **物理路径**：`refs/flutter_widget_from_html/packages/core/lib/`
- **本项目用途**：POC2 HTML 管线 — 渲染预处理后的 HTML、自定义 `span.word` 点击与虚线下划线

---

## 目录树（core 包）

```
refs/flutter_widget_from_html/packages/core/lib/src/
├── core_html_widget.dart       ★ HtmlWidget 入口
├── core_widget_factory.dart    ★ 扩展点：手势、TextSpan、BuildOp
├── core_data.dart              ○ 数据类
├── internal/
│   ├── ops/
│   │   ├── tag_a.dart              ★ 内联点击 + GestureRecognizer 范例
│   │   ├── style_text_decoration.dart  ★ underline / dashed 样式
│   │   ├── flattener.dart          ○ TextSpan 扁平化流程
│   │   └── core_ops.dart           ○ BuildOp 注册汇总
│   ├── text_ops.dart           ○ 文本节点处理
│   └── core_build_tree.dart    ○ DOM 树构建
└── widgets/                    ○ 表格、列表等块级组件
```

★ = POC 直接相关　○ = 进阶/备选

---

## 阅读管线步骤映射

对照 `docs/tech-stack.md` §3.3、§4：

| 步骤 | 本项目动作 | fwfh 参照 |
|------|-----------|-----------|
| 1. 读块 HTML 文件 | 从 `contentPath` 加载 | 传入 `HtmlWidget(html)` |
| 2. 注入 span.word | 预处理 HTML 字符串 | 自研；渲染侧用自定义 BuildOp 识别 |
| 3. 渲染 | 显示带高亮正文 | `core_html_widget.dart` |
| 4. 词点击 | 打开查词面板 | `core_widget_factory.dart` → `buildGestureRecognizer` |
| 5. 虚线下划线 | `.word.unknown` 样式 | `style_text_decoration.dart` 或预处理 CSS class |
| 6. 本地图片 | `assets/...` 相对路径 | `WidgetFactory.urlFull` / 默认图片加载 |

---

## 核心 API

### 渲染入口 — `core_html_widget.dart`

```dart
HtmlWidget(
  html,
  factoryBuilder: () => MyWidgetFactory(),  // 自定义工厂
  onTapUrl: (url) => ...,                   // 链接点击（本项目用 span 而非 a）
)
```

### 扩展工厂 — `core_widget_factory.dart`

关键可覆写方法：

```dart
class MyWidgetFactory extends WidgetFactory {
  // 构建手势识别器（参照 tag_a.dart）
  GestureRecognizer? buildGestureRecognizer(
    BuildTree tree, {
    GestureTapCallback? onTap,
  });

  // 构建 TextSpan
  TextSpan buildTextSpan(
    BuildTree tree,
    InheritedProperties resolved,
    TextSpan textSpan,
  );

  // 内联手势包裹
  Widget? buildGestureDetector(
    BuildTree tree,
    Widget child,
    GestureRecognizer recognizer,
  );
}
```

### 链接点击范例 — `tag_a.dart`

`TagA` 展示了标准模式：

1. 在 `BuildOp.onParsed` 中读取 `tree.element.attributes`
2. 调用 `wf.buildGestureRecognizer(tree, onTap: ...)`
3. 对内联节点设置 recognizer

本项目 `span.word` 可类比：

```dart
// 伪代码思路（非 refs 内现有代码）
BuildOp(
  debugLabel: 'span.word',
  onParsed: (tree) {
    final classes = tree.element.classes;
    if (!classes.contains('word')) return tree;
    final dataWord = tree.element.attributes['data-word'];
    final recognizer = wf.buildGestureRecognizer(
      tree,
      onTap: () => onWordTap(dataWord, classes.contains('unknown')),
    );
    // 设置 recognizer 到 tree...
    return tree;
  },
)
```

### 下划线样式 — `style_text_decoration.dart`

- 解析 CSS `text-decoration` / `text-decoration-line` / `text-decoration-style`
- 支持 `underline`、`line-through` 等
- 本项目可在预处理阶段直接注入 class + 内联 style，减少自定义 BuildOp 复杂度

---

## 扩展范例（extends + mixin）

各子包 `example/main.dart` 展示标准扩展模式：

```
refs/flutter_widget_from_html/packages/fwfh_url_launcher/example/main.dart
```

```dart
class MyWidgetFactory extends WidgetFactory with UrlLauncherFactory {}
```

本项目可定义 `WordTapWidgetFactory extends WidgetFactory`，在 `parse` 阶段注册自定义 `BuildOp`。

---

## 与本项目 HTML 示例的对照

`docs/tech-stack.md` §6.3 目标 HTML：

```html
<p>It was a <span class="word unknown" data-word="bright">Bright</span> cold day.</p>
```

实现路径（二选一或组合）：

1. **预处理注入 class** — fwfh 默认解析 span，通过 CSS / `customStylesBuilder` 渲染下划线
2. **自定义 BuildOp** — 参照 `tag_a.dart` 为 `span.word` 添加 `TapGestureRecognizer`

---

## 常见陷阱

| 问题 | 说明 |
|------|------|
| 包路径混淆 | pub 名 `flutter_widget_from_html_core`，目录名 `packages/core` |
| 只支持 TapGestureRecognizer | `buildGestureRecognizer` 目前主要支持 `onTap` |
| recognizer 需释放 | `WidgetFactory` 内部维护 `_recognizersNeedDisposing`，扩展时遵循其生命周期 |
| 大 HTML 性能 | POC2 指标：~500 词/块预处理 <200ms；必要时缓存已注入 HTML |

---

## 关联文档

- 双管线：`docs/tech-stack.md` §4
- 高亮样式：`docs/tech-stack.md` §6
- 场景矩阵：`scenario-map.md` POC2 HTML 子任务
