#Requires -Version 5.1
<#
.SYNOPSIS
  生成可上传 CDN 的 MVP 词典包（含 manifest.json + SHA256）。

.DESCRIPTION
  从 poc/assets/dict/ 复制 mvp_dict.json、mvp_dict_aliases.json，
  计算 SHA256，写入 dict/v1/manifest.json 到输出目录。

.PARAMETER OutputDir
  输出目录（默认 poc/build/dict-pack/v1）

.PARAMETER BaseUrl
  CDN 基础 URL（manifest 内 file url 前缀），默认占位 https://cdn.example.com/dict/v1
#>
param(
    [string]$OutputDir = "",
    [string]$BaseUrl = "https://cdn.example.com/dict/v1"
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PocRoot = Split-Path -Parent $ScriptRoot
$AssetsDict = Join-Path $PocRoot "assets\dict"

if (-not $OutputDir) {
    $OutputDir = Join-Path $PocRoot "build\dict-pack\v1"
}

$files = @(
    "mvp_dict.json",
    "mvp_dict_aliases.json"
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$manifestFiles = @{}
foreach ($name in $files) {
    $src = Join-Path $AssetsDict $name
    if (-not (Test-Path $src)) {
        throw "Missing $src"
    }
    $dest = Join-Path $OutputDir $name
    Copy-Item -Force $src $dest
    $hash = (Get-FileHash -Algorithm SHA256 $src).Hash.ToLower()
    $size = (Get-Item $src).Length
    $manifestFiles[$name] = @{
        url       = "$BaseUrl/$name"
        sha256    = $hash
        sizeBytes = $size
    }
    Write-Host "$name  sha256=$hash  size=$size"
}

$manifest = @{
    version = "2"
    files   = $manifestFiles
} | ConvertTo-Json -Depth 5

$manifestPath = Join-Path $OutputDir "manifest.json"
$manifest | Set-Content -Path $manifestPath -Encoding UTF8
$assetsManifestPath = Join-Path $AssetsDict "manifest.json"
$manifest | Set-Content -Path $assetsManifestPath -Encoding UTF8
Write-Host ""
Write-Host "Bundle written to: $OutputDir"
Write-Host "Upload manifest.json + both JSON files to CDN."
Write-Host "Set DICT_PACK_MANIFEST_URL to the manifest URL when building release."
