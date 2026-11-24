#!/usr/bin/env bash
input=$(cat)

# rate_limits は statusline の入力にしか現れず、Claude Code はどこにも保存しない。
# 外部ツールが読めるよう最新値を書き出す。複数セッションが同時に書くので tmp + mv で置き換える
RATE_LIMITS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
if RATE_LIMITS=$(echo "$input" | jq -ce '.rate_limits // empty' 2>/dev/null); then
  mkdir -p "$RATE_LIMITS_DIR" &&
    TMP=$(mktemp "$RATE_LIMITS_DIR/.rate-limits.XXXXXX") &&
    jq -c --argjson at "$(date +%s)" '{captured_at: $at} + .' <<<"$RATE_LIMITS" >"$TMP" &&
    mv -f "$TMP" "$RATE_LIMITS_DIR/rate-limits.json"
fi

MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100)); EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))
COST_FMT=$(printf '$%.2f' "$COST")

echo -e "${CYAN}[${MODEL}]${RESET} ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m${SECS}s"
