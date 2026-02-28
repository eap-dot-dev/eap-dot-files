#!/usr/bin/env bash
set -euo pipefail

# scripts/linux/setup-packages.sh — Pre-install steps for Linux packages
# Adds required third-party repos before package installation.
# Requires: lib/log.sh, lib/platform.sh, lib/packages.sh sourced by caller.

log_info "Setting up Linux package repositories..."

# Update package index
case "$DOTFILES_PKG" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y software-properties-common apt-transport-https wget gpg
    ensure_apt_repo "github-cli"
    ensure_apt_repo "vscode"
    sudo apt-get update -y
    ;;
  dnf)
    sudo dnf check-update || true
    ensure_dnf_repo "github-cli"
    ensure_dnf_repo "vscode"
    ;;
esac

log_ok "Linux package repositories configured"
