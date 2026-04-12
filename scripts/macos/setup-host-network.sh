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
      dest="${entry%%|*}"
      gateway="${entry##*|}"
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
