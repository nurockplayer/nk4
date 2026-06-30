# nk4: one-command downloader
# Inspired by yt-dlp — one URL, one download.
# Supported sites: jable.tv, missav.ai, x.com, twitter.com
# Usage: nk4 <url> [--cookies-from-browser <browser>] [--dry-run]

NK4_DIR="${NK4_DIR:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"
NK4_SCRIPT="$NK4_DIR/scrape.mjs"
NK4_PW="$NK4_DIR/node_modules/playwright"

_nk4_ensure_deps() {
  if [[ ! -d "$NK4_PW" ]]; then
    print "📦 安裝 Playwright 依賴..."
    (cd "$NK4_DIR" && pnpm add playwright &>/dev/null) || return 1
  fi
  local pw_ver browser_ok
  pw_ver=$(node -e "console.log(require('playwright/package.json').version)" 2>/dev/null)
  if [[ -n "$pw_ver" ]]; then
    ls "$HOME/Library/Caches/ms-playwright/chromium-"* "$HOME/.cache/ms-playwright/chromium-"* &>/dev/null
    browser_ok=$?
    if [[ $browser_ok -ne 0 ]]; then
      print "🌐 下載 Chromium 瀏覽器..."
      (cd "$NK4_DIR" && pnpm exec playwright install chromium &>/dev/null) || return 1
    fi
  fi
  return 0
}

_nk4_download_x() {
  local url="$1" browser="$2" dry_run="$3"

  # 從 URL 抽出貼文 ID 和使用者名稱
  local tweet_id user_screen
  tweet_id=$(echo "$url" | grep -oE '/status/[0-9]+' | tr -cd '0-9')
  user_screen=$(echo "$url" | awk -F'/' '{for(i=1;i<=NF;i++){if($i~/^(x|twitter)\.com$/ && i+1<=NF){print $(i+1);exit}}}')

  # Must-fix: reject empty / malformed params before any API call
  if [[ -z "$tweet_id" || -z "$user_screen" ]]; then
    echo "❌ 無法解析 X/Twitter 網址"
    return 1
  fi

  # Must-fix: validate X username format (alphanumeric + underscore, 1-15 chars)
  if ! echo "$user_screen" | grep -qE '^[A-Za-z0-9_]{1,15}$'; then
    echo "❌ 無效的 X/Twitter 使用者名稱: $user_screen"
    return 1
  fi

  print "🔍 正在解析 X 貼文: @$user_screen / $tweet_id"

  # Must-fix: curl -fsSL to fail on HTTP errors
  local json
  json=$(curl -fsSL "https://api.vxtwitter.com/$user_screen/status/$tweet_id" 2>&1) || {
    echo "❌ 無法取得貼文資料"
    return 1
  }

  # Must-fix: use printf instead of echo to preserve backslash escapes in JSON
  local parsed
  parsed=$(printf '%s' "$json" | node -e "
    let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
      try {
        const j=JSON.parse(d);
        if (j.message==='No tweet found') { console.log('ERR_NOT_FOUND'); return; }
        const videos = (j.media_extended||[]).filter(m => m.type==='video');
        if (!videos.length) { console.log('ERR_NO_VIDEO'); return; }
        const m = videos[0];
        console.log(JSON.stringify({user_name:j.user_name||'',text:j.text||'',media_url:m.url}));
      } catch(e) { console.log('ERR_PARSE'); }
    })
  " 2>/dev/null)

  case "$parsed" in
    ERR_NOT_FOUND)
      echo "❌ 找不到該貼文（可能已刪除或設為不公開）"
      return 1
      ;;
    ERR_NO_VIDEO)
      echo "❌ 該貼文沒有影片"
      return 1
      ;;
    ERR_PARSE)
      echo "❌ 無法解析貼文資料"
      return 1
      ;;
    "")
      echo "❌ 無法取得貼文資料"
      return 1
      ;;
  esac

  local user_name text media_url
  user_name=$(printf '%s' "$parsed" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).user_name))")
  text=$(printf '%s' "$parsed" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).text))")
  media_url=$(printf '%s' "$parsed" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).media_url))")

  # Must-fix: validate media_url scheme
  if ! echo "$media_url" | grep -qE '^https://'; then
    echo "❌ 影片網址格式異常，放棄下載"
    return 1
  fi

  print "📄 作者: $user_name"
  print "📄 內容: $text"

  local filename="${user_screen}_${tweet_id}"

  print "🎬 影片: $media_url"
  print ""

  if $dry_run; then
    echo "🧪 預覽指令:"
    echo "yt-dlp --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -o '${filename}.%(ext)s' -- '${media_url}'"
  else
    print "⬇️  開始下載..."
    yt-dlp \
      --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
      -o "${filename}.%(ext)s" \
      -- \
      "${media_url}"
  fi
}

