#!/usr/bin/env bash
# statusline.sh — Claude Code statusline script
# Receives JSON on stdin, outputs a single formatted line.
# See docs/superpowers/specs/2026-03-12-claude-statusline-design.md

# Bail gracefully if jq is not available
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)

# --- Colors ---
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RED=$'\033[31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# --- Segment 1: Identity [Model] branch (worktree) ---
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')

BRANCH=""
if git rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null)
fi

WORKTREE=$(echo "$INPUT" | jq -r '.worktree.name // empty')

IDENTITY="${CYAN}[${MODEL}]${RESET}"
if [[ -n "$BRANCH" ]]; then
  IDENTITY="${IDENTITY} ${BRANCH}"
fi
if [[ -n "$WORKTREE" ]]; then
  IDENTITY="${IDENTITY} ${MAGENTA}(${WORKTREE})${RESET}"
fi

# --- Segment 2: Spend $cost duration ---
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(LC_NUMERIC=C printf '$%.2f' "$COST")

DURATION_MS=$(echo "$INPUT" | jq -r '(.cost.total_duration_ms // 0) | floor')
DURATION_SEC=$((DURATION_MS / 1000))

if [[ $DURATION_SEC -ge 3600 ]]; then
  HOURS=$((DURATION_SEC / 3600))
  MINS=$(( (DURATION_SEC % 3600) / 60 ))
  DURATION_FMT="${HOURS}h${MINS}m"
elif [[ $DURATION_SEC -ge 60 ]]; then
  MINS=$((DURATION_SEC / 60))
  SECS=$((DURATION_SEC % 60))
  DURATION_FMT="${MINS}m${SECS}s"
else
  DURATION_FMT="${DURATION_SEC}s"
fi

SPEND="${YELLOW}${COST_FMT}${RESET} ${DURATION_FMT}"

# --- Segment 3: Context bar pct% in/out ---
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
PCT=${PCT:-0}

FILLED=$(( (PCT * 10 + 50) / 100 ))
EMPTY=$((10 - FILLED))

if [[ $PCT -ge 90 ]]; then
  BAR_COLOR="$RED"
elif [[ $PCT -ge 70 ]]; then
  BAR_COLOR="$YELLOW"
else
  BAR_COLOR="$GREEN"
fi

BAR=""
if [[ $FILLED -gt 0 ]]; then
  BAR=$(printf "%${FILLED}s" | tr ' ' '▓')
fi
if [[ $EMPTY -gt 0 ]]; then
  BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"
fi

# Token formatting: raw if <1000, Xk if >=1000
format_tokens() {
  local val=${1:-0}
  if [[ $val -ge 1000 ]]; then
    echo "$((val / 1000))k"
  else
    echo "$val"
  fi
}

IN_TOKENS=$(echo "$INPUT" | jq -r '(.context_window.current_usage.input_tokens // 0) | floor')
OUT_TOKENS=$(echo "$INPUT" | jq -r '(.context_window.current_usage.output_tokens // 0) | floor')
IN_FMT=$(format_tokens "$IN_TOKENS")
OUT_FMT=$(format_tokens "$OUT_TOKENS")

CONTEXT="${BAR_COLOR}${BAR} ${PCT}%${RESET} ${IN_FMT}/${OUT_FMT}"

# --- Segment 4: Impact +added/-removed ---
ADDED=$(echo "$INPUT" | jq -r '(.cost.total_lines_added // 0) | floor')
REMOVED=$(echo "$INPUT" | jq -r '(.cost.total_lines_removed // 0) | floor')

IMPACT="${GREEN}+${ADDED}${RESET}/${RED}-${REMOVED}${RESET}"

# --- Output ---
SEP="${DIM}|${RESET}"
echo "${IDENTITY} ${SEP} ${SPEND} ${SEP} ${CONTEXT} ${SEP} ${IMPACT}"
