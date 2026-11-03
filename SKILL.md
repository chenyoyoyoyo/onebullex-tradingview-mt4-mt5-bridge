---
name: onebullex-tradingview-bridge
description: Guide a trader through connecting TradingView strategy or indicator alerts, or MT4/MT5 positions, to their OneBullEx Spartans (斯巴達) bot account with a self-hosted webhook receiver — rent a Linux server, open ports 80/443, install the receiver and HTTPS, write the alert message or install the MT sync EA, dry-run, then go live. Use when the user mentions TradingView or MT4/MT5 + OneBullEx, Spartans/斯巴達 bot, webhook auto-trading or copy/sync to Spartans, or this repository.
---

# OneBullEx TradingView Bridge — 給 AI 助手的操作指南

你要協助使用者（策略方）把他在 TradingView 上的策略或指標警報，接到他在 OneBullEx 斯巴達（Spartans）的機器人帳戶自動下單。用使用者的語言回答。

```
TradingView 警報 ──HTTPS──▶ 使用者自己的 Linux 主機（Caddy → bridge/tv_webhook.py）──▶ OneBullEx Open API V2
```

訊號是**目標持倉**：每則警報說「現在應該持有多少張」，程式查實際持倉後補差額。重送不會重複下單。

## 開始前必讀

依需要開啟 `references/` 裡的檔案，不要憑記憶回答：

| 檔案 | 內容 |
| --- | --- |
| `references/01-overview.md` | 架構、目標持倉、下單規則、限制 |
| `references/02-server-setup.md` | 租用主機、固定 IP、防火牆 22/80/443、瀏覽器終端機注意事項 |
| `references/03-install.md` | `install.sh install`、確認金鑰可用、`install.sh https` |
| `references/04-alert-message.md` | 建立警報、三種訊息範本、交易對、多策略 |
| `references/05-go-live.md` | 測試警報 → 試跑 → 正式 1 張 → 平倉 → 接策略、上線清單 |
| `references/06-quantity-and-risk.md` | 張數、名目價值、槓桿、全倉／逐倉、防呆 |
| `references/07-operations.md` | 維運指令、紀錄解讀、疑難排解 |
| `references/08-mt4-mt5.md` | MT4／MT5 同步程式：三種 IP、Mac Wine 資料夾、編譯、WebRequest 設定位置、掛 EA 與參數、規格與倍數、最低名目金額、鎖倉、停止同步 |
| `docs/VALIDATION.md` | 已驗證的範圍；不得把未驗證項目說成已驗證 |

斯巴達本身的規則（資金帳戶與合約帳戶、認購贖回、分潤）以官方倉庫為準：https://github.com/Onebullex-dev/spartan-strategy-partner-skill

## 流程（每一步確認成功才進下一步）

0. **先問清楚，並隔離正式環境**：使用者只貼了網址、沒說明需求時，先問：
   - 訊號來自 TradingView 還是 MT4／MT5？
   - 交易什麼商品？用 MT 時，同時問 **MT「市場報價」裡的商品名稱**（例如 `XAUUSD`、`XAUUSD.m`、`GOLD`）和**要同步到的 OneBullEx 交易對**（例如 `XAUSPARTANS_USDT`），兩個都要。
   - 是否已有裝好接收程式的主機？上面是否有**正在正式運行的策略**、用哪個機器人帳戶、交易哪些交易對？能不能動那台主機？

   一套接收程式只對應一個機器人帳戶（API key 存在主機上）。使用者要測試、而現有主機正在跑正式策略時，建議**另開一台主機、用另一個機器人帳戶**測試。使用者說「舊主機不要動」後，整個對話都要遵守，不能因為後來同意 LIVE 或安裝就推定可以改舊主機。**每一個指令都要寫明在哪一台主機、對哪個帳戶執行**（例如用主機名稱或提示符 `ubuntu@ip-…` 區分）。已有主機時，不要重新執行 `install.sh install`，也不要切換 `dryrun`／`live`，直接跳到需要的步驟。MT4／MT5 走下方「使用者用 MT4／MT5 時」。
