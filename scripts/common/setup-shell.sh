#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-shell.sh — Install Zsh plugins via zinit
# Requires: lib/log.sh, lib/platform.sh sourced by caller.

# Install zinit on Linux if not present (macOS uses Homebrew)
if [[ "$DOTFILES_OS" == "linux" ]]; then
  if ! command -v brew &>/dev/null || ! brew list zinit &>/dev/null 2>&1; then
    ZINIT_HOME="${HOME}/.local/share/zinit/zinit.zsh"
    if [[ ! -f "$ZINIT_HOME" ]]; then
      log_info "Installing zinit..."
      mkdir -p "$(dirname "$ZINIT_HOME")"
      git clone https://github.com/zdharma-continuum/zinit.git "$(dirname "$ZINIT_HOME")"
      log_ok "Zinit installed to ${ZINIT_HOME}"
    else
      log_warn "Zinit already installed"
    fi
  fi
fi

# Ensure zsh is the default shell
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  ZSH_PATH="$(command -v zsh)"
  if [[ -n "$ZSH_PATH" ]]; then
    log_info "Setting zsh as default shell..."
    if ! grep -q "$ZSH_PATH" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    chsh -s "$ZSH_PATH"
    log_ok "Default shell set to zsh"
  else
    log_error "zsh not found in PATH"
  fi
else
  log_warn "zsh is already the default shell"
fi
