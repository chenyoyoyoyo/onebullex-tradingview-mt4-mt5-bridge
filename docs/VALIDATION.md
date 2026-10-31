# 驗證紀錄

只列出實際驗證過的項目。未列出的情境（例如其他交易對的正式環境下單、長時間連續運行統計）不得視為已驗證。

## 離線測試（不連網、不下真單）

```bash
cd bridge
python3 tests/test_tv.py      # 27 項
python3 tests/test_client.py  # 10 項
sudo bash tests/test_install.sh  # 11 項
```

| 範圍 | 內容 |
| --- | --- |
| 接收程式 | 幣數換張數（含浮點誤差與無條件捨去）、三種訊息格式、passphrase／來源 IP／JSON 檢查、目標持倉不重複下單、反手先平後開、多空並存、分倉先進先出、未成交不重送、試跑、持倉上限、交易對清單、槓桿設定、連續訊號只執行最新 |
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

公開文件不包含私人帳戶名稱、主機 IP、API key、passphrase、訂單 ID、餘額或原始部署日誌。
