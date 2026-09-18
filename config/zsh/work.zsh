#!/usr/bin/env zsh
# Work environment settings (non-secret)
# Secrets (tokens, PATs) go in ~/.secrets.sh which is gitignored.

# ——— AWS Defaults ———
export AWS_REGION="us-east-1"
export AWS_PROFILE="twl-tst"

# ——— Claude Code (via Bedrock) ———
# Uses twl-srd profile for Bedrock access
alias claude='AWS_PROFILE=twl-srd CLAUDE_CODE_USE_BEDROCK=1 command claude'
alias claude-auto='AWS_PROFILE=twl-srd CLAUDE_CODE_USE_BEDROCK=1 command claude --dangerously-skip-permissions'

# ——— Codex ———
# Bedrock is configured locally in ~/.codex/config.toml, not in dotfiles.
alias codex='command codex'
alias codex-auto='command codex --yolo'

# ——— Claude Code (via GLM / Vercel AI Gateway) ———
# Requires VERCEL_AI_API_KEY in ~/.secrets.sh
# Provider config: ~/.claude/glm-settings.json
#   claude  / claude-auto  -> Bedrock,  us.anthropic.claude-*
#   gclaude / gcclaude     -> GLM,      zai/glm-*
# Usage: gclaude [5.3|flash|fast|<full-model-id>] [claude args...]
function gclaude() {
  local m=zai/glm-5.3
  case "$1" in
    5.3|glm-5.3) m=zai/glm-5.3;      shift ;;
    flash)       m=zai/glm-5.3-flash; shift ;;
    fast)        m=zai/glm-5.3-fast;  shift ;;
    zai/*)       m="$1";              shift ;;
  esac
  if [[ -z "$VERCEL_AI_API_KEY" ]]; then
    print -u2 "gclaude: VERCEL_AI_API_KEY is not set (add it to ~/.secrets.sh)"
    return 1
  fi
  local -x ANTHROPIC_AUTH_TOKEN="$VERCEL_AI_API_KEY"
  command claude --settings ~/.claude/glm-settings.json --model "$m" "$@"
}
function gcclaude() { gclaude "$@" --dangerously-skip-permissions; }

# ——— Codex CLI (via GLM / Vercel AI Gateway) ———
# Requires VERCEL_AI_API_KEY in ~/.secrets.sh
# Provider config: inline via -c overrides (vercel provider, codex compat endpoint)
#   codex  / codex-auto  -> Bedrock,  us.openai.gpt-*
#   gcodex / gccodex     -> GLM,      zai/glm-*
# Usage: gcodex [5.3|flash|fast|<full-model-id>] [codex args...]
function gcodex() {
  local m=zai/glm-5.3
  case "$1" in
    5.3|glm-5.3) m=zai/glm-5.3;      shift ;;
    flash)       m=zai/glm-5.3-flash; shift ;;
    fast)        m=zai/glm-5.3-fast;  shift ;;
    zai/*)       m="$1";              shift ;;
  esac
  if [[ -z "$VERCEL_AI_API_KEY" ]]; then
    print -u2 "gcodex: VERCEL_AI_API_KEY is not set (add it to ~/.secrets.sh)"
    return 1
  fi
  AI_GATEWAY_API_KEY="$VERCEL_AI_API_KEY" \
  command codex \
    -c 'model_provider="vercel"' \
    -c 'model_providers.vercel.name="Vercel AI Gateway"' \
    -c 'model_providers.vercel.base_url="https://ai-gateway.vercel.sh/codex/v1"' \
    -c 'model_providers.vercel.env_key="AI_GATEWAY_API_KEY"' \
    -c 'model_providers.vercel.wire_api="responses"' \
    -c "model=\"$m\"" \
    "$@"
}
function gccodex() { gcodex "$@" --yolo; }
