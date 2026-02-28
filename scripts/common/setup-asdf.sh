#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-asdf.sh — Install ASDF and configure runtimes
# Reads [asdf-runtimes] from packages.toml for version specs.
# Requires: lib/log.sh, lib/platform.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install ASDF on Linux if not present (macOS uses Homebrew)
if [[ "$DOTFILES_OS" == "linux" ]]; then
  if ! command -v asdf &>/dev/null; then
    if [[ -d "$HOME/.asdf" ]]; then
      log_warn "ASDF directory exists but not in PATH"
    else
      log_info "Installing ASDF via git..."
      git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.16.0
    fi
    # shellcheck source=/dev/null
    . "$HOME/.asdf/asdf.sh"
  fi
fi

# Source ASDF if available but not yet in session
if command -v asdf &>/dev/null; then
  : # already available
elif command -v brew &>/dev/null && [[ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]]; then
  # shellcheck source=/dev/null
  . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
elif [[ -f "$HOME/.asdf/asdf.sh" ]]; then
  # shellcheck source=/dev/null
  . "$HOME/.asdf/asdf.sh"
fi

if ! command -v asdf &>/dev/null; then
  log_error "ASDF not found after installation attempt"
  exit 1
fi

# Plugin definitions
plugins=( nodejs python )
plugin_urls=(
  "https://github.com/asdf-vm/asdf-nodejs.git"
  "https://github.com/asdf-community/asdf-python.git"
)

# Read versions from packages.toml [asdf-runtimes] section
declare -A runtime_versions
in_asdf_section=false
while IFS= read -r line; do
  if [[ "$line" == "[asdf-runtimes]" ]]; then
    in_asdf_section=true
    continue
  fi
  if $in_asdf_section; then
    [[ "$line" =~ ^\[ ]] && break
    if [[ "$line" =~ ^([a-z]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      runtime_versions["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  fi
done < "$REPO_DIR/packages.toml"

for i in "${!plugins[@]}"; do
  plugin="${plugins[i]}"
  url="${plugin_urls[i]}"
  version="${runtime_versions[$plugin]:-}"

  if [[ -z "$version" ]]; then
    log_warn "No version specified for $plugin in packages.toml, skipping"
    continue
  fi

  # Add plugin if missing
  if ! asdf plugin list 2>/dev/null | grep -q "^${plugin}$"; then
    log_info "Adding ASDF plugin: $plugin"
    asdf plugin add "$plugin" "$url"
  fi

  # Resolve latest matching version
  local_version="$(asdf latest "$plugin" "$version" 2>/dev/null || echo "")"
  if [[ -z "$local_version" ]]; then
    log_error "Could not resolve version '$version' for $plugin"
    continue
  fi

  log_info "Installing $plugin $local_version..."
  asdf install "$plugin" "$local_version"
  asdf set -u "$plugin" "$local_version"
  log_ok "$plugin $local_version installed and set as global"
done

asdf reshim
log_ok "ASDF setup complete"
