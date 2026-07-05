# 用 curl 绕过 Gradle HEAD/TLS 问题，将失败依赖写入 local-maven 后重试构建
param(
    [int]$MaxRounds = 40
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalMaven = Join-Path $ProjectRoot "local-maven"
$GradleHome = Join-Path $env:USERPROFILE ".gradle"
$env:GRADLE_USER_HOME = $GradleHome

New-Item -ItemType Directory -Force -Path $LocalMaven | Out-Null

function Import-MavenArtifactFromUrl {
    param([string]$Url)
    if ($Url -notmatch '/([^/]+)/([^/]+)/([^/]+)/([^/]+\.(jar|pom|module))$') { return $false }
    $fileName = $Matches[4]
    $version = $Matches[3]
    $artifact = $Matches[2]
    $prefix = $Url -replace "https?://[^/]+/repository/[^/]+/", ""
    $groupPath = $prefix.Substring(0, $prefix.Length - $artifact.Length - $version.Length - 2)
    $destDir = Join-Path $LocalMaven $groupPath
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $destFile = Join-Path $destDir $fileName
    if ((Test-Path $destFile) -and ((Get-Item $destFile).Length -gt 100)) { return $true }
    Write-Host "  curl -> $fileName"
    curl.exe -fsSL --max-time 180 -o $destFile $Url 2>$null
    return (Test-Path $destFile) -and ((Get-Item $destFile).Length -gt 100)
}

function Get-AltUrls {
    param([string]$Url)
    $list = @($Url)
    if ($Url -match "maven\.aliyun\.com/repository/google/") {
        $list += $Url -replace "repository/google", "repository/public"
    }
    if ($Url -match "dl\.google\.com") {
        $list += $Url -replace "https://dl\.google\.com/dl/android/maven2/", "https://maven.aliyun.com/repository/google/"
    }
    if ($Url -match "repo\.maven\.apache\.org") {
        $list += $Url -replace "https://repo\.maven\.apache\.org/maven2/", "https://maven.aliyun.com/repository/public/"
    }
    if ($Url -match "plugins\.gradle\.org") {
        $list += $Url -replace "https://plugins\.gradle\.org/m2/", "https://maven.aliyun.com/repository/gradle-plugin/"
        $list += $Url -replace "https://plugins\.gradle\.org/m2/", "https://maven.aliyun.com/repository/public/"
    }
    $list | Select-Object -Unique
}

function Extract-FailedUrls {
    param([string]$LogText)
    [regex]::Matches($LogText, "Could not GET '([^']+)'") | ForEach-Object { ($_.Groups[1].Value -replace '\s','') } | Select-Object -Unique
}

Push-Location $ProjectRoot
try {
    for ($i = 1; $i -le $MaxRounds; $i++) {
        Write-Host "`n=== Round $i / $MaxRounds ===" -ForegroundColor Cyan
        $log = & .\gradlew.bat assembleDebug --no-daemon 2>&1 | Out-String
        if ($log -match "BUILD SUCCESSFUL") {
            Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
            exit 0
        }
        $urls = Extract-FailedUrls $log
        if (-not $urls -or @($urls).Count -eq 0) {
            Write-Host $log
            exit 1
        }
        Write-Host "Seeding $(@($urls).Count) failed URLs..."
        foreach ($m in $urls) {
            $u = ($m -replace '\s', '')
            $ok = $false
            foreach ($alt in (Get-AltUrls $u)) {
                if (Import-MavenArtifactFromUrl $alt) { $ok = $true; break }
            }
            if (-not $ok) { Write-Warning "Failed: $u" }
        }
    }
    exit 1
} finally {
    Pop-Location
}
