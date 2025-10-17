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

# Symlink Zsh configs
echo "Linking Zsh config files..."
ln -sf "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$REPO_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

# macOS app / shell tweaks
if [[ -f "$REPO_DIR/scripts/install-macos-apps.sh" ]]; then
  echo "Running macOS app install script..."
  bash "$REPO_DIR/scripts/install-macos-apps.sh"
fi

# GH CLI / remote setup
if ! gh auth status &>/dev/null; then
  echo "Not authenticated with GitHub, running gh auth login..."
  gh auth login
fi

echo "Bootstrap done. Restart terminal or run: exec zsh"