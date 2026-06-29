#Requires -RunAsAdministrator

<#
.SYNOPSIS
    nk4 一鍵安裝腳本 (Windows)
.DESCRIPTION
    自動安裝 fnm + Node.js + pnpm + Playwright + chromium
    並將 nk4 加入 PowerShell profile
#>

$ErrorActionPreference = "Stop"
$Nk4Dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  nk4 一鍵安裝腳本" -ForegroundColor Cyan
Write-Host "  (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Check / install fnm + Node.js ---
if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    Write-Host "📦 安裝 fnm (Node.js 版本管理器)..." -ForegroundColor Yellow
    winget install Schniz.fnm 2>&1 | Out-Null
    if (-not $?) {
        Write-Host "⚠️  winget 安裝失敗，嘗試手動安裝 fnm..." -ForegroundColor Yellow
        npm install -g fnm 2>&1 | Out-Null
    }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:Path"
} else {
    Write-Host "✅ fnm 已安裝" -ForegroundColor Green
}

$fnmPath = "$env:USERPROFILE\AppData\Local\fnm"
if (Test-Path $fnmPath) {
    $env:Path = "$fnmPath;$env:Path"
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "📦 安裝 Node.js LTS..." -ForegroundColor Yellow
    fnm install --lts 2>&1 | Out-Null
    fnm use lts-latest 2>&1 | Out-Null
    $fnmNodePath = "$env:USERPROFILE\AppData\Local\fnm_multishell\*\bin"
    $env:Path = "$fnmNodePath;$env:Path"
} else {
    Write-Host "✅ Node.js $(node -v) 已安裝" -ForegroundColor Green
}

# --- 2. Enable pnpm via corepack ---
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "📦 啟用 pnpm (透過 corepack)..." -ForegroundColor Yellow
    corepack enable 2>&1 | Out-Null
    $pnpmPath = "$env:USERPROFILE\AppData\Local\pnpm"
    if (-not (Test-Path $pnpmPath)) { New-Item -ItemType Directory -Force -Path $pnpmPath | Out-Null }
    $env:Path = "$pnpmPath;$env:Path"
} else {
    Write-Host "✅ pnpm $(pnpm -v) 已安裝" -ForegroundColor Green
}

# --- 3. Install playwright + chromium ---
Write-Host "📦 安裝 Playwright 與 Chromium..." -ForegroundColor Yellow
Push-Location $Nk4Dir
pnpm add playwright *>&1 | Out-Null
pnpm exec playwright install chromium *>&1 | Out-Null
Pop-Location
Write-Host "✅ Playwright 就緒" -ForegroundColor Green

# --- 4. Check yt-dlp ---
if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "⚠️  需要安裝 yt-dlp（下載引擎）" -ForegroundColor Yellow
    Write-Host "   建議安裝方式：" -ForegroundColor Yellow
    Write-Host "      winget install yt-dlp" -ForegroundColor Gray
    Write-Host "   或手動安裝：https://github.com/yt-dlp/yt-dlp/releases" -ForegroundColor Gray
    Write-Host "   下載 yt-dlp.exe 後放到任意 PATH 目錄即可" -ForegroundColor Gray
    Write-Host ""
    pause
} else {
    Write-Host "✅ yt-dlp $(yt-dlp --version) 已安裝" -ForegroundColor Green
}

# --- 5. Add to PowerShell profile ---
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

$profileLine = ". `"$Nk4Dir\nk4.ps1`""

if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains("nk4")) {
        Write-Host "✅ nk4 已在 PowerShell profile 中" -ForegroundColor Green
    } else {
        Add-Content -Path $PROFILE -Value "`r`n# nk4: one-command downloader"
        Add-Content -Path $PROFILE -Value $profileLine
        Write-Host "✅ 已將 nk4 加入 PowerShell profile" -ForegroundColor Green
    }
} else {
    Set-Content -Path $PROFILE -Value $profileLine
    Write-Host "✅ 已建立 PowerShell profile 並加入 nk4" -ForegroundColor Green
}

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  安裝完成！" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "使用方式：" -ForegroundColor White
Write-Host "  1. 重新開啟 PowerShell，或執行: . $PROFILE" -ForegroundColor Gray
Write-Host "  2. nk4 https://jable.tv/videos/XXXXX/" -ForegroundColor Gray
Write-Host "  3. 預覽不下載：nk4 -Url https://... -DryRun" -ForegroundColor Gray
Write-Host ""
Write-Host "注意：第一次需要從 Brave 匯入 cookie（yt-dlp 會自動處理）" -ForegroundColor Yellow
