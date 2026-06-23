# macOS 메뉴바 xbar 플러그인 가이드

macOS 메뉴바에서 GitHub Copilot 사용량과 SK하이닉스 관련 주가를 실시간 모니터링합니다.

---

## 플러그인 목록

| 파일명 | 설명 | 갱신 주기 | 노출 조건 |
|--------|------|----------|----------|
| `copilot-usage.60s.sh` | GitHub Copilot premium requests 사용량 | 60초 | 항상 |
| `sk-hynix-combined.1s.sh` | SK하이닉스 + KODEX SK하이닉스레버리지 통합 | 1초 | 항상 |

플러그인 폴더: `~/Library/Application Support/xbar/plugins/`

---

## 사전 요구사항

- macOS
- [Homebrew](https://brew.sh/)
- `python3`
- [xbar](https://xbarapp.com/)

```bash
brew install --cask xbar
brew install python3
```

---

## 공통 설치 절차

1. xbar 실행 후 메뉴바 아이콘 클릭 → `Preferences` > `Set Plugin Folder...`
2. 기본 폴더(`~/Library/Application Support/xbar/plugins`) 사용
3. 스크립트 파일 생성 후 실행 권한 부여
4. `Preferences` > `Refresh All`

---

## 공통 색상 규칙

### 주가/ETF 플러그인 (한국 증권 컨벤션)

| 상태 | 색상 | 코드 |
|------|------|------|
| 상승 | 🔴 빨강 | `#FF453A` |
| 보합 (0.00%) | ⬜ 회색 | `#8E8E93` |
| 하락 | 🔵 파랑 | `#0A84FF` |

> 한국 증권 컨벤션 적용: 상승=빨강, 하락=파랑.

---

## 1. GitHub Copilot 사용량 플러그인

### 메뉴바 표시

메뉴바 텍스트는 **흰색 고정**. 드롭다운 진행률 바는 사용량 기반 색상.

| 메뉴바 예시 | 진행률 바 색상 | 상태 |
|------------|--------------|------|
| `45/300 · 15.0%` | 🟢 `#30D158` | 정상 (50% 미만) |
| `160/300 · 53.3%` | 🟡 `#FFD60A` | 50% 이상 |
| `250/300 · 83.3%` | 🟠 `#FF9F0A` | 80% 이상 |
| `320/300 · 106.7%` | 🔴 `#FF453A` | 한도 초과 |

### GitHub Personal Access Token 발급

1. [GitHub Tokens 페이지](https://github.com/settings/tokens) → `Tokens (classic)`
2. `Generate new token (classic)` 클릭
3. Note: `xbar-copilot-usage`, Scope: `read:user`만 체크
4. 생성된 토큰(`ghp_...`) 복사

### 스크립트

파일 경로: `~/Library/Application Support/xbar/plugins/copilot-usage.60s.sh`

```bash
#!/bin/bash

# <bitbar.title>Copilot Usage</bitbar.title>
# <bitbar.version>v4.0</bitbar.version>
# <bitbar.author>User</bitbar.author>
# <bitbar.desc>GitHub Copilot premium request usage monitor</bitbar.desc>

GITHUB_TOKEN="ghp_YOUR_TOKEN_HERE"
CACHE_FILE="/tmp/copilot_usage_cache.json"
CACHE_TTL=60

if [[ -f "$CACHE_FILE" ]] && [[ $(( $(date +%s) - $(stat -f %m "$CACHE_FILE") )) -lt $CACHE_TTL ]]; then
    RESPONSE=$(cat "$CACHE_FILE")
else
    NEW_RESPONSE=$(curl -sf \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/json" \
      -H "User-Agent: copilot-xbar" \
      "https://api.github.com/copilot_internal/user" 2>&1)

    if [[ $? -ne 0 ]]; then
        if [[ -f "$CACHE_FILE" ]]; then
            RESPONSE=$(cat "$CACHE_FILE")
        else
            echo "⚠️ Copilot Error"
            exit 0
        fi
    else
        RESPONSE="$NEW_RESPONSE"
        echo "$RESPONSE" > "$CACHE_FILE"
    fi
fi

python3 - <<EOF
import json

data = json.loads('''$RESPONSE''')

premium = data.get("quota_snapshots", {}).get("premium_interactions", {})
chat    = data.get("quota_snapshots", {}).get("chat", {})
comp    = data.get("quota_snapshots", {}).get("completions", {})

entitlement = premium.get("entitlement", 0)
remaining   = premium.get("remaining", 0)
used        = entitlement - remaining
pct         = (used / entitlement * 100) if entitlement > 0 else 0
reset_date  = data.get("quota_reset_date", "?")
plan        = data.get("copilot_plan", "unknown")

filled = min(int(pct / 10), 10)
bar = "█" * filled + "░" * (10 - filled)

if remaining < 0:
    status_color = "#FF453A"
elif pct >= 80:
    status_color = "#FF9F0A"
elif pct >= 50:
    status_color = "#FFD60A"
else:
    status_color = "#30D158"

print(f"{used}/{entitlement} · {pct:.1f}% | size=13 color=#FFFFFF")
print("---")
print(f"✦ GitHub Copilot  ·  {plan.upper()}")
print("---")
print(f"{bar}  {pct:.1f}%  |  font=Menlo size=12 color={status_color}")
print("---")
print(f"  Used        {used:>5}  |  font=Menlo size=12")
print(f"  Remaining   {remaining:>5}  |  font=Menlo size=12")
print(f"  Limit       {entitlement:>5}  |  font=Menlo size=12")
print("---")
chat_val = "∞" if chat.get("unlimited") else str(chat.get("remaining", 0))
comp_val = "∞" if comp.get("unlimited") else str(comp.get("remaining", 0))
print(f"  💬 Chat          {chat_val:>5}  |  font=Menlo size=12")
print(f"  ⌨️  Completions   {comp_val:>5}  |  font=Menlo size=12")
print("---")
print(f"  🔄 Resets: {reset_date}")
print("---")
print("↗ Open Copilot Settings | href=https://github.com/settings/copilot")
print("🔄 Refresh | refresh=true")
EOF
```

```bash
chmod +x ~/Library/Application\ Support/xbar/plugins/copilot-usage.60s.sh
```

### API 정보

- 엔드포인트: `GET https://api.github.com/copilot_internal/user` (비공식 내부 API, VS Code 클라이언트와 동일)
- 인증: GitHub Personal Access Token (`read:user` scope)
- 캐시: 60초 TTL (`/tmp/copilot_usage_cache.json`)
- 퍼센트 계산: `(entitlement - remaining) / entitlement * 100`

---

## 2. SK하이닉스 통합 플러그인

### 메뉴바 표시

SK하이닉스와 KODEX 레버리지를 **한 줄에 표시**. API 호출 1회로 두 종목을 동시에 처리.

예시: `SKH ₩2,864,000 ▼-1.9%  ·  KODEX ₩41,900 ▼-4.8%`

**메뉴바 색상 규칙**

| 조건 | 색상 |
|------|------|
| 둘 다 상승 | 🔴 `#FF453A` |
| 둘 다 하락 | 🔵 `#0A84FF` |
| 방향 혼합 | ⬜ `#8E8E93` |

### 스크립트

파일 경로: `~/Library/Application Support/xbar/plugins/sk-hynix-combined.1s.sh`

```bash
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
```

```bash
chmod +x ~/Library/Application\ Support/xbar/plugins/sk-hynix-combined.1s.sh
```

### API 정보

- 엔드포인트: `GET https://wts-info-api.tossinvest.com/api/v3/stock-prices?meta=true&productCodes=A000660,A0193T0`
- 인증: 불필요 (Origin/Referer 헤더만 필요)
- Toss 내부 종목 코드: `A000660` (SK하이닉스), `A0193T0` (KODEX SK하이닉스레버리지)
- 캐시: 없음 (3초마다 직접 호출, 두 종목 동시 처리)
- 세션 판단:
  - SK하이닉스 (주식): 프리마켓(08:00–08:30) / 동시호가(08:30–09:00) / 정규장(09:00–15:20) / 종가 동시호가(15:20–15:30) / 거래 없음(15:30–15:40) / 시간외 종가(15:40–16:00) / 시간외 단일가(16:00–18:00) / 애프터마켓(18:00–20:00, NXT)
  - KODEX ETF: 동시호가(08:30–09:00) / 정규장(09:00–15:20) / 종가 동시호가(15:20–15:30) / 거래 없음(15:30–15:40) / 시간외 종가(15:40–16:00) / 시간외 단일가(16:00–18:00) — NXT 불가
- 주요 응답 필드:

| 필드 | 설명 |
|------|------|
| `base` | 기준가 |
| `close` | 현재가 |
| `volume` | 거래량 |
| `tradingEnd` | 마지막 거래 종료 시각 (ISO 8601) |
| `nextTradingStart` | 다음 거래 시작 시각 (ISO 8601) |

---

## 갱신 주기 변경

파일명의 숫자가 xbar 실행 주기입니다. 주가 플러그인은 캐시가 없으므로 파일명만 변경하면 됩니다.

```bash
# 예: 통합 플러그인을 5초로 변경
mv ~/Library/Application\ Support/xbar/plugins/sk-hynix-combined.1s.sh \
   ~/Library/Application\ Support/xbar/plugins/sk-hynix-combined.5s.sh
```

> Copilot 플러그인은 캐시(`CACHE_TTL`)를 사용하므로 파일명 변경 시 스크립트 내 `CACHE_TTL`도 함께 수정.

---

## macOS 업데이트 후 사라질 경우

1. xbar 재실행: `open /Applications/xbar.app`
2. **시스템 설정 → 일반 → 로그인 항목**에서 xbar 체크

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 플러그인이 메뉴바에 없음 | 실행 권한 없음 | `chmod +x <파일경로>` |
| `⚠️ Copilot Error` | GitHub 토큰 만료 또는 오입력 | 토큰 재발급 후 스크립트 수정 |
| `⚠️ Error` / `⚠️ Parse Error` (주가) | Toss API 응답 이상 | 잠시 후 Refresh All |
| `python3 not found` | python3 미설치 | `brew install python3` |
| 가격이 멈춤 (주말/장마감) | 거래 시간 외 또는 데이터 반영 지연 | 장 시작 후 Refresh All |

---

## 주의사항

- **Copilot 플러그인**: `copilot_internal` API는 비공식 내부 엔드포인트. GitHub 정책 변경 시 예고 없이 중단될 수 있음
- **주가/ETF 플러그인**: `wts-info-api.tossinvest.com`은 Toss Invest 비공식 API. 인증 불필요하나 서비스 정책 변경 시 중단 가능
