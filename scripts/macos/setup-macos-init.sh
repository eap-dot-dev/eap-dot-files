#!/usr/bin/env bash
set -euo pipefail

# scripts/macos/setup-macos-init.sh — Pre-bootstrap for fresh macOS machines
# Run this in Terminal.app before opening Ghostty.
# This script is self-contained (sources its own libs).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_DIR/lib/log.sh"

# Set hostname
read -rp "Enter your desired hostname: " NEW_HOSTNAME
read -rp "You entered '${NEW_HOSTNAME}'. Is this correct? [y/N] " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  log_error "Aborting. Please re-run with correct hostname."
  exit 1
fi

log_info "Setting hostname to ${NEW_HOSTNAME}..."
sudo scutil --set ComputerName "$NEW_HOSTNAME"
sudo scutil --set HostName "$NEW_HOSTNAME"
sudo scutil --set LocalHostName "$NEW_HOSTNAME"
sudo sed -i '' "s/127\.0\.0\.1.*$/127.0.0.1 localhost ${NEW_HOSTNAME}/" /etc/hosts || true
log_ok "Hostname set to ${NEW_HOSTNAME}"

# Install Homebrew
if ! command -v brew &>/dev/null; then
  run_or_die "Installing Homebrew" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log_warn "Homebrew already installed"
fi

if [[ -d /opt/homebrew/bin ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d /usr/local/bin ]] && [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install gh CLI
if ! command -v gh &>/dev/null; then
  run_or_die "Installing GitHub CLI" brew install gh
else
  log_warn "GitHub CLI already installed"
fi

# GitHub auth
log_info "Authenticating with GitHub..."
gh auth login

# Install Ghostty
if ! brew list --cask ghostty &>/dev/null 2>&1; then
  run_or_die "Installing Ghostty" brew install --cask ghostty
else
  log_warn "Ghostty already installed"
fi

# Clone repo
DEV_DIR="${HOME}/Development"
mkdir -p "$DEV_DIR"
if [[ ! -d "${DEV_DIR}/eap-dot-files" ]]; then
  log_info "Cloning dotfiles repo..."
  cd "$DEV_DIR"
  gh repo clone eap-dot-dev/eap-dot-files
  log_ok "Repository cloned"
else
  log_warn "Repository already exists at ${DEV_DIR}/eap-dot-files"
fi

log_ok "Pre-bootstrap done. Now launch Ghostty and run: bash setup.sh"
