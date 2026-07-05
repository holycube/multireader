# Flutter 开发环境一键检查（Windows）
# 用法：在项目根或 poc 目录执行 .\poc\scripts\setup-flutter-env.ps1

$ErrorActionPreference = "Stop"
$FlutterRoot = "C:\src\flutter"
$FlutterBin = Join-Path $FlutterRoot "bin"

function Test-FlutterInPath {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

# 1. 检测 / 提示安装 Flutter
if (-not (Test-Path (Join-Path $FlutterBin "flutter.bat"))) {
    Write-Host "未检测到 Flutter SDK（预期路径：$FlutterRoot）" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请任选一种方式安装："
    Write-Host "  A) Git 克隆（推荐）："
    Write-Host "     git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter"
    Write-Host "  B) 官方 zip：https://docs.flutter.dev/get-started/install/windows"
    Write-Host ""
    Write-Host "安装后重新运行本脚本。"
    exit 1
}

# 2. 写入用户 PATH（若缺失）
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$FlutterBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$FlutterBin;$userPath", "User")
    Write-Host "已将 $FlutterBin 加入用户 PATH（新终端生效）" -ForegroundColor Green
}
$env:PATH = "$FlutterBin;" + (($env:PATH -split ';' | Where-Object { $_ -and $_ -ne $FlutterBin }) -join ';')

Write-Host ""
Write-Host "=== Flutter 版本 ===" -ForegroundColor Cyan
flutter --version

# 3. Android SDK 环境变量（本机已装 Android Studio 时）
$androidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
if (Test-Path $androidSdk) {
    if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = $androidSdk }
    if (-not $env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT = $androidSdk }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $platformTools = Join-Path $androidSdk "platform-tools"
    if ($userPath -notlike "*$platformTools*") {
        [Environment]::SetEnvironmentVariable("Path", "$platformTools;$userPath", "User")
        Write-Host "已将 Android platform-tools 加入用户 PATH" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== flutter doctor ===" -ForegroundColor Cyan
flutter doctor

Write-Host ""
Write-Host "若 Android toolchain 有 ✗，在 Android Studio 中：" -ForegroundColor Yellow
Write-Host "  Settings → Languages & Frameworks → Android SDK → 安装 SDK Platform + Build-Tools"
Write-Host "  并创建 AVD 模拟器（Device Manager）"
Write-Host ""
Write-Host "接受许可：flutter doctor --android-licenses" -ForegroundColor Yellow
Write-Host ""
Write-Host "若 flutter run 提示 symlink，请开启 Windows 开发者模式：" -ForegroundColor Yellow
Write-Host "  设置 → 隐私和安全性 → 开发者选项 → 开发人员模式"
Write-Host "  或运行：start ms-settings:developers"
Write-Host ""
Write-Host "环境就绪后，在 poc 目录执行：.\scripts\bootstrap.ps1" -ForegroundColor Green
