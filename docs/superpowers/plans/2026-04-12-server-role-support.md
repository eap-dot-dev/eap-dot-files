# Server Role Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--role server --host <hostname>` support to `setup.sh` so the two Mac Studios (urza and mishra) can be provisioned as always-on headless servers using the same dotfiles framework.

**Architecture:** `setup.sh` gains two optional flags (`--role` and `--host`). The default role is `workstation` (current behavior, unchanged). When `--role server` is passed on macOS, `setup.sh` runs the standard workstation setup first, then calls a new `scripts/macos/setup-server.sh` for shared server config (pmset, SSH, /etc/hosts). When `--host <name>` is also passed, it reads `hosts/<name>.toml` and calls `scripts/macos/setup-host-network.sh` to apply per-host Thunderbolt IPs, static routes, NAS mounts, and sysctl settings.

**Tech Stack:** Bash, TOML (same parsing patterns as `packages.toml`), macOS `pmset`/`scutil`/`networksetup`/`route`/`mount_nfs` commands, LaunchDaemons (plist XML).

---

### Task 1: Add `--role` and `--host` argument parsing to `setup.sh`

**Files:**
- Modify: `setup.sh:1-9` (add arg parsing before library sourcing)

- [ ] **Step 1: Add argument parsing at the top of setup.sh**

After the `set -euo pipefail` and `REPO_DIR` lines, before `source` statements, add:

```bash
# Parse arguments
DOTFILES_ROLE="workstation"
DOTFILES_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      DOTFILES_ROLE="$2"
      shift 2
      ;;
    --host)
      DOTFILES_HOST="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: setup.sh [--role workstation|server] [--host hostname]" >&2
      exit 1
      ;;
  esac
done

export DOTFILES_ROLE DOTFILES_HOST
```

- [ ] **Step 2: Add server role dispatch at the end of setup.sh**

After the existing Step 9 (GitHub CLI Auth) block and before the "Done" section, add:

```bash
# --- Step 10: Server Role Setup ---------------------------------------------

if [[ "$DOTFILES_ROLE" == "server" ]] && [[ "$DOTFILES_OS" == "macos" ]]; then
  bash "$REPO_DIR/scripts/macos/setup-server.sh"

  if [[ -n "$DOTFILES_HOST" ]]; then
    if [[ -f "$REPO_DIR/hosts/${DOTFILES_HOST}.toml" ]]; then
      bash "$REPO_DIR/scripts/macos/setup-host-network.sh" "$REPO_DIR/hosts/${DOTFILES_HOST}.toml"
    else
      log_error "Host config not found: hosts/${DOTFILES_HOST}.toml"
      exit 1
    fi
  else
    log_warn "No --host specified, skipping host-specific network config"
  fi
fi
```

- [ ] **Step 3: Update the log banner to show role/host**

Change the existing log line at `setup.sh:25`:

```bash
log_info "OS: $DOTFILES_OS | Distro: $DOTFILES_DISTRO | Pkg: $DOTFILES_PKG | WSL: $DOTFILES_IS_WSL | Arch: $DOTFILES_ARCH | Role: $DOTFILES_ROLE | Host: ${DOTFILES_HOST:-none}"
```

- [ ] **Step 4: Verify no-arg behavior is unchanged**

Run: `bash setup.sh --help 2>&1 || true`
Expected: prints usage and exits (tests the arg parser)

