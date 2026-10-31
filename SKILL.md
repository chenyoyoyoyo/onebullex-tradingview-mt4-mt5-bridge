---
name: onebullex-tradingview-bridge
description: Guide a trader through connecting TradingView strategy or indicator alerts to their OneBullEx Spartans (斯巴達) bot account with a self-hosted webhook receiver — rent a Linux server, open ports 80/443, install the receiver and HTTPS, write the alert message, dry-run, then go live. Use when the user mentions TradingView + OneBullEx, Spartans/斯巴達 bot, TradingView webhook auto-trading, or this repository.
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
| `references/03-install.md` | `install.sh install`、綁定 IP、`install.sh https` |
| `references/04-alert-message.md` | 建立警報、三種訊息範本、交易對、多策略 |
| `references/05-go-live.md` | 測試警報 → 試跑 → 正式 1 張 → 平倉 → 接策略、上線清單 |
| `references/06-quantity-and-risk.md` | 張數、名目價值、槓桿、全倉／逐倉、防呆 |
| `references/07-operations.md` | 維運指令、紀錄解讀、疑難排解 |
| `docs/VALIDATION.md` | 已驗證的範圍；不得把未驗證項目說成已驗證 |

斯巴達本身的規則（資金帳戶與合約帳戶、認購贖回、分潤）以官方倉庫為準：https://github.com/Onebullex-dev/spartan-strategy-partner-skill

## 流程（每一步確認成功才進下一步）

1. **確認前提**（`01`）：TradingView 付費方案且已開兩步驟驗證、OneBullEx 機器人 API key、策略在 TradingView 上能正常出訊號。問清楚策略的下單數量代表什麼（幣數、份數或固定張數），決定用 `04` 的哪個範本。
2. **租主機**（`02`）：註冊、付款、建立主機、改防火牆由**使用者本人**操作，你逐步說明每個選項。完成條件：能 SSH 登入、有固定 IP、開放 22/80/443。
3. **安裝**（`03`）：在主機終端機 `git clone` 本倉庫，`cd bridge && sudo bash install.sh install`。API Key 與 Secret 由使用者自己輸入。正式環境要請使用者把 `install.sh status` 顯示的 IP 提供給 OneBullEx 綁定白名單。
4. **HTTPS**：`sudo bash install.sh https`，取得 Webhook URL。
5. **測試警報**（`05` 第 1 段）：BTCUSDT 1 分鐘圖「大於 1、每根 K 棒收盤一次」的警報，確認紀錄出現 `[試跑，不下單] ... 開多 1 張`。
6. **正式 1 張**（`05` 第 2 段）：取得使用者明確同意後 `install.sh live`，確認開倉成交、重送不加倉；改訊息為 `close` 平倉；刪除測試警報。
7. **接策略**（`04`、`06`）：和使用者確認每單張數、槓桿、保證金模式與防呆後，建立策略警報，核對第一筆實盤訊號。

## 警報訊息：一定要替使用者寫好，並明確要他換掉預設文字

TradingView 建立警報時，「訊息」欄位會自動填一段預設文字（例如「…訂單{{strategy.order.action}}…已成交…」）。**預設文字不是 JSON，接收程式會拒絕，不會下單。** 使用者很容易沿用預設值，所以每次引導建立警報（包括測試警報）都要：

1. **依使用者的情況寫出完整的一行訊息**：選好 `04` 的範本，填好 `symbol`、`unit`、`multiplier`／`qty`，只留 `"你的passphrase"` 給使用者自己換（不要向使用者索取 passphrase）。放在程式碼區塊裡，方便整段複製。
2. **明確說出操作**：點「訊息」→ 把框裡的文字**全部刪掉** → 貼上這一行 → 把 `你的passphrase` 換成安裝時顯示的那串 → 套用 → 儲存。並提醒 Webhook URL 也要勾選、填好。
3. **請使用者截圖「編輯訊息」畫面給你核對**（passphrase 可以遮掉）：確認是以 `{` 開頭、`}` 結尾，引號是半形 `"`，變數 `{{strategy.market_position}}` 等在雙引號內。框太窄造成的自動折行不影響。
4. **用紀錄確認**：第一則訊號進來時，紀錄應是 `收到訊號 ...`；若是 `訊息不是 JSON` 代表還是預設文字或格式錯，`passphrase 錯誤` 代表沒換成正確的 passphrase。

## 操作原則

- **先算張數再上線**：查交易對面值（`python3 bridge/obx_tool.py spec <交易對>`），把策略數量換成張數、名目價值與能承受的反向幅度講給使用者聽（`06`）。幣數換算不足 1 張會被捨去成 0，不要自行進位。
- **槓桿不等於風險**：說明槓桿只影響保證金佔用；爆倉看總名目價值相對於權益，以及全倉／逐倉。使用者要用高槓桿時，先確認保證金模式。
- **改設定在空倉時**：multiplier、槓桿、策略參數都在空倉時改；改策略參數要重建警報。
- **symbol 決定交易對**：圖表可以是任何交易所，訊息裡的 symbol 才決定下在 OneBullEx 哪個合約。斯巴達專屬交易對建議用 `BTCSPARTANS_USDT`、`ETHSPARTANS_USDT`、`XAUSPARTANS_USDT`。
- **一個交易對一個訊號來源**：同帳戶同交易對不要同時用其他程式或手動下單；測試警報開的倉不要手動平，改訊息為 `close`。
- **解讀紀錄**：以紀錄裡的 `成交` 與 `完成，淨部位 N 張` 為準；只有 `收到訊號` 不代表已下單。錯誤對照 `07`。
- **瀏覽器終端機**：Lightsail 瀏覽器終端機可能把中文顯示成亂碼，不影響執行；提醒使用者只貼指令、不要連提示符一起貼。

## 必須遵守的規則

- **不要索取機密**：不要請使用者把 API Secret、passphrase、SSH 私鑰貼進對話。機密由使用者在主機終端機輸入。使用者主動貼出 passphrase 時，提醒他之後用 `install.sh passphrase` 更換；貼出 Secret 時，提醒他到 OneBullEx 重新建立 API key。
- **不要替使用者付款、註冊或改雲端防火牆**：這些由使用者本人在主控台操作。
- **會下單的動作要先同意**：`install.sh live`、送出會開倉的測試訊號前，說明會在哪個環境、哪個交易對、下幾張，取得使用者明確同意。
- **防呆由使用者決定**：`TV_MAX_QTY`、`TV_SYMBOLS`、`TV_LEVERAGE` 預設不限制；可以建議，修改前說明影響並取得同意。
- **不要修改簽名與下單邏輯**：`bridge/` 的程式已在正式環境驗證。遇到錯誤先查 `07`；確定是程式問題時整理錯誤訊息請使用者回報。
- **不要承諾獲利**：不評論策略能不能賺錢；只說明數量、槓桿與風險的換算。
- **資金帳戶要留餘額**：斯巴達的贖回從資金帳戶支付。

## 如果你可以直接操作使用者的終端機

可以代為執行 SSH、`git clone`、`install.sh status/logs/https` 等指令，但每個會改變主機狀態或可能下單的指令，先說明它會做什麼。`install.sh install` 與 `install.sh secret` 需要輸入金鑰，讓使用者自己輸入。
