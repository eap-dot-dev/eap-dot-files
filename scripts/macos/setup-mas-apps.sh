#!/usr/bin/env bash
set -euo pipefail

# scripts/macos/setup-mas-apps.sh — Install Mac App Store apps
# Reads [mas-apps] from packages.toml.
# Requires: lib/log.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v mas &>/dev/null; then
  log_warn "mas not installed — skipping Mac App Store apps"
  exit 0
fi

# Try to verify App Store access
if mas account &>/dev/null; then
  log_info "Signed into App Store"
else
  log_warn "mas signin not supported or not signed in — installs may fail"
fi

# Read [mas-apps] from packages.toml
in_mas_section=false
while IFS= read -r line; do
  if [[ "$line" == "[mas-apps]" ]]; then
    in_mas_section=true
    continue
  fi
  if $in_mas_section; then
    [[ "$line" =~ ^\[ ]] && break
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([0-9]+)\" ]]; then
      app_name="${BASH_REMATCH[1]}"
      app_id="${BASH_REMATCH[2]}"
      if mas list | awk '{print $1}' | grep -q "^${app_id}$"; then
        log_warn "Already installed: $app_name ($app_id)"
      else
        log_info "Installing $app_name ($app_id)..."
        mas install "$app_id"
        log_ok "Installed $app_name"
      fi
    fi
  fi
done < "$REPO_DIR/packages.toml"

log_ok "Mac App Store apps done"