Run: `bash -n setup.sh`
Expected: exit 0, no syntax errors

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "Add --role and --host flags to setup.sh for server provisioning"
```

---

### Task 2: Create `scripts/macos/setup-server.sh` (shared server config)

**Files:**
- Create: `scripts/macos/setup-server.sh`

This script handles config that is identical on both Mac Studios: always-on power settings, remote access, and homelab `/etc/hosts` entries.

- [ ] **Step 1: Create the server setup script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/macos/setup-server.sh — macOS server role configuration
# Configures always-on power, remote access, and homelab hosts.
# Called by setup.sh when --role server is passed. Requires sudo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_DIR/lib/log.sh"

# --- Always-On Power Settings -----------------------------------------------

log_info "Configuring always-on power settings..."

sudo pmset -a sleep 0
sudo pmset -a disksleep 0
sudo pmset -a displaysleep 0
sudo pmset -a autorestart 1
sudo pmset -a womp 1
sudo pmset -a hibernatemode 0

log_ok "Power settings configured (sleep disabled, auto-restart on)"

# --- Remote Access -----------------------------------------------------------

log_info "Configuring remote access..."

# Enable SSH (Remote Login)
if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
  log_warn "SSH already enabled"
else
  sudo systemsetup -setremotelogin on
  log_ok "SSH enabled"
fi

# Enable Screen Sharing (VNC)
if sudo launchctl list 2>/dev/null | grep -q "com.apple.screensharing"; then
  log_warn "Screen Sharing already enabled"
else
  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
  log_ok "Screen Sharing enabled"
fi

# Enable Remote Management (ARD) for full control
log_info "Enabling Remote Management (ARD)..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -privs -all -restart -agent -menu 2>/dev/null || log_warn "ARD configuration failed (may require manual setup)"

log_ok "Remote access configured"

# --- Homelab /etc/hosts Entries -----------------------------------------------

HOSTS_MARKER="# --- eap-dot-files homelab ---"
if grep -q "$HOSTS_MARKER" /etc/hosts 2>/dev/null; then
  log_warn "Homelab hosts entries already present in /etc/hosts"
else
  log_info "Adding homelab entries to /etc/hosts..."
  sudo tee -a /etc/hosts > /dev/null << 'EOF'

# --- eap-dot-files homelab ---
# LAN
192.168.86.101  urza      urza.lab
192.168.86.102  mishra    mishra.lab
192.168.86.103  emrakul   emrakul.lab
192.168.86.104  library   library.lab

# Thunderbolt mesh
10.10.10.1   urza-tb1
10.10.10.2   urza-tb2
10.10.10.3   mishra-tb1
10.10.10.4   mishra-tb2
10.10.10.10  library-tb1
10.10.10.11  library-tb2

# 10GbE
10.10.20.10  library-10g
10.10.20.50  emrakul-10g
# --- end eap-dot-files homelab ---
EOF
  log_ok "Homelab hosts entries added to /etc/hosts"
fi

log_ok "Server setup complete"
```

**Note on LAN subnet:** The conversation uses `192.168.x.0/24` as a placeholder. The script above uses `192.168.86` as a concrete value. You will need to replace this with your actual FIOS subnet. Consider making this configurable via a `hosts/common.toml` or environment variable if it ever changes.

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/macos/setup-server.sh`

- [ ] **Step 3: Verify syntax**

Run: `bash -n scripts/macos/setup-server.sh`
Expected: exit 0, no syntax errors

- [ ] **Step 4: Commit**

```bash
git add scripts/macos/setup-server.sh
git commit -m "Add macOS server setup script (pmset, SSH, VNC, /etc/hosts)"
```

---

### Task 3: Create host config files `hosts/urza.toml` and `hosts/mishra.toml`

**Files:**
- Create: `hosts/urza.toml`
- Create: `hosts/mishra.toml`

These declare per-host network config: Thunderbolt IPs, static routes, NFS mounts, and sysctl settings. The TOML format follows the same conventions as `packages.toml`.

- [ ] **Step 1: Create `hosts/urza.toml`**

```toml
# hosts/urza.toml — M3 Ultra Mac Studio (AI API server, local model hosting)

[thunderbolt.tb1]
description = "to library (NAS)"
interface = "Thunderbolt Bridge"
ip = "10.10.10.1"
subnet = "255.255.255.0"

[thunderbolt.tb2]
description = "to mishra"
interface = "Thunderbolt Bridge 2"
ip = "10.10.10.2"
subnet = "255.255.255.0"

[routes]
# Route 10GbE subnet through library's Thunderbolt IP
"10.10.20.0/24" = "10.10.10.10"

[nfs-mounts]
# mount_point = "nfs_host:export_path"
"/Volumes/ai-models" = "10.10.10.10:/ai-models"
"/Volumes/datasets" = "10.10.10.10:/datasets"

[sysctl]
# IP forwarding: urza bridges WireGuard traffic to the Thunderbolt mesh
"net.inet.ip.forwarding" = "1"
```

- [ ] **Step 2: Create `hosts/mishra.toml`**

```toml
# hosts/mishra.toml — M2 Ultra Mac Studio (App/dev server)

