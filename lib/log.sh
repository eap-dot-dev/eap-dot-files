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
