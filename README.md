# nk4

`nk4` 是一個從 jable.tv 與 missav.ai 一鍵下載影片的命令列工具。

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

## 自訂瀏覽器

預設使用 Chrome 匯入 cookie。若使用其他瀏覽器，設定環境變數即可：

```bash
export NK4_BROWSER=brave
export NK4_BROWSER=edge
export NK4_BROWSER=firefox
```

## 注意事項

- 預設從 Chrome 匯入 cookie，可透過 `NK4_BROWSER` 環境變數切換瀏覽器
- 腳本中的 Chromium 快取約佔 170MB 硬碟空間，僅第一次安裝時下載。

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
