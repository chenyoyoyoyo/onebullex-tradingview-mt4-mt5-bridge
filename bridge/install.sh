#!/usr/bin/env bash
# OneBullEx TradingView Bridge 主機安裝與維運腳本（Ubuntu 22.04 / 24.04，例如 AWS Lightsail）
#
#   sudo bash install.sh install            安裝或更新接收程式（第一次會詢問 API key，並產生 passphrase）
#   sudo bash install.sh https [網域]       安裝 Caddy，建立 TradingView 用的 HTTPS 網址（預設 <IP>.sslip.io）
#   sudo bash install.sh status             服務狀態、目前設定、最近訊號、Webhook URL、主機對外 IP
#   sudo bash install.sh logs               即時紀錄（Ctrl+C 離開）
#   sudo bash install.sh dryrun             切換為試跑：只記錄要下的單，不送出
#   sudo bash install.sh live               切換為正式下單
#   sudo bash install.sh secret             重新輸入 API Key 與 Secret
#   sudo bash install.sh passphrase         產生新的 passphrase（之後要更新 TradingView 警報訊息）
#   sudo bash install.sh set <設定> <值>    修改選用設定：TV_LEVERAGE、TV_MAX_QTY、TV_SYMBOLS、TV_ALLOWED_IPS
#   sudo bash install.sh balance            查帳戶餘額與持倉
#   sudo bash install.sh uninstall          停止並移除服務（保留設定檔）
#
# 雲端防火牆需開放 80（申請 HTTPS 憑證）與 443（接收 TradingView 訊號），SSH（22）照舊。
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR=/opt/onebullex_tv
APP_USER=obxtv
TV_ENV="${OBX_TV_ENV:-/etc/onebullex-tv.env}"
TV_SVC=onebullex-tv
CADDYFILE=/etc/caddy/Caddyfile
SETTABLE="TV_LEVERAGE TV_MAX_QTY TV_SYMBOLS TV_ALLOWED_IPS"

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[注意 / Note] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[錯誤 / Error] %s\033[0m\n' "$*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "請用 sudo 執行 / Run with sudo: sudo bash $0 $*"; }
need_env()  { [ -f "$TV_ENV" ] || die "還沒安裝 / Not installed yet: sudo bash $0 install"; }

# 安全地寫入設定檔的一行（值不經過 shell 展開；沒有這一行就加在最後）
set_env() {
  KEY="$1" VAL="$2" FILE="$TV_ENV" python3 - <<'PY'
import os
key, val, path = os.environ["KEY"], os.environ["VAL"], os.environ["FILE"]
if "\n" in val or "\r" in val:
    raise SystemExit("值不可以有換行")
lines = open(path, encoding="utf-8").read().splitlines()
for i, line in enumerate(lines):
    if line.startswith(key + "="):
        lines[i] = f"{key}={val}"
        break
else:
    lines.append(f"{key}={val}")
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

get_env() { grep -E "^$1=" "$TV_ENV" 2>/dev/null | tail -n1 | cut -d= -f2- || true; }

restart_tv() {
  command -v systemctl >/dev/null 2>&1 || return 0
  systemctl is-enabled --quiet "$TV_SVC" 2>/dev/null || return 0
  systemctl restart "$TV_SVC"
  sleep 2
  if systemctl is-active --quiet "$TV_SVC"; then
    journalctl -u "$TV_SVC" -n 1 --no-pager -o cat 2>/dev/null || true
  else
    warn "接收程式沒有啟動 / Service failed: sudo journalctl -u $TV_SVC -n 50"
  fi
}

new_passphrase() { python3 -c 'import secrets; print(secrets.token_urlsafe(18))'; }

ask_keys() {
  local key secret
  read -rp "OneBullEx 機器人 API Key / Bot API Key: " key
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  [ -n "$key" ] || die "API Key 不可為空 / API Key is empty"
  read -rsp "OneBullEx 機器人 API Secret / Bot API Secret（輸入時不顯示 / hidden）: " secret; echo
  secret="$(printf '%s' "$secret" | tr -d '[:space:]')"
  [ -n "$secret" ] || die "API Secret 不可為空（沒貼進去？）/ API Secret is empty (paste failed?)"
  echo "已輸入 Secret ${#secret} 個字元 / Secret length: ${#secret}"
  set_env OBX_API_KEY "$key"
  set_env OBX_SECRET "$secret"
  unset secret
}

install_tv() {
  need_root install
  [ -f "$SRC_DIR/tv_webhook.py" ] && [ -f "$SRC_DIR/onebullex_client.py" ] \
    || die "找不到程式檔，請在 bridge 資料夾內執行 / Run inside the bridge folder"

  say "安裝 Python 與憑證套件 / Installing Python"
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import certifi' 2>/dev/null \
     || ! command -v curl >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-certifi curl
  fi
  python3 -c 'import sys; assert sys.version_info >= (3, 8)' || die "需要 Python 3.8 以上 / Python 3.8+ required"

  say "複製程式到 $APP_DIR / Copying files"
  id "$APP_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
  install -d -m 755 "$APP_DIR"
  for f in onebullex_client.py tv_webhook.py obx_tool.py; do
    install -m 644 "$SRC_DIR/$f" "$APP_DIR/"
  done

  if [ ! -f "$TV_ENV" ]; then
    say "第一次設定（金鑰輸入時不會顯示）/ First-time setup"
    local env
    read -rp "連線環境 Environment: test 或/or prod [test]: " env
    env="$(printf '%s' "${env:-test}" | tr -d '[:space:]')"
    [ "$env" = test ] || [ "$env" = prod ] || die "只能輸入 test 或 prod / Enter test or prod"
    umask 077
    cat > "$TV_ENV" <<EOF
# OneBullEx TradingView Bridge 設定。修改後執行：sudo systemctl restart $TV_SVC
# 建議用 install.sh 的 secret／passphrase／dryrun／live／set 指令修改，不必手動編輯。
OBX_ENV=$env
OBX_API_KEY=
OBX_SECRET=
# TradingView 警報訊息裡的 passphrase 必須與此相同
TV_PASSPHRASE=$(new_passphrase)
TV_PORT=8780
# 1 = 試跑（只記錄要下的單，不送出）；確認訊號正確後改成 0（sudo bash install.sh live）
TV_DRY_RUN=1
# 以下為選用（空白或 0 = 不限制）：
# 來源 IP（預設 TradingView 官方 4 個）、允許的交易對、持倉上限（張）、開倉槓桿（0 = 沿用帳戶設定）
TV_ALLOWED_IPS=
TV_SYMBOLS=all
TV_MAX_QTY=0
TV_LEVERAGE=0
EOF
    ask_keys
  else
    warn "保留既有設定 / Keeping existing settings: $TV_ENV"
  fi
  chown root:"$APP_USER" "$TV_ENV"
  chmod 640 "$TV_ENV"

  say "設定開機自動啟動 / Enabling service (systemd: $TV_SVC)"
  cat > "/etc/systemd/system/${TV_SVC}.service" <<EOF
[Unit]
Description=OneBullEx TradingView webhook receiver
After=network-online.target
Wants=network-online.target

[Service]
User=$APP_USER
EnvironmentFile=$TV_ENV
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/tv_webhook.py
Restart=always
RestartSec=3
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$TV_SVC" >/dev/null 2>&1
  systemctl restart "$TV_SVC"
  sleep 2
  if systemctl is-active --quiet "$TV_SVC"; then
    say "接收程式已啟動 / Receiver is running"
    journalctl -u "$TV_SVC" -n 1 --no-pager -o cat || true
    say "TradingView 警報訊息要帶的 passphrase（不要截圖分享）/ Alert passphrase (keep private)"
    get_env TV_PASSPHRASE
    if [ -f "$CADDYFILE" ] && grep -q '/webhook' "$CADDYFILE"; then
      echo "Webhook URL: $(webhook_url)"
    else
      echo "下一步 / Next: sudo bash $0 https"
    fi
  else
    warn "接收程式沒有啟動 / Service failed: sudo journalctl -u $TV_SVC -n 50"
  fi
}

public_ip() { curl -s -m 10 https://checkip.amazonaws.com | tr -d '[:space:]'; }
default_domain() { local ip; ip="$(public_ip)"; [ -n "$ip" ] && echo "${ip//./-}.sslip.io"; }
webhook_url() { echo "https://$(grep -m1 -E '^[a-z0-9.-]+ \{' "$CADDYFILE" | cut -d' ' -f1)/webhook"; }

install_https() {
  need_root https
  need_env
  local domain="${1:-}"
  [ -n "$domain" ] || domain="$(default_domain)"
  [ -n "$domain" ] || die "查不到本機對外 IP，請指定網域 / Cannot detect public IP: sudo bash $0 https your.domain"
  local port; port="$(get_env TV_PORT)"; port="${port:-8780}"

  say "安裝 Caddy（自動申請與更新 HTTPS 憑證）/ Installing Caddy"
  command -v caddy >/dev/null 2>&1 || { apt-get update -qq; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq caddy; }
  cat > "$CADDYFILE" <<EOF
# TradingView 訊號接收（由 install.sh https 產生）
$domain {
	handle /webhook {
		reverse_proxy 127.0.0.1:$port
	}
	handle {
		respond "OK" 200
	}
}
EOF
  systemctl enable caddy >/dev/null 2>&1
  systemctl reload caddy 2>/dev/null || systemctl restart caddy
  say "等待憑證申請（約 10–60 秒；雲端防火牆必須已開放 80 與 443）/ Waiting for certificate"
  local i ok=""
  for i in $(seq 1 12); do
    if curl -s -m 5 "https://$domain/" >/dev/null 2>&1; then ok=1; break; fi
    sleep 5
  done
  if [ -n "$ok" ]; then
    say "完成。TradingView 警報的 Webhook URL / Webhook URL for TradingView:"
    echo "https://$domain/webhook"
  else
    warn "還連不到 https://$domain/ 。請確認雲端防火牆已開放 80、443，再執行 / Check firewall 80+443: sudo journalctl -u caddy -n 30"
  fi
}

show_status() {
  need_env
  say "接收程式 / Receiver ($TV_SVC)"
  systemctl is-active "$TV_SVC" 2>/dev/null || true
  local dry; dry="$(get_env TV_DRY_RUN)"
  echo "環境 / Env: $(get_env OBX_ENV)｜模式 / Mode: $([ "$dry" = 0 ] && echo '正式下單 LIVE' || echo '試跑 DRY RUN')"
  grep -E '^(TV_SYMBOLS|TV_MAX_QTY|TV_LEVERAGE|TV_ALLOWED_IPS)=' "$TV_ENV" || true
  local key; key="$(get_env OBX_API_KEY)"
  echo "API Key: ${key:0:6}…｜Secret: $([ -n "$(get_env OBX_SECRET)" ] && echo '已設定 / set' || echo '未設定 / missing')"
  say "最近處理的訊號 / Recent signals"
  curl -s -m 5 "http://127.0.0.1:$(get_env TV_PORT)/status" || echo "（讀不到 / unavailable）"; echo
  if [ -f "$CADDYFILE" ] && grep -q '/webhook' "$CADDYFILE"; then
    say "Webhook URL"
    webhook_url
  fi
  say "本機對外 IP（綁定 API key 白名單用）/ Public IP for API key whitelist"
  public_ip || echo "查詢失敗 / failed"; echo
}

set_mode() {
  need_root "$1"; need_env
  if [ "$1" = live ]; then
    set_env TV_DRY_RUN 0
    say "已切換為正式下單 / Switched to LIVE trading"
  else
    set_env TV_DRY_RUN 1
    say "已切換為試跑（不下單）/ Switched to DRY RUN"
  fi
  restart_tv
}

set_option() {
  need_root set; need_env
  local k="${1:-}" v="${2:-}"
  case " $SETTABLE " in *" $k "*) ;; *) die "可設定 / Settable: $SETTABLE" ;; esac
  [ -n "$v" ] || die "請給值 / Missing value: sudo bash $0 set $k <值>"
  case "$k" in
    TV_LEVERAGE|TV_MAX_QTY) [[ "$v" =~ ^[0-9]+$ ]] || die "$k 必須是整數 / must be an integer（0 = 不限 / off）" ;;
    *) [[ "$v" =~ ^[A-Za-z0-9_.,:-]+$ ]] || die "$k 只能有英數字、底線、逗號 / letters, digits, _ , only" ;;
  esac
  set_env "$k" "$v"
  say "$k=$v"
  restart_tv
}

case "${1:-}" in
  install)    install_tv ;;
  https)      install_https "${2:-}" ;;
  status)     show_status ;;
  logs)       journalctl -u "$TV_SVC" -f ;;
  dryrun)     set_mode dryrun ;;
  live)       set_mode live ;;
  secret)     need_root secret; need_env; ask_keys; restart_tv ;;
  passphrase) need_root passphrase; need_env; p="$(new_passphrase)"; set_env TV_PASSPHRASE "$p"
              say "新的 passphrase（請更新所有 TradingView 警報訊息）/ New passphrase — update your alerts"
              echo "$p"; restart_tv ;;
  set)        set_option "${2:-}" "${3:-}" ;;
  balance)    need_root balance; need_env; python3 "$APP_DIR/obx_tool.py" balance ;;
  uninstall)  need_root uninstall
              systemctl disable --now "$TV_SVC" 2>/dev/null || true
              rm -f "/etc/systemd/system/${TV_SVC}.service"; systemctl daemon-reload
              say "已移除服務，設定檔保留在 $TV_ENV / Service removed, settings kept" ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac
