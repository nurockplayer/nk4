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
        # 使用 fxtwitter API：會提供 m3u8 HLS 播放清單。
        # vxtwitter 只回傳最高解析度的單一 mp4，4K/長片會超過 twimg CDN 的單一
        # response 上限（503 Response object too large），HLS 分段下載才能繞過。
        $json = Invoke-RestMethod -Uri "https://api.fxtwitter.com/${userScreen}/status/${tweetId}" -Method Get
    } catch {
        Write-Host "❌ 無法取得貼文資料: $_" -ForegroundColor Red
        return
    }

    if ($json.code -ne 200 -or -not $json.tweet) {
        Write-Host "❌ 找不到該貼文（可能已刪除或設為不公開）" -ForegroundColor Red
        return
    }

    $userName = $json.tweet.author.name
    $text = $json.tweet.raw_text.text
    $mediaUrl = $null
    if ($json.tweet.media -and $json.tweet.media.all) {
        $media = $json.tweet.media.all | Select-Object -First 1
        if ($media.type -eq "video") {
            # HLS 播放清單優先（避免單一超大 mp4 超過 CDN 上限），沒有才用 mp4
            $m3u8 = $media.formats | Where-Object { $_.container -eq "m3u8" } | Select-Object -First 1
            if ($m3u8) {
                $mediaUrl = $m3u8.url
            } else {
                $mp4 = $media.formats | Where-Object { $_.container -eq "mp4" -and $_.bitrate } | Select-Object -First 1
                $mediaUrl = $mp4.url
            }
        }
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

    # HLS（.m3u8）需帶 Referer 才能連到 segment，mp4 則不需要
    if ($mediaUrl -match '\.m3u8') {
        if ($DryRun) {
            Write-Host "🧪 預覽指令:" -ForegroundColor Yellow
            Write-Host "yt-dlp --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' --referer 'https://x.com/' -o '${filename}.%(ext)s' '${mediaUrl}'" -ForegroundColor Gray
        } else {
            Write-Host "⬇️  開始下載..." -ForegroundColor Green
            yt-dlp `
                --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" `
                --referer "https://x.com/" `
                -o "${filename}.%(ext)s" `
                $mediaUrl
        }
    } else {
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
}

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

    # X/Twitter — 直接 API 下載，免 Playwright（在依賴檢查之前路由）
    if ($url -match "https?://(x|twitter)\.com/") {
        _Nk4DownloadX $url $browser $dryRun
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
