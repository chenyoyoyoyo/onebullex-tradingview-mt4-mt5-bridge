# 02 租用雲端主機

註冊雲端帳號、付款、建立主機、修改防火牆由**使用者本人**在雲端主控台操作；AI 助手負責逐步說明。

## 規格

- 作業系統：**Ubuntu 24.04 LTS**（22.04 亦可）
- 規格：最低方案即可（512 MB–1 GB 記憶體）
- 區域：建議**新加坡**
- 必須有**固定公網 IP**（正式環境 API key 要綁定 IP 白名單）
- 防火牆：開放 **22**（SSH）、**80**（申請 HTTPS 憑證）、**443**（接收 TradingView 訊號）

TradingView 只會把 webhook 送到 80 或 443 埠，所以不能改用其他埠。

## AWS Lightsail（建議）

1. 登入 https://lightsail.aws.amazon.com ，右上角區域選 **Singapore**。
2. **Create instance**
   - Platform：Linux/Unix
   - Blueprint：**OS Only → Ubuntu 24.04 LTS**
   - Plan：最低方案
   - 名稱自訂
3. 建立完成後，進入主機的 **Networking** 分頁：
   - **Attach static IP**：建立並綁定固定 IP，記下這個 IP。
   - **Firewall rules → + Add rule**：
     - Application 選 **HTTP**（TCP 80）
     - 下方「Source IP addresses」的 Preset 選 **Any IPv4 address**（如果出現一列空白的 Custom，按 Remove 刪掉）
     - 按右下角橘色的 **Add rule**
   - 再加一條 **HTTPS**（TCP 443），來源一樣是 Any IPv4 address。
   - 原本的 SSH（22）保留。
4. 完成後規則應該有三條：HTTP 80、HTTPS 443、SSH 22。

> 開放給所有 IP 是安全的：80 只用來申請憑證；443 進來的訊號，接收程式還會檢查來源是否為 TradingView 官方 IP 與 passphrase。

## 連上主機

- **最簡單**：Lightsail 主機頁面按 **Connect using SSH**，會開一個瀏覽器終端機。
  - 這個終端機可能把中文顯示成亂碼，不影響執行。安裝腳本的每個提示都附有英文。
  - 貼上指令時，貼到提示符（`ubuntu@ip-...:~$`）**後面**，不要把提示符一起貼進去。
- **用自己電腦**：下載 Lightsail 的 SSH 金鑰（`.pem`），

  ```bash
  chmod 400 ~/Downloads/LightsailDefaultKey-ap-southeast-1.pem
  ssh -i ~/Downloads/LightsailDefaultKey-ap-southeast-1.pem ubuntu@<固定IP>
  ```

## 其他雲端

AWS EC2、Google Cloud、Vultr、DigitalOcean 等皆可：Ubuntu、最低規格、固定 IP（EC2 叫 Elastic IP）、安全群組開放 22、80、443。

## 完成條件

- [ ] 能用 SSH 登入
- [ ] 已綁定固定 IP，並記下 IP
- [ ] 防火牆開放 22、80、443

## 注意

- 這台主機建議只跑本程式，不要放其他交易所的金鑰或無關服務。
- SSH 私鑰（`.pem`）不要傳給任何人，也不要貼進 AI 對話。
- 系統出現 `System restart required` 時，找空倉的時間 `sudo reboot`；接收程式與 Caddy 會自動啟動。
