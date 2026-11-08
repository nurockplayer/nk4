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
- Chrome 或其他 yt-dlp 支援的瀏覽器（用於匯入 cookie，預設 Chrome）

> 其餘依賴（fnm、Node.js、pnpm、Playwright、所選瀏覽器引擎（預設 Chromium））安裝腳本會自動處理。

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

1. 檢查 Playwright 與所選引擎能否啟動，若不能則安裝該引擎並再次檢查
2. 開啟目標頁面，擷取影片標題與 `.m3u8` 串流網址
3. 呼叫 yt-dlp 下載影片並以標題作為檔名

### 預覽不下載

```bash
nk4 https://jable.tv/videos/XXXXX/ --dry-run
```

只顯示將要執行的 yt-dlp 指令，不實際下載。

## 自訂瀏覽器

解析引擎與 cookie 來源為兩個獨立選項，不會自動互相切換。

### 頁面解析引擎

支援 Playwright 的 `chromium`（預設）、`firefox`、`webkit`，以及系統 `chrome`：

```bash
nk4 https://example.com/video --browser firefox
nk4 https://example.com/video --browser=webkit
export NK4_ENGINE=firefox
bash setup.sh
```

PowerShell：

```powershell
$env:NK4_ENGINE = "firefox"
.\setup.ps1
nk4 https://example.com/video --browser webkit
```

`--browser` 優先於 `NK4_ENGINE`。安裝腳本只安裝所選引擎；切換引擎時會自動檢查及安裝。亦可手動執行 `pnpm exec playwright install firefox webkit`。Linux 若缺少系統函式庫，依 Playwright 診斷安裝所需依賴後重試。

WebKit 是 Playwright 的 WebKit 引擎，不是啟動本機 Safari；Firefox 亦使用 Playwright 配套版本，不直接使用個人瀏覽器設定檔。各網站相容性可能不同，可切回 Chromium。X/Twitter API 路徑仍不需要 Playwright。

### Cookie 來源


預設使用 Chrome 匯入 cookie。若使用其他瀏覽器，設定環境變數即可：

```bash
export NK4_BROWSER=brave
export NK4_BROWSER=edge
export NK4_BROWSER=firefox
```

## 注意事項

- 預設從 Chrome 匯入 cookie，可透過 `NK4_BROWSER` 環境變數切換瀏覽器
- 瀏覽器快取大小因引擎與版本而異；Playwright 升級後可能需重新下載。
- `NK4_BROWSER` 僅指定 yt-dlp cookie 來源；`--cookies-from-browser` 優先。PowerShell 可用 `$env:NK4_BROWSER = "firefox"`。
- 解析器使用全新、未登入的瀏覽器 context，不會匯入個人 cookie。

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

## 開發檢查

```bash
pnpm test
node --check scrape.mjs
zsh -n nk4.zsh
bash -n setup.sh
```

單元測試不需安裝瀏覽器；實際啟動檢查可用 `node browser.mjs probe firefox`（或 chromium / webkit）。


### 系統 Chrome 與相容旗標

`--engine` 與 `--browser` 是同義旗標，均接受空格或等號語法；同時提供時最後一個生效，並覆蓋 `NK4_ENGINE`。例如：

```bash
nk4 https://jable.tv/videos/XXXXX/ --engine chrome --cookies-from-browser firefox --dry-run
```

`chrome` 使用系統已安裝的 Google Chrome channel，不下載 Chrome，也不自動切換引擎；啟動失敗會停止並提示。預設 `chromium` 僅安裝與專案 Playwright 相符的 Headless Shell（`--only-shell chromium`）。Firefox / WebKit 維持對應引擎安裝。缺少專案依賴時在專案目錄執行 `pnpm install`，不再以 `pnpm add` 改寫依賴宣告。

整合來源：PR #4（nurockplayer，head 0d1b1f744fd3fac9e923e91d7ff6eb30eeedd2a0）。保留共用探測／啟動與 cookie 來源分離；未變動該 PR。
