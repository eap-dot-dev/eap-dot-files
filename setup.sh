#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Main entry point for macOS, Linux, and WSL setup
# Idempotent: safe to run repeatedly.
#
# NOTE: Per-host network provisioning (Thunderbolt IPs, NFS mounts, routes)
# has moved out of this repo. It now lives in the sibling epanahi.cloud
# repository. The --host flag is still accepted for backward compatibility
# but is now ignored for network provisioning. Use:
#
#   cd ~/Development/epanahi.cloud && bash bootstrap.sh
#
# to apply homelab-specific host config after this setup runs.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
DOTFILES_ROLE="workstation"
DOTFILES_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      [[ $# -lt 2 ]] && { echo "Error: --role requires a value" >&2; exit 1; }
      DOTFILES_ROLE="$2"
      shift 2
      ;;
    --host)
      [[ $# -lt 2 ]] && { echo "Error: --host requires a value" >&2; exit 1; }
      DOTFILES_HOST="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: setup.sh [--role workstation|server] [--host hostname]" >&2
      exit 1
      ;;
  esac
done

if [[ ! "$DOTFILES_ROLE" =~ ^(workstation|server)$ ]]; then
  echo "Error: unknown role '$DOTFILES_ROLE' (expected: workstation or server)" >&2
  exit 1
fi

export DOTFILES_ROLE DOTFILES_HOST

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
export -f install_brew_taps_from_toml install_packages_from_toml install_pkg is_pkg_installed
export -f link_file link_config_dir

echo ""
log_info "=== eap-dot-files setup ==="
log_info "OS: $DOTFILES_OS | Distro: $DOTFILES_DISTRO | Pkg: $DOTFILES_PKG | WSL: $DOTFILES_IS_WSL | Arch: $DOTFILES_ARCH | Role: $DOTFILES_ROLE | Host: ${DOTFILES_HOST:-none}"
if [[ -n "$DOTFILES_HOST" ]]; then
  log_warn "--host is deprecated; homelab network config has moved to the"
  log_warn "  sibling epanahi.cloud repo. Run 'bash bootstrap.sh' in that"
  log_warn "  repo after this setup completes."
fi
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

# --- Step 5b: Ruby Gems --------------------------------------------------

bash "$REPO_DIR/scripts/common/setup-ruby-gems.sh"

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

# Claude Code statusline
link_file "$REPO_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"

# Merge statusLine config into ~/.claude/settings.json (preserves existing keys)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi
if command -v jq &>/dev/null; then
  STATUSLINE_CONFIG='{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}'
  MERGED=$(jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" <(echo "$STATUSLINE_CONFIG"))
  printf '%s\n' "$MERGED" > "$CLAUDE_SETTINGS"
  log_ok "Claude Code statusline configured"

  # Merge MCP server config into ~/.claude.json (user-level, available in all projects)
  CLAUDE_USER_CONFIG="$HOME/.claude.json"
  if [[ ! -f "$CLAUDE_USER_CONFIG" ]]; then
    echo '{}' > "$CLAUDE_USER_CONFIG"
  fi
  MCP_CONFIG_SRC="$REPO_DIR/config/claude/mcp.json"
  if [[ -f "$MCP_CONFIG_SRC" ]]; then
    MERGED=$(jq -s '.[0] * .[1]' "$CLAUDE_USER_CONFIG" "$MCP_CONFIG_SRC")
    printf '%s\n' "$MERGED" > "$CLAUDE_USER_CONFIG"
    log_ok "Claude Code MCP servers configured"
  fi
else
  log_warn "jq not found — skipping Claude Code config merge (install jq and re-run)"
fi

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

# --- Step 10: Server Role Setup ---------------------------------------------

if [[ "$DOTFILES_ROLE" == "server" ]] && [[ "$DOTFILES_OS" == "macos" ]]; then
  bash "$REPO_DIR/scripts/macos/setup-server.sh"

  # Per-host network config has migrated to the epanahi.cloud repo.
  # Run its bootstrap (or per-role provision script) after this setup.
  log_info "Server-layer base setup complete."
  log_info "For per-host homelab config (Thunderbolt IPs, NFS, launchd),"
  log_info "run:  cd ~/Development/epanahi.cloud && bash bootstrap.sh"
fi

# --- Done -----------------------------------------------------------------

echo ""
log_ok "=== Setup complete! ==="
log_info "Restart your terminal or run: exec zsh"