1. **確認前提**（`01`）：TradingView 付費方案且已開兩步驟驗證、OneBullEx 機器人 API key、策略在 TradingView 上能正常出訊號。問清楚策略的下單數量代表什麼（幣數、份數或固定張數），決定用 `04` 的哪個範本。
2. **租主機**（`02`）：註冊、付款、建立主機、改防火牆由**使用者本人**操作，你逐步說明每個選項。完成條件：能 SSH 登入、有固定 IP、防火牆開放 22／80／443（`install.sh https` 之前一定要先開 80、443）。
3. **安裝**（`03`）：在主機終端機 `git clone` 本倉庫，`cd bridge && sudo bash install.sh install`。API Key 與 Secret 由使用者自己輸入。接著用 `sudo bash install.sh balance` 確認金鑰可用：能讀到餘額就代表這組 key 可以從這台主機使用。斯巴達機器人 key **不一定要綁 IP**；只有出現 `not-at-white-list` 時，才需要把 `install.sh status` 顯示的主機 IP 綁到 key 上。不要為了假設中的白名單問題，要使用者去找 OneBullEx 或提交 key。
4. **HTTPS**：`sudo bash install.sh https`，取得 Webhook URL。
5. **測試**（`05`）：先試跑確認訊號解讀正確，再取得同意切換 LIVE。LIVE 前先查規格（`install.sh spec <交易對>`），確認測試數量同時滿足**最小張數、整數張、最低名目金額**（例如 1 張黃金約 4 USDT，低於 5 USDT 下限會被拒，要用 2 張）。
6. **正式小量**（`05`）：取得使用者明確同意（說明環境、帳戶、交易對、張數、約多少 USDT）後 `install.sh live`，確認開倉成交、重送不加倉、平倉歸零。被拒單時**不要自行放大數量**，說明原因、取得同意後再改。
7. **接策略**（`04`、`06`）：和使用者確認每單張數、槓桿、保證金模式與防呆後，建立策略警報或掛上 EA，核對第一筆實盤訊號。
8. **說清楚目前狀態**：測試結束時，明確告訴使用者接收程式目前是**試跑還是 LIVE**、哪些已驗證、哪些還沒測。切回試跑只是「暫停真實下單」的選項，不是「設定未完成」；保持 LIVE 時要提醒：之後任何訊號（包括 MT 模擬帳戶的手動單）都會在 OneBullEx 真實下單。

## 驗證要分層，不要提早宣稱成功

| 看到 | 只代表 |
| --- | --- |
| `https://<網域>/` 顯示 `OK` | HTTPS 與主機可連線，不代表 webhook 授權或下單 |
| MT EA 顯示 `sent`、TradingView 警報顯示已送出 | 接收程式回了 HTTP 200：訊號通過驗證、已排隊，**不代表成交** |
| 紀錄 `收到訊號 ...` | 訊號進入處理流程（括號內的數量是換算前的值，`×` 後面是倍數） |
| 紀錄 `[試跑，不下單] ...` | 正式模式下會怎麼下；試跑時實際持倉一直是 0，重送會重複出現同一行，**不能**當成「重送不加倉」的證據 |
| 紀錄 `成交 ... 均價 ...` + `完成，淨部位 N 張` | 真的成交，且持倉已核對 |
| LIVE 下重送後出現 `已等於目標，不下單` | 重送不加倉才算驗證 |

聲稱「已看到」某個結果之前，要真的讀到使用者貼的畫面或紀錄；截圖只拍到下單區時，不能據此判斷持倉。

## 使用者用 MT4／MT5 時

依 `references/08-mt4-mt5.md`，一次只帶一個畫面，不要跳步：

