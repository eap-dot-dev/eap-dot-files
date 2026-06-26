#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Main entry point for macOS, Linux, and WSL setup
# Idempotent: safe to run repeatedly.
# Prompts for machine context (work/personal/server) at startup.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Interactive Context Selection -------------------------------------------

echo ""
echo "What kind of machine is this?"
echo "  1) work       — Work laptop (skip personal MCP servers, preserve Claude settings)"
echo "  2) personal   — Personal workstation (full setup incl. XcodeBuildMCP)"
echo "  3) server     — Headless server (no GUI apps, no Claude)"
echo ""
while true; do
  printf "Select [1-3]: "
  read -r choice
  case "$choice" in
    1) DOTFILES_CONTEXT="work";     DOTFILES_ROLE="workstation"; break ;;
    2) DOTFILES_CONTEXT="personal"; DOTFILES_ROLE="workstation"; break ;;
    3) DOTFILES_CONTEXT="server";   DOTFILES_ROLE="server";      break ;;
    *) echo "  Invalid choice, try again." ;;
  esac
done
echo ""

export DOTFILES_CONTEXT DOTFILES_ROLE

# Legacy flags (ignored but accepted for backward compat)
DOTFILES_HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role|--host) shift 2 ;;
    *) shift ;;
  esac
done
export DOTFILES_HOST

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
log_info "OS: $DOTFILES_OS | Distro: $DOTFILES_DISTRO | Pkg: $DOTFILES_PKG | WSL: $DOTFILES_IS_WSL | Arch: $DOTFILES_ARCH | Context: $DOTFILES_CONTEXT"
echo ""

# --- Step 0: Hostname (macOS, workstation/work) ---------------------------

if [[ "$DOTFILES_OS" == "macos" && "$DOTFILES_CONTEXT" != "server" ]]; then
  CURRENT_HOSTNAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
  printf 'Current hostname: %s\n' "$CURRENT_HOSTNAME"
  printf 'Enter new hostname (or press Enter to keep "%s"): ' "$CURRENT_HOSTNAME"
  read -r NEW_HOSTNAME
  if [[ -n "$NEW_HOSTNAME" && "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]]; then
    log_info "Setting hostname to ${NEW_HOSTNAME}..."
    sudo scutil --set ComputerName "$NEW_HOSTNAME"
    sudo scutil --set HostName "$NEW_HOSTNAME"
    sudo scutil --set LocalHostName "$NEW_HOSTNAME"
    sudo sed -i '' "s/127\.0\.0\.1.*$/127.0.0.1 localhost ${NEW_HOSTNAME}/" /etc/hosts || true
    log_ok "Hostname set to ${NEW_HOSTNAME}"
  else
    log_warn "Keeping hostname: ${CURRENT_HOSTNAME}"
  fi
elif [[ "$DOTFILES_OS" == "linux" && "$DOTFILES_CONTEXT" != "server" ]]; then
  bash "$REPO_DIR/scripts/linux/setup-hostname.sh"
fi

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

if [[ "$DOTFILES_CONTEXT" != "server" ]]; then
  # Remove any npm-global Claude Code — it predates the native installer and,
  # via the asdf node shim, shadows ~/.local/bin/claude in PATH. The native
  # install below is the supported one; the npm package must not linger.
  for npm_bin in npm pnpm; do
    if command -v "$npm_bin" &>/dev/null \
       && "$npm_bin" ls -g --depth=0 2>/dev/null | grep -q "@anthropic-ai/claude-code"; then
      log_info "Removing npm-global Claude Code installed via ${npm_bin}..."
      "$npm_bin" rm -g @anthropic-ai/claude-code &>/dev/null \
        && log_ok "Removed npm-global Claude Code (${npm_bin})" \
        || log_warn "Could not remove npm-global Claude Code (${npm_bin}) — remove manually"
    fi
  done
  command -v asdf &>/dev/null && asdf reshim nodejs &>/dev/null || true

  if [[ -x "$HOME/.local/bin/claude" ]]; then
    log_warn "Claude Code already installed (native)"
  else
    log_info "Installing Claude Code via native installer..."
    if curl -fsSL https://claude.ai/install.sh | bash; then
      log_ok "Claude Code installed"
    else
      log_warn "Claude Code install failed (network issue?) — install manually: curl -fsSL https://claude.ai/install.sh | bash"
    fi
  fi
fi

# --- Step 6b: Persist machine context -------------------------------------
# DOTFILES_CONTEXT only lives for the duration of this script. The interactive
# shell needs it too, so it can decide whether to source work-only config
# (work.zsh). Persist the choice to an XDG-conventional, sourceable env file.

CONTEXT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
mkdir -p "$CONTEXT_DIR"
cat > "$CONTEXT_DIR/context.env" <<EOF
# Written by eap-dot-files setup.sh — do not edit by hand.
# Re-run setup.sh to change this machine's context.
DOTFILES_CONTEXT=$DOTFILES_CONTEXT
DOTFILES_ROLE=$DOTFILES_ROLE
EOF
log_ok "Machine context persisted: $DOTFILES_CONTEXT -> $CONTEXT_DIR/context.env"

# --- Step 7: Symlink Configs ---------------------------------------------

log_info "Linking configuration files..."

link_file "$REPO_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
link_file "$REPO_DIR/config/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$REPO_DIR/config/secrets.sh.template" "$HOME/.secrets.sh.template"

# Claude Code statusline (universal)
if [[ "$DOTFILES_CONTEXT" != "server" ]]; then
  link_file "$REPO_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"

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
  else
    log_warn "jq not found — skipping Claude Code statusline merge"
  fi
fi

# Claude Code MCP servers (personal only — work machines manage their own)
if [[ "$DOTFILES_CONTEXT" == "personal" ]]; then
  if command -v jq &>/dev/null; then
    CLAUDE_USER_CONFIG="$HOME/.claude.json"
    if [[ ! -f "$CLAUDE_USER_CONFIG" ]]; then
      echo '{}' > "$CLAUDE_USER_CONFIG"
    fi
    MCP_CONFIG_SRC="$REPO_DIR/config/claude/mcp.json"
    if [[ -f "$MCP_CONFIG_SRC" ]]; then
      MERGED=$(jq -s '.[0] * .[1]' "$CLAUDE_USER_CONFIG" "$MCP_CONFIG_SRC")
      printf '%s\n' "$MERGED" > "$CLAUDE_USER_CONFIG"
      log_ok "Claude Code MCP servers configured (personal)"
    fi
  fi
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

if [[ "$DOTFILES_CONTEXT" == "server" ]] && [[ "$DOTFILES_OS" == "macos" ]]; then
  bash "$REPO_DIR/scripts/macos/setup-server.sh"

  log_info "Server-layer base setup complete."
  log_info "For per-host homelab config (Thunderbolt IPs, NFS, launchd),"
  log_info "run:  cd ~/Development/epanahi.cloud && bash bootstrap.sh"
fi

# --- Done -----------------------------------------------------------------

echo ""
log_ok "=== Setup complete! ==="
log_info "Restart your terminal or run: exec zsh"
