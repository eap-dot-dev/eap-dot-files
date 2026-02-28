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