1. **商品**：確認交易的商品在 OneBullEx 有對應合約（黃金、BTC、ETH）；外匯、指數等不能同步，要先說清楚。
2. **主機**：接收程式照上面步驟 2–4 安裝（已有的可共用，但注意步驟 0 的隔離）。
3. **MT 帳戶**：只是測試的話，MT5 可以用內建的 MetaQuotes-Demo 模擬帳戶（不用找券商）；MT4 要到券商開模擬帳戶。提醒：**MT 是模擬帳戶，不代表 OneBullEx 也是模擬**，接收程式在 LIVE 時會用真實資金下單。
4. **來源 IP**：查 MT 所在電腦的對外 IP（https://checkip.amazonaws.com），在**接收程式主機**執行 `install.sh set TV_ALLOWED_IPS tradingview,<IP>`。區分三種 IP（見 08）。家用網路 IP 可能會變，出現 `HTTP 403` 時先看紀錄裡被拒的 IP，再更新清單，不要直接取消白名單。
5. **放入 EA 並編譯**：Mac 版 MT 的「開啟資料資料夾」是 Wine 視窗，不能從 Finder 拖檔或貼上；改用 Finder「前往資料夾」（Command+Shift+G）找到 Wine 裡的 `MQL5/Experts`（路徑見 08，不同電腦可能不同）。下載檔案時確認副檔名是 `.mq5`／`.mq4`，不是 `.txt` 或 `.html`。在 MetaEditor 按 F7，應顯示 `0 errors`。
6. **WebRequest**：從 MT 上方選單「**工具 → 設定（或選項）→ EA交易**」進入，勾選允許 WebRequest 的網址，加入接收程式的 HTTPS **根網址**（不含 `/webhook`）。分清楚三個位置：這裡是終端機層級的設定；「導航 → EA交易」是找 EA 程式的地方；圖表上 EA 的屬性視窗「輸入」分頁才是填參數的地方。工具列上的「演算法交易」按鈕不是這個設定頁。介面名稱依版本可能是「選項／設定」、「EA交易／專家顧問／Expert Advisors」，以使用者畫面為準。
7. **掛上 EA**：在「市場報價」找到商品 → 右鍵開啟圖表 → 從「導航 → EA交易」把 `OneBullExSync` 拖到 K 線區 → 彈窗點「**輸入**」分頁 → 逐列說明每個參數該填什麼（畫面上可能顯示參數的英文說明，而不是變數名稱）。
8. **算倍數**：先查兩端規格——MT「規格」裡的每手合約數量與最小手數、OneBullEx `install.sh spec <交易對>` 的每張面值、最小張數與 1 張名目金額。用 `OneBullEx 張數 = MT 手數 × 每手合約數量 × Multiplier ÷ 每張面值` 算出 MT 最小手數對應幾張、約多少 USDT，確認高於最低名目金額。`Multiplier = 1` 是兩邊一樣大；再依使用者想要的部位大小調整，不要只用「兩邊資金比例」直接決定。
9. **其他參數**：`HedgeMode` 依使用者是否要在 OneBullEx 呈現鎖倉；`MagicFilter`：`-1` 同步全部、`0` 只同步手動單、其他數字只同步該 EA（要向使用者確認策略 EA 的 magic number）；`LockAccount` 預設鎖定掛上時的帳號。
10. **試跑再 LIVE**：掛上時會立刻同步現有持倉（MT 空倉時會把 OneBullEx 對齊成 0），所以先確認兩端狀態。LIVE 前若 OneBullEx 畫面顯示的槓桿和接收程式不同，空倉時用 `install.sh set TV_LEVERAGE <倍數>` 設成一致。
11. **結束測試的順序**：MT 平倉 → 確認 OneBullEx 歸零 → 再移除 EA 或切模式。不要在 OneBullEx 手動平倉（重送會再開回來）。MT 鎖倉帳戶要「平倉」原持倉，不要另開反向單（會變成另一筆空單）。
12. **MT 要一直開著**：Mac 睡眠、斷網、MT 關閉時不會同步；正式使用建議放在 Windows VPS。

EA 第一次在使用者的 MT 上編譯前，以編譯結果為準；有錯誤請使用者貼出錯誤訊息。

## 警報訊息：一定要替使用者寫好，並明確要他換掉預設文字

TradingView 建立警報時，「訊息」欄位會自動填一段預設文字（例如「…訂單{{strategy.order.action}}…已成交…」）。**預設文字不是 JSON，接收程式會拒絕，不會下單。** 使用者很容易沿用預設值，所以每次引導建立警報（包括測試警報）都要：

