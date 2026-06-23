#!/bin/bash

# <bitbar.title>SK hynix Combined</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>User</bitbar.author>
# <bitbar.desc>SK하이닉스 + KODEX SK하이닉스레버리지 통합 모니터</bitbar.desc>

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
URL="https://wts-info-api.tossinvest.com/api/v3/stock-prices?meta=true&productCodes=A000660,A0193T0"
CACHE_FILE="/tmp/sk_hynix_cache.json"

# 거래 가능 시간 확인: 평일 08:00~20:00 (KST)
HOUR=$(date +%H)
MIN=$(date +%M)
DOW=$(date +%u)   # 1=월 ... 7=일
T=$(( 10#$HOUR * 60 + 10#$MIN ))
IN_HOURS=false
[[ $DOW -le 5 && $T -ge 480 && $T -lt 1200 ]] && IN_HOURS=true

if [[ "$IN_HOURS" == "true" ]]; then
    NEW_RESPONSE=$(curl -sf -A "$UA" \
        -H "Origin: https://www.tossinvest.com" \
        -H "Referer: https://www.tossinvest.com/" \
        "$URL" 2>/dev/null)
    if [[ $? -eq 0 ]] && [[ -n "$NEW_RESPONSE" ]]; then
        echo "$NEW_RESPONSE" > "$CACHE_FILE"
        RESPONSE="$NEW_RESPONSE"
    elif [[ -f "$CACHE_FILE" ]]; then
        RESPONSE=$(cat "$CACHE_FILE")
    else
        echo "⚠️ Error"
        exit 0
    fi
else
    if [[ -f "$CACHE_FILE" ]]; then
        RESPONSE=$(cat "$CACHE_FILE")
    else
        echo "거래 불가 | font=Menlo size=12 color=#8E8E93"
        exit 0
    fi
fi

python3 - <<EOF
import json
from datetime import datetime

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

def fmt_last_stock(s):
    """주식 마지막 거래 종료: NXT 애프터마켓 20:00"""
    dt = parse_iso(s)
    if not dt:
        return "?"
    return dt.replace(hour=20, minute=0, second=0, microsecond=0).strftime("%m/%d %H:%M")

def fmt_last_etf(s):
    """ETF 마지막 거래 종료: 시간외 단일가 18:00"""
    dt = parse_iso(s)
    if not dt:
        return "?"
    return dt.replace(hour=18, minute=0, second=0, microsecond=0).strftime("%m/%d %H:%M")

def fmt_next_stock(s):
    """주식 다음 거래 시작: NXT 프리마켓 08:00"""
    dt = parse_iso(s)
    if not dt:
        return "?"
    return dt.replace(hour=8, minute=0, second=0, microsecond=0).strftime("%m/%d %H:%M")

def fmt_next_etf(s):
    """ETF 다음 거래 시작: 시가 동시호가 08:30"""
    dt = parse_iso(s)
    if not dt:
        return "?"
    return dt.replace(hour=8, minute=30, second=0, microsecond=0).strftime("%m/%d %H:%M")

def session_label_stock():
    """SK하이닉스 주식 (KRX + NXT)
    08:00~08:30  NXT 프리마켓
    08:30~09:00  동시호가
    09:00~15:20  정규장
    15:20~15:30  종가 동시호가
    15:30~15:40  거래 없음
    15:40~16:00  시간외 종가
    16:00~18:00  시간외 단일가
    18:00~20:00  NXT 애프터마켓
    그 외 / 주말  거래 불가
    """
    now = datetime.now().astimezone()
    if now.weekday() >= 5:
        return "거래 불가"
    t = (now.hour, now.minute)
    if   (8,  0) <= t < (8, 30): return "NXT 프리마켓"
    elif (8, 30) <= t < (9,  0): return "동시호가"
    elif (9,  0) <= t < (15,20): return "정규장"
    elif (15,20) <= t < (15,30): return "종가 동시호가"
    elif (15,30) <= t < (15,40): return "거래 없음"
    elif (15,40) <= t < (16, 0): return "시간외 종가"
    elif (16, 0) <= t < (18, 0): return "시간외 단일가"
    elif (18, 0) <= t < (20, 0): return "NXT 애프터마켓"
    else:                         return "거래 불가"

def session_label_etf():
    """SK하이닉스 단일종목 레버리지 ETF (KRX만, NXT 불가)
    08:30~09:00  동시호가
    09:00~15:20  정규장
    15:20~15:30  종가 동시호가
    15:30~15:40  거래 없음
    15:40~16:00  시간외 종가
    16:00~18:00  시간외 단일가
    그 외 / 주말  거래 불가
    """
    now = datetime.now().astimezone()
    if now.weekday() >= 5:
        return "거래 불가"
    t = (now.hour, now.minute)
    if   (8, 30) <= t < (9,  0): return "동시호가"
    elif (9,  0) <= t < (15,20): return "정규장"
    elif (15,20) <= t < (15,30): return "종가 동시호가"
    elif (15,30) <= t < (15,40): return "거래 없음"
    elif (15,40) <= t < (16, 0): return "시간외 종가"
    elif (16, 0) <= t < (18, 0): return "시간외 단일가"
    else:                         return "거래 불가"

try:
    result = json.loads('''$RESPONSE''')['result']
    items = {p['productCode']: p for p in result}
    skh = items['A000660']
    lev = items['A0193T0']
except Exception:
    print("⚠️ Parse Error")
    exit()

def parse_stock(p):
    base  = float(p.get('base', 0))
    close = float(p.get('close', 0))
    vol   = int(p.get('volume', 0))
    change = close - base
    pct    = (change / base * 100) if base else 0
    return base, close, vol, change, pct, p.get('tradingEnd',''), p.get('nextTradingStart','')

skh_base, skh_close, skh_vol, skh_change, skh_pct, skh_end, skh_next = parse_stock(skh)
lev_base, lev_close, lev_vol, lev_change, lev_pct, lev_end, lev_next = parse_stock(lev)

def color(change):
    return "#FF453A" if change > 0 else "#0A84FF" if change < 0 else "#8E8E93"

def sign(change):
    return "+" if change >= 0 else "-"

# 메뉴바 색상: SK하이닉스 변동 기준
bar_color = "#FF453A" if skh_change > 0 else "#0A84FF" if skh_change < 0 else "#8E8E93"

menubar = (
    f"{skh_close:,.0f}원 {sign(skh_change)}{abs(skh_change):,.0f}원 ({sign(skh_change)}{abs(skh_pct):.1f}%)"
    f"  ·  "
    f"{lev_close:,.0f}원 {sign(lev_change)}{abs(lev_change):,.0f}원 ({sign(lev_change)}{abs(lev_pct):.1f}%)"
)
print(f"{menubar} | font=Menlo size=12 color={bar_color}")
print("---")

# ── SK하이닉스 ──────────────────────────────────────
sess = session_label_stock()
c = color(skh_change)
s = sign(skh_change)
print(f"✦ SK hynix · SK하이닉스 · {sess}")
print("---")
print(f"  Price    {skh_close:>12,.0f}원  |  font=Menlo size=12 color={c}")
print(f"  Change   {s}{abs(skh_change):>11,.0f}원  |  font=Menlo size=12 color={c}")
print(f"  Change % {s}{abs(skh_pct):>10.1f}%  |  font=Menlo size=12 color={c}")
print("---")
print(f"  Base     {skh_base:>12,.0f}원  |  font=Menlo size=12")
print(f"  Volume   {skh_vol:>12,}   |  font=Menlo size=12")
print("---")
print(f"  🕐 Last:  {fmt_last_stock(skh_end)}")
print(f"  🕐 Next:  {fmt_next_stock(skh_next)}")
print("---")
print("↗ Toss (SKH)   | href=https://www.tossinvest.com/stocks/A000660/order")

# ── KODEX 레버리지 ──────────────────────────────────
c = color(lev_change)
s = sign(lev_change)
print("---")
print(f"✦ KODEX SK하이닉스레버리지 · {session_label_etf()}")
print("---")
print(f"  Price    {lev_close:>12,.0f}원  |  font=Menlo size=12 color={c}")
print(f"  Change   {s}{abs(lev_change):>11,.0f}원  |  font=Menlo size=12 color={c}")
print(f"  Change % {s}{abs(lev_pct):>10.1f}%  |  font=Menlo size=12 color={c}")
print("---")
print(f"  Base     {lev_base:>12,.0f}원  |  font=Menlo size=12")
print(f"  Volume   {lev_vol:>12,}   |  font=Menlo size=12")
print("---")
print(f"  🕐 Last:  {fmt_last_etf(lev_end)}")
print(f"  🕐 Next:  {fmt_next_etf(lev_next)}")
print("---")
print("↗ Toss (KODEX) | href=https://www.tossinvest.com/stocks/A0193T0/order")
print("🔄 Refresh | refresh=true")
EOF
