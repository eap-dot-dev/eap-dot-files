# Cross-Platform Dotfiles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure the macOS-only dotfiles repo into a cross-platform system supporting macOS, Linux (apt + dnf), and Windows (native + WSL).

**Architecture:** Bash + TOML with zero external dependencies. Two entry points (`setup.sh` for Unix, `setup.ps1` for Windows). A shared function library (`lib/`) handles logging, platform detection, package management, and symlinks. A single `packages.toml` manifest declares all tools with per-platform keys.

**Tech Stack:** Bash, PowerShell (Windows only), TOML (parsed with awk/grep)

---

### Task 1: Create `lib/log.sh` — Logging Foundation

**Files:**
- Create: `lib/log.sh`

**Step 1: Create the lib directory and log.sh**

```bash
#!/usr/bin/env bash
# lib/log.sh — Colored logging and error handling
# Source this file; do not execute directly.

_LOG_RED='\033[0;31m'
_LOG_GREEN='\033[0;32m'
_LOG_YELLOW='\033[0;33m'
_LOG_BLUE='\033[0;34m'
_LOG_NC='\033[0m'

log_info()  { printf "${_LOG_BLUE}[INFO]${_LOG_NC} %s\n" "$*"; }
log_ok()    { printf "${_LOG_GREEN}[  OK]${_LOG_NC} %s\n" "$*"; }
log_warn()  { printf "${_LOG_YELLOW}[WARN]${_LOG_NC} %s\n" "$*"; }
log_error() { printf "${_LOG_RED}[ ERR]${_LOG_NC} %s\n" "$*" >&2; }

run_or_die() {
  local description="$1"
  shift
  log_info "$description"
  if "$@"; then
    log_ok "$description"
  else
    log_error "$description failed (exit code $?)"
    exit 1
  fi
}
```

**Step 2: Verify it sources cleanly**

Run: `bash -c 'source lib/log.sh && log_info "test" && log_ok "test" && log_warn "test" && log_error "test"'`
Expected: Four lines with colored prefixes, no errors.

**Step 3: Commit**

```bash
git add lib/log.sh
git commit -m "feat: add lib/log.sh — colored logging and error handling"
```

---

### Task 2: Create `lib/platform.sh` — Platform Detection

**Files:**
- Create: `lib/platform.sh`

**Step 1: Create platform.sh**

```bash
#!/usr/bin/env bash
# lib/platform.sh — OS, distro, and architecture detection
# Source this file; do not execute directly.
# Sets: DOTFILES_OS, DOTFILES_DISTRO, DOTFILES_PKG, DOTFILES_IS_WSL, DOTFILES_ARCH

DOTFILES_OS=""
DOTFILES_DISTRO=""
DOTFILES_PKG=""
DOTFILES_IS_WSL=false
DOTFILES_ARCH=""

_detect_platform() {
  local kernel
  kernel="$(uname -s)"

  case "$kernel" in
    Darwin)
      DOTFILES_OS="macos"
      DOTFILES_PKG="brew"
      ;;
    Linux)
      DOTFILES_OS="linux"
      # Detect WSL
      if [[ -f /proc/version ]] && grep -qi "microsoft\|WSL" /proc/version; then
        DOTFILES_IS_WSL=true
      fi
      # Detect distro
      if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "${ID:-}" in
          ubuntu|debian|linuxmint|pop)
            DOTFILES_DISTRO="${ID}"
            DOTFILES_PKG="apt"
            ;;
          fedora|rhel|centos|rocky|alma)
            DOTFILES_DISTRO="${ID}"
            DOTFILES_PKG="dnf"
            ;;
          *)
            # Check ID_LIKE for derivatives
            case "${ID_LIKE:-}" in
              *debian*|*ubuntu*) DOTFILES_DISTRO="${ID}"; DOTFILES_PKG="apt" ;;
              *fedora*|*rhel*)   DOTFILES_DISTRO="${ID}"; DOTFILES_PKG="dnf" ;;
            esac
            ;;
        esac
      fi
      ;;
    *)
      log_error "Unsupported OS: $kernel"
      exit 1
      ;;
  esac

  DOTFILES_ARCH="$(uname -m)"
}

_detect_platform
```

**Step 2: Verify on current platform**

Run: `bash -c 'source lib/log.sh && source lib/platform.sh && echo "OS=$DOTFILES_OS DISTRO=$DOTFILES_DISTRO PKG=$DOTFILES_PKG WSL=$DOTFILES_IS_WSL ARCH=$DOTFILES_ARCH"'`
Expected on this WSL machine: `OS=linux DISTRO=ubuntu PKG=apt WSL=true ARCH=x86_64` (or similar)

**Step 3: Commit**

```bash
git add lib/platform.sh
git commit -m "feat: add lib/platform.sh — OS, distro, and architecture detection"
```

---

### Task 3: Create `lib/symlinks.sh` — Idempotent Symlink Management

**Files:**
- Create: `lib/symlinks.sh`

**Step 1: Create symlinks.sh**

