#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Main entry point for macOS, Linux, and WSL setup
# Idempotent: safe to run repeatedly.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$REPO_DIR/lib/log.sh"
source "$REPO_DIR/lib/platform.sh"
source "$REPO_DIR/lib/symlinks.sh"
source "$REPO_DIR/lib/packages.sh"

# Export variables and functions for subscripts called via bash
export DOTFILES_OS DOTFILES_DISTRO DOTFILES_PKG DOTFILES_IS_WSL DOTFILES_ARCH
export DOTFILES_BACKUP_DIR
export -f log_info log_ok log_warn log_error run_or_die
export -f ensure_apt_repo ensure_dnf_repo ensure_brew
export -f install_packages_from_toml install_pkg is_pkg_installed
export -f link_file link_config_dir

echo ""
log_info "=== eap-dot-files setup ==="
log_info "OS: $DOTFILES_OS | Distro: $DOTFILES_DISTRO | Pkg: $DOTFILES_PKG | WSL: $DOTFILES_IS_WSL | Arch: $DOTFILES_ARCH"
echo ""

# --- Step 1: Platform Package Manager ------------------------------------

if [[ "$DOTFILES_OS" == "macos" ]]; then
  # Xcode CLI tools
  if ! xcode-select -p &>/dev/null; then
    log_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
    log_ok "Xcode CLI tools installed"
  fi

  ensure_brew
  brew update
fi

if [[ "$DOTFILES_OS" == "linux" ]]; then
  # Set up third-party repos before installing packages
  bash "$REPO_DIR/scripts/linux/setup-packages.sh"
fi

# --- Step 2: Install Packages --------------------------------------------

install_packages_from_toml "$REPO_DIR/packages.toml"

# --- Step 3: ASDF Runtimes -----------------------------------------------

bash "$REPO_DIR/scripts/common/setup-asdf.sh"

# --- Step 4: Shell Setup --------------------------------------------------

bash "$REPO_DIR/scripts/common/setup-shell.sh"

# --- Step 5: pnpm Setup --------------------------------------------------

bash "$REPO_DIR/scripts/common/setup-pnpm.sh"

# --- Step 6: Claude Code -------------------------------------------------

if [[ -x "$HOME/.local/bin/claude" ]]; then
  log_warn "Claude Code already installed"
else
  log_info "Installing Claude Code via native installer..."
  if curl -fsSL https://claude.ai/install.sh | bash; then
    log_ok "Claude Code installed"
  else
    log_warn "Claude Code install failed (network issue?) — install manually: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# --- Step 7: Symlink Configs ---------------------------------------------

log_info "Linking configuration files..."

link_file "$REPO_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
link_file "$REPO_DIR/config/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$REPO_DIR/config/secrets.sh.template" "$HOME/.secrets.sh.template"

# Ghostty: concatenate shared + platform-specific config
mkdir -p "$HOME/.config/ghostty"
GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
# Remove any existing file/symlink (may be dangling from old layout)
[[ -e "$GHOSTTY_CONFIG" || -L "$GHOSTTY_CONFIG" ]] && rm -f "$GHOSTTY_CONFIG"

{
  cat "$REPO_DIR/config/ghostty/config"
  echo ""
  if [[ -f "$REPO_DIR/config/ghostty/config.${DOTFILES_OS}" ]]; then
    cat "$REPO_DIR/config/ghostty/config.${DOTFILES_OS}"
  fi
} > "$GHOSTTY_CONFIG"
log_ok "Ghostty config written to $GHOSTTY_CONFIG"

# --- Step 8: Platform-Specific Setup --------------------------------------

if [[ "$DOTFILES_OS" == "macos" ]]; then
  if [[ -f "$REPO_DIR/scripts/macos/setup-mas-apps.sh" ]]; then
    bash "$REPO_DIR/scripts/macos/setup-mas-apps.sh"
  fi
fi

# --- Step 9: GitHub CLI Auth ----------------------------------------------

if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    log_warn "Already authenticated with GitHub"
  else
    log_info "Not authenticated with GitHub, running gh auth login..."
    gh auth login
  fi
fi

# --- Done -----------------------------------------------------------------

echo ""
log_ok "=== Setup complete! ==="
log_info "Restart your terminal or run: exec zsh"
