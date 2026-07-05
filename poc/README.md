# 小说阅读�?POC

独立 Flutter 最小工程，用于验证 EPUB/TXT 分块导入与高亮查词（�?`docs/poc-plan.md`）�?

## 前置条件

- [Flutter SDK](https://docs.flutter.dev/get-started/install)（建�?3.24+�?
- Android Studio / Xcode（真机或模拟器）

## 首次初始�?

本目录只包含 `lib/` �?`pubspec.yaml`�?*首次需生成 Android/iOS 平台工程**�?

```powershell
cd poc
.\scripts\bootstrap.ps1
```

或手动：

```powershell
cd poc
flutter create . --org com.novelreader.multireader --project-name multi_novel_reader
flutter pub get
```

## 运行

```powershell
cd d:\ccccc\novel_reader\poc
flutter run
```

## UI 点选调试（Flutter DevTools�?

在真�?模拟器里点击界面元素，查�?Widget 树、padding、颜色，并跳转到对应源码（如 `lookup_card.dart`）�?

### 方式 A：脚本一键启�?

```powershell
cd d:\ccccc\novel_reader\poc
.\scripts\dev-inspect.ps1
```

脚本会后台启�?`dart devtools`，并在当前终端运�?`flutter run`�?

### 方式 B：Cursor / VS Code

1. 安装推荐扩展�?*Dart**�?*Flutter**（打开工作区时会提示）
2. �?**F5** 选择 **Flutter App (poc)** 启动调试
3. 调试控制台或状态栏点击 **Open DevTools**
4. DevTools �?**Inspector** �?**Select Widget Mode**（靶心）
5. �?App 里点击组�?�?右侧看属�?�?**Jump to source** 跳到 Dart 文件

### 方式 C：手�?

```powershell
cd poc
flutter run
# 终端里点�?DevTools 链接，或另开终端�?
dart devtools
```

**局�?*：不能拖拽改布局；查词卡、底栏等 Dialog/Overlay 需先在 App 里手动打开再点选�?

官方文档：[Flutter Inspector](https://docs.flutter.dev/tools/devtools/inspector)

## Android 构建（Windows�?

- 工程路径保持 ASCII（当�?`d:\ccccc\novel_reader\poc`�?
- 建议用户环境变量 `PUB_CACHE=D:\pub-cache`
- Clash TUN 时勿�?`android/gradle.properties` �?`~/.gradle/gradle.properties` 同时启用 `127.0.0.1:7897` 代理
- Release：`flutter build apk --release` �?`build/app/outputs/flutter-apk/app-release.apk`

详见 [`docs/mvp-plan.md`](../docs/mvp-plan.md)「Android 构建环境」�?

## 验收标准（任�?#1�?
- `flutter pub get` 无报�?
- `flutter run` 在模拟器/真机显示「POC 工程已就绪」首�?

## 目录结构

```
lib/
├── main.dart          # 入口
├── database/          # Drift 八表（任�?#2�?
├── import/            # EPUB/TXT 导入（任�?#3-4�?
├── reader/            # 阅读器（任务 #5+�?
└── vocab/             # 词库 Set（任�?#7�?
```

## 依赖说明

| �?| 用�?|
|----|------|
| drift + drift_flutter | 本地 SQLite |
| epubx | EPUB 解析 |
| flutter_widget_from_html | HTML 块渲�?|
| file_picker | 选书导入 |
| path_provider | 块文件私有目�?|