```bash
#!/usr/bin/env bash
# lib/symlinks.sh — Idempotent symlink creation with backup
# Source this file; do not execute directly.
# Requires: lib/log.sh sourced first.

DOTFILES_BACKUP_DIR="${HOME}/.dotfiles-backup"

link_file() {
  local src="$1"
  local dest="$2"

  # Resolve source to absolute path if relative
  if [[ "$src" != /* ]]; then
    src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  fi

  if [[ ! -e "$src" ]]; then
    log_error "Source does not exist: $src"
    return 1
  fi

  # Already correctly linked
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    log_warn "Already linked: $dest"
    return 0
  fi

  # Existing file or wrong symlink — back up
  if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
    mkdir -p "$DOTFILES_BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$dest").$(date +%Y%m%d%H%M%S)"
    mv "$dest" "${DOTFILES_BACKUP_DIR}/${backup_name}"
    log_warn "Backed up existing $dest to ${DOTFILES_BACKUP_DIR}/${backup_name}"
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  ln -s "$src" "$dest"
  log_ok "Linked: $dest -> $src"
}

link_config_dir() {
  local src="$1"
  local dest="$2"

  # Resolve source to absolute path if relative
  if [[ "$src" != /* ]]; then
    src="$(cd "$src" && pwd)"
  fi

  if [[ ! -d "$src" ]]; then
    log_error "Source directory does not exist: $src"
    return 1
  fi

  # Already correctly linked
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    log_warn "Already linked: $dest"
    return 0
  fi

  # Existing dir or wrong symlink — back up
  if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
    mkdir -p "$DOTFILES_BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$dest").$(date +%Y%m%d%H%M%S)"
    mv "$dest" "${DOTFILES_BACKUP_DIR}/${backup_name}"
    log_warn "Backed up existing $dest to ${DOTFILES_BACKUP_DIR}/${backup_name}"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log_ok "Linked: $dest -> $src"
}
```

**Step 2: Verify with a temp file**

Run:
```bash
bash -c '
  source lib/log.sh && source lib/symlinks.sh
  echo "test" > /tmp/dotfiles-test-src
  link_file /tmp/dotfiles-test-src /tmp/dotfiles-test-dest
  ls -la /tmp/dotfiles-test-dest
  # Run again — should say "Already linked"
  link_file /tmp/dotfiles-test-src /tmp/dotfiles-test-dest
  rm -f /tmp/dotfiles-test-src /tmp/dotfiles-test-dest
'
```
Expected: First call prints `[  OK] Linked: ...`, second call prints `[WARN] Already linked: ...`

**Step 3: Commit**

```bash
git add lib/symlinks.sh
git commit -m "feat: add lib/symlinks.sh — idempotent symlink creation with backup"
```

---

### Task 4: Create `lib/packages.sh` — TOML-Driven Package Installation

**Files:**
- Create: `lib/packages.sh`

**Step 1: Create packages.sh**

This is the most complex library file. It parses the TOML manifest and installs packages using the detected platform's package manager.

```bash
#!/usr/bin/env bash
# lib/packages.sh — TOML-driven package installation
# Source this file; do not execute directly.
# Requires: lib/log.sh and lib/platform.sh sourced first.

# Parse packages.toml and install packages for the current platform.
# Reads keys matching $DOTFILES_PKG (brew/apt/dnf) and "cask" (macOS only).
install_packages_from_toml() {
  local toml_file="$1"

  if [[ ! -f "$toml_file" ]]; then
    log_error "Package manifest not found: $toml_file"
    return 1
  fi

  log_info "Reading package manifest: $toml_file"

  local current_section=""
  local pkg_name=""
  local install_count=0
  local skip_count=0

  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    # Section header: [category.name]
    if [[ "$line" =~ ^\[([a-zA-Z0-9._-]+)\]$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi

    # Skip special sections (handled by their own scripts)
    case "$current_section" in
      mas-apps|asdf-runtimes|pnpm-globals) continue ;;
    esac

    # Key = "value" line
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Match against current platform's package manager
      if [[ "$key" == "$DOTFILES_PKG" ]] || { [[ "$key" == "cask" ]] && [[ "$DOTFILES_OS" == "macos" ]]; }; then
        if is_pkg_installed "$value" "$key"; then
          log_warn "Already installed: $value"
          ((skip_count++))
        else
          install_pkg "$key" "$value"
          ((install_count++))
        fi
      fi
    fi
  done < "$toml_file"

  log_ok "Packages: $install_count installed, $skip_count already present"
}

is_pkg_installed() {
  local pkg="$1"
  local manager="${2:-$DOTFILES_PKG}"

  case "$manager" in
    brew)
      brew list --formula "$pkg" &>/dev/null 2>&1
      ;;
    cask)
      brew list --cask "$pkg" &>/dev/null 2>&1
      ;;
    apt)
      dpkg -s "$pkg" &>/dev/null 2>&1
      ;;
    dnf)
      rpm -q "$pkg" &>/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

install_pkg() {
  local manager="$1"
  local pkg="$2"

  log_info "Installing $pkg via $manager..."
  case "$manager" in
    brew)
      brew install "$pkg"
      ;;
    cask)
      brew install --cask "$pkg"
      ;;
    apt)
      sudo apt-get install -y "$pkg"
      ;;
    dnf)
      sudo dnf install -y "$pkg"
      ;;
    *)
      log_error "Unknown package manager: $manager"
      return 1
      ;;
  esac
}

ensure_brew() {
  if command -v brew &>/dev/null; then
    log_warn "Homebrew already installed"
    return 0
  fi
  log_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Ensure brew is in PATH for this session
  if [[ -d /opt/homebrew/bin ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /usr/local/bin ]] && [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  log_ok "Homebrew installed"
}

ensure_apt_repo() {
  local repo_name="$1"
  case "$repo_name" in
    github-cli)
      if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
        log_info "Adding GitHub CLI apt repository..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update
      fi
      ;;
    vscode)
      if [[ ! -f /etc/apt/sources.list.d/vscode.list ]]; then
        log_info "Adding VS Code apt repository..."
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo dd of=/usr/share/keyrings/packages.microsoft.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt-get update
      fi
      ;;
  esac
}

ensure_dnf_repo() {
  local repo_name="$1"
  case "$repo_name" in
    github-cli)
      if ! dnf repolist | grep -q "github-cli"; then
        log_info "Adding GitHub CLI dnf repository..."
        sudo dnf install -y 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      fi
      ;;
    vscode)
      if ! dnf repolist | grep -q "code"; then
        log_info "Adding VS Code dnf repository..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        printf "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
        sudo dnf check-update || true
      fi
      ;;
  esac
}
```