nk4() {
  local url=""
  local browser="chrome"
  local dry_run=false

  # Parse arguments like yt-dlp style
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --cookies-from-browser)
        browser="$2"
        shift 2
        ;;
      --cookies-from-browser=*)
        browser="${1#*=}"
        shift
        ;;
      -*)
        echo "未知參數: $1"
        echo "Usage: nk4 <url> [--cookies-from-browser <browser>] [--dry-run]"
        return 1
        ;;
      *)
        url="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$url" ]]; then
    echo "Usage: nk4 <url> [--cookies-from-browser <browser>] [--dry-run]"
    echo ""
    echo "支援網站:"
    echo "  jable.tv / missav.ai — 使用 Playwright + yt-dlp（需 cookies）"
    echo "  x.com / twitter.com  — 使用 API 直接下載（免登入）"
    echo ""
    echo "範例:"
    echo "  nk4 https://jable.tv/videos/XXXXX/"
    echo "  nk4 https://missav.ai/dm31/XXXXX/"
    echo "  nk4 https://x.com/xxx/status/123456789"
    echo "  nk4 https://jable.tv/videos/XXXXX/ --cookies-from-browser brave"
    echo "  nk4 https://x.com/xxx/status/123456789 --dry-run"
    return 1
  fi

  # X/Twitter URL = 免 Playwright 直接下載
  if echo "$url" | grep -qE 'https?://(x|twitter)\.com/'; then
    _nk4_download_x "$url" "$browser" "$dry_run"
    return $?
  fi

  _nk4_ensure_deps || {
    echo "❌ 自動安裝 Playwright 失败，請手動執行:"
    echo "  cd $NK4_DIR && pnpm add playwright && pnpm exec playwright install chromium"
    return 1
  }

  echo "🔍 正在解析: $url"

  local json
  json=$(node "$NK4_SCRIPT" "$url" 2>&1)
  if [[ $? -ne 0 ]]; then
    echo "❌ 解析失敗"
    return 1
  fi

  local title m3u8_url
  title=$(echo "$json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).title))")
  m3u8_url=$(echo "$json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).m3u8Url))")

  if [[ -z "$m3u8_url" ]]; then
    echo "❌ 找不到 .m3u8 網址"
    return 1
  fi

  # Dynamic referer based on URL
  local referer="https://jable.tv/"
  if [[ "$url" == *missav* ]]; then
    referer="https://missav.ai/"
  fi

  local filename="${title//\//_}"
  filename="${filename%% }"
  filename="${filename## }"

  echo "📄 標題: $title"
  echo "🎬 串流: $m3u8_url"
  echo ""

  if $dry_run; then
    echo "🧪 預覽指令:"
    echo "yt-dlp --cookies-from-browser ${browser} --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' --referer '${referer}' -o '${filename}.%(ext)s' '${m3u8_url}'"
  else
    echo "⬇️  開始下載..."
    yt-dlp \
      --cookies-from-browser ${browser} \
      --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
      --referer "${referer}" \
      -o "${filename}.%(ext)s" \
      "${m3u8_url}"
  fi
}
