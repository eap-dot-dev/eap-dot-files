#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-pnpm.sh — Configure pnpm and install global packages
# Reads [pnpm-globals] from packages.toml.
# Requires: lib/log.sh, lib/platform.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install pnpm on Linux if not available
if ! command -v pnpm &>/dev/null; then
  if [[ "$DOTFILES_OS" == "linux" ]]; then
    log_info "Installing pnpm via corepack..."
    if command -v corepack &>/dev/null; then
      corepack enable
      corepack prepare pnpm@latest --activate
    else
      log_info "Installing pnpm via install script..."
      curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
  fi
fi

if ! command -v pnpm &>/dev/null; then
  log_warn "pnpm not found — skipping pnpm setup"
  exit 0
fi

# Configure pnpm home
if [[ "$DOTFILES_OS" == "macos" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
mkdir -p "${PNPM_HOME}/bin"

case ":$PATH:" in
  *":${PNPM_HOME}/bin:"*) ;;
  *) export PATH="${PNPM_HOME}/bin:${PATH}" ;;
esac

pnpm config set global-bin-dir "${PNPM_HOME}/bin" 2>/dev/null || true

# Read [pnpm-globals] from packages.toml and install
in_pnpm_section=false
while IFS= read -r line; do
  if [[ "$line" == "[pnpm-globals]" ]]; then
    in_pnpm_section=true
    continue
  fi
  if $in_pnpm_section; then
    [[ "$line" =~ ^\[ ]] && break
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      pkg="${BASH_REMATCH[2]}"
      log_info "Installing pnpm global: $pkg"
      pnpm install -g "$pkg" || log_warn "Failed to install $pkg (non-fatal)"
    fi
  fi
done < "$REPO_DIR/packages.toml"

log_ok "pnpm setup complete"