**Step 2: Verify parsing works with a test TOML snippet**

Run:
```bash
bash -c '
  source lib/log.sh && source lib/platform.sh
  source lib/packages.sh
  # Just test the TOML reading — actual installs would need sudo
  echo "Platform: $DOTFILES_OS / $DOTFILES_PKG"
'
```
Expected: Prints the detected platform info, sources without error.

**Step 3: Commit**

```bash
git add lib/packages.sh
git commit -m "feat: add lib/packages.sh — TOML-driven cross-platform package installation"
```

---

### Task 5: Create `packages.toml` — Unified Package Manifest

**Files:**
- Create: `packages.toml`

**Step 1: Create packages.toml**

Translate the existing `Brewfile` plus cross-platform equivalents:

```toml
# packages.toml — Unified package manifest for all platforms
# Keys: brew, cask (macOS), apt (Debian/Ubuntu), dnf (Fedora/RHEL), winget (Windows)
# Missing keys = silently skipped on that platform.

# ─── CLI Tools ───────────────────────────────────────────────

[cli.git]
description = "Version control"
brew = "git"
apt = "git"
dnf = "git"

[cli.zsh]
description = "Z shell"
brew = "zsh"
apt = "zsh"
dnf = "zsh"

[cli.fzf]
description = "Fuzzy finder"
brew = "fzf"
apt = "fzf"
dnf = "fzf"

[cli.fd]
description = "Fast find alternative"
brew = "fd"
apt = "fd-find"
dnf = "fd-find"

[cli.bat]
description = "Cat with syntax highlighting"
brew = "bat"
apt = "bat"
dnf = "bat"

[cli.htop]
description = "Interactive process viewer"
brew = "htop"
apt = "htop"
dnf = "htop"

[cli.ripgrep]
description = "Fast grep alternative"
brew = "ripgrep"
apt = "ripgrep"
dnf = "ripgrep"
winget = "BurntSushi.ripgrep.MSVC"

[cli.coreutils]
description = "GNU core utilities"
brew = "coreutils"
# Already included on Linux

[cli.curl]
description = "HTTP client"
brew = "curl"
apt = "curl"
dnf = "curl"

[cli.gh]
description = "GitHub CLI"
brew = "gh"
apt = "gh"
dnf = "gh"
# Note: apt/dnf require repo setup (handled by ensure_apt_repo/ensure_dnf_repo)

[cli.mas]
description = "Mac App Store CLI"
brew = "mas"
# macOS only

# ─── Package / Runtime Managers ──────────────────────────────

[managers.asdf]
description = "Runtime version manager"
brew = "asdf"
# Linux: installed via git clone (handled in setup-asdf.sh)

[managers.pnpm]
description = "Fast Node.js package manager"
brew = "pnpm"
# Linux: installed via corepack or npm (handled in setup-pnpm.sh)

[managers.zinit]
description = "Zsh plugin manager"
brew = "zinit"
# Linux: installed via git clone (handled in setup-shell.sh)

# ─── GUI Applications ───────────────────────────────────────

[apps.ghostty]
description = "GPU-accelerated terminal"
cask = "ghostty"
winget = "Ghostty.Ghostty"
# Linux: installed from package repo (handled in platform script)

[apps.vscode]
description = "Code editor"
cask = "visual-studio-code"
winget = "Microsoft.VisualStudioCode"
apt = "code"
dnf = "code"
# Note: apt/dnf require repo setup

[apps.firefox]
description = "Web browser"
cask = "firefox"
winget = "Mozilla.Firefox"
apt = "firefox"
dnf = "firefox"

[apps.webstorm]
description = "JetBrains IDE"
cask = "webstorm"
winget = "JetBrains.WebStorm"

[apps.1password]
description = "Password manager"
cask = "1password"
winget = "AgileBits.1Password"

[apps.obsidian]
description = "Knowledge base"
cask = "obsidian"
winget = "Obsidian.Obsidian"

[apps.bettermouse]
description = "Mouse utility"
cask = "bettermouse"
# macOS only

[apps.betterdisplay]
description = "Display management"
cask = "betterdisplay"
# macOS only

[apps.bettertouchtool]
description = "Input customization"
cask = "bettertouchtool"
# macOS only

# ─── Fonts ───────────────────────────────────────────────────

[fonts.fira-code]
description = "Monospace programming font"
cask = "font-fira-code"
# Windows/Linux: handled by platform font scripts

[fonts.hack-nerd-font]
description = "Nerd font with icons"
cask = "font-hack-nerd-font"
# Windows/Linux: handled by platform font scripts

# ─── Special Sections (handled by dedicated scripts) ─────────

[mas-apps]
# Mac App Store apps (macOS only, installed via mas)
bettersnaptool = "417375580"
drafts = "1435957248"
todoist = "585829637"

[asdf-runtimes]
# Runtime versions managed by ASDF
nodejs = "22"
python = "3"

[pnpm-globals]
# Packages installed globally via pnpm
claude-code = "@anthropic-ai/claude-code"
```

**Step 2: Verify the file is valid (parseable)**

