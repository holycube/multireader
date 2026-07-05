# Google Play 封闭测试清单（v1.0）

应用 ID：`com.novelreader.multireader`  
显示名：**小说阅读器**  
版本：**1.0.0+1**

## 构建前

- [ ] 本地 keystore 已生成并备份（丢失无法更新同一包名）
- [ ] 复制 `poc/android/key.properties.example` → `key.properties`，填写签名信息
- [ ] 运行 `poc/scripts/publish_dict_pack.ps1`，上传词典包至 CDN
- [ ] 确认生产 `DICT_PACK_MANIFEST_URL` 可访问
- [ ] 运行 `poc/scripts/build_release.ps1`（或 `-SkipAab` 仅跑测试）
- [ ] 卸载旧 POC 包 `com.novelreader.poc.novel_reader_poc`（若曾安装）

## Play Console — 应用创建

- [ ] 创建应用，包名 `com.novelreader.multireader`
- [ ] 商店列表：英文标题建议 "Multi Novel Reader"；简短说明含「首次启动需联网下载词典（约 5 MB）」

## 封闭测试轨道

- [ ] 上传 Release AAB（`build/app/outputs/bundle/release/app-release.aab`）
- [ ] App Bundle Explorer 确认 **不含** `mvp_dict.json` / `mvp_dict_aliases.json`
- [ ] 记录 arm64 **download size**（目标 &lt; 35 MB；字体 ~22 MB 可能仍超标 → 记入 follow-up）
- [ ] 创建**封闭测试**轨道，添加测试员邮箱
- [ ] 版本说明注明：首次启动需联网下载词典

## 政策与合规

- [ ] **隐私政策**公开 URL（GitHub Pages / 静态站；App 内 Markdown 不够）
- [ ] **Data safety**：本地存储、无广告 SDK、无账号、INTERNET（词典下载）
- [ ] **IARC 分级**问卷完成
- [ ] 内容分级：无 UGC、无暴力 → 低年龄友好

## 真机验收（封闭测试员）

- [ ] Release 安装 → 清数据 → 首次启动显示「正在下载词典…」→ 查词正常
- [ ] 二次启动无下载（读缓存）
- [ ] 导入 EPUB / TXT → 高亮查词
- [ ] Debug 构建：`flutter run` 无需联网即可查词（bundled assets）

## 签名备份警告

> Release keystore 与 `key.properties` **不得提交 git**。丢失后无法向同一 applicationId 推送更新。
