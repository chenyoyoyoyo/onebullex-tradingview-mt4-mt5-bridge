# 05 試跑 → 正式下單

安裝後預設是**試跑**：收到訊號只記錄打算下的單，不會送出。依序完成下面三段。

## 1. 用測試警報確認整條線是通的

不用等策略出訊號，先建一個每分鐘觸發的測試警報：

1. 開一個終端機視窗看即時紀錄，放著不要關：

   ```bash
   sudo bash ~/onebullex-tradingview-bridge/bridge/install.sh logs
   ```

2. TradingView 打開 **BTCUSDT 1 分鐘圖**，建立警報：
   - 條件：BTCUSDT **大於（Greater Than）** 數值 `1`
   - 觸發：**每根 K 棒收盤一次（Once Per Bar Close）**
   - Webhook URL：你的網址
   - 訊息：把預設文字全部刪掉，換成（passphrase 換成你的）：

     ```json
     {"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "action": "long", "qty": 1}
     ```

3. 一分鐘內紀錄應該出現：

   ```
   收到訊號 BTCSPARTANS_USDT action=long unit=contracts
   [試跑，不下單] BTCSPARTANS_USDT 目前 0 張 → 目標 1 張：開多 1 張
   ```

   紀錄沒出現或出現錯誤，查 [07 疑難排解](07-operations.md#疑難排解)。

## 2. 正式下小量、再平倉

先查這個交易對的規格：

```bash
sudo bash ~/onebullex-tradingview-bridge/bridge/install.sh spec BTCSPARTANS_USDT
```

測試數量要同時滿足**最小張數、整數張、最低名目金額**。交易所可能拒絕名目金額太小的單（例如回覆 `notional can not less than 5 USDT`）：BTC 1 張約 8 USDT 沒問題；黃金 1 張約 4 USDT 會被拒，要用 2 張。被拒單時，說明原因並取得同意後再調整數量，不要自動放大。

再到 OneBullEx 看這個交易對的槓桿倍數。和接收程式不同時（`install.sh status` 的 `TV_LEVERAGE`，0 代表沿用帳戶），空倉時設定成一致，避免 `leverage not match`：

```bash
sudo bash ~/onebullex-tradingview-bridge/bridge/install.sh set TV_LEVERAGE <OneBullEx 畫面上的倍數>
```

取得使用者明確同意後再做這一步（會在所選環境真的下單）：

```bash
sudo bash ~/onebullex-tradingview-bridge/bridge/install.sh live
```

下一分鐘紀錄應該出現：

```
成交 BTCSPARTANS_USDT BUY LONG 1 張，均價 ...，訂單 ...
BTCSPARTANS_USDT 完成，淨部位 1 張
```

再下一分鐘會出現 `已等於目標，不下單`（重送不會加倉）。注意：試跑時持倉一直是 0，重送會重複出現同一行「開多 1 張」，那不能當成「重送不加倉」的證據，要在 LIVE 成交後看到 `已等於目標` 才算。到 OneBullEx 機器人帳戶確認持倉。

**平倉不要在 OneBullEx 手動操作**：測試警報每分鐘都送「目標多 1 張」，手動平掉下一分鐘又會開回來。編輯測試警報，把訊息改成：

```json
{"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "action": "close"}
```

確認紀錄出現 `完成，淨部位 0 張` 後，**刪除測試警報**。

## 3. 接上真正的策略

1. 決定每單大小、槓桿與防呆（[06](06-quantity-and-risk.md)），在空倉時設定。
2. 依 [04](04-alert-message.md) 建立策略警報。
3. 若想先觀察真實策略訊號：`sudo bash install.sh dryrun`，看幾個訊號都正確後再 `sudo bash install.sh live`。
4. 第一筆實盤訊號進來後，對照紀錄、OneBullEx 持倉與 TradingView 圖表的成交標記。

## 上線檢查清單

- [ ] API key 只開交易權限；`install.sh balance` 讀得到餘額（有綁 IP 的話是這台主機的 IP）
- [ ] 測試數量滿足最小張數與最低名目金額；接收程式槓桿與 OneBullEx 畫面一致
- [ ] 測試警報開倉、平倉都成功，並已刪除
- [ ] 警報訊息的 symbol、unit、multiplier 正確，張數換算過
- [ ] 帳戶保證金模式與槓桿已確認（[06](06-quantity-and-risk.md)）
- [ ] 視需要設定 `TV_SYMBOLS`、`TV_MAX_QTY`
- [ ] 記下 TradingView 警報到期日
- [ ] passphrase 沒有出現在截圖或公開對話中（有的話已用 `install.sh passphrase` 更換）
- [ ] 斯巴達資金帳戶留有足夠餘額支付贖回
- [ ] 已明確告知目前是試跑還是 LIVE，以及哪些情境已驗證、哪些還沒測
