#!/usr/bin/env bash
# 離線測試：install.sh 的設定檔修改指令（不安裝服務、不連網）。需要 root（install.sh 會檢查）。
# 執行：sudo bash tests/test_install.sh
set -u
cd "$(dirname "$0")/.."
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
printf 'OBX_ENV=test\nOBX_API_KEY=K\nOBX_SECRET=S\nTV_PASSPHRASE=oldpassphrase1\nTV_PORT=8780\nTV_DRY_RUN=1\nTV_SYMBOLS=all\nTV_MAX_QTY=0\nTV_LEVERAGE=0\n' > "$T"
export OBX_TV_ENV="$T"
pass=0; total=0
check() { total=$((total+1)); if eval "$2"; then pass=$((pass+1)); echo "PASS $1"; else echo "FAIL $1"; fi; }
run() { bash install.sh "$@" >/dev/null 2>&1; }

run live;                         check "live → TV_DRY_RUN=0"          "grep -qx 'TV_DRY_RUN=0' '$T'"
run dryrun;                       check "dryrun → TV_DRY_RUN=1"        "grep -qx 'TV_DRY_RUN=1' '$T'"
run set TV_LEVERAGE 20;           check "set TV_LEVERAGE 20"           "grep -qx 'TV_LEVERAGE=20' '$T'"
run set TV_SYMBOLS BTCSPARTANS_USDT,ETHSPARTANS_USDT
                                  check "set TV_SYMBOLS 清單"           "grep -qx 'TV_SYMBOLS=BTCSPARTANS_USDT,ETHSPARTANS_USDT' '$T'"
run set TV_MAX_QTY abc;           check "TV_MAX_QTY 非整數被拒"          "grep -qx 'TV_MAX_QTY=0' '$T'"
run set OBX_SECRET x;             check "不能用 set 改金鑰"             "grep -qx 'OBX_SECRET=S' '$T'"
run set TV_SYMBOLS 'a;rm -rf /';  check "非法字元被拒"                  "grep -qx 'TV_SYMBOLS=BTCSPARTANS_USDT,ETHSPARTANS_USDT' '$T'"
printf 'NEWKEY \n  s$e`c|r&et  \n' | bash install.sh secret >/dev/null 2>&1
                                  check "secret：去空白、特殊字元原樣寫入" "grep -qx 'OBX_API_KEY=NEWKEY' '$T' && grep -qxF 'OBX_SECRET=s\$e\`c|r&et' '$T'"
printf '\n' | bash install.sh secret >/dev/null 2>&1
                                  check "空的 API Key 被拒、不覆蓋"       "grep -qx 'OBX_API_KEY=NEWKEY' '$T'"
run passphrase;                   check "passphrase 已更換"            "! grep -qx 'TV_PASSPHRASE=oldpassphrase1' '$T' && grep -qE '^TV_PASSPHRASE=.{20,}$' '$T'"
check "設定檔行數不變（沒有重複的行）" "[ \"\$(wc -l < '$T')\" -eq 9 ]"

echo; echo "$pass/$total 項通過"; [ "$pass" -eq "$total" ]
