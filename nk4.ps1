# nk4.ps1 - PowerShell 函數
# 在 PowerShell profile 中 dot-source 這個檔案即可全域使用

$script:Nk4Dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function nk4 {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Remaining
    )

    $url = ""
    $browser = "chrome"
    $dryRun = $false

    # Manual arg parsing
    $i = 0
    while ($i -lt $Remaining.Count) {
        switch -Wildcard ($Remaining[$i]) {
            "--dry-run" {
                $dryRun = $true
                $i++
            }
            "--cookies-from-browser" {
                if ($i + 1 -lt $Remaining.Count) {
                    $browser = $Remaining[$i + 1]
                    $i += 2
                } else { $i++ }
            }
            default {
                if ($Remaining[$i] -match "^--cookies-from-browser=(.+)$") {
                    $browser = $Matches[1]
                } elseif ($Remaining[$i] -notlike "-*") {
                    $url = $Remaining[$i]
                }
                $i++
            }
        }
    }

    if ([string]::IsNullOrEmpty($url)) {
        Write-Host "Usage: nk4 <url> [--cookies-from-browser <browser>] [--dry-run]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "範例:"
        Write-Host "  nk4 https://jable.tv/videos/XXXXX/"
        Write-Host "  nk4 https://missav.ai/dm31/XXXXX/ --cookies-from-browser brave"
        return
    }

    $pwDir = Join-Path $script:Nk4Dir "node_modules" "playwright"

    if (-not (Test-Path $pwDir)) {
        Write-Host "📦 安裝 Playwright 依賴..." -ForegroundColor Yellow
        Push-Location $script:Nk4Dir
        pnpm add playwright *>&1 | Out-Null
        if (-not $?) {
            Write-Host "❌ pnpm add playwright 失敗" -ForegroundColor Red
            Pop-Location
            return
        }
        Pop-Location
    }

    $localAppData = $env:LOCALAPPDATA
    $pwCacheDirs = @(
        "$localAppData\ms-playwright\chromium-*",
        "$env:USERPROFILE\.cache\ms-playwright\chromium-*"
    )
    $chromiumFound = $false
    foreach ($pattern in $pwCacheDirs) {
        if (Get-ChildItem $pattern -ErrorAction SilentlyContinue) {
            $chromiumFound = $true
            break
        }
    }
    if (-not $chromiumFound) {
        Write-Host "🌐 下載 Chromium 瀏覽器..." -ForegroundColor Yellow
        Push-Location $script:Nk4Dir
        pnpm exec playwright install chromium *>&1 | Out-Null
        if (-not $?) {
            Write-Host "❌ 安裝 Chromium 失敗" -ForegroundColor Red
            Pop-Location
            return
        }
        Pop-Location
    }

    Write-Host "🔍 正在解析: $Url" -ForegroundColor Cyan

    $scrapeScript = Join-Path $script:Nk4Dir "scrape.mjs"
    if (-not (Test-Path $scrapeScript)) {
        Write-Host "❌ 找不到 $scrapeScript" -ForegroundColor Red
        return
    }

    $json = node $scrapeScript $url 2>&1
    if (-not $?) {
        Write-Host "❌ 解析失敗" -ForegroundColor Red
        return
    }

    try {
        $obj = $json | ConvertFrom-Json
    } catch {
        Write-Host "❌ JSON 解析失敗: $json" -ForegroundColor Red
        return
    }

    $title = $obj.title
    $m3u8Url = $obj.m3u8Url

    if ([string]::IsNullOrEmpty($m3u8Url)) {
        Write-Host "❌ 找不到 .m3u8 網址" -ForegroundColor Red
        return
    }

    # Dynamic referer based on URL
    $referer = "https://jable.tv/"
    if ($url -match "missav") {
        $referer = "https://missav.ai/"
    }

    $filename = $title -replace '[/\\:*?"<>|]', '_'
    $filename = $filename.Trim()

    Write-Host "📄 標題: $title" -ForegroundColor Green
    Write-Host "🎬 串流: $m3u8Url" -ForegroundColor Green
    Write-Host ""

    if ($dryRun) {
        Write-Host "🧪 預覽指令:" -ForegroundColor Yellow
        Write-Host "yt-dlp --cookies-from-browser $browser --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' --referer '$referer' -o '$filename.%(ext)s' '$m3u8Url'" -ForegroundColor Gray
    } else {
        Write-Host "⬇️  開始下載..." -ForegroundColor Green
        yt-dlp `
            --cookies-from-browser $browser `
            --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" `
            --referer $referer `
            -o "$filename.%(ext)s" `
            $m3u8Url
    }
}
