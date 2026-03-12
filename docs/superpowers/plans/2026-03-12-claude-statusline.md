# Claude Code Statusline Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single-line Claude Code statusline showing model, branch, worktree, cost, duration, context bar, tokens, and lines changed — installed cross-platform via setup.sh.

**Architecture:** A bash script (`statusline.sh`) reads JSON from stdin via `jq`, formats each segment with ANSI colors, and outputs a single line. Installation uses the existing `link_file` symlink system and merges settings into `~/.claude/settings.json` via `jq`.

**Tech Stack:** Bash, jq, git CLI, ANSI escape codes

**Spec:** `docs/superpowers/specs/2026-03-12-claude-statusline-design.md`

---

## Chunk 1: Statusline Script and Installation

### Task 1: Add jq to packages.toml

**Files:**
- Modify: `packages.toml` (between `[cli.curl]` and `[cli.gh]` blocks)

- [ ] **Step 1: Add jq entry to packages.toml**

Add between the `[cli.curl]` block (ends line 59) and the `[cli.gh]` block (starts line 61):

```toml
[cli.jq]
description = "JSON processor"
brew = "jq"
apt = "jq"
dnf = "jq"
```

- [ ] **Step 2: Verify the TOML is valid**

Run: `cat packages.toml | grep -A4 'cli.jq'`
Expected: The 4-line block above

- [ ] **Step 3: Commit**

```bash
git add packages.toml
git commit -m "feat: add jq to packages.toml for statusline support"
```

---

### Task 2: Create the statusline script

**Files:**
- Create: `config/claude/statusline.sh`

- [ ] **Step 1: Create config/claude directory and statusline.sh**

```bash
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
CYAN='\033[36m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

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
COST_FMT=$(printf '$%.2f' "$COST")

DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0')
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

IN_TOKENS=$(echo "$INPUT" | jq -r '.context_window.current_usage.input_tokens // 0')
OUT_TOKENS=$(echo "$INPUT" | jq -r '.context_window.current_usage.output_tokens // 0')
IN_FMT=$(format_tokens "$IN_TOKENS")
OUT_FMT=$(format_tokens "$OUT_TOKENS")

CONTEXT="${BAR_COLOR}${BAR} ${PCT}%${RESET} ${IN_FMT}/${OUT_FMT}"

# --- Segment 4: Impact +added/-removed ---
ADDED=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // 0')

IMPACT="${GREEN}+${ADDED}${RESET}/${RED}-${REMOVED}${RESET}"

# --- Output ---
SEP="${DIM}|${RESET}"
echo -e "${IDENTITY} ${SEP} ${SPEND} ${SEP} ${CONTEXT} ${SEP} ${IMPACT}"
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x config/claude/statusline.sh`

- [ ] **Step 3: Test locally with mock JSON**

Run:
```bash
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.12,"total_duration_ms":222000,"total_lines_added":15,"total_lines_removed":8},"context_window":{"used_percentage":25,"current_usage":{"input_tokens":12345,"output_tokens":3200}}}' | ./config/claude/statusline.sh
```
Expected: A colored single line resembling `[Opus] main | $0.12 3m42s | ▓▓▓░░░░░░░ 25% 12k/3k | +15/-8` (branch will show if run from inside a git repo)

- [ ] **Step 4: Test edge case — no jq available**

Run:
```bash
echo '{}' | PATH="" bash ./config/claude/statusline.sh
```
Expected: No output, exit 0 (graceful degradation)

- [ ] **Step 5: Test edge case — null/missing values**

Run:
```bash
echo '{"model":{"display_name":"Sonnet"}}' | ./config/claude/statusline.sh
```
Expected: `[Sonnet] | $0.00 0s | ░░░░░░░░░░ 0% 0/0 | +0/-0`

- [ ] **Step 6: Commit**

```bash
git add config/claude/statusline.sh
git commit -m "feat: add Claude Code statusline script"
```

---

### Task 3: Update setup.sh to install statusline

**Files:**
- Modify: `setup.sh` (inside Step 7: Symlink Configs, after line 83's `link_file` for secrets.sh.template, before the Ghostty config block at line 85)

- [ ] **Step 1: Add statusline symlink and settings merge to setup.sh**

Add after line 83 (`link_file ... secrets.sh.template`) and before the Ghostty config block (line 85):

```bash
# Claude Code statusline
link_file "$REPO_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"

# Merge statusLine config into ~/.claude/settings.json (preserves existing keys)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi
STATUSLINE_CONFIG='{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}'
MERGED=$(jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" <(echo "$STATUSLINE_CONFIG"))
echo "$MERGED" > "$CLAUDE_SETTINGS"
log_ok "Claude Code statusline configured"
```

- [ ] **Step 2: Verify setup.sh syntax**

Run: `bash -n setup.sh`
Expected: No output (no syntax errors)

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: install Claude Code statusline via setup.sh"
```

---

### Task 4: End-to-end verification

- [ ] **Step 1: Run the statusline script with full mock data including worktree**

Run:
```bash
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0.45,"total_duration_ms":728000,"total_lines_added":120,"total_lines_removed":34},"context_window":{"used_percentage":68,"current_usage":{"input_tokens":45000,"output_tokens":9200}},"worktree":{"name":"my-feature"}}' | ./config/claude/statusline.sh
```
Expected: `[Opus] main (my-feature) | $0.45 12m8s | ▓▓▓▓▓▓▓░░░ 68% 45k/9k | +120/-34` (branch from `git branch --show-current`, worktree name in parens; 68% → 7 filled blocks via rounding)

- [ ] **Step 2: Test high context (red bar)**

Run:
```bash
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.23,"total_duration_ms":1695000,"total_lines_added":85,"total_lines_removed":12},"context_window":{"used_percentage":92,"current_usage":{"input_tokens":180000,"output_tokens":22000}}}' | ./config/claude/statusline.sh
```
Expected: `[Opus] | $1.23 28m15s | ▓▓▓▓▓▓▓▓▓░ 92% 180k/22k | +85/-12` (bar should be red)

- [ ] **Step 3: Test duration over 1 hour**

Run:
```bash
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":3.45,"total_duration_ms":4500000,"total_lines_added":230,"total_lines_removed":45},"context_window":{"used_percentage":78,"current_usage":{"input_tokens":150000,"output_tokens":18000}}}' | ./config/claude/statusline.sh
```
Expected: `[Opus] | $3.45 1h15m | ▓▓▓▓▓▓▓▓░░ 78% 150k/18k | +230/-45`

- [ ] **Step 4: Test low token counts (no k abbreviation)**

Run:
```bash
echo '{"model":{"display_name":"Opus"},"cost":{"total_cost_usd":0,"total_duration_ms":5000,"total_lines_added":0,"total_lines_removed":0},"context_window":{"used_percentage":1,"current_usage":{"input_tokens":200,"output_tokens":50}}}' | ./config/claude/statusline.sh
```
Expected: `[Opus] | $0.00 5s | ░░░░░░░░░░ 1% 200/50 | +0/-0` (1% rounds to 0 filled bar blocks, but percentage text still shows 1%)
