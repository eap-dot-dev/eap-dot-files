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

Early session (low tokens):
```
[Opus] main | $0.00 0s | ░░░░░░░░░░ 0% 200/50 | +0/-0
```

Long session (over 1 hour):
```
[Opus] main | $3.45 1h15m | ▓▓▓▓▓▓▓▓░░ 78% 150k/18k | +230/-45
```

## Segments

### 1. Identity

- **Model**: `model.display_name` from statusline JSON, wrapped in brackets, colored cyan
- **Branch**: from `git branch --show-current` (omitted if not in a git repo)
- **Worktree**: `worktree.name` from JSON, shown in parentheses and colored magenta (omitted when not in a worktree session). When in a worktree, the branch shown is from `git branch --show-current` (which reflects the worktree's checked-out branch)

### 2. Spend

- **Cost**: `cost.total_cost_usd`, formatted as `$X.XX`, colored yellow
- **Duration**: `cost.total_duration_ms`, formatted as:
  - Under 1 minute: `Xs` (e.g., `45s`)
  - 1-59 minutes: `XmYs` (e.g., `3m42s`)
  - 1 hour+: `XhYm` (e.g., `1h15m`)

### 3. Context

- **Progress bar**: 10-character bar using `▓` (filled) and `░` (empty), derived from `context_window.used_percentage`
  - Green (`\033[32m`): 0-69%
  - Yellow (`\033[33m`): 70-89%
  - Red (`\033[31m`): 90-100%
- **Percentage**: integer value (floored) from `context_window.used_percentage`
- **Tokens**: `context_window.current_usage.input_tokens` / `context_window.current_usage.output_tokens`
  - Under 1000: shown as-is (e.g., `200/50`)
  - 1000+: floored to integer `k` (e.g., 12345 -> `12k`, 1500 -> `1k`)

### 4. Impact

- **Lines added**: `cost.total_lines_added`, prefixed with `+`, colored green
- **Lines removed**: `cost.total_lines_removed`, prefixed with `-`, colored red

## File Layout

A new `config/claude/` directory will be created in the repo:

```
config/claude/
  statusline.sh      # The statusline script (executable)
```

### Settings strategy

The statusline config is added to `~/.claude/settings.json` (the user-level settings file). This file may already exist with other user preferences. Rather than symlinking a whole file (which would overwrite existing settings), `setup.sh` will:

1. Create `~/.claude/settings.json` if it doesn't exist (with `{}`)
2. Use `jq` to merge the `statusLine` key into the existing file, preserving all other keys

The statusline config to merge:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

This approach leaves the existing `.claude/settings.local.json` (project-level permissions) untouched.

### Installation in setup.sh

Add to the symlink/config step (Step 7) in `setup.sh`:

1. `link_file "$DOTFILES/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"` (using existing `link_file` from `lib/symlinks.sh`)
2. `chmod +x "$HOME/.claude/statusline.sh"`
3. Merge `statusLine` config into `~/.claude/settings.json` via `jq`

## Dependencies

- `jq` — for parsing JSON stdin in the script and for merging settings during install. Add to `packages.toml`:
  ```toml
  [cli.jq]
  description = "JSON processor"
  brew = "jq"
  apt = "jq"
  dnf = "jq"
  ```
- `git` — for branch detection. Already in `packages.toml`.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Before first API call | Tokens/cost show `$0.00 0s`, bar empty (`░░░░░░░░░░ 0%`) |
| No git repo | Branch segment omitted entirely |
| No worktree | Parenthetical omitted |
| Null JSON values | Handled with jq `// 0` fallbacks |
| jq not installed | Script degrades gracefully (print nothing or a static fallback) |
| Narrow terminal | Single line may truncate on right — most important info (model, branch) is leftmost |
| Duration over 1 hour | Displays as `XhYm` instead of `XmYs` |
| Token count under 1000 | Shown as raw number, not abbreviated |

## Color Scheme

All colors use ANSI escape codes (no emoji) for cross-platform terminal compatibility. Every colored segment is followed by a reset (`\033[0m`) to prevent color bleed.

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
| Reset | — | `\033[0m` |

## Non-Goals

- No emoji (terminal compatibility)
- No session summary/topic (not available in statusline JSON)
- No multi-line output (user preference for single line)
- No clickable links (not universally supported)
