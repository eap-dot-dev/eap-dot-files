# eap-dot-files

Cross-platform dotfiles and machine setup for macOS, Linux, and Windows.

## Quick Start

### macOS (fresh machine)

**Step 1** — In Terminal.app (pre-bootstrap):
```bash
# Copy/paste the contents of scripts/macos/setup-macos-init.sh into Terminal
# (the script is self-contained — no git or dependencies needed)
```

**Step 2** — In Ghostty:
```bash
cd ~/Development/eap-dot-files
bash setup.sh
```

### macOS Server (Mac Studios)

After the standard Quick Start above, re-run with the server role:
```bash
cd ~/Development/eap-dot-files
bash setup.sh --role server
```

This layers server-level base config on top of the workstation setup:
- Always-on power (sleep disabled, auto-restart)
- Remote access (SSH, Screen Sharing, ARD)
- Homelab `/etc/hosts` entries

Per-host network config (Thunderbolt static IPs, static routes, NFS mounts)
has moved to the sibling [`epanahi.cloud`](https://github.com/eap-dot-dev/epanahi.cloud)
repository — run its `bootstrap.sh` after this finishes for homelab
provisioning.

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
hosts/                # Per-host network config (server role)
```

## Customization

- **Add/remove packages**: Edit `packages.toml`
- **Change runtime versions**: Edit `[asdf-runtimes]` in `packages.toml`
- **Shell config**: Edit `config/zsh/.zshrc`
- **Terminal config**: Edit `config/ghostty/config` (shared) or `config.macos`/`config.linux` (platform-specific)
- **Secrets**: Copy `~/.secrets.sh.template` to `~/.secrets.sh` and fill in values
- **Per-host homelab config**: See the sibling `epanahi.cloud` repo; its `hosts/<hostname>.toml` holds TB IPs, NFS mounts, etc.

## Re-running

Setup is idempotent — safe to run anytime to update or fix your setup. Already-installed packages are skipped, existing symlinks are preserved.
