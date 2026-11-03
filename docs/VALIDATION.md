# 驗證紀錄

只列出實際驗證過的項目。未列出的情境（例如其他交易對的正式環境下單、長時間連續運行統計）不得視為已驗證。

## 離線測試（不連網、不下真單）

```bash
cd bridge
python3 tests/test_tv.py      # 43 項
python3 tests/test_client.py  # 10 項
sudo bash tests/test_install.sh  # 11 項
```

| 範圍 | 內容 |
| --- | --- |
| 接收程式 | 幣數換張數（含浮點誤差與無條件捨去）、三種訊息格式、passphrase／來源 IP／JSON 檢查、目標持倉不重複下單、反手先平後開、多空並存、分倉先進先出、未成交不重送、試跑、持倉上限、交易對清單、槓桿設定、連續訊號只執行最新 |
| 多空分開與 MT4／MT5 訊息 | 多空分開目標（鎖倉）、重送不加倉、單邊出場、持倉上限；以同步程式組出的原始訊息測試淨部位與鎖倉、盎司換張數與倍數；MT 主機 IP 未允許時拒絕；`tradingview` 關鍵字展開 |
| 紀錄與規格 | 紀錄顯示倍數、最低名目金額與槓桿不符的錯誤提示、`spec` 顯示 1 張名目金額 |
| 用戶端 | 簽名字串與簽名值與已在正式環境下單成功的版本一致、交易對名稱轉換、錯誤處理提示 |
| 安裝腳本 | `set`／`live`／`dryrun`／`secret`／`passphrase` 寫入設定檔，含特殊字元與非法值檢查 |

## 正式環境驗證（匿名摘要）

- 環境：AWS Lightsail 新加坡、Ubuntu 24.04、Caddy + sslip.io HTTPS。
- 訊號來源：TradingView 真實警報（webhook），經官方來源 IP 與 passphrase 驗證。
- 交易對：`BTCSPARTANS_USDT`，斯巴達機器人帳戶。

| 步驟 | 結果 |
| --- | --- |
| 試跑 | 正確查到持倉 0 張，紀錄「開多 1 張」，未送單 |
| 正式開倉 | 市價開多 1 張，確認成交與均價，淨部位 1 張 |
| 重送同一則訊號 | 已等於目標，不下單 |
| 平倉訊號 | 平多 1 張成交，淨部位 0 張 |
| 重送平倉訊號 | 已等於目標，不下單 |
| 錯誤的 Secret | 回 `code-sign-not-match`，未下單；重新輸入後恢復 |
| 非 JSON 訊息 | 拒絕並記錄，未下單 |

## MT5 同步實測（2026-11-03，匿名摘要）

- 證據：接收程式主機日誌、MT5 編譯畫面；EA 版本 1.00（`mt/OneBullExSync.mq5`），MT5 build 未記錄。

- 訊號來源：Mac 版 MT5（Wine），MetaQuotes-Demo 模擬帳戶（鎖倉帳戶），手動下單。
- 接收程式：全新 Lightsail 主機，另一個斯巴達機器人帳戶（未綁 IP 的 API key），LIVE。
- 設定：`SymbolMap=XAUUSD=XAUSPARTANS_USDT`、`Multiplier=0.001`、`HedgeMode=false`、`MagicFilter=0`、`TV_LEVERAGE` 設成與 OneBullEx 畫面一致的 10。
- 規格：MT5 XAUUSD 每手 100、最小 0.01 手；`XAUSPARTANS_USDT` 每張 0.001、最小 1 張、整數張。

| 步驟 | 結果 |
| --- | --- |
| `OneBullExSync.mq5` 編譯 | 0 errors, 0 warnings |
| 金鑰 | `install.sh balance` 讀到餘額，未出現 `not-at-white-list` |
| 來源 IP | 家用 IP 與允許清單不同時回 `HTTP 403`；依紀錄更新 `TV_ALLOWED_IPS` 後通過 |
| LIVE 1 張 | 被交易所拒絕：`notional can not less than 5 USDT`（1 張約 3.95 USDT） |
| LIVE 槓桿 | 曾回 `leverage not match`；設定 `TV_LEVERAGE` 與 OneBullEx 一致後解決 |
| MT5 買 0.02 手 | OneBullEx 開多 2 張成交，淨部位 2 |
| 60 秒重送 | 已等於目標，不加倉 |
| MT5 平倉 | OneBullEx 平多 2 張成交，淨部位 0 |

## MT4 同步實測（2026-11-04，匿名摘要）

- 證據：接收程式主機 SSH 日誌（`journalctl`）、MT4 編譯與設定截圖。
- EA：`mt/OneBullExSync.mq4` 版本 1.00，SHA-256 `2d4b176bc65b41b8cb89dfa42500f32115216eac057832d867dc63d5b573209c`（自 commit `8999680` 起未變動）；MT4 build 未記錄。
- 訊號來源：Mac 版 MT4（Wine），券商 MT4 Standard 模擬帳戶，手動下單，商品名稱 `GOLD`。
- 接收程式：與 MT5 測試相同的專用測試主機與機器人帳戶，原本就是 LIVE，槓桿沿用 10 倍；沒有重裝或切換模式，也沒有另外做 MT4 試跑（先用空倉訊號核對，再取得同意小量實測）。測試前已移除 MT5 的同步程式，只有 MT4 送訊號。
- 設定：`SymbolMap=GOLD=XAUSPARTANS_USDT`、`Multiplier=0.001`、`HedgeMode=false`、`MagicFilter=0`、`PollSeconds=1`、`ResendSeconds=60`。
- 規格（登入成功後查詢）：GOLD 每手 100、最小交易量與步長 0.01；`XAUSPARTANS_USDT` 每張 0.001、最小 1 張、整數張。未連線時規格視窗曾顯示每手 250，判定為無效值、未採用。

| 步驟 | 結果 |
| --- | --- |
| `OneBullExSync.mq4` 編譯 | 0 errors, 0 warnings |
| 空倉掛上 EA | 目標 0、淨部位 0，不下單 |
| 買入 0.02 手 | 開多 2 張成交，淨部位 +2；兩次重送不加倉 |
| 多單全部平倉 | 平多 2 張成交，淨部位 0；兩次重送不下單 |
| 賣出 0.04 手 | 開空 4 張成交，淨部位 −4；兩次重送不加倉 |
| 空單部分平倉 0.02 手（對原持倉平倉） | 平空 2 張成交，淨部位 −2；兩次重送不多平、不加倉 |
| 剩餘 0.02 手平倉 | 平空 2 張成交，淨部位 0；重送不下單 |

測試結束時接收程式仍為 LIVE、MT4 同步程式仍掛著，黃金淨部位 0。未另外核對全部委託清單，也未計算含手續費的淨損益。

## 尚未驗證

- MT4、MT5 共同：多單部分平倉、加倉、反手、`HedgeMode=true`（黃金多空同時持有）、指定 magic number 的策略 EA 單、其他商品、斷線與重啟恢復、Windows VPS、長時間運行。
- MT5 另外未測：做空、部分平倉。
- 平倉單是否同樣受最低名目金額（5 USDT）限制：未驗證；測試時每次變動都保持 2 張以上。
- `ETHSPARTANS_USDT` 的正式環境下單。

公開文件不包含私人帳戶名稱、主機 IP、API key、passphrase、訂單 ID、餘額或原始部署日誌。