[thunderbolt.tb1]
description = "to library (NAS)"
interface = "Thunderbolt Bridge"
ip = "10.10.10.3"
subnet = "255.255.255.0"

[thunderbolt.tb2]
description = "to urza"
interface = "Thunderbolt Bridge 2"
ip = "10.10.10.4"
subnet = "255.255.255.0"

[routes]
# Route 10GbE subnet through library's Thunderbolt IP
"10.10.20.0/24" = "10.10.10.11"

[nfs-mounts]
# mount_point = "nfs_host:export_path"
"/Volumes/dev" = "10.10.10.11:/dev"
"/Volumes/backups" = "10.10.10.11:/backups"
```

- [ ] **Step 3: Commit**

```bash
git add hosts/urza.toml hosts/mishra.toml
git commit -m "Add host config for urza and mishra Mac Studios"
```

---

### Task 4: Create `lib/hosts.sh` (TOML parser for host config)

**Files:**
- Create: `lib/hosts.sh`

This library parses host TOML files and provides functions to iterate sections. It follows the same line-by-line parsing pattern used in `lib/packages.sh`.

- [ ] **Step 1: Create the host config parser**

```bash
#!/usr/bin/env bash
# lib/hosts.sh — Parse host TOML config files
# Source this file; do not execute directly.
# Requires: lib/log.sh sourced first.

