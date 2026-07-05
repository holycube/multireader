# 启动 Flutter App 并打开 DevTools Inspector（点选组件调试）
# 用法：在 poc 目录执行 .\scripts\dev-inspect.ps1
# 可选参数：-DeviceId <id>  指定设备（flutter devices 查看）

param(
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"
$PocRoot = Split-Path -Parent $PSScriptRoot
Set-Location $PocRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 flutter 命令，请先安装 Flutter SDK。"
}

Write-Host ""
Write-Host "=== Flutter DevTools 点选调试 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "步骤："
Write-Host "  1. 下方终端会启动 App（保持运行）"
Write-Host "  2. 另开终端执行: dart devtools"
Write-Host "     或点击 flutter run 输出里的 DevTools 链接"
Write-Host "  3. DevTools → Inspector → Select Widget Mode（靶心图标）"
Write-Host "  4. 在 App 里点击查词卡、底栏等 → 右侧查看属性"
Write-Host "  5. 若已装 Flutter 扩展，可 Jump to source 跳到源码"
Write-Host ""
Write-Host "提示：Dialog / Overlay（查词卡、底栏）需先在 App 里手动打开再点选。"
Write-Host "文档：https://docs.flutter.dev/tools/devtools/inspector"
Write-Host ""

# 后台启动 DevTools 服务（不阻塞 flutter run）
if (Get-Command dart -ErrorAction SilentlyContinue) {
    Start-Process -FilePath "dart" -ArgumentList "devtools" -WindowStyle Minimized
    Write-Host "已后台启动 dart devtools → 浏览器打开 http://127.0.0.1:9100" -ForegroundColor Green
    Write-Host ""
}

$runArgs = @("run")
if ($DeviceId) {
    $runArgs += @("-d", $DeviceId)
}

Write-Host "启动 App..." -ForegroundColor Cyan
& flutter @runArgs