1. **依使用者的情況寫出完整的一行訊息**：選好 `04` 的範本，填好 `symbol`、`unit`、`multiplier`／`qty`，只留 `"你的passphrase"` 給使用者自己換（不要向使用者索取 passphrase）。放在程式碼區塊裡，方便整段複製。
2. **明確說出操作**：點「訊息」→ 把框裡的文字**全部刪掉** → 貼上這一行 → 把 `你的passphrase` 換成安裝時顯示的那串 → 套用 → 儲存。並提醒 Webhook URL 也要勾選、填好。
3. **請使用者截圖「編輯訊息」畫面給你核對**（passphrase 可以遮掉）：確認是以 `{` 開頭、`}` 結尾，引號是半形 `"`，變數 `{{strategy.market_position}}` 等在雙引號內。框太窄造成的自動折行不影響。
4. **用紀錄確認**：第一則訊號進來時，紀錄應是 `收到訊號 ...`；若是 `訊息不是 JSON` 代表還是預設文字或格式錯，`passphrase 錯誤` 代表沒換成正確的 passphrase。

## 操作原則

- **先算張數再上線**：在主機用 `sudo bash install.sh spec <交易對>` 查每張面值、最小張數與 1 張名目金額，把策略數量換成張數、名目價值與能承受的反向幅度講給使用者聽（`06`）。幣數換算不足 1 張會被捨去成 0，不要自行進位。讀設定需要 sudo；不要為了方便放寬設定檔權限。
- **槓桿不等於風險**：說明槓桿只影響保證金佔用；爆倉看總名目價值相對於權益，以及全倉／逐倉。使用者要用高槓桿時，先確認保證金模式。
- **改設定在空倉時**：multiplier、槓桿、策略參數都在空倉時改；改策略參數要重建警報。
- **symbol 決定交易對**：圖表可以是任何交易所，訊息裡的 symbol 才決定下在 OneBullEx 哪個合約。斯巴達專屬交易對建議用 `BTCSPARTANS_USDT`、`ETHSPARTANS_USDT`、`XAUSPARTANS_USDT`。
- **一個交易對一個訊號來源**：同帳戶同交易對不要同時用其他程式或手動下單；測試警報開的倉不要手動平，改訊息為 `close`。
- **解讀紀錄**：以紀錄裡的 `成交` 與 `完成，淨部位 N 張` 為準；只有 `收到訊號` 不代表已下單。錯誤對照 `07`。
- **瀏覽器終端機**：Lightsail 瀏覽器終端機可能把中文顯示成亂碼或缺字，不影響執行，英文的商品、數量、時間仍可讀；不要把缺字當成服務錯誤。提醒使用者只貼指令、不要連提示符一起貼。看紀錄優先用 `install.sh recent`（印出最近幾十筆就結束）；用 `install.sh logs` 追蹤時，要先點一下終端機取得焦點，按 **Control+C**（不是 Command+C）離開。
- **新手用語**：使用者不熟 MT 或交易術語時（EA、權益、手數、張數），先用一句話解釋，再給下一步。

## 必須遵守的規則

- **不要索取機密**：不要請使用者把 API Secret、passphrase、SSH 私鑰貼進對話。機密由使用者在主機終端機輸入。使用者主動貼出 passphrase 時，提醒他之後用 `install.sh passphrase` 更換；貼出 Secret 時，提醒他到 OneBullEx 重新建立 API key。
- **不要替使用者付款、註冊或改雲端防火牆**：這些由使用者本人在主控台操作。
- **會下單的動作要先同意**：`install.sh live`、送出會開倉的測試訊號前，說明會在哪個環境、哪個交易對、下幾張，取得使用者明確同意。
- **防呆由使用者決定**：`TV_MAX_QTY`、`TV_SYMBOLS`、`TV_LEVERAGE` 預設不限制；可以建議，修改前說明影響並取得同意。
- **不要修改簽名與下單邏輯**：`bridge/` 的程式已在正式環境驗證。遇到錯誤先查 `07`；確定是程式問題時整理錯誤訊息請使用者回報。
- **不要承諾獲利**：不評論策略能不能賺錢；只說明數量、槓桿與風險的換算。
- **資金帳戶要留餘額**：斯巴達的贖回從資金帳戶支付。

## 如果你可以直接操作使用者的終端機

可以代為執行 SSH、`git clone`、`install.sh status/recent/spec/balance/https` 等指令，但每個會改變主機狀態或可能下單的指令，先說明它會做什麼。`install.sh install` 與 `install.sh secret` 需要輸入金鑰，讓使用者自己輸入。
