#!/usr/bin/env bash
# lib/log.sh — Colored logging and error handling
# Source this file; do not execute directly.

log_info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
log_ok()    { printf '\033[0;32m[  OK]\033[0m %s\n' "$*"; }
log_warn()  { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }
log_error() { printf '\033[0;31m[ ERR]\033[0m %s\n' "$*" >&2; }

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
