# nk4

`nk4` 是一個從多個網站一鍵下載影片的命令列工具。

### 支援網站

| 網站 | 方式 | 需要登入 |
|------|------|----------|
| jable.tv | Playwright 解析 .m3u8 + yt-dlp | 否（敏感內容需 cookies） |
| missav.ai | Playwright 解析 .m3u8 + yt-dlp | 否（敏感內容需 cookies） |
| x.com / twitter.com | 直接 API → yt-dlp | 否 |

## 安裝需求

- macOS / Linux / Windows
- [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)（下載引擎，需手動安裝）
- Chrome 瀏覽器（用於匯入 cookie，預設）

> 其餘依賴（fnm、Node.js、pnpm、Playwright、Chromium）安裝腳本會自動處理。

## 安裝方式

### macOS / Linux

```bash
git clone git@github.com:nurockplayer/nk4.git
cd nk4
bash setup.sh
```

### Windows

以**系統管理員**開啟 PowerShell，執行：

```powershell
git clone git@github.com:nurockplayer/nk4.git
cd nk4
.\setup.ps1
```

### 手動安裝 yt-dlp

**macOS：**

```bash
brew install yt-dlp
```

**Linux：**

```bash
sudo curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod +x /usr/local/bin/yt-dlp
```

**Windows：**

```powershell
winget install yt-dlp
```

## 使用方式

### 一鍵下載

```bash
nk4 https://jable.tv/videos/XXXXX/
nk4 https://missav.ai/dm31/XXXXX/
nk4 https://x.com/xxx/status/123456789
```

工具會自動完成以下流程：

1. 檢查 Playwright 與 Chromium 是否已安裝，若無則自動安裝
2. 開啟目標頁面，擷取影片標題與 `.m3u8` 串流網址
3. 呼叫 yt-dlp 下載影片並以標題作為檔名

### 預覽不下載

```bash
nk4 https://jable.tv/videos/XXXXX/ --dry-run
```

只顯示將要執行的 yt-dlp 指令，不實際下載。

## 選擇 Playwright 瀏覽器引擎

預設使用 Playwright 的 Chromium Headless Shell。也可以使用系統已安裝的 Google Chrome、Playwright Firefox 或 WebKit：

```bash
nk4 https://jable.tv/videos/XXXXX/ --engine chrome
nk4 https://jable.tv/videos/XXXXX/ --engine firefox
nk4 https://jable.tv/videos/XXXXX/ --engine webkit

# 設定預設值（也可由 --engine 覆蓋）
export NK4_ENGINE=firefox
```

- `chromium`：自動安裝與專案 Playwright 版本相符的 Headless Shell（預設）。
- `chrome`：使用系統安裝的 Google Chrome，不額外下載 Chromium；需先安裝 Chrome。
- `firefox` / `webkit`：首次使用時，自動安裝 Playwright 管理的對應瀏覽器。

`--engine` 控制網頁解析引擎；`--cookies-from-browser` 控制 yt-dlp 讀取哪個瀏覽器的 Cookie，兩者互不影響。例如：

```bash
nk4 https://jable.tv/videos/XXXXX/ --engine firefox --cookies-from-browser brave
```

## 注意事項

- 目前支援 macOS、Linux、Windows；系統瀏覽器與 Playwright 管理的瀏覽器相互獨立。
- `nk4` 會以專案內的 Playwright 版本啟動瀏覽器，不使用全域 `playwright` 指令的版本。
- X / Twitter 走 API 下載，不需要 Playwright。


## 檔案結構

```
nk4/
├── scrape.mjs       # Playwright 解析核心
├── nk4.zsh          # zsh 函數（macOS / Linux）
├── nk4.ps1          # PowerShell 函數（Windows）
├── setup.sh         # 安裝腳本（macOS / Linux）
├── setup.ps1        # 安裝腳本（Windows）
└── .gitignore
```
