# eap-dot-files

Dotfiles + bootstrap setup for Zsh + ASDF (macOS / Linux)  
Cloned under `~/Development/eap-dot-files`

## What it does

- Installs Homebrew and requisite CLI / GUI apps using `Brewfile`  
- Installs and configures ASDF with plugins `nodejs` and `python` at specified versions  
- Sets global defaults via ASDF  
- Sets up Zsh with Powerlevel10k, autosuggestions, syntax highlighting, Ghostty integration  
- Uses `gh` CLI to help create / push the repo if needed  
- Provides a “pre-bootstrap” script for initial setup (before switching to Ghostty)  

## Usage

**Step 1: pre-bootstrap (in macOS Terminal)**  
```bash
# Assuming you’ve transferred the `scripts/macos/macos-init.sh` script
chmod +x macos-init.sh
./macos-init.sh
```

This will:
 - Ask for hostname and apply it
 - Install Homebrew, gh, Ghostty
 - Create ~/Development
 - Clone eap-dot-files into ~/Development/eap-dot-files

Then open Ghostty and run:

**Step 2: main bootstrap (inside Ghostty)**
```bash
cd ~/Development/eap-dot-files
chmod +x bootstrap.sh
./bootstrap.sh
```

That will:
 - Install / update Homebrew dependencies (via Brewfile)
 - Run ASDF initialization and install specified plugin versions
 - Symlink Zsh config files
 - Optionally create / push remote repo using gh
 - Set default shell, etc.

## Customization
 - Edit asdf/init-asdf.sh if you wish to change plugin versions or add plugins
 - Edit Zsh configs (zsh/.zshrc, zsh/custom-prompt.zsh, zsh/.p10k.zsh) to adjust prompt, plugin behavior, etc
 - Add or remove apps in Brewfile or in scripts/macos/install-macos-apps.sh

## Notes & caveats
 - Ensure build dependencies are present (e.g. for compiling Python / Node)
 - If ASDF plugin version install fails, script will abort (because of set -euo pipefail)
 - Verify Ghostty shell integration works (prompt redraw, cursor behavior)
 - You may need to run p10k configure after initial bootstrap
 