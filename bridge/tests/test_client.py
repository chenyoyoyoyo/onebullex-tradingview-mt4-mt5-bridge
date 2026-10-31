#!/usr/bin/env python3
"""
離線測試：OneBullEx 用戶端的簽名與交易對名稱轉換，以及錯誤提示。
簽名的預期值取自已在 OneBullEx 正式環境實際下單成功的版本，用來確保之後修改不會改壞簽名。

執行：python3 tests/test_client.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import onebullex_client as c  # noqa: E402
import tv_webhook as tv  # noqa: E402

RESULTS = []


def check(name, cond, detail=""):
    RESULTS.append(bool(cond))
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  -> {detail}"))


def main():
    params = {"symbol": "btcspartans_usdt", "origQty": "3", "leverage": 20, "positionId": 123,
              "price": 0.1, "x": None, "nested": {"a": 1}, "flag": True}
    s = c.build_sign_string("abc123", "1700000000", params)
    check("簽名字串：按 key 排序、略過 None 與巢狀物件",
          s == "flag=true&leverage=20&nonce=abc123&origQty=3&positionId=123&price=0.1"
               "&symbol=btcspartans_usdt&timestamp=1700000000", s)
    check("簽名值與已驗證版本相同",
          c.sign("secret-xyz", s) == "80e37c3857cbac1f2be876c3cbac19b05e00f0f1564c8bb29f860000d5c0e80a")

    c.KNOWN_SYMBOLS.clear()
    c.KNOWN_SYMBOLS.update({"btcspartans_usdt", "btc_usdt", "ethspartans_usdt"})
    check("交易對：BTCSPARTANS_USDT → btcspartans_usdt", c.to_ob_symbol("BTCSPARTANS_USDT") == "btcspartans_usdt")
    check("交易對：btc_usdt.swap → btc_usdt", c.to_ob_symbol("btc_usdt.swap") == "btc_usdt")
    check("交易對：ETHSPARTANSUSDT（沒有底線）也能對應", c.to_ob_symbol("ETHSPARTANSUSDT") == "ethspartans_usdt")
    check("顯示名稱：btcspartans_usdt → BTCSPARTANS_USDT", c.display_symbol("btcspartans_usdt") == "BTCSPARTANS_USDT")
    try:
        c.to_ob_symbol("")
        check("空的交易對會報錯", False)
    except c.ApiError:
        check("空的交易對會報錯", True)

    h = tv.with_hint(c.ApiError("OneBullEx 錯誤：code-sign-not-match"))
    check("簽名錯誤附上處理提示", "install.sh secret" in h, h)
    h = tv.with_hint(c.ApiError("OneBullEx 錯誤：not-at-white-list"))
    check("IP 白名單錯誤附上處理提示", "install.sh status" in h, h)
    check("其他錯誤原樣保留", tv.with_hint(c.ApiError("x")) == "x")

    passed = sum(RESULTS)
    print(f"\n{passed}/{len(RESULTS)} 項通過")
    sys.exit(0 if passed == len(RESULTS) else 1)


if __name__ == "__main__":
    main()
