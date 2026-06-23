#!/bin/bash

# <bitbar.title>TSLA Stock Price</bitbar.title>
# <bitbar.version>v6.0</bitbar.version>
# <bitbar.author>User</bitbar.author>
# <bitbar.desc>TSLA stock price monitor via Toss Invest</bitbar.desc>

CODE="US20100629001"
SYMBOL="TSLA"
CACHE_FILE="/tmp/tsla_stock_cache.json"
CACHE_TTL=5

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
URL="https://wts-info-api.tossinvest.com/api/v2/stock-prices?codes=${CODE}"

if [[ -f "$CACHE_FILE" ]] && [[ $(( $(date +%s) - $(stat -f %m "$CACHE_FILE") )) -lt $CACHE_TTL ]]; then
    RESPONSE=$(cat "$CACHE_FILE")
else
    NEW_RESPONSE=$(curl -sf -A "$UA" \
        -H "Origin: https://www.tossinvest.com" \
        -H "Referer: https://www.tossinvest.com/" \
        "$URL" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$NEW_RESPONSE" ]]; then
        if [[ -f "$CACHE_FILE" ]]; then
            RESPONSE=$(cat "$CACHE_FILE")
        else
            echo "⚠️ Error"
            exit 0
        fi
    else
        RESPONSE="$NEW_RESPONSE"
        echo "$RESPONSE" > "$CACHE_FILE"
    fi
fi

python3 - <<EOF
import json
from datetime import datetime

try:
    p = json.loads('''$RESPONSE''')['result']['prices'][0]
except Exception:
    print("⚠️ Parse Error")
    exit()

base = float(p.get('base', 0))
close = float(p.get('close', 0))
volume = int(p.get('volume', 0))
trading_end = p.get('tradingEnd', '')
next_start = p.get('nextTradingStart', '')
close_krw = float(p.get('closeKrwDecimal', p.get('closeKrw', 0)))
meta = p.get('metaData', {}) or {}
ah_close = float(meta.get('afterMarketClose', 0))
ah_close_krw = float(meta.get('afterMarketCloseKrwDecimal', meta.get('afterMarketCloseKrw', 0)))

change = close - base
pct = (change / base * 100) if base else 0

def parse_iso(s):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00')).astimezone()
    except Exception:
        return None

def fmt_dt(s):
    dt = parse_iso(s)
    return dt.strftime("%m/%d %H:%M") if dt else "?"

now = datetime.now().astimezone()
trading_end_dt = parse_iso(trading_end)
next_start_dt = parse_iso(next_start)
is_closed_session = bool(
    trading_end_dt and next_start_dt and trading_end_dt <= now < next_start_dt
)
show_after_hours = is_closed_session and ah_close > 0

display_close = ah_close if show_after_hours else close
display_close_krw = ah_close_krw if show_after_hours and ah_close_krw > 0 else close_krw
display_change = display_close - base
display_pct = (display_change / base * 100) if base else 0
session_label = "시간외" if show_after_hours else "정규장"

c = "#30D158" if display_change > 0 else "#FF453A" if display_change < 0 else "#FFFFFF"
arrow = "▲" if display_change >= 0 else "▼"
sign = "+" if display_change >= 0 else "-"

print(f"\${display_close:.2f} {arrow} {sign}\${abs(display_change):.2f} ({sign}{abs(display_pct):.2f}%) | font=Menlo size=12 color={c}")
print("---")
print(f"✦ TSLA · Tesla · {session_label}")
print("---")
print(f"  Price       \${display_close:>8.2f}  |  font=Menlo size=12 color={c}")
print(f"  Change      {sign}\${abs(display_change):>7.2f}  |  font=Menlo size=12 color={c}")
print(f"  Change %    {sign}{abs(display_pct):>7.2f}%  |  font=Menlo size=12 color={c}")
print("---")
print(f"  Base        \${base:>7.2f}  |  font=Menlo size=12")
print(f"  KRW         ₩{display_close_krw:>7,.0f}  |  font=Menlo size=12")
print(f"  Volume    {volume:>10,}  |  font=Menlo size=12")

if show_after_hours:
    print(f"  Regular     \${close:>7.2f}  |  font=Menlo size=12")
elif ah_close:
    print(f"  After Mkt   \${ah_close:>7.2f}  |  font=Menlo size=12")

print("---")
print(f"  🕐 Last:  {fmt_dt(trading_end)}")
print(f"  🕐 Next:  {fmt_dt(next_start)}")
print("---")
print("↗ Toss   | href=https://www.tossinvest.com/stocks/US20100629001/order")
print("🔄 Refresh | refresh=true")
EOF