# Parse a section from a host TOML file and call a callback for each key=value pair.
# Usage: parse_host_section <toml_file> <section_prefix> <callback_fn>
# The callback receives: key, value
# For nested sections like [thunderbolt.tb1], use prefix "thunderbolt" to match all.
parse_host_section() {
  local toml_file="$1"
  local section_prefix="$2"
  local callback="$3"
  local current_section=""

  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    # Section header
    if [[ "$line" =~ ^\[([a-zA-Z0-9._/-]+)\]$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi

    # Only process lines in matching sections
    if [[ "$current_section" == "$section_prefix" ]] || [[ "$current_section" == "$section_prefix".* ]]; then
      # key = "value" (quoted)
      if [[ "$line" =~ ^\"?([^\"=]+)\"?[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        # Trim whitespace from key
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        "$callback" "$key" "$value" "$current_section"
      fi
    fi
  done < "$toml_file"
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n lib/hosts.sh`
Expected: exit 0

- [ ] **Step 3: Commit**

```bash
git add lib/hosts.sh
git commit -m "Add host TOML config parser library"
```

---

### Task 5: Create `scripts/macos/setup-host-network.sh`

**Files:**
- Create: `scripts/macos/setup-host-network.sh`

This script reads a host TOML file and applies: Thunderbolt static IPs, static routes (with persistent LaunchDaemon), NFS mounts (with `/etc/fstab`), and sysctl settings.

- [ ] **Step 1: Create the host network setup script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# scripts/macos/setup-host-network.sh — Apply per-host network config from hosts/*.toml
# Usage: bash setup-host-network.sh <path-to-host.toml>
# Called by setup.sh when --role server --host <name> is passed.

HOST_TOML="$1"

if [[ ! -f "$HOST_TOML" ]]; then
  echo "Host config not found: $HOST_TOML" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_DIR/lib/log.sh"
source "$REPO_DIR/lib/hosts.sh"

HOST_NAME="$(basename "$HOST_TOML" .toml)"
log_info "Applying host network config for: $HOST_NAME"

# --- Thunderbolt Static IPs -------------------------------------------------

_apply_thunderbolt() {
  local key="$1" value="$2" section="$3"

  if [[ "$key" == "interface" ]]; then
    _tb_interface="$value"
  elif [[ "$key" == "ip" ]]; then
    _tb_ip="$value"
  elif [[ "$key" == "subnet" ]]; then
    _tb_subnet="$value"
    # All three fields collected — apply
    if [[ -n "${_tb_interface:-}" ]] && [[ -n "${_tb_ip:-}" ]]; then
      local current_ip
      current_ip="$(networksetup -getinfo "$_tb_interface" 2>/dev/null | grep "^IP address" | awk '{print $3}')" || true
      if [[ "$current_ip" == "$_tb_ip" ]]; then
        log_warn "Thunderbolt '$_tb_interface' already set to $_tb_ip"
      else
        log_info "Setting '$_tb_interface' to $_tb_ip/$_tb_subnet..."
        sudo networksetup -setmanual "$_tb_interface" "$_tb_ip" "$_tb_subnet"
        log_ok "Set '$_tb_interface' to $_tb_ip"
      fi
    fi
    # Reset for next section
    _tb_interface="" _tb_ip="" _tb_subnet=""
  fi
}

log_info "Configuring Thunderbolt static IPs..."
_tb_interface="" _tb_ip="" _tb_subnet=""
parse_host_section "$HOST_TOML" "thunderbolt" _apply_thunderbolt

# --- Static Routes (persistent via LaunchDaemon) ----------------------------

ROUTES_PLIST="/Library/LaunchDaemons/com.eap-dot-files.routes.plist"
_route_entries=()

_collect_route() {
  local dest="$1" gateway="$2" section="$3"
  _route_entries+=("$dest|$gateway")
}

parse_host_section "$HOST_TOML" "routes" _collect_route

if [[ ${#_route_entries[@]} -gt 0 ]]; then
  log_info "Configuring static routes..."

  # Build a multi-command shell script for the LaunchDaemon
  ROUTE_SCRIPT="/usr/local/bin/eap-homelab-routes.sh"
  {
    echo "#!/bin/bash"
    for entry in "${_route_entries[@]}"; do
      local dest="${entry%%|*}"
      local gateway="${entry##*|}"
      echo "/sbin/route -n add -net $dest $gateway 2>/dev/null || true"
    done
  } | sudo tee "$ROUTE_SCRIPT" > /dev/null
  sudo chmod +x "$ROUTE_SCRIPT"

  # Create LaunchDaemon plist
  sudo tee "$ROUTES_PLIST" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.eap-dot-files.routes</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$ROUTE_SCRIPT</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  # Load the daemon (unload first if exists)
  sudo launchctl unload "$ROUTES_PLIST" 2>/dev/null || true
  sudo launchctl load "$ROUTES_PLIST"

  # Also apply routes immediately
  sudo bash "$ROUTE_SCRIPT"
  log_ok "Static routes configured and persisted"
else
  log_warn "No static routes defined"
fi

# --- NFS Mounts + /etc/fstab ------------------------------------------------

FSTAB_MARKER="# --- eap-dot-files nfs ---"

_apply_nfs() {
  local mount_point="$1" nfs_source="$2" section="$3"

  # Create mount point
  if [[ ! -d "$mount_point" ]]; then
    sudo mkdir -p "$mount_point"
    log_ok "Created mount point: $mount_point"
  fi

  # Add to /etc/fstab if not already present
  if ! grep -q "$mount_point" /etc/fstab 2>/dev/null; then
    # Add marker on first entry
    if ! grep -q "$FSTAB_MARKER" /etc/fstab 2>/dev/null; then
      echo "" | sudo tee -a /etc/fstab > /dev/null
      echo "$FSTAB_MARKER" | sudo tee -a /etc/fstab > /dev/null
    fi
    echo "$nfs_source $mount_point nfs rw,bg,soft,intr,timeo=30 0 0" | sudo tee -a /etc/fstab > /dev/null
    log_ok "Added fstab entry: $nfs_source -> $mount_point"
  else
    log_warn "fstab entry already exists for $mount_point"
  fi

  # Mount if not already mounted
  if mount | grep -q "$mount_point"; then
    log_warn "Already mounted: $mount_point"
  else
    log_info "Mounting $mount_point..."
    sudo mount "$mount_point" 2>/dev/null || log_warn "Mount failed for $mount_point (NAS may not be reachable yet)"
  fi
}

log_info "Configuring NFS mounts..."
parse_host_section "$HOST_TOML" "nfs-mounts" _apply_nfs

# --- sysctl Settings ---------------------------------------------------------

_apply_sysctl() {
  local key="$1" value="$2" section="$3"

  local current
  current="$(sysctl -n "$key" 2>/dev/null)" || true
  if [[ "$current" == "$value" ]]; then
    log_warn "sysctl $key already set to $value"
  else
    sudo sysctl -w "${key}=${value}"
    log_ok "Set sysctl $key=$value"
  fi

  # Persist in /etc/sysctl.conf
  if grep -q "^${key}=" /etc/sysctl.conf 2>/dev/null; then
    sudo sed -i '' "s|^${key}=.*|${key}=${value}|" /etc/sysctl.conf
  else
    echo "${key}=${value}" | sudo tee -a /etc/sysctl.conf > /dev/null
  fi
}

log_info "Configuring sysctl settings..."
parse_host_section "$HOST_TOML" "sysctl" _apply_sysctl

log_ok "Host network config applied for: $HOST_NAME"
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x scripts/macos/setup-host-network.sh`

- [ ] **Step 3: Verify syntax**

Run: `bash -n scripts/macos/setup-host-network.sh`
Expected: exit 0

- [ ] **Step 4: Commit**

```bash
git add scripts/macos/setup-host-network.sh
git commit -m "Add per-host network setup (Thunderbolt, routes, NFS, sysctl)"
```

---

### Task 6: Update README.md with server usage

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add server setup instructions to the Quick Start section**

After the existing macOS Step 2 block, add:

```markdown
### macOS Server (Mac Studios)

After the standard Quick Start above, re-run with server flags:
```bash
cd ~/Development/eap-dot-files
bash setup.sh --role server --host urza    # on M3 Ultra
bash setup.sh --role server --host mishra  # on M2 Ultra
```

This layers server config on top of the workstation setup:
- Always-on power (sleep disabled, auto-restart)
- Remote access (SSH, Screen Sharing, ARD)
- Homelab `/etc/hosts` entries
- Per-host Thunderbolt static IPs, static routes, NFS mounts
```

- [ ] **Step 2: Add hosts directory to the Structure section**

In the Structure tree, add after `scripts/windows/`:

```
hosts/                # Per-host network config (server role)
```

- [ ] **Step 3: Add server customization to the Customization section**

Add:

```markdown
- **Server hosts**: Edit `hosts/<hostname>.toml` for per-machine network config
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document server role and host config in README"
```

---

### Task 7: Source `lib/hosts.sh` in `setup.sh` and export functions

**Files:**
- Modify: `setup.sh:13-17` (add hosts.sh to source/export block)

- [ ] **Step 1: Add hosts.sh to the source block**

After `source "$REPO_DIR/lib/packages.sh"`, add:

```bash
source "$REPO_DIR/lib/hosts.sh"
```

- [ ] **Step 2: Add parse_host_section to the export block**

After the existing `export -f` lines, add:

```bash
export -f parse_host_section
```

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "Source hosts.sh library and export parser function"
```

---

### Task 8: Update `setup-macos-init.sh` to accept an optional `--role server` flow

**Files:**
- Modify: `scripts/macos/setup-macos-init.sh`

The init script currently always prompts for hostname interactively. For server provisioning, the flow should hint at the next step.

- [ ] **Step 1: Update the final message to mention server setup**

Change the last `log_ok` line from:

```bash
log_ok "Pre-bootstrap done. Now launch Ghostty and run: bash setup.sh"
```

to:

```bash
log_ok "Pre-bootstrap done. Now launch Ghostty and run:"
log_info "  Workstation: bash setup.sh"
log_info "  Server:      bash setup.sh --role server --host <hostname>"
```

- [ ] **Step 2: Commit**

```bash
git add scripts/macos/setup-macos-init.sh
git commit -m "Update init script to show server setup option"
```

---

## Execution Notes

**LAN subnet placeholder:** The `/etc/hosts` entries in `setup-server.sh` use `192.168.86.x` as a concrete subnet. Replace this with your actual FIOS subnet before running.

**Thunderbolt interface names:** The `interface` values in `hosts/*.toml` (`"Thunderbolt Bridge"`, `"Thunderbolt Bridge 2"`) are guesses. On each Mac Studio, run `networksetup -listallhardwareports` to find the actual names, then update the TOML files before running.

**NFS exports:** The NFS mount paths (`/ai-models`, `/datasets`, etc.) must match the actual NFS exports configured on the QNAP. Set those up in QTS first.

**Ordering:** Tasks 1-5 are sequential (each builds on prior work). Tasks 6-8 are independent of each other but depend on Tasks 1-5 being complete.
