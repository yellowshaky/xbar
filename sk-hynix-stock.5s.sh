#!/bin/bash

# <bitbar.title>SK hynix Stock Price</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>User</bitbar.author>
# <bitbar.desc>SK hynix stock price monitor via Toss Invest</bitbar.desc>

CODE="A000660"
SYMBOL="000660.KS"
CACHE_FILE="/tmp/sk_hynix_stock_v3_cache.json"
CACHE_TTL=5

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
URL="https://wts-info-api.tossinvest.com/api/v3/stock-prices?meta=true&productCodes=${CODE}"

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
    result = json.loads('''$RESPONSE''')['result']
    p = result[0] if isinstance(result, list) else result['prices'][0]
except Exception:
    print("⚠️ Parse Error")
    exit()

base = float(p.get('base', 0))
close = float(p.get('close', 0))
volume = int(p.get('volume', 0))
trading_end = p.get('tradingEnd', '')
next_start = p.get('nextTradingStart', '')

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
regular_open = now.replace(hour=9, minute=0, second=0, microsecond=0)
regular_close = now.replace(hour=15, minute=30, second=0, microsecond=0)
is_regular_session = now.weekday() < 5 and regular_open <= now < regular_close
session_label = "정규장" if is_regular_session else "시간외"

c = "#30D158" if change > 0 else "#FF453A" if change < 0 else "#FFFFFF"
arrow = "▲" if change >= 0 else "▼"
sign = "+" if change >= 0 else "-"

print(f"₩{close:,.0f} {arrow} {sign}₩{abs(change):,.0f} ({sign}{abs(pct):.2f}%) | font=Menlo size=12 color={c}")
print("---")
print(f"✦ SK hynix · SK하이닉스 · {session_label}")
print("---")
print(f"  Price       ₩{close:>10,.0f}  |  font=Menlo size=12 color={c}")
print(f"  Change      {sign}₩{abs(change):>9,.0f}  |  font=Menlo size=12 color={c}")
print(f"  Change %    {sign}{abs(pct):>7.2f}%  |  font=Menlo size=12 color={c}")
print("---")
print(f"  Base        ₩{base:>10,.0f}  |  font=Menlo size=12")
print(f"  Volume    {volume:>10,}  |  font=Menlo size=12")
print("---")
print(f"  🕐 Last:  {fmt_dt(trading_end)}")
print(f"  🕐 Next:  {fmt_dt(next_start)}")
print("---")
print("↗ Toss   | href=https://www.tossinvest.com/stocks/A000660/order")
print("🔄 Refresh | refresh=true")
EOF
