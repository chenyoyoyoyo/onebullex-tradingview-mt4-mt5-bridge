# OneBullEx TradingView Bridge

> **給 AI 助手（Claude、ChatGPT、Codex 等）**：使用者只貼了這個網址時，請先讀 [`SKILL.md`](SKILL.md) 並照它的流程進行。第一步先問使用者：訊號來自 **TradingView** 還是 **MT4／MT5**？是否已經有裝好接收程式的主機？

把 **TradingView 的策略或指標警報**直接接到你在 **OneBullEx 斯巴達（Spartans）的機器人帳戶**自動下單。不需要 FMZ 或其他付費的託管平台，只要一台自己的雲端主機。

*Connect TradingView strategy / indicator alerts to your OneBullEx Spartans bot account through a small self-hosted webhook receiver. No third-party bot platform required.*

**也支援 MT4／MT5**：在 MT 掛上同步程式 `OneBullExSync`，MT 上的持倉（手動或 EA）會自動同步到斯巴達機器人帳戶，見 [08-mt4-mt5](references/08-mt4-mt5.md)。

```
TradingView 警報（webhook）
   │  HTTPS POST https://<你的主機>/webhook
   ▼
Caddy（自動 HTTPS）→ 接收程式 tv_webhook.py
   │  驗證 → 查實際持倉 → 補差額 → 確認成交 → 核對持倉
   ▼
OneBullEx 斯巴達機器人帳戶
```

## 特色

- **目標持倉**：每則警報說「現在應該持有多少張」，程式查實際持倉後只補差額。TradingView 重送不會重複下單，漏掉一則也會在下一則自動對齊。
- **安全**：只接受 TradingView 官方 IP 和正確的 passphrase；API key 只存在你自己的主機。
- **先試跑**：安裝後預設只記錄要下的單，確認無誤才切換成正式下單。
- **簡單**：只用 Python 標準函式庫；一支安裝腳本完成安裝、HTTPS、切換模式、換金鑰。
- **費用**：只有一台雲端主機（例如 AWS Lightsail 最低方案，每月約 5 美元）。

## 你需要準備

| 項目 | 說明 |
| --- | --- |
| TradingView 付費方案 | 免費方案不能用 webhook；帳號要開啟**兩步驟驗證**才能填 Webhook URL |
| OneBullEx 斯巴達機器人 API key | 向 OneBullEx 申請；有提供 IP 綁定時建議綁主機的固定 IP |
| 一台 Linux 雲端主機 | Ubuntu 22.04／24.04、固定 IP、防火牆開放 22、80、443 |

## 用 AI 助手帶你設定（建議）

把下面這段**整段**貼給你的 AI 助手（Claude、ChatGPT、Codex 等）。只貼網址的話，AI 常常不會主動讀文件：

```
請先讀這個 repo 的 README.md 和 SKILL.md，照 SKILL.md 的流程一步步帶我設定：
https://github.com/chenyoyoyoyo/onebullex-tradingview-bridge

我是 OneBullEx 斯巴達的策略方，不是開發者，不要修改程式碼。
我想讓我的交易訊號自動在我的斯巴達機器人帳戶下單。
```

AI 會先問你訊號來源（TradingView 或 MT4／MT5）、交易商品，以及有沒有主機。API Secret、passphrase、SSH 私鑰不要貼給 AI。

## 快速開始

完整步驟見 [`references/`](references/)。

```bash
# 在主機上（SSH 登入後）
git clone https://github.com/chenyoyoyoyo/onebullex-tradingview-bridge ~/onebullex-tradingview-bridge
cd ~/onebullex-tradingview-bridge/bridge
sudo bash install.sh install     # 輸入環境、API Key、Secret；畫面會顯示 passphrase
sudo bash install.sh https       # 建立 Webhook URL（需先開放 80、443）
```

然後在 TradingView 建立警報，Webhook URL 填安裝時顯示的網址。**「訊息」欄位的預設文字要全部刪掉**（預設文字不是 JSON，不會下單），換成：

```json
{"passphrase": "你的passphrase", "symbol": "BTCSPARTANS_USDT", "market_position": "{{strategy.market_position}}", "size": "{{strategy.market_position_size}}", "unit": "coin"}
```

試跑確認紀錄正確後：`sudo bash install.sh live`。

## 文件

| 檔案 | 內容 |
| --- | --- |
| [01-overview](references/01-overview.md) | 運作方式、目標持倉、限制 |
| [02-server-setup](references/02-server-setup.md) | 租用與設定雲端主機 |
| [03-install](references/03-install.md) | 安裝接收程式與 HTTPS |
| [04-alert-message](references/04-alert-message.md) | 建立 TradingView 警報、訊息範本、數量換算 |
| [05-go-live](references/05-go-live.md) | 試跑 → 正式下單 → 上線檢查清單 |
| [06-quantity-and-risk](references/06-quantity-and-risk.md) | 張數、名目價值、槓桿、保證金模式、防呆設定 |
| [07-operations](references/07-operations.md) | 日常維運指令與疑難排解 |
| [08-mt4-mt5](references/08-mt4-mt5.md) | MT4／MT5 持倉同步（`mt/OneBullExSync.mq4`、`.mq5`） |

斯巴達本身的規則（資金帳戶與合約帳戶、認購贖回、分潤）以官方倉庫為準：https://github.com/Onebullex-dev/spartan-strategy-partner-skill

## 免責聲明

本專案以 MIT 授權提供，不保證適合任何用途。自動交易有虧損風險，包括訊號延遲、漏送、滑價、主機或網路中斷。請先用試跑模式和最小數量驗證，並自行承擔使用結果。TradingView、OneBullEx 等名稱僅用於識別服務。
