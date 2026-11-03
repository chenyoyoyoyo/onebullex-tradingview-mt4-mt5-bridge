# 03 安裝接收程式與 HTTPS

全部在**主機的終端機**執行（SSH 登入後），不是在自己電腦上。

## 1. 下載並安裝

```bash
git clone https://github.com/chenyoyoyoyo/onebullex-tradingview-bridge ~/onebullex-tradingview-bridge
cd ~/onebullex-tradingview-bridge/bridge
sudo bash install.sh install
```

依序回答三個問題（畫面中文若是亂碼，照順序輸入即可）：

| 順序 | 提示 | 輸入 |
| --- | --- | --- |
| 1 | `連線環境 Environment: test 或/or prod` | `test`（測試網）或 `prod`（正式環境） |
| 2 | `OneBullEx 機器人 API Key / Bot API Key` | 你的機器人 API Key |
| 3 | `OneBullEx 機器人 API Secret / Bot API Secret` | 你的 Secret（**輸入時不顯示**，貼上後直接按 Enter） |

輸入 Secret 後會顯示字元數。顯示 0 或明顯太短，代表沒貼進去：之後執行 `sudo bash install.sh secret` 重新輸入。

完成時畫面會顯示：

- `接收程式已啟動`，以及一行啟動紀錄：環境網址、`試跑模式（不下單）`、TradingView 官方 4 個來源 IP。
- **passphrase**：TradingView 警報訊息和 MT4／MT5 同步程式都要用。**現在就存進密碼管理器**，註明是哪台主機、哪個機器人帳戶的；不要截圖分享。忘記時不用重設，在主機上自己的終端機執行 `sudo grep '^TV_PASSPHRASE=' /etc/onebullex-tv.env` 查看。只有外流時才用 `sudo bash install.sh passphrase` 換一組（舊的立刻失效，所有訊號來源都要更新）。

> API Key、Secret 由使用者自己在終端機輸入。不要貼進 AI 對話。

## 2. 確認金鑰可用

```bash
sudo bash install.sh balance
```

顯示資金帳戶、合約帳戶餘額與持倉，就代表這組 API key 可以從這台主機使用，不用另外處理。

斯巴達機器人的 API key 不一定要綁 IP。只有出現 `not-at-white-list` 時，代表這組 key 有綁 IP、但不是這台主機：執行 `sudo bash install.sh status`，最後一行是主機對外 IP，把它綁到 key 上（OneBullEx 提供綁定選項時，建議都綁上這台主機的固定 IP）。

讀得到餘額只代表金鑰可用；能不能下單，要到 [05](05-go-live.md) 小量 LIVE 成交後才算確認。

## 3. 建立 HTTPS 網址

確認雲端防火牆已開放 80、443（[02](02-server-setup.md)），然後：

```bash
sudo bash install.sh https
```

它會安裝 Caddy，用主機 IP 組成免費網域（例如 `203-0-113-10.sslip.io`），自動申請憑證，最後顯示：

```
https://203-0-113-10.sslip.io/webhook
```

這就是 TradingView 警報的 **Webhook URL**。過程中出現 `Pending kernel upgrade`、`Restarting services` 等訊息是 Ubuntu 的系統更新提示，不影響安裝。

有自己的網域時：`sudo bash install.sh https bot.example.com`（網域要先指到主機 IP）。

## 4. 確認

- 用瀏覽器打開 `https://<網域>/`，應該顯示 `OK`。
- `sudo bash install.sh status` 會列出服務狀態、目前模式、Webhook URL。

接著到 [04](04-alert-message.md) 建立 TradingView 警報。

## 更新程式

```bash
cd ~/onebullex-tradingview-bridge && git pull && cd bridge && sudo bash install.sh install
```

設定（金鑰、passphrase、模式）會保留。
