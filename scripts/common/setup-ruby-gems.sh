#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-ruby-gems.sh — Install global Ruby gems
# Reads [ruby-gems] from packages.toml.
# Requires: lib/log.sh, lib/platform.sh sourced by caller.
# Requires: Ruby installed via ASDF (setup-asdf.sh runs first).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Ensure ASDF shims are in PATH (ruby is required)
if command -v brew &>/dev/null && [[ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]]; then
  . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
elif [[ -f "$HOME/.asdf/asdf.sh" ]]; then
  . "$HOME/.asdf/asdf.sh"
fi

if ! command -v ruby &>/dev/null; then
  log_warn "Ruby not found — skipping Ruby gems setup"
  exit 0
fi

if ! command -v gem &>/dev/null; then
  log_warn "gem not found — skipping Ruby gems setup"
  exit 0
fi

# Read [ruby-gems] from packages.toml and install
in_gems_section=false
while IFS= read -r line; do
  if [[ "$line" == "[ruby-gems]" ]]; then
    in_gems_section=true
    continue
  fi
  if $in_gems_section; then
    [[ "$line" =~ ^\[ ]] && break
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      pkg="${BASH_REMATCH[2]}"
      if gem list -i "^${pkg}$" &>/dev/null; then
        log_warn "Already installed: $pkg"
      else
        log_info "Installing Ruby gem: $pkg"
        gem install "$pkg" --no-document || log_warn "Failed to install $pkg (non-fatal)"
      fi
    fi
  fi
done < "$REPO_DIR/packages.toml"

asdf reshim ruby 2>/dev/null || true
log_ok "Ruby gems setup complete"
