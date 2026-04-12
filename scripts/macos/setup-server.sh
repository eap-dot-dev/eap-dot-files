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
  sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
  log_ok "Screen Sharing enabled"
fi

# Enable Remote Management (ARD) for full control
log_info "Enabling Remote Management (ARD)..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -privs -all -restart -agent -menu 2>/dev/null || log_warn "ARD configuration failed (may require manual setup)"

log_ok "Remote access configured"

# --- Disable mDNS on Thunderbolt (prevents "name already in use" conflicts) ---

# When a Mac has multiple active interfaces, macOS advertises its Bonjour name
# on all of them. This causes the machine to detect its own name as a conflict
# across Thunderbolt and LAN interfaces. Fix: disable multicast on bridge ifaces.

TB_MULTICAST_PLIST="/Library/LaunchDaemons/com.eap-dot-files.disable-tb-multicast.plist"
TB_BRIDGES=()
while IFS= read -r iface; do
  TB_BRIDGES+=("$iface")
done < <(ifconfig -l | tr ' ' '\n' | grep '^bridge')

if [[ ${#TB_BRIDGES[@]} -gt 0 ]]; then
  log_info "Disabling multicast on Thunderbolt bridges: ${TB_BRIDGES[*]}"

  # Apply immediately
  for iface in "${TB_BRIDGES[@]}"; do
    sudo ifconfig "$iface" -multicast 2>/dev/null || true
  done

  # Persist via LaunchDaemon
  MULTICAST_CMD=""
  for iface in "${TB_BRIDGES[@]}"; do
    MULTICAST_CMD+="ifconfig $iface -multicast; "
  done

  sudo tee "$TB_MULTICAST_PLIST" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.eap-dot-files.disable-tb-multicast</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>${MULTICAST_CMD}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>LaunchOnlyOnce</key>
  <true/>
</dict>
</plist>
EOF

  sudo launchctl bootout system/com.eap-dot-files.disable-tb-multicast 2>/dev/null || true
  sudo launchctl bootstrap system "$TB_MULTICAST_PLIST"
  log_ok "mDNS disabled on Thunderbolt bridges (prevents hostname conflicts)"
else
  log_warn "No bridge interfaces found — skipping mDNS fix"
fi

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
