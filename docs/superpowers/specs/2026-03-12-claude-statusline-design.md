# Claude Code Statusline Design

## Overview

A single-line statusline for Claude Code that displays usage metrics, git context, and session impact. Designed as part of the eap-dot-files cross-platform dotfiles system, installed via `setup.sh` on every machine.

## Format

```
[Model] branch (worktree) | $cost duration | ▓▓▓░░░░░░░ pct% in/out | +added/-removed
```

### Examples

Standard session:
```
[Opus] main | $0.12 3m42s | ▓▓▓░░░░░░░ 25% 12k/3k | +15/-8
```

In a worktree:
```
[Sonnet] main (my-feature) | $0.45 12m8s | ▓▓▓▓▓▓▓░░░ 68% 45k/9k | +120/-34
```

High context usage:
```
[Opus] feat/auth | $1.23 28m15s | ▓▓▓▓▓▓▓▓▓░ 92% 180k/22k | +85/-12
```

No git repo:
```
[Opus] | $0.02 1m5s | ▓░░░░░░░░░ 5% 4k/1k | +0/-0
```

## Segments

### 1. Identity

- **Model**: `model.display_name` from statusline JSON, wrapped in brackets, colored cyan
- **Branch**: from `git branch --show-current` (omitted if not in a git repo)
- **Worktree**: `worktree.name` from JSON, shown in parentheses and colored magenta (omitted when not in a worktree session)

### 2. Spend

- **Cost**: `cost.total_cost_usd`, formatted as `$X.XX`, colored yellow
- **Duration**: `cost.total_duration_ms`, formatted as `XmYs` (e.g., `3m42s`)

### 3. Context

- **Progress bar**: 10-character bar using `▓` (filled) and `░` (empty), derived from `context_window.used_percentage`
  - Green (`\033[32m`): 0-69%
  - Yellow (`\033[33m`): 70-89%
  - Red (`\033[31m`): 90-100%
- **Percentage**: integer value from `context_window.used_percentage`
- **Tokens**: `context_window.current_usage.input_tokens` / `context_window.current_usage.output_tokens`, abbreviated with `k` suffix (e.g., `12k/3k`)

### 4. Impact

- **Lines added**: `cost.total_lines_added`, prefixed with `+`, colored green
- **Lines removed**: `cost.total_lines_removed`, prefixed with `-`, colored red

## File Layout

```
config/claude/
  statusline.sh      # The statusline script (executable)
  settings.json      # Claude Code settings with statusLine config
```

### settings.json

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

### Installation

`setup.sh` symlinks:
- `config/claude/statusline.sh` -> `~/.claude/statusline.sh`
- `config/claude/settings.json` -> `~/.claude/settings.json` (merged or symlinked alongside existing settings)

The script must be made executable (`chmod +x`).

## Dependencies

- `jq` — for parsing JSON stdin. Already a common CLI tool; should be added to `packages.toml` if not present.
- `git` — for branch detection. Already in `packages.toml`.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Before first API call | Tokens and cost show `$0.00 0m0s`, bar empty |
| No git repo | Branch segment omitted entirely |
| No worktree | Parenthetical omitted |
| Null JSON values | Handled with jq `// 0` fallbacks |
| jq not installed | Script should degrade gracefully (print raw model name or nothing) |
| Narrow terminal | Single line may truncate on right — most important info (model, branch) is leftmost |

## Color Scheme

All colors use ANSI escape codes (no emoji) for cross-platform terminal compatibility.

| Element | Color | ANSI Code |
|---------|-------|-----------|
| Model name | Cyan | `\033[36m` |
| Branch | Default | (none) |
| Worktree name | Magenta | `\033[35m` |
| Cost | Yellow | `\033[33m` |
| Duration | Default | (none) |
| Bar <70% | Green | `\033[32m` |
| Bar 70-89% | Yellow | `\033[33m` |
| Bar 90%+ | Red | `\033[31m` |
| Percentage | Same as bar | (matches bar) |
| Lines added | Green | `\033[32m` |
| Lines removed | Red | `\033[31m` |
| Pipe separators | Dim | `\033[2m` |

## Non-Goals

- No emoji (terminal compatibility)
- No session summary/topic (not available in statusline JSON)
- No multi-line output (user preference for single line)
- No clickable links (not universally supported)
