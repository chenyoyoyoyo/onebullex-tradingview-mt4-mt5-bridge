# 04 建立 TradingView 警報

## 建立步驟

1. 打開圖表，加入你的策略（或指標），時間框架設成策略要用的週期。
2. 按「建立警報 / Create alert」：
   - **條件**：選你的策略。新版 TradingView 不再顯示「Order fills only」選項，預設會在**訂單成交**與 `alert()` 呼叫時觸發；策略沒有用 `alert()` 時，效果就是「只在成交時觸發」。
   - **到期**：設成方案允許的最長期限，並記下日期。**警報到期就不會再送訊號**，實盤持倉也不會再跟著策略調整。
   - **通知**：勾選 **Webhook URL**，貼上安裝時顯示的網址（`https://.../webhook`）。看不到 Webhook 欄位時，代表帳號沒開兩步驟驗證或方案不支援。
   - **訊息**：把預設文字**全部刪掉**，換成下面其中一個範本（passphrase 換成你的）。
3. 快訊名稱自訂，例如「我的策略 實盤」。按套用 → 儲存。

> 修改策略參數後，**既有警報不會跟著更新**（警報記住的是建立當下的參數）。改參數要刪掉舊警報、重新建立。

### 驚嘆號提示

警報視窗出現橘色驚嘆號「此快訊可能無法按預期運行」，是 TradingView 對重繪風險的通用提醒，不代表策略一定會重繪。檢查策略是否：用前一根 K 棒或收盤後的值判斷、沒有 `request.security` 抓未完成的高週期資料、沒有 `calc_on_every_tick`。不確定時先用試跑觀察幾個訊號，對照圖表上的成交標記。

## 訊息範本

訊息必須是有效的 JSON：雙引號、逗號、大括號都要正確，TradingView 變數要放在雙引號裡。框太窄造成的自動折行不影響。

### 範本 A：策略，數量是幣數

策略的下單數量就是實際幣數（例如 `default_qty_value = 0.001` 代表 0.001 BTC）時用這個：

```json
{"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "market_position": "{{strategy.market_position}}", "size": "{{strategy.market_position_size}}", "unit": "coin"}
```

- 程式用合約面值換成張數：0.001 BTC ÷ 0.0001 = 10 張。不是整數張時**無條件捨去**。
- 想讓實盤是回測的一部分，加 `"multiplier": 0.1`（實盤 = 回測 × 0.1）。

### 範本 B：策略，數量當作「份數」

策略用 `1`、`2`、`3` 這種份數下單（例如分批進場，每批固定 1 份），想自己決定「每份幾張」時用這個：

```json
{"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "market_position": "{{strategy.market_position}}", "size": "{{strategy.market_position_size}}", "unit": "contracts", "multiplier": 10}
```

- `unit: "contracts"`：把策略持倉數量直接當張數，再乘 `multiplier`。
- 上例：策略持有 3 份 → 實盤 30 張。要調整每份大小，只改 `multiplier` 的數字。
- 回測的資金曲線用的是策略本身的數量，和實盤張數無關。

### 範本 C：指標警報或固定張數

```json
{"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "action": "long", "qty": 2}
```

- `action`：`long`（持有多單 qty 張）、`short`（持有空單 qty 張）、`close`（平到空手）。
- qty 是**張數**，而且是目標持倉：連續收到兩次 `long 2`，結果仍是多 2 張。
- 也可以寫 `"target": 2`（多 2 張）、`"target": -2`（空 2 張）、`"target": 0`（空手）。
- 指標警報不能用 `{{strategy...}}` 變數；做多、做空、平倉各建一個警報，各自的訊息填對應的 action。

## 交易對

訊息裡的 `symbol` 決定在 OneBullEx 交易哪個合約，**跟 TradingView 圖表是哪家交易所無關**。圖表可以用幣安的 BTCUSDT.P，訊息寫 BTCSPARTANS_USDT，就會下在 BTCSPARTANS_USDT。

| 資產 | symbol | 1 張 |
| --- | --- | --- |
| BTC（斯巴達專屬） | `BTCSPARTANS_USDT` | 0.0001 BTC |
| ETH（斯巴達專屬） | `ETHSPARTANS_USDT` | 0.01 ETH |
| 黃金（斯巴達專屬） | `XAUSPARTANS_USDT` | 0.001 |
| 一般交易對 | `BTC_USDT` 等 | 用 `python3 obx_tool.py spec BTC_USDT` 查 |

面值以交易所查詢結果為準：`python3 ~/onebullex-tradingview-bridge/bridge/obx_tool.py spec BTCSPARTANS_USDT`。

只想接受特定交易對（防止訊息打錯）：`sudo bash install.sh set TV_SYMBOLS BTCSPARTANS_USDT`（多個用逗號分隔）。

## 多個策略

- 不同交易對：各建一個警報，訊息的 symbol 不同即可，共用同一個 Webhook URL 和 passphrase。
- **同一個交易對只能有一個策略**：目標持倉會互相覆蓋。要在同一個交易對跑兩個策略，用兩個機器人帳戶、兩台主機（或兩套安裝）。
