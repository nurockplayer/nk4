# nk4: one-command download from jable.tv
# Usage: nk4 <url>
#   or:  nk4 <url> --dry-run   (just print the command, don't run)

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

nk4() {
  local url=$1
  local dry_run=false

  if [[ -z "$url" ]]; then
    echo "Usage: nk4 <jable.tv-url> [--dry-run]"
    return 1
  fi

  if [[ "$2" == "--dry-run" ]]; then
    dry_run=true
  fi

  _nk4_ensure_deps || {
    echo "❌ 自動安裝 Playwright 失敗，請手動執行:"
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

  local filename="${title//\//_}"
  filename="${filename%% }"
  filename="${filename## }"

  echo "📄 標題: $title"
  echo "🎬 串流: $m3u8_url"
  echo ""

  if $dry_run; then
    echo "🧪 預覽指令:"
    echo "yt-dlp --cookies-from-browser brave --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' --referer 'https://jable.tv/' -o '${filename}.%(ext)s' '${m3u8_url}'"
  else
    echo "⬇️  開始下載..."
    yt-dlp \
      --cookies-from-browser brave \
      --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
      --referer "https://jable.tv/" \
      -o "${filename}.%(ext)s" \
      "${m3u8_url}"
  fi
}
