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
