# nk4.ps1 - PowerShell 函數
# 在 PowerShell profile 中 dot-source 這個檔案即可全域使用

$script:Nk4Dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function _Nk4DownloadX {
    param($Url, $Browser, $DryRun)

    if ($url -notmatch "https?://(x|twitter)\.com/([^/]+)/status/(\d+)") {
        Write-Host "❌ 無法解析 X/Twitter 網址" -ForegroundColor Red
        return
    }

    $userScreen = $Matches[2]
    $tweetId = $Matches[3]

    # Validate X username format (alphanumeric + underscore, 1-15 chars)
    if ($userScreen -notmatch '^[A-Za-z0-9_]{1,15}$') {
        Write-Host "❌ 無效的 X/Twitter 使用者名稱: $userScreen" -ForegroundColor Red
        return
    }

    Write-Host "🔍 正在解析 X 貼文: @${userScreen} / ${tweetId}" -ForegroundColor Cyan

    try {
        $json = Invoke-RestMethod -Uri "https://api.vxtwitter.com/${userScreen}/status/${tweetId}" -Method Get
    } catch {
        Write-Host "❌ 無法取得貼文資料: $_" -ForegroundColor Red
        return
    }

    if ($json.message -eq "No tweet found") {
        Write-Host "❌ 找不到該貼文（可能已刪除或設為不公開）" -ForegroundColor Red
        return
    }

    $userName = $json.user_name
    $text = $json.text
    $mediaUrl = $null
    # Filter for video type only
    if ($json.media_extended) {
        $video = $json.media_extended | Where-Object { $_.type -eq "video" } | Select-Object -First 1
        if ($video) { $mediaUrl = $video.url }
    }

    if ([string]::IsNullOrEmpty($mediaUrl)) {
        Write-Host "❌ 該貼文沒有影片" -ForegroundColor Red
        if (-not [string]::IsNullOrEmpty($text)) {
            Write-Host "   內容: $text" -ForegroundColor Gray
        }
        return
    }

    # Validate media_url scheme
    if ($mediaUrl -notmatch '^https://') {
        Write-Host "❌ 影片網址格式異常，放棄下載" -ForegroundColor Red
        return
    }

    Write-Host "📄 作者: $userName" -ForegroundColor Green
    Write-Host "📄 內容: $text" -ForegroundColor Green

    $filename = "${userScreen}_${tweetId}"

    Write-Host "🎬 影片: $mediaUrl" -ForegroundColor Green
    Write-Host ""

    if ($DryRun) {
        Write-Host "🧪 預覽指令:" -ForegroundColor Yellow
        Write-Host "yt-dlp --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -o '${filename}.%(ext)s' -- '${mediaUrl}'" -ForegroundColor Gray
    } else {
        Write-Host "⬇️  開始下載..." -ForegroundColor Green
        yt-dlp `
            --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" `
            -o "${filename}.%(ext)s" `
            -- `
            $mediaUrl
    }
}

function nk4 {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Remaining
    )

    $url = ""
    $browser = "chrome"
    $dryRun = $false
    $engine = if ($env:NK4_ENGINE) { $env:NK4_ENGINE } else { "chromium" }

    # Manual arg parsing
    $i = 0
    while ($i -lt $Remaining.Count) {
        switch -Wildcard ($Remaining[$i]) {
            "--dry-run" {
                $dryRun = $true
                $i++
            }
            "--engine" {
                if ($i + 1 -ge $Remaining.Count -or $Remaining[$i + 1] -like "-*") {
                    Write-Host "❌ --engine 需要指定瀏覽器引擎" -ForegroundColor Red
                    return
                }
                $engine = $Remaining[$i + 1]
                $i += 2
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
                } elseif ($Remaining[$i] -match "^--engine=(.+)$") {
                    $engine = $Matches[1]
                } elseif ($Remaining[$i] -notlike "-*") {
                    $url = $Remaining[$i]
                }
                $i++
            }
        }
    }

    $engine = $engine.ToLowerInvariant()
    if (@("chromium", "chrome", "firefox", "webkit") -notcontains $engine) {
        Write-Host "❌ 不支援的 Playwright 引擎：$engine" -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrEmpty($url)) {
        Write-Host "Usage: nk4 <url> [--engine chromium|chrome|firefox|webkit] [--cookies-from-browser <browser>] [--dry-run]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "範例:"
        Write-Host "  nk4 https://jable.tv/videos/XXXXX/"
        Write-Host "  nk4 https://missav.ai/dm31/XXXXX/ --cookies-from-browser brave"
        return
    }

    # X/Twitter — 直接 API 下載，免 Playwright（在依賴檢查之前路由）
    if ($url -match "https?://(x|twitter)\.com/") {
        _Nk4DownloadX $url $browser $dryRun
        return
    }

    $pwDir = Join-Path $script:Nk4Dir "node_modules" "playwright"

    if (-not (Test-Path $pwDir)) {
        Write-Host "📦 安裝 Playwright 依賴..." -ForegroundColor Yellow
        Push-Location $script:Nk4Dir
        pnpm install *>&1 | Out-Null
        if (-not $?) {
            Write-Host "❌ pnpm install 失敗" -ForegroundColor Red
            Pop-Location
            return
        }
        Pop-Location
    }

    # Check the selected engine using nk4's own Playwright version.
    $scrapeScript = Join-Path $script:Nk4Dir "scrape.mjs"
    Push-Location $script:Nk4Dir
    node $scrapeScript --probe-browser $engine 2>$null
    $engineLaunchStatus = $LASTEXITCODE
    Pop-Location

    if ($engineLaunchStatus -ne 0) {
        if ($engine -eq "chrome") {
            Write-Host "❌ Google Chrome 無法啟動。請安裝 Chrome，或使用 --engine chromium。" -ForegroundColor Red
            return
        }

        Write-Host "🌐 安裝 Playwright $engine 瀏覽器..." -ForegroundColor Yellow
        Push-Location $script:Nk4Dir
        if ($engine -eq "chromium") {
            pnpm exec playwright install --only-shell chromium *>&1 | Out-Null
        } else {
            pnpm exec playwright install $engine *>&1 | Out-Null
        }
        $installStatus = $LASTEXITCODE
        Pop-Location
        if ($installStatus -ne 0) {
            Write-Host "❌ 安裝 Playwright $engine 失敗" -ForegroundColor Red
            return
        }

        Push-Location $script:Nk4Dir
        node $scrapeScript --probe-browser $engine 2>$null
        $engineLaunchStatus = $LASTEXITCODE
        Pop-Location
        if ($engineLaunchStatus -ne 0) {
            Write-Host "❌ 無法啟動 Playwright $engine，請檢查瀏覽器與系統依賴。" -ForegroundColor Red
            return
        }
    }

    Write-Host "🔍 正在解析: $Url" -ForegroundColor Cyan

    $scrapeScript = Join-Path $script:Nk4Dir "scrape.mjs"
    if (-not (Test-Path $scrapeScript)) {
        Write-Host "❌ 找不到 $scrapeScript" -ForegroundColor Red
        return
    }

    $json = node $scrapeScript $url $engine 2>&1
    if (-not $?) {
        $rawError = ($json | Out-String).Trim()
        $scrapeError = $null
        try {
            $scrapeError = ($rawError | ConvertFrom-Json).error
        } catch {
            $scrapeError = $rawError
        }

        if ([string]::IsNullOrWhiteSpace($scrapeError)) {
            $scrapeError = "未取得診斷資訊"
        }
        Write-Host "❌ 解析失敗：$scrapeError" -ForegroundColor Red
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
