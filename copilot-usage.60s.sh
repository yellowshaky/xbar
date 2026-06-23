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
