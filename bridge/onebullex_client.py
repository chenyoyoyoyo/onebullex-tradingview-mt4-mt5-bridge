#!/usr/bin/env python3
"""
OneBullEx Open API V2 用戶端（簽名、請求、交易對名稱轉換）。

給 tv_webhook.py 與 obx_tool.py 共用。只用 Python 標準函式庫（Python 3.8 以上）。
依據文件：OneBullEx Open API V2（文件版本 2.1.1）。
"""

import hashlib
import hmac
import json
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from decimal import Decimal

BASE_URLS = {
    "test": "https://futures-openapi.1bullex.com",
    "prod": "https://futures-openapi.onebullex.com",
}


class ApiError(Exception):
    """OneBullEx 回應錯誤或連線失敗。"""


def _ssl_context():
    """macOS 上從 python.org 安裝的 Python 沒有內建憑證清單；
    有安裝 certifi 就用它的憑證，否則用系統預設。"""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


SSL_CONTEXT = _ssl_context()


# ---------------------------------------------------------------------------
# OneBullEx Open API V2 用戶端
# ---------------------------------------------------------------------------

def _sign_value(v):
    """把參數值轉成簽名用字串：整數保持整數、小數保留原精度、不用科學記號。"""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return format(Decimal(repr(v)), "f")
    if isinstance(v, Decimal):
        return format(v, "f")
    return str(v)


def build_sign_string(nonce, timestamp, params):
    """依文件 3.3：nonce、timestamp 加上參數，按 key 排序後以 & 串接。
    params 只取頂層的字串、數字；None 與巢狀物件、陣列忽略。"""
    items = {"nonce": nonce, "timestamp": timestamp}
    for k, v in (params or {}).items():
        if v is None or isinstance(v, (dict, list, tuple)):
            continue
        items[k] = v
    return "&".join(f"{k}={_sign_value(items[k])}" for k in sorted(items))


def sign(secret, sign_string):
    return hmac.new(secret.encode(), sign_string.encode(), hashlib.sha256).hexdigest()


class OneBullExClient:
    def __init__(self, base_url, api_key="", secret="", timeout=10):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.secret = secret
        self.timeout = timeout

    def request(self, method, path, params=None, private=False):
        params = {k: v for k, v in (params or {}).items() if v is not None}
        # 網站防火牆會擋 Python 預設的 User-Agent（Python-urllib），需明確指定
        headers = {"Content-Type": "application/json", "Accept": "application/json",
                   "User-Agent": "Mozilla/5.0 (compatible; OneBullEx-TradingView-Bridge/1.0)"}
        url = self.base_url + path
        body = None
        if method == "GET" and params:
            url += "?" + urllib.parse.urlencode({k: _sign_value(v) for k, v in params.items()})
        if method == "POST":
            body = json.dumps(params, separators=(",", ":")).encode()

        if private:
            if not self.api_key or not self.secret:
                raise ApiError("缺少 API key 或 Secret Key")
            nonce = uuid.uuid4().hex
            timestamp = str(int(time.time()))
            headers.update({
                "X-API-KEY": self.api_key,
                "X-Nonce": nonce,
                "X-Timestamp": timestamp,
                "X-Signature": sign(self.secret, build_sign_string(nonce, timestamp, params)),
            })

        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout, context=SSL_CONTEXT) as resp:
                payload = json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            try:
                payload = json.loads(raw)
            except Exception:
                snippet = " ".join(raw.split())[:200]
                raise ApiError(f"OneBullEx HTTP {e.code}：{snippet}")
        except urllib.error.URLError as e:
            if isinstance(e.reason, ssl.SSLCertVerificationError):
                raise ApiError("HTTPS 憑證驗證失敗：請先執行 python3 -m pip install certifi 後再試")
            raise ApiError(f"連線 OneBullEx 失敗：{e.reason}")
        except json.JSONDecodeError:
            raise ApiError("OneBullEx 回應不是 JSON")

        if not isinstance(payload, dict) or payload.get("code") != 0:
            msg = payload.get("msg") if isinstance(payload, dict) else payload
            raise ApiError(f"OneBullEx 錯誤：{msg}")
        return payload.get("data")


# OneBullEx 的交易對清單（/v2/public/symbol/all），用來對應寫法不同的名稱，
# 例如訊息裡的 BTCSPARTANS_USDT 對應交易所的斯巴達專屬交易對。
KNOWN_SYMBOLS = set()


def _squash(s):
    return s.replace("_", "").replace("-", "")


def to_ob_symbol(name):
    """BTC_USDT / BTC_USDT.swap / btc_usdt -> btc_usdt；
    BTCSPARTANS_USDT -> 交易所清單中對應的名稱（例如 btcspartans_usdt）"""
    s = str(name or "").strip()
    if not s:
        raise ApiError("缺少交易對（symbol）")
    s = s.split(".")[0].lower()
    if KNOWN_SYMBOLS and s not in KNOWN_SYMBOLS:
        for k in KNOWN_SYMBOLS:
            if _squash(k) == _squash(s):
                return k
    if "_" not in s and s not in KNOWN_SYMBOLS:
        raise ApiError(f"交易對格式錯誤：{name}，應為 BTC_USDT 或 BTCSPARTANS_USDT")
    return s


def display_symbol(ob_symbol):
    """btcspartans_usdt -> BTCSPARTANS_USDT（紀錄與訊息用的寫法）"""
    s = str(ob_symbol or "")
    if s and "_" not in s and s.lower().endswith("usdt"):
        s = s[:-4] + "_" + s[-4:]
    return s.upper()
