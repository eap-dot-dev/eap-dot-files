# Cross-Platform Dotfiles System Design

**Date**: 2026-02-27
**Status**: Approved

## Goal

Restructure the macOS-only dotfiles repo into a cross-platform system supporting macOS, Linux (apt + dnf), and Windows (native + WSL), with idempotent setup, a unified package manifest, and clean script organization.

## Decisions

- **Scripting**: Bash + TOML (zero external dependencies)
- **Shell**: Zsh + Powerlevel10k on all platforms; PowerShell only for Windows bootstrap
- **Terminal**: Ghostty on all platforms
- **Windows packages**: winget
- **Linux distros**: Ubuntu/Debian (apt) and Fedora/RHEL (dnf)
- **Package manifest**: Unified `packages.toml` with per-platform keys
- **Idempotent**: Safe to re-run anytime

## Directory Structure

```
eap-dot-files/
├── setup.sh                    # Entry point for macOS/Linux/WSL
├── setup.ps1                   # Entry point for Windows native
├── packages.toml               # Unified package manifest
│
├── lib/                        # Shared bash function library (sourced)
│   ├── platform.sh             #   OS/distro/arch detection
│   ├── packages.sh             #   Package install/update logic
│   ├── symlinks.sh             #   Idempotent symlink creation
│   └── log.sh                  #   Colored logging, error handling
│
├── config/                     # Dotfiles to symlink
│   ├── zsh/
│   │   ├── .zshrc
│   │   └── .p10k.zsh
│   ├── ghostty/
│   │   ├── config              #   Shared settings
│   │   ├── config.macos        #   macOS-only (titlebar, quick-terminal)
│   │   ├── config.linux
│   │   └── config.windows
│   ├── git/
│   │   └── .gitconfig          #   (optional)
│   └── secrets.sh.template     #   Documents expected secret vars
│
├── scripts/
│   ├── common/                 #   Cross-platform
│   │   ├── setup-asdf.sh
│   │   ├── setup-shell.sh
│   │   └── setup-pnpm.sh
│   ├── macos/
│   │   ├── setup-macos-init.sh
│   │   ├── setup-macos-defaults.sh
│   │   └── setup-mas-apps.sh
│   ├── linux/
│   │   ├── setup-packages.sh
│   │   └── setup-hostname.sh
│   └── windows/
│       ├── setup-wsl.ps1
│       ├── setup-winget.ps1
│       └── setup-fonts.ps1
│
└── docs/
    └── plans/
```

## Platform Detection

`lib/platform.sh` sets global variables on source:

| Variable | Values | Detection |
|----------|--------|-----------|
| `DOTFILES_OS` | `macos`, `linux` | `uname -s` |
| `DOTFILES_DISTRO` | `ubuntu`, `debian`, `fedora`, `rhel`, `""` | `/etc/os-release` |
| `DOTFILES_PKG` | `brew`, `apt`, `dnf` | Derived from OS + distro |
| `DOTFILES_IS_WSL` | `true`, `false` | `/proc/version` contains "microsoft" |
| `DOTFILES_ARCH` | `arm64`, `x86_64` | `uname -m` |

## setup.sh Flow

1. Source `lib/*.sh`
2. Detect platform
3. Run common setup:
   a. Install platform package manager if needed (Homebrew on macOS)
   b. Install packages from `packages.toml` for this platform
   c. Setup ASDF + runtimes
   d. Setup Zsh + zinit + plugins
   e. Setup pnpm + global packages
   f. Symlink all configs from `config/` to `~`
4. Run platform-specific setup:
   - macOS: system defaults, Mac App Store apps
   - Linux: hostname setup
   - WSL: WSL-specific tweaks
5. Authenticate GitHub CLI if not already
6. Print summary

## setup.ps1 Flow (Windows)

1. Check for Administrator privileges
2. Install winget packages (Ghostty, VS Code, 1Password, Firefox, etc.)
3. Install Nerd Fonts
4. Install/configure WSL (may require reboot — saves resume state)
5. Clone dotfiles repo inside WSL
6. Invoke `setup.sh` inside WSL
7. Print summary

## Package Manifest (packages.toml)

Packages declared with per-platform keys. Missing keys = silently skipped on that platform.

```toml
[cli.ripgrep]
description = "Fast grep alternative"
brew = "ripgrep"
apt = "ripgrep"
dnf = "ripgrep"
winget = "BurntSushi.ripgrep.MSVC"

[apps.bettermouse]
description = "Mouse utility"
cask = "bettermouse"
# macOS only — no other keys, skipped elsewhere
```

**Categories**: `cli`, `apps`, `fonts`, `managers` (organizational only).
**Special sections**: `mas-apps`, `asdf-runtimes`, `pnpm-globals` (handled by dedicated scripts).

## Shared Library (lib/)

### log.sh
- `log_info`, `log_ok`, `log_warn`, `log_error` — colored prefixed output
- `run_or_die "description" command args` — runs command, exits on failure

### platform.sh
- Sets detection globals on source (see table above)

### packages.sh
- `install_packages_from_toml "packages.toml"` — reads TOML, installs missing packages for current platform
- `is_pkg_installed`, `install_pkg`, `ensure_brew`, `ensure_apt_repo`, `ensure_dnf_repo`

### symlinks.sh
- `link_file "source" "target"` — idempotent symlink with backup of existing files to `~/.dotfiles-backup/`
- `link_config_dir "source" "target"` — same for directories

## Ghostty Config — Platform Split

```
config/ghostty/
├── config              # Shared (font, theme, keybindings)
├── config.macos        # macOS-only (titlebar, quick-terminal)
├── config.linux
└── config.windows
```

Symlink step concatenates shared + platform-specific into `~/.config/ghostty/config`.

## Zsh Config — Portability Fixes

- Replace hardcoded `/Users/epanahi/Library/pnpm` with `$HOME`-relative and platform-conditional paths
- Homebrew sourcing guarded behind macOS check
- Zinit already tries two paths (Homebrew or `~/.local/share/`) — works cross-platform

## Migration

| Current | New | Notes |
|---------|-----|-------|
| `bootstrap.sh` | `setup.sh` | Rewritten |
| `Brewfile` | `packages.toml` | Deleted |
| `zsh/` | `config/zsh/` | Moved |
| `ghostty/` | `config/ghostty/` | Split into shared + platform |
| `asdf/` | `scripts/common/setup-asdf.sh` | Moved |
| `scripts/macos/macos-init.sh` | `scripts/macos/setup-macos-init.sh` | Refactored |
| `scripts/macos/install-macos-apps.sh` | `scripts/macos/setup-mas-apps.sh` | Renamed |

Existing machines: re-running `setup.sh` updates symlinks, detects already-installed packages, no data loss.
