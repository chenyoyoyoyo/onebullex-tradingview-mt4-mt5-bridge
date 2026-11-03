# 07 日常維運與疑難排解

以下指令都在主機上執行，路徑以 `~/onebullex-tradingview-bridge/bridge` 為例：

```bash
cd ~/onebullex-tradingview-bridge/bridge
```

## 常用指令

| 要做的事 | 指令 |
| --- | --- |
| 最近的紀錄（印完就結束，建議先用這個） | `sudo bash install.sh recent`（或 `recent 200`） |
| 較早版本沒有 `recent`／`spec` 時 | `sudo journalctl -u onebullex-tv -n 60 --no-pager`；`sudo python3 ~/onebullex-tradingview-bridge/bridge/obx_tool.py spec <交易對>` |
| 即時紀錄（先點終端機，按 Control+C 離開） | `sudo bash install.sh logs` |
| 查合約規格、1 張名目金額 | `sudo bash install.sh spec XAUSPARTANS_USDT` |
| 狀態總覽、最近 20 則訊號、Webhook URL、主機 IP | `sudo bash install.sh status` |
| 切換為試跑 | `sudo bash install.sh dryrun` |
| 切換為正式下單 | `sudo bash install.sh live` |
| 重新輸入 API Key 與 Secret | `sudo bash install.sh secret` |
| 查看目前的 passphrase（只在自己的終端機看） | `sudo grep '^TV_PASSPHRASE=' /etc/onebullex-tv.env` |
| 換一組 passphrase（舊的立刻失效） | `sudo bash install.sh passphrase`（之後更新所有 TradingView 警報與 MT 同步程式） |
| 固定槓桿／持倉上限／交易對清單 | `sudo bash install.sh set TV_LEVERAGE 10` 等，見 [06](06-quantity-and-risk.md) |
| 查餘額與持倉 | `sudo bash install.sh balance` |
| 更新程式 | `cd .. && git pull && cd bridge && sudo bash install.sh install` |
| 停止並移除服務（保留設定） | `sudo bash install.sh uninstall` |

## 看懂紀錄

先分清楚每一層代表什麼，不要提早當成成功：

| 看到 | 只代表 |
| --- | --- |
| `https://<網域>/` 顯示 `OK` | HTTPS 與主機可連線 |
| TradingView 警報已送出、MT 顯示 `sent` | 接收程式收下了訊號（HTTP 200），**不代表成交** |
| `收到訊號 ...` | 訊號通過驗證、進入處理 |
| `[試跑，不下單] ...` | 正式模式下會怎麼下單 |
| `成交 ...` + `完成，淨部位 N 張` | 真的成交，且持倉已核對 |


| 紀錄 | 意思 |
| --- | --- |
| `接收程式啟動 ... 試跑模式（不下單）` | 服務啟動，目前不會下單 |
| `收到訊號 BTCSPARTANS_USDT market_position=long size=3 ×10 unit=contracts` | 收到並通過驗證的訊號；`×` 後面是 multiplier，數量是換算前的值 |
| `[試跑，不下單] ... 目前 0 張 → 目標 30 張：開多 30 張` | 試跑：正式模式下會做的事 |
| `成交 ... BUY LONG 30 張，均價 ...` | 訂單已確認成交 |
| `完成，淨部位 30 張` | 持倉已核對等於目標 |
| `已等於目標，不下單` | 重送或沒有變化的訊號 |
| `（取代尚未執行的上一則）` | 處理中又收到新訊號，只執行最新的一則 |

## 疑難排解

| 狀況 | 原因與處理 |
| --- | --- |
| 警報觸發了，紀錄沒有任何東西 | 防火牆沒開 443、Webhook URL 打錯、TradingView 未開兩步驟驗證或方案不支援 webhook。到 TradingView 警報紀錄看錯誤 |
| `拒絕：來源 IP ... 不在允許清單` | 不是從 TradingView 送來的請求。自己測試請在主機上送到 `http://127.0.0.1:8780/webhook` |
| `拒絕：... passphrase 錯誤` | 訊息裡的 passphrase 和主機設定不同。`install.sh status` 不會顯示 passphrase；忘記時用 `install.sh passphrase` 換新的並更新警報 |
| `拒絕：... 訊息不是 JSON` | 訊息還是 TradingView 預設文字，或 JSON 格式錯（少引號、逗號、大括號）。把整段換成 [04](04-alert-message.md) 的範本 |
| `market_position 只能是 long、short、flat` | 警報條件不是策略，`{{strategy...}}` 沒有被替換。指標警報請用範本 C |
| `code-sign-not-match` | API Secret 與 Key 不是同一組，或輸入不完整。`install.sh secret` 重新輸入，注意顯示的 Secret 字元數 |
| `not-at-white-list` | 這組 API key 有綁 IP，但不是這台主機。`install.sh status` 查主機 IP，綁到 key 上 |
| `notional can not less than 5 USDT` | 名目金額低於交易所下限。調大數量（取得同意後），讓張數 × 面值 × 價格高於下限；提高槓桿沒有用 |
| `leverage not match`（`order_leverage_not_match_position_leverage`） | 送出的槓桿和 OneBullEx 上該交易對的槓桿不同，空倉時也可能發生。空倉時 `install.sh set TV_LEVERAGE <OneBullEx 畫面上的倍數>` |
| 目標是 0 張、沒有下單 | 幣數換算不足 1 張（例如 0.00005 BTC）。調大數量或改用範本 B |
| `超過設定的上限` | 目標超過 `TV_MAX_QTY`。確認 multiplier 沒打錯，或調高上限 |
| `未完整成交`、`未確認成交`、`淨部位與目標不符` | 到 OneBullEx 核對訂單與持倉；必要時手動處理。下一則訊號會依實際持倉重算 |
| `https` 步驟連不到網址 | 80 埠沒開導致憑證申請失敗：`sudo journalctl -u caddy -n 30` |
| 瀏覽器終端機中文是亂碼 | Lightsail 瀏覽器終端機的顯示問題，不影響執行；提示都附英文 |
| `-bash: ubuntu@ip-...: No such file or directory` | 把提示符一起貼進去了，忽略即可，只貼指令本身 |
| 警報突然沒有訊號 | 檢查 TradingView 警報是否到期或被停用；修改策略參數後要重建警報 |
| MT4／MT5 同步的問題 | 看 MT 圖表左上角的狀態，對照 [08 疑難排解](08-mt4-mt5.md#疑難排解) |

## 安全

- passphrase 就是下單的鑰匙：不要截圖分享警報設定；外流時 `install.sh passphrase` 更換並更新警報。
- API key 只開交易權限，有綁定選項時綁主機 IP；只存在主機，不放進 TradingView 訊息，也不貼進 AI 對話。
- 設定檔 `/etc/onebullex-tv.env` 只有 root 讀得到，查資料請用 `sudo bash install.sh ...`，不要放寬權限。
- 主機只跑本程式，SSH 私鑰不外流。
