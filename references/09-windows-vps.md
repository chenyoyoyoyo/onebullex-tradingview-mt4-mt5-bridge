# 09 MT 主機：租用與連線 Windows VPS

只有 **MT4／MT5 用戶**需要這一份。只用 TradingView 的不需要。

## 先分清楚：MT 用戶要兩台主機

| | 接收程式主機 | MT 主機 |
| --- | --- | --- |
| 作業系統 | **Linux**（Ubuntu） | **Windows** |
| 用途 | 跑接收程式，收到訊號後在斯巴達下單 | 跑 MT4／MT5、你的策略 EA 和同步程式 `OneBullExSync` |
| 誰需要 | 所有人 | 只有 MT4／MT5 用戶 |
| 怎麼準備 | [02](02-server-setup.md)、[03](03-install.md) | 本文件 |

兩台**不能合併，也不能互換**：MT4／MT5 是 Windows 程式；接收程式是為 Linux 寫的，不能裝在 Windows 上。

自己有一台 24 小時開機、不睡眠的 Windows 電腦，也可以當 MT 主機，但家用網路的 IP 可能會變（見 [08](08-mt4-mt5.md) 的 403 排錯），停電、更新重開機也會中斷同步。

> **用 Mac 也沒關係。** VPS 是雲端上一台獨立的電腦，你只是從自己的電腦遠端操作它的畫面，所以 Mac、Windows、手機都能連。MT 裝在 VPS 裡，Mac 上不需要裝任何 Windows 程式。

## 規格

- 作業系統：**Windows Server**（服務商提供的最新版即可）
- 記憶體：建議 **2 GB 以上**（MT 加上 Windows 本身，1 GB 會很卡）
- 必須有**固定公網 IP**：要加進接收程式的來源白名單
- 區域：選離你的**券商交易伺服器**近的地區，下單延遲較低；不確定時，亞洲券商選新加坡或東京
- 費用：Windows VPS 比同規格的 Linux 貴，依服務商與方案而定，建立前看清楚月費

## AWS Lightsail（和接收程式主機同一個帳號即可）

建立、付款、改防火牆由**使用者本人**在主控台操作。

1. 登入 https://lightsail.aws.amazon.com ，右上角選區域。
2. **Create instance**
   - Platform：**Microsoft Windows**
   - Blueprint：**OS Only → Windows Server**（選列出的最新版本）
   - Plan：**2 GB 記憶體以上**的方案
   - 名稱自訂，例如 `mt-vps`
3. 建立後等約 **10–15 分鐘**，Windows 第一次開機比 Linux 慢，主機狀態顯示 Running 後再連線。
4. 主機的 **Networking** 分頁 → **Attach static IP**，建立並綁定固定 IP，記下這個 IP（等一下加進接收程式的白名單）。
5. 防火牆保留預設的 **RDP（3389）**，這是遠端桌面用的。不用開 80、443。

### 連線到 Windows 桌面

**方法 A：瀏覽器（最簡單）**
主機頁面按 **Connect using RDP**，瀏覽器會打開 Windows 桌面。

**方法 B：Windows App（畫面較順，可以複製貼上）**
1. 在主機的 **Connect** 分頁，找到 **Retrieve default password**（取得預設密碼）。使用者名稱是 `Administrator`。密碼由使用者自己保存，不要貼給 AI。
2. Mac 到 App Store 安裝微軟的 **Windows App**（舊名 Microsoft Remote Desktop）。
3. 新增 PC：電腦名稱填固定 IP，使用者 `Administrator`，密碼填剛才取得的。
4. 第一次連線會跳出憑證警告，確認是自己的固定 IP 後選「繼續」。

建議第一次登入後，在 Windows 裡改成自己的強密碼（Ctrl+Alt+End → 變更密碼；Mac 的 Windows App 也有對應選單）。

### 離開時：「中斷連線」，不要「登出」

- 直接**關閉遠端桌面視窗**（中斷連線），VPS 裡的 MT 會繼續執行。
- 如果在 Windows 裡選「**登出**」（Sign out），MT 會被關掉，同步就停了。

## 在 VPS 裡安裝 MT 與同步程式

以下都在 **VPS 的 Windows 桌面裡**操作：

1. **安裝 MT**：用 VPS 裡的瀏覽器（Edge）到**你的券商官網**下載 MT4／MT5 安裝檔。用券商提供的安裝檔，伺服器清單會比較完整。安裝後登入交易帳戶，確認真的連線（[08](08-mt4-mt5.md)「登入並確認連線」）。
2. **確認對外 IP**：在 VPS 的瀏覽器打開 https://checkip.amazonaws.com ，顯示的應該是剛才綁定的固定 IP。
3. **加入白名單**：在**接收程式主機**（Linux）執行：

   ```bash
   sudo bash ~/onebullex-tradingview-mt4-mt5-bridge/bridge/install.sh set TV_ALLOWED_IPS tradingview,<Windows VPS 的固定 IP>
   ```

   原本有其他來源（例如之前測試用的家用 IP）且還要保留的話，一起寫進去，用逗號分隔。
4. **下載同步程式**：在 VPS 的瀏覽器打開 GitHub 上的 `mt/OneBullExSync.mq4`（MT4）或 `mt/OneBullExSync.mq5`（MT5），按「Download raw file」，確認副檔名正確。
5. **放進資料夾並編譯**：MT「檔案 → 開啟資料資料夾」→ `MQL4\Experts`（MT5 是 `MQL5\Experts`）→ 把檔案拖進去 → MT 選單「工具 → MetaQuotes Language Editor」→ 開啟檔案 → 編譯（F7 或工具列的編譯按鈕）→ `0 errors`。Windows 上可以直接拖放，不像 Mac 有 Wine 的限制。
6. 接著照 [08](08-mt4-mt5.md) 的步驟 3 之後：設定 WebRequest、算倍數、掛上 EA、試跑、小量 LIVE。

## 讓 VPS 重開後自動恢復

Windows 更新或服務商維護時，VPS 可能會重開機。重開後：

- **MT 不會自己打開**，同步會中斷，直到有人再登入 Windows 並開啟 MT。
- 建議至少做到：
  1. **MT 隨登入啟動**：按 Win+R，輸入 `shell:startup`，把 MT 的捷徑複製進打開的資料夾。
  2. **重開後連一次遠端桌面**：登入後 MT 會自動打開，確認圖表左上角的同步狀態正常。
  3. **控制更新重開時間**：Windows「設定 → Windows Update」設定使用時段，避免在交易時段自動重開。
- 進階：用微軟 Sysinternals 的 **Autologon** 工具設定開機自動登入，加上第 1 點，重開後不用手動連線。這會把登入資訊存在 VPS 上，請自行評估。

MT 和同步程式停止時，斯巴達的持倉**不會**自動平倉；恢復同步後會對齊到 MT 當下的持倉。

## 其他服務商

Vultr、Contabo、Google Cloud、Azure 等的 Windows VPS 也可以，要點相同：Windows Server、2 GB 以上記憶體、**固定 IP**、能用遠端桌面（RDP）連線。

券商提供的免費 VPS、MT5 內建的 MetaQuotes 虛擬主機，對外 IP 通常不固定或無法得知，不適合接收程式的 IP 白名單，也無法照上面的方式安裝同步程式，不建議使用。

## 驗證狀態

本文件依一般 Windows VPS 與 Lightsail 的操作整理，**尚未以本專案在 Windows VPS 上完整實測**（實測是在 Mac 上的 MT4／MT5 進行，見 [VALIDATION](../docs/VALIDATION.md)）。遇到和畫面不符的地方，以服務商當下的介面為準。
