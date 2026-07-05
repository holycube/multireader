#Requires -Version 5.1
<#
.SYNOPSIS
  Release AAB 构建：临时剔除 dict assets、跑测试、打签名包。

.PARAMETER ManifestUrl
  DICT_PACK_MANIFEST_URL（默认占位，生产需替换）

.PARAMETER SkipAab
  跳过 appbundle 构建（无 keystore 时可用）
#>
param(
    [string]$ManifestUrl = "https://cdn.example.com/dict/v1/manifest.json",
    [switch]$SkipAab
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PocRoot = Split-Path -Parent $ScriptRoot
$Pubspec = Join-Path $PocRoot "pubspec.yaml"
$Backup = Join-Path $PocRoot "pubspec.yaml.bak.release"

Push-Location $PocRoot
try {
    Write-Host "==> flutter test (with bundled dict assets)"
    flutter test
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }

    Write-Host "==> Backing up pubspec.yaml"
    Copy-Item -Force $Pubspec $Backup

    Write-Host "==> Stripping dict assets from pubspec (Release only)"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $content = [System.IO.File]::ReadAllText($Pubspec, $utf8NoBom)
    $content = $content -replace "(?m)^\s*- assets/dict/mvp_dict\.json\s*\r?\n", ""
    $content = $content -replace "(?m)^\s*- assets/dict/mvp_dict_aliases\.json\s*\r?\n", ""
    [System.IO.File]::WriteAllText($Pubspec, $content, $utf8NoBom)

    Write-Host "==> flutter pub get"
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

    if ($SkipAab) {
        Write-Host "==> SkipAab set; skipping appbundle build"
    }
    else {
        $keyProps = Join-Path $PocRoot "android\key.properties"
        if (-not (Test-Path $keyProps)) {
            Write-Warning "android/key.properties not found — AAB will use debug signing or fail."
            Write-Warning "Copy key.properties.example and create keystore, or pass -SkipAab"
        }

        Write-Host "==> flutter build appbundle --release"
        flutter build appbundle --release `
            --dart-define=DICT_PACK_MANIFEST_URL=$ManifestUrl
        if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed" }

        $aab = Join-Path $PocRoot "build\app\outputs\bundle\release\app-release.aab"
        Write-Host ""
        Write-Host "AAB: $aab"
        Write-Host "Check Play Console App Bundle Explorer for arm64 download size (target < 35 MB)."
    }
}
finally {
    if (Test-Path $Backup) {
        Write-Host "==> Restoring pubspec.yaml"
        Move-Item -Force $Backup $Pubspec
        flutter pub get | Out-Null
    }
    Pop-Location
}

Write-Host "Done."
