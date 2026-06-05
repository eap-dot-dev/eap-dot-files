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