Run: `bash -c 'source lib/log.sh && source lib/platform.sh && source lib/packages.sh && install_packages_from_toml packages.toml'`
Expected: Should list packages as "Already installed" or attempt installs (may fail without sudo, that's fine — confirms parsing works).

**Step 3: Commit**

```bash
git add packages.toml
git commit -m "feat: add packages.toml — unified cross-platform package manifest"
```

---

### Task 6: Migrate Config Files

**Files:**
- Move: `zsh/.zshrc` -> `config/zsh/.zshrc` (and fix hardcoded paths)
- Move: `zsh/.p10k.zsh` -> `config/zsh/.p10k.zsh`
- Move: `ghostty/config` -> split into `config/ghostty/config` + `config/ghostty/config.macos`
- Create: `config/ghostty/config.linux` (empty or minimal)
- Create: `config/ghostty/config.windows` (empty or minimal)
- Create: `config/secrets.sh.template`

**Step 1: Create config directory structure**

```bash
mkdir -p config/zsh config/ghostty config/git
```

**Step 2: Move and fix .zshrc**

Copy `zsh/.zshrc` to `config/zsh/.zshrc` and replace the hardcoded pnpm path:

Replace lines 69-75 of the current `zsh/.zshrc`:
```bash
# pnpm
export PNPM_HOME="/Users/epanahi/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
```

With:
```bash
# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
```

Also replace the `ls` alias on the last line:
```bash
# Current (macOS-only -G flag):
alias ls='ls -G'

# Replace with:
if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi
```

**Step 3: Move .p10k.zsh**

```bash
cp zsh/.p10k.zsh config/zsh/.p10k.zsh
```

**Step 4: Split ghostty config**

Create `config/ghostty/config` (shared settings only):
```
# ---------- Theme ----------
# theme = "JetBrains Darcula"

# ---------- Fonts ----------
font-family = "JetBrains Mono"
font-size = 16

# ---------- Window ----------
window-padding-x = 8
window-padding-y = 8

# ---------- Keybindings ----------
keybind = shift+enter=text:\x1b\r
```

Create `config/ghostty/config.macos` (macOS-only):
```
# ---------- macOS-specific ----------
macos-titlebar-style = transparent

# ---------- Quick Terminal ----------
keybind = global:cmd+backquote=toggle_quick_terminal
quick-terminal-position = center
quick-terminal-size = 90%,90%
quick-terminal-autohide = true
quick-terminal-animation-duration = 0
```

Create `config/ghostty/config.linux` (initially empty):
```
# ---------- Linux-specific ----------
# Add Linux-specific Ghostty settings here
```

Create `config/ghostty/config.windows` (initially empty):
```
# ---------- Windows-specific ----------
# Add Windows-specific Ghostty settings here
```

**Step 5: Create secrets template**

Create `config/secrets.sh.template`:
```bash
#!/usr/bin/env bash
# ~/.secrets.sh — Sensitive environment variables
# Copy this to ~/.secrets.sh and fill in your values.
# This file is sourced by .zshrc and should NOT be committed to git.

# Example:
# export ANTHROPIC_API_KEY="sk-ant-..."
# export GITHUB_TOKEN="ghp_..."
# export OPENAI_API_KEY="sk-..."
```

**Step 6: Commit**

```bash
git add config/
git commit -m "feat: migrate configs to config/ with cross-platform support

- Move zsh configs to config/zsh/, fix hardcoded pnpm path
- Split ghostty config into shared + platform-specific files
- Add secrets.sh.template for new machine guidance"
```

---

### Task 7: Create `scripts/common/` — Cross-Platform Setup Scripts

**Files:**
- Create: `scripts/common/setup-asdf.sh`
- Create: `scripts/common/setup-shell.sh`
- Create: `scripts/common/setup-pnpm.sh`

**Step 1: Create setup-asdf.sh**

Refactor from `asdf/init-asdf.sh` — add cross-platform ASDF installation (git clone on Linux), read versions from `packages.toml`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-asdf.sh — Install ASDF and configure runtimes
# Reads [asdf-runtimes] from packages.toml for version specs.
# Requires: lib/log.sh, lib/platform.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install ASDF on Linux if not present (macOS uses Homebrew)
if [[ "$DOTFILES_OS" == "linux" ]]; then
  if ! command -v asdf &>/dev/null; then
    if [[ -d "$HOME/.asdf" ]]; then
      log_warn "ASDF directory exists but not in PATH"
    else
      log_info "Installing ASDF via git..."
      git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.16.0
    fi
    # Source it for this session
    # shellcheck source=/dev/null
    . "$HOME/.asdf/asdf.sh"
  fi
fi

# Source ASDF if available
if command -v brew &>/dev/null && [[ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]]; then
  # shellcheck source=/dev/null
  . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
elif [[ -f "$HOME/.asdf/asdf.sh" ]]; then
  # shellcheck source=/dev/null
  . "$HOME/.asdf/asdf.sh"
fi

if ! command -v asdf &>/dev/null; then
  log_error "ASDF not found after installation attempt"
  exit 1
fi

# Plugin definitions
plugins=( nodejs python )
plugin_urls=(
  "https://github.com/asdf-vm/asdf-nodejs.git"
  "https://github.com/asdf-community/asdf-python.git"
)

# Read versions from packages.toml [asdf-runtimes] section
declare -A runtime_versions
in_asdf_section=false
while IFS= read -r line; do
  if [[ "$line" == "[asdf-runtimes]" ]]; then
    in_asdf_section=true
    continue
  fi
  if $in_asdf_section; then
    [[ "$line" =~ ^\[ ]] && break
    if [[ "$line" =~ ^([a-z]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      runtime_versions["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  fi
done < "$REPO_DIR/packages.toml"

for i in "${!plugins[@]}"; do
  plugin="${plugins[i]}"
  url="${plugin_urls[i]}"
  version="${runtime_versions[$plugin]:-}"

  if [[ -z "$version" ]]; then
    log_warn "No version specified for $plugin in packages.toml, skipping"
    continue
  fi

  # Add plugin if missing
  if ! asdf plugin list 2>/dev/null | grep -q "^${plugin}$"; then
    log_info "Adding ASDF plugin: $plugin"
    asdf plugin add "$plugin" "$url"
  fi

  # Resolve latest matching version
  local_version="$(asdf latest "$plugin" "$version" 2>/dev/null || echo "")"
  if [[ -z "$local_version" ]]; then
    log_error "Could not resolve version '$version' for $plugin"
    continue
  fi

  log_info "Installing $plugin $local_version..."
  asdf install "$plugin" "$local_version"
  asdf set -u "$plugin" "$local_version"
  log_ok "$plugin $local_version installed and set as global"
done

asdf reshim
log_ok "ASDF setup complete"
```

**Step 2: Create setup-shell.sh**

```bash
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
    # Ensure zsh is in /etc/shells
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
```

**Step 3: Create setup-pnpm.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/common/setup-pnpm.sh — Configure pnpm and install global packages
# Reads [pnpm-globals] from packages.toml.
# Requires: lib/log.sh, lib/platform.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install pnpm on Linux if not available
if ! command -v pnpm &>/dev/null; then
  if [[ "$DOTFILES_OS" == "linux" ]]; then
    log_info "Installing pnpm via corepack..."
    if command -v corepack &>/dev/null; then
      corepack enable
      corepack prepare pnpm@latest --activate
    else
      log_info "Installing pnpm via install script..."
      curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
  fi
fi

if ! command -v pnpm &>/dev/null; then
  log_warn "pnpm not found — skipping pnpm setup"
  exit 0
fi

# Configure pnpm home
if [[ "$DOTFILES_OS" == "macos" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
mkdir -p "${PNPM_HOME}/bin"

case ":$PATH:" in
  *":${PNPM_HOME}/bin:"*) ;;
  *) export PATH="${PNPM_HOME}/bin:${PATH}" ;;
esac

pnpm config set global-bin-dir "${PNPM_HOME}/bin" 2>/dev/null || true

# Read [pnpm-globals] from packages.toml and install
in_pnpm_section=false
while IFS= read -r line; do
  if [[ "$line" == "[pnpm-globals]" ]]; then
    in_pnpm_section=true
    continue
  fi
  if $in_pnpm_section; then
    [[ "$line" =~ ^\[ ]] && break
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      local_name="${BASH_REMATCH[1]}"
      pkg="${BASH_REMATCH[2]}"
      log_info "Installing pnpm global: $pkg"
      pnpm install -g "$pkg" || log_warn "Failed to install $pkg (non-fatal)"
    fi
  fi
done < "$REPO_DIR/packages.toml"

log_ok "pnpm setup complete"
```

**Step 4: Commit**

```bash
git add scripts/common/
git commit -m "feat: add scripts/common/ — cross-platform ASDF, shell, and pnpm setup"
```

---

### Task 8: Refactor `scripts/macos/` — macOS-Specific Scripts

**Files:**
- Create: `scripts/macos/setup-macos-init.sh` (refactored from `scripts/macos/macos-init.sh`)
- Create: `scripts/macos/setup-mas-apps.sh` (refactored from `scripts/macos/install-macos-apps.sh`)

**Step 1: Create setup-macos-init.sh**

Refactored version of `macos-init.sh` using `lib/` functions:

```bash
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
```

**Step 2: Create setup-mas-apps.sh**

Refactored from `install-macos-apps.sh`, reads from `packages.toml`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/macos/setup-mas-apps.sh — Install Mac App Store apps
# Reads [mas-apps] from packages.toml.
# Requires: lib/log.sh sourced by caller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v mas &>/dev/null; then
  log_warn "mas not installed — skipping Mac App Store apps"
  exit 0
fi

# Try to verify App Store access
if mas account &>/dev/null; then
  log_info "Signed into App Store"
else
  log_warn "mas signin not supported or not signed in — installs may fail"
fi

# Read [mas-apps] from packages.toml
in_mas_section=false
while IFS= read -r line; do
  if [[ "$line" == "[mas-apps]" ]]; then
    in_mas_section=true
    continue
  fi
  if $in_mas_section; then
    [[ "$line" =~ ^\[ ]] && break
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z_-]+)[[:space:]]*=[[:space:]]*\"([0-9]+)\" ]]; then
      app_name="${BASH_REMATCH[1]}"
      app_id="${BASH_REMATCH[2]}"
      if mas list | awk '{print $1}' | grep -q "^${app_id}$"; then
        log_warn "Already installed: $app_name ($app_id)"
      else
        log_info "Installing $app_name ($app_id)..."
        mas install "$app_id"
        log_ok "Installed $app_name"
      fi
    fi
  fi
done < "$REPO_DIR/packages.toml"

log_ok "Mac App Store apps done"
```

**Step 3: Commit**

```bash
git add scripts/macos/setup-macos-init.sh scripts/macos/setup-mas-apps.sh
git commit -m "feat: refactor scripts/macos/ — use lib functions and read from packages.toml"
```

---

### Task 9: Create `scripts/linux/` — Linux-Specific Scripts

**Files:**
- Create: `scripts/linux/setup-packages.sh`
- Create: `scripts/linux/setup-hostname.sh`

**Step 1: Create setup-packages.sh**

Handles apt/dnf repo setup for packages that need it (gh, code), then delegates to `lib/packages.sh`:

```bash
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
```

**Step 2: Create setup-hostname.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/linux/setup-hostname.sh — Set hostname on Linux
# Requires: lib/log.sh sourced by caller.

current_hostname="$(hostname)"
log_info "Current hostname: $current_hostname"

read -rp "Enter your desired hostname (or press Enter to keep '$current_hostname'): " NEW_HOSTNAME

if [[ -z "$NEW_HOSTNAME" ]] || [[ "$NEW_HOSTNAME" == "$current_hostname" ]]; then
  log_warn "Keeping current hostname"
  exit 0
fi

read -rp "Set hostname to '${NEW_HOSTNAME}'? [y/N] " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  log_warn "Hostname change cancelled"
  exit 0
fi

sudo hostnamectl set-hostname "$NEW_HOSTNAME"
log_ok "Hostname set to $NEW_HOSTNAME"
```

**Step 3: Commit**

```bash
git add scripts/linux/
git commit -m "feat: add scripts/linux/ — repo setup and hostname configuration"
```

---

### Task 10: Create `scripts/windows/` — Windows PowerShell Scripts

**Files:**
- Create: `scripts/windows/setup-winget.ps1`
- Create: `scripts/windows/setup-wsl.ps1`
- Create: `scripts/windows/setup-fonts.ps1`

**Step 1: Create setup-winget.ps1**

```powershell
# scripts/windows/setup-winget.ps1 — Install Windows apps via winget
# Reads winget keys from packages.toml

param(
    [string]$PackagesFile = "$PSScriptRoot\..\..\packages.toml"
)

Write-Host "[INFO] Installing Windows apps via winget..." -ForegroundColor Blue

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[ ERR] winget not found. Please install App Installer from the Microsoft Store." -ForegroundColor Red
    exit 1
}

# Parse packages.toml for winget keys
$content = Get-Content $PackagesFile -Raw
$lines = $content -split "`n"

foreach ($line in $lines) {
    if ($line -match '^\s*winget\s*=\s*"([^"]+)"') {
        $packageId = $Matches[1]

        # Check if already installed
        $installed = winget list --id $packageId 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $packageId) {
            Write-Host "[WARN] Already installed: $packageId" -ForegroundColor Yellow
        } else {
            Write-Host "[INFO] Installing: $packageId" -ForegroundColor Blue
            winget install --id $packageId --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[  OK] Installed: $packageId" -ForegroundColor Green
            } else {
                Write-Host "[ ERR] Failed to install: $packageId" -ForegroundColor Red
            }
        }
    }
}

Write-Host "[  OK] winget installations complete" -ForegroundColor Green
```

**Step 2: Create setup-wsl.ps1**

```powershell
# scripts/windows/setup-wsl.ps1 — Install and configure WSL

param(
    [string]$Distribution = "Ubuntu"
)

$StageFile = "$env:USERPROFILE\.dotfiles-setup-stage"

Write-Host "[INFO] Setting up WSL..." -ForegroundColor Blue

# Check if WSL is already installed
$wslInstalled = $false
try {
    $wslOutput = wsl --list --quiet 2>$null
    if ($wslOutput -match $Distribution) {
        $wslInstalled = $true
    }
} catch {}

if ($wslInstalled) {
    Write-Host "[WARN] WSL with $Distribution already installed" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Installing WSL with $Distribution..." -ForegroundColor Blue
    wsl --install --distribution $Distribution

    if ($LASTEXITCODE -ne 0) {
        # Likely needs a reboot
        "wsl-installed" | Out-File $StageFile -Force
        Write-Host "[WARN] Reboot required. After rebooting, run setup.ps1 again to continue." -ForegroundColor Yellow
        exit 0
    }
}

# Clone and run setup inside WSL
$repoPath = "~/Development/eap-dot-files"
Write-Host "[INFO] Checking for dotfiles repo inside WSL..." -ForegroundColor Blue

wsl -d $Distribution -- bash -c "
  if [ ! -d $repoPath ]; then
    mkdir -p ~/Development
    cd ~/Development
    git clone https://github.com/eap-dot-dev/eap-dot-files.git
  fi
"

Write-Host "[INFO] Running setup.sh inside WSL..." -ForegroundColor Blue
wsl -d $Distribution -- bash -c "cd $repoPath && bash setup.sh"

# Clean up stage file if it exists
if (Test-Path $StageFile) {
    Remove-Item $StageFile
}

Write-Host "[  OK] WSL setup complete" -ForegroundColor Green
```

**Step 3: Create setup-fonts.ps1**

```powershell
# scripts/windows/setup-fonts.ps1 — Install Nerd Fonts on Windows

Write-Host "[INFO] Installing Nerd Fonts..." -ForegroundColor Blue

$fontsToInstall = @(
    @{ Name = "Hack"; Url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" },
    @{ Name = "FiraCode"; Url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" }
)

$tempDir = "$env:TEMP\nerd-fonts"
$fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

foreach ($font in $fontsToInstall) {
    $zipPath = "$tempDir\$($font.Name).zip"
    $extractPath = "$tempDir\$($font.Name)"

    # Check if any font from this family is already installed
    $existingFonts = Get-ChildItem $fontsDir -Filter "*$($font.Name)*" -ErrorAction SilentlyContinue
    if ($existingFonts) {
        Write-Host "[WARN] $($font.Name) Nerd Font already installed" -ForegroundColor Yellow
        continue
    }

    Write-Host "[INFO] Downloading $($font.Name) Nerd Font..." -ForegroundColor Blue
    Invoke-WebRequest -Uri $font.Url -OutFile $zipPath

    Write-Host "[INFO] Extracting $($font.Name)..." -ForegroundColor Blue
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Install each .ttf file
    Get-ChildItem "$extractPath\*.ttf" | ForEach-Object {
        $destPath = Join-Path $fontsDir $_.Name
        Copy-Item $_.FullName $destPath -Force

        # Register the font
        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontName = $_.BaseName
        New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $destPath -PropertyType String -Force | Out-Null
    }

    Write-Host "[  OK] $($font.Name) Nerd Font installed" -ForegroundColor Green
}

# Cleanup
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[  OK] Font installation complete" -ForegroundColor Green
```

**Step 4: Commit**

```bash
git add scripts/windows/
git commit -m "feat: add scripts/windows/ — winget, WSL, and font setup for Windows"
```

---

### Task 11: Create `setup.sh` — Main Unix Entry Point

**Files:**
- Create: `setup.sh`

**Step 1: Create setup.sh**

```bash
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

echo ""
log_info "=== eap-dot-files setup ==="
log_info "OS: $DOTFILES_OS | Distro: $DOTFILES_DISTRO | Pkg: $DOTFILES_PKG | WSL: $DOTFILES_IS_WSL | Arch: $DOTFILES_ARCH"
echo ""

# ─── Step 1: Platform Package Manager ────────────────────────

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

# ─── Step 2: Install Packages ────────────────────────────────

install_packages_from_toml "$REPO_DIR/packages.toml"

# ─── Step 3: ASDF Runtimes ───────────────────────────────────

bash "$REPO_DIR/scripts/common/setup-asdf.sh"

# ─── Step 4: Shell Setup ─────────────────────────────────────

bash "$REPO_DIR/scripts/common/setup-shell.sh"

# ─── Step 5: pnpm Setup ──────────────────────────────────────

bash "$REPO_DIR/scripts/common/setup-pnpm.sh"

# ─── Step 6: Symlink Configs ─────────────────────────────────

log_info "Linking configuration files..."

link_file "$REPO_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
link_file "$REPO_DIR/config/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$REPO_DIR/config/secrets.sh.template" "$HOME/.secrets.sh.template"

# Ghostty: concatenate shared + platform-specific config
mkdir -p "$HOME/.config/ghostty"
GHOSTTY_CONFIG="$HOME/.config/ghostty/config"

{
  cat "$REPO_DIR/config/ghostty/config"
  echo ""
  if [[ -f "$REPO_DIR/config/ghostty/config.${DOTFILES_OS}" ]]; then
    cat "$REPO_DIR/config/ghostty/config.${DOTFILES_OS}"
  fi
} > "$GHOSTTY_CONFIG"
log_ok "Ghostty config written to $GHOSTTY_CONFIG"

# ─── Step 7: Platform-Specific Setup ─────────────────────────

if [[ "$DOTFILES_OS" == "macos" ]]; then
  if [[ -f "$REPO_DIR/scripts/macos/setup-mas-apps.sh" ]]; then
    bash "$REPO_DIR/scripts/macos/setup-mas-apps.sh"
  fi
fi

# ─── Step 8: GitHub CLI Auth ─────────────────────────────────

if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    log_warn "Already authenticated with GitHub"
  else
    log_info "Not authenticated with GitHub, running gh auth login..."
    gh auth login
  fi
fi

# ─── Done ─────────────────────────────────────────────────────

echo ""
log_ok "=== Setup complete! ==="
log_info "Restart your terminal or run: exec zsh"
```

**Step 2: Make executable**

```bash
chmod +x setup.sh
```

**Step 3: Verify it sources libs correctly**

Run: `bash -c 'source lib/log.sh && source lib/platform.sh && echo "libs load OK"'`
Expected: "libs load OK"

**Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: add setup.sh — main cross-platform entry point"
```

---

### Task 12: Create `setup.ps1` — Windows Entry Point

**Files:**
- Create: `setup.ps1`

**Step 1: Create setup.ps1**

```powershell
# setup.ps1 — Windows native entry point
# Installs Windows apps, fonts, and sets up WSL.

param(
    [switch]$SkipWSL,
    [switch]$SkipWinget,
    [switch]$SkipFonts
)

$ErrorActionPreference = "Stop"
$RepoDir = $PSScriptRoot

Write-Host ""
Write-Host "[INFO] === eap-dot-files Windows setup ===" -ForegroundColor Blue
Write-Host ""

# Check for admin rights (needed for WSL install)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SkipWSL) {
    Write-Host "[WARN] Not running as Administrator. WSL installation requires admin rights." -ForegroundColor Yellow
    Write-Host "[INFO] Re-launching as Administrator..." -ForegroundColor Blue
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit 0
}

# Step 1: winget packages
if (-not $SkipWinget) {
    & "$RepoDir\scripts\windows\setup-winget.ps1" -PackagesFile "$RepoDir\packages.toml"
}

# Step 2: Fonts
if (-not $SkipFonts) {
    & "$RepoDir\scripts\windows\setup-fonts.ps1"
}

# Step 3: WSL
if (-not $SkipWSL) {
    & "$RepoDir\scripts\windows\setup-wsl.ps1"
}

Write-Host ""
Write-Host "[  OK] === Windows setup complete! ===" -ForegroundColor Green
```

**Step 2: Commit**

```bash
git add setup.ps1
git commit -m "feat: add setup.ps1 — Windows native entry point"
```

---

### Task 13: Clean Up Old Files & Update README

**Files:**
- Delete: `bootstrap.sh`
- Delete: `Brewfile`
- Delete: `zsh/.zshrc`, `zsh/.p10k.zsh`, `zsh/` directory
- Delete: `ghostty/config`, `ghostty/` directory
- Delete: `asdf/init-asdf.sh`, `asdf/` directory
- Delete: `scripts/macos/macos-init.sh`
- Delete: `scripts/macos/install-macos-apps.sh`
- Modify: `README.md`

**Step 1: Remove old files**

```bash
git rm bootstrap.sh
git rm Brewfile
git rm -r zsh/
git rm -r ghostty/
git rm -r asdf/
git rm scripts/macos/macos-init.sh
git rm scripts/macos/install-macos-apps.sh
```

**Step 2: Update README.md**

Replace the entire README with updated content reflecting the new cross-platform structure:

```markdown
# eap-dot-files

Cross-platform dotfiles and machine setup for macOS, Linux, and Windows.

## Quick Start

### macOS (fresh machine)

**Step 1** — In Terminal.app (pre-bootstrap):
```bash
# Transfer or curl the init script, then:
bash scripts/macos/setup-macos-init.sh
```

**Step 2** — In Ghostty:
```bash
cd ~/Development/eap-dot-files
bash setup.sh
```

### Linux (Ubuntu/Debian or Fedora/RHEL)

```bash
git clone https://github.com/eap-dot-dev/eap-dot-files.git ~/Development/eap-dot-files
cd ~/Development/eap-dot-files
bash setup.sh
```

### Windows

```powershell
# In PowerShell (as Administrator):
git clone https://github.com/eap-dot-dev/eap-dot-files.git $HOME\Development\eap-dot-files
cd $HOME\Development\eap-dot-files
.\setup.ps1
```

This installs Windows apps via winget, sets up WSL, and runs `setup.sh` inside WSL automatically.

## What Gets Installed

All packages are declared in `packages.toml`. Each package lists per-platform identifiers — missing keys mean the package is skipped on that platform.

### CLI Tools
git, zsh, fzf, fd, bat, htop, ripgrep, curl, GitHub CLI

### GUI Apps
Ghostty, VS Code, WebStorm, Firefox, 1Password, Obsidian
macOS-only: BetterMouse, BetterDisplay, BetterTouchTool

### Runtimes (via ASDF)
Node.js, Python

### Global Packages (via pnpm)
Claude Code

## Structure

```
setup.sh              # Entry point (macOS/Linux/WSL)
setup.ps1             # Entry point (Windows)
packages.toml         # Unified package manifest
lib/                  # Shared bash functions
config/               # Dotfiles (symlinked to ~)
scripts/common/       # Cross-platform setup steps
scripts/macos/        # macOS-specific setup
scripts/linux/        # Linux-specific setup
scripts/windows/      # Windows PowerShell scripts
```

## Customization

- **Add/remove packages**: Edit `packages.toml`
- **Change runtime versions**: Edit `[asdf-runtimes]` in `packages.toml`
- **Shell config**: Edit `config/zsh/.zshrc`
- **Terminal config**: Edit `config/ghostty/config` (shared) or `config.macos`/`config.linux` (platform-specific)
- **Secrets**: Copy `~/.secrets.sh.template` to `~/.secrets.sh` and fill in values

## Re-running

Setup is idempotent — safe to run anytime to update or fix your setup. Already-installed packages are skipped, existing symlinks are preserved.
```

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove old files and update README for cross-platform structure"
```

---

### Task 14: End-to-End Verification

**Files:** None (verification only)

**Step 1: Verify lib/ loads on current platform (WSL/Linux)**

Run:
```bash
bash -c '
  set -euo pipefail
  source lib/log.sh
  source lib/platform.sh
  source lib/symlinks.sh
  source lib/packages.sh
  log_info "All libraries loaded successfully"
  log_info "OS=$DOTFILES_OS DISTRO=$DOTFILES_DISTRO PKG=$DOTFILES_PKG WSL=$DOTFILES_IS_WSL ARCH=$DOTFILES_ARCH"
'
```
Expected: All libraries source cleanly, platform detected correctly.

**Step 2: Verify packages.toml parsing**

Run:
```bash
bash -c '
  source lib/log.sh && source lib/platform.sh && source lib/packages.sh
  # Dry run — just parse, dont install (check output for package names)
  echo "Would install these packages for $DOTFILES_PKG:"
  while IFS= read -r line; do
    if [[ "$line" =~ ^${DOTFILES_PKG}[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      echo "  - ${BASH_REMATCH[1]}"
    fi
  done < packages.toml
'
```
Expected: Lists all apt (or dnf) packages from the TOML file.

**Step 3: Verify symlink functions**

Run:
```bash
bash -c '
  source lib/log.sh && source lib/symlinks.sh
  echo "test" > /tmp/dotfiles-verify-src
  link_file /tmp/dotfiles-verify-src /tmp/dotfiles-verify-dest
  link_file /tmp/dotfiles-verify-src /tmp/dotfiles-verify-dest  # Should say already linked
  readlink /tmp/dotfiles-verify-dest
  rm -f /tmp/dotfiles-verify-src /tmp/dotfiles-verify-dest
'
```
Expected: First call creates link, second says "Already linked", readlink shows source path.

**Step 4: Verify directory structure is correct**

Run: `find . -not -path './.git/*' -not -path './.git' | sort`
Expected: Should match the design document structure.

**Step 5: Commit any fixes**

If any issues found during verification, fix and commit.
