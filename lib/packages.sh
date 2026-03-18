#!/usr/bin/env bash
# lib/packages.sh — TOML-driven package installation
# Source this file; do not execute directly.
# Requires: lib/log.sh and lib/platform.sh sourced first.

# Add Homebrew taps declared in [brew-taps] section of packages.toml.
# Idempotent: already-tapped repos are skipped.
install_brew_taps_from_toml() {
  local toml_file="$1"
  [[ "$DOTFILES_PKG" != "brew" ]] && return 0

  local in_taps=false
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    if [[ "$line" =~ ^\[([a-zA-Z0-9._-]+)\]$ ]]; then
      [[ "${BASH_REMATCH[1]}" == "brew-taps" ]] && in_taps=true || in_taps=false
      continue
    fi

    if $in_taps && [[ "$line" =~ ^[a-zA-Z_-]+[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      local tap="${BASH_REMATCH[1]}"
      if brew tap | grep -qx "$tap"; then
        log_warn "Tap already added: $tap"
      else
        log_info "Adding Homebrew tap: $tap..."
        brew tap "$tap"
        log_ok "Tapped $tap"
      fi
    fi
  done < "$toml_file"
}

# Parse packages.toml and install packages for the current platform.
# Reads keys matching $DOTFILES_PKG (brew/apt/dnf) and "cask" (macOS only).
install_packages_from_toml() {
  local toml_file="$1"

  if [[ ! -f "$toml_file" ]]; then
    log_error "Package manifest not found: $toml_file"
    return 1
  fi

  if [[ -z "$DOTFILES_PKG" ]] || [[ -z "$DOTFILES_OS" ]]; then
    log_error "Platform not detected. Source lib/platform.sh first."
    return 1
  fi

  # Process brew taps first so tapped formulae are available
  install_brew_taps_from_toml "$toml_file"

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
      mas-apps|asdf-runtimes|pnpm-globals|brew-taps) continue ;;
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
          if install_pkg "$key" "$value"; then
            ((install_count++))
          else
            log_error "Failed to install $value — continuing"
          fi
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
      brew list --formula "$pkg" &>/dev/null
      ;;
    cask)
      brew list --cask "$pkg" &>/dev/null
      ;;
    apt)
      dpkg -s "$pkg" &>/dev/null
      ;;
    dnf)
      rpm -q "$pkg" &>/dev/null
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
      if ! brew install "$pkg"; then
        log_error "Failed to install $pkg via $manager"
        return 1
      fi
      ;;
    cask)
      if ! brew install --cask "$pkg"; then
        log_error "Failed to install $pkg via $manager"
        return 1
      fi
      ;;
    apt)
      if ! sudo apt-get install -y "$pkg"; then
        log_error "Failed to install $pkg via $manager"
        return 1
      fi
      ;;
    dnf)
      if ! sudo dnf install -y "$pkg"; then
        log_error "Failed to install $pkg via $manager"
        return 1
      fi
      ;;
    *)
      log_error "Unknown package manager: $manager"
      return 1
      ;;
  esac
  log_ok "Installed $pkg"
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
