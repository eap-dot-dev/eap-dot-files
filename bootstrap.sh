#!/usr/bin/env bash

DEV_DIR="${HOME}/Development"
REPO_DIR="${DEV_DIR}/eap-dot-files"

echo "=== Bootstrapping eap-dot-files ==="

# Ensure Development directory
if [ ! -d "$DEV_DIR" ]; then
  echo "Creating $DEV_DIR"
  mkdir -p "$DEV_DIR"
fi

cd "$DEV_DIR"

# Clone or update repo
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning into $REPO_DIR"
  git clone https://github.com/eap-dot-dev/eap-dot-files.git "$REPO_DIR"
else
  echo "Updating existing repo"
  (cd "$REPO_DIR" && git pull)
fi

cd "$REPO_DIR"

# On macOS: ensure Xcode CLI
if [[ "$(uname)" == "Darwin" ]]; then
  if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi
fi

# Homebrew install & path setup
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [[ -d /opt/homebrew/bin ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [[ -d /usr/local/bin ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Brew dependencies
echo "Installing Brew dependencies..."
brew update
brew bundle --file="$REPO_DIR/Brewfile"

# ASDF setup
bash "$REPO_DIR/asdf/init-asdf.sh"

if command -v pnpm &>/dev/null; then
  echo "Configuring pnpm global bin directory"
  export PNPM_HOME="${HOME}/Library/pnpm"
  mkdir -p "${PNPM_HOME}/bin"
  case ":$PATH:" in
    *":${PNPM_HOME}/bin:"*) ;;
    *) export PATH="${PNPM_HOME}/bin:${PATH}" ;;
  esac
  pnpm config set global-bin-dir "${PNPM_HOME}/bin"
  
  echo "Installing Claude Code via pnpm"
  pnpm install -g @anthropic-ai/claude-code || echo "pnpm global install failed"
else
  echo "pnpm not found — skipping Claude Code install"
fi

# Symlink Zsh configs
echo "Linking Zsh config files..."
ln -sf "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$REPO_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

echo "Linking Ghostty config files"
mkdir -p ~/.config/ghostty
ln -sf "$REPO_DIR/ghostty/config" "$HOME/.config/ghostty/config"

# Now run your macOS apps script
if [[ -f "$REPO_DIR/scripts/macos/install-macos-apps.sh" ]]; then
  echo "Installing macOS apps (casks, App Store, etc.)"
  bash "$REPO_DIR/scripts/macos/install-macos-apps.sh"
fi

# GH CLI / remote setup
if ! gh auth status &>/dev/null; then
  echo "Not authenticated with GitHub, running gh auth login..."
  gh auth login
fi

echo "Bootstrap done. Restart terminal or run: exec zsh"