#!/usr/bin/env bash
set -euo pipefail

NK4_DIR="$(cd "$(dirname "$0")" && pwd)"
SHELL_PROFILE=""

if [[ "$SHELL" == */zsh ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
  if [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_PROFILE="$HOME/.bash_profile"
  elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_PROFILE="$HOME/.bashrc"
  fi
fi

echo "=============================="
echo "  nk4 一鍵安裝腳本"
echo "=============================="
echo ""

# --- 1. Check / install fnm + Node.js ---
if ! command -v fnm &>/dev/null; then
  echo "📦 安裝 fnm (Node.js 版本管理器)..."
  if [[ "$(uname)" == "Darwin" ]] && command -v brew &>/dev/null; then
    brew install fnm
  else
    curl -fsSL https://fnm.vercel.app/install | bash
  fi
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh 2>/dev/null || fnm env --use-on-cd --shell bash 2>/dev/null)"
else
  echo "✅ fnm 已安裝"
fi

if ! command -v node &>/dev/null; then
  echo "📦 安裝 Node.js LTS..."
  fnm install --lts
  fnm use lts-latest
else
  echo "✅ Node.js $(node -v) 已安裝"
fi

# --- 2. Enable pnpm via corepack ---
if ! command -v pnpm &>/dev/null; then
  echo "📦 啟用 pnpm (透過 corepack)..."
  corepack enable
  pnpm --version &>/dev/null || true
else
  echo "✅ pnpm $(pnpm -v) 已安裝"
fi

# --- 3. Install playwright + chromium ---
echo "📦 安裝 Playwright 與 Chromium..."
cd "$NK4_DIR"
pnpm add playwright
pnpm exec playwright install chromium
echo "✅ Playwright 就緒"

# --- 4. Check yt-dlp ---
if ! command -v yt-dlp &>/dev/null; then
  echo ""
  echo "⚠️  需要安裝 yt-dlp（下載引擎）"
  echo "   建議安裝方式："
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "      brew install yt-dlp"
  else
    echo "      sudo curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp"
    echo "      sudo chmod +x /usr/local/bin/yt-dlp"
  fi
  echo "   或手動下載：https://github.com/yt-dlp/yt-dlp/releases"
  echo ""
  read -rp "按 Enter 繼續（或之後再裝 yt-dlp，下載時會報錯）..."
else
  echo "✅ yt-dlp $(yt-dlp --version) 已安裝"
fi

# --- 5. Setup shell alias ---
if grep -q "nk4" "$SHELL_PROFILE" 2>/dev/null; then
  echo "✅ nk4 已在 $SHELL_PROFILE 中"
else
  echo "" >> "$SHELL_PROFILE"
  echo "# nk4: one-command downloader" >> "$SHELL_PROFILE"
  echo "source \"$NK4_DIR/nk4.zsh\"" >> "$SHELL_PROFILE"
  echo "✅ 已將 nk4 加入 $SHELL_PROFILE"
fi

echo ""
echo "=============================="
echo "  安裝完成！"
echo "=============================="
echo ""
echo "使用方式："
echo "  1. 重新開啟 Terminal，或執行: source $SHELL_PROFILE"
echo "  2. nk4 https://jable.tv/videos/XXXXX/"
echo "  3. 若要預覽不下載：nk4 https://jable.tv/videos/XXXXX/ --dry-run"
echo ""
echo "注意：第一次需要從 Brave 匯入 cookie（yt-dlp 會自動處理）"
