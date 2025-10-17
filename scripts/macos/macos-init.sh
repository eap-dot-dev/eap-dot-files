#!/usr/bin/env bash
######################
# Run this to set up a new Mac in the built-in terminal app
# Then you can open Ghostty and run the proper bootstrap script from the checked-out repo
######################

# Prompt for hostname
read -rp "Enter your desired hostname: " NEW_HOSTNAME
read -rp "You entered '${NEW_HOSTNAME}'. Is this correct? [y/N] " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  echo "Aborting. Please re-run with correct hostname."
  exit 1
fi

echo "Setting hostname to ${NEW_HOSTNAME}..."
sudo scutil --set ComputerName "$NEW_HOSTNAME"
sudo scutil --set HostName "$NEW_HOSTNAME"
sudo scutil --set LocalHostName "$NEW_HOSTNAME"
# Also set in /etc/hosts for localhost mapping (optional)
sudo sed -i '' "s/127\.0\.0\.1.*$/127.0.0.1 localhost ${NEW_HOSTNAME}/" /etc/hosts || true

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew in PATH
if [[ -d /opt/homebrew/bin ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [[ -d /usr/local/bin ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install gh CLI
if ! command -v gh &>/dev/null; then
  echo "Installing GitHub CLI..."
  brew install gh
fi

# Run gh auth login (interactive)
echo "Authenticating with GitHub..."
gh auth login

# Install Ghostty
if ! command -v ghostty &>/dev/null; then
  echo "Installing Ghostty..."
  brew install --cask ghostty
fi

# Create ~/Development if absent
DEV_DIR="${HOME}/Development"
if [ ! -d "$DEV_DIR" ]; then
  echo "Creating $DEV_DIR"
  mkdir -p "$DEV_DIR"
fi

# Clone your eap-dot-files repo into ~/Development
cd "$DEV_DIR"
if [ ! -d "eap-dot-files" ]; then
  echo "Cloning repository into $DEV_DIR/eap-dot-files"
  gh repo clone eap-dot-dev/eap-dot-files
else
  echo "Repository already exists at $DEV_DIR/eap-dot-files"
fi

echo "Pre-bootstrap done. Now launch Ghostty and run bootstrap inside it."