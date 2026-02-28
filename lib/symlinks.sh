#!/usr/bin/env bash
# lib/symlinks.sh — Idempotent symlink creation with backup
# Source this file; do not execute directly.
# Requires: lib/log.sh sourced first.

DOTFILES_BACKUP_DIR="${HOME}/.dotfiles-backup"

link_file() {
  local src="$1"
  local dest="$2"

  # Resolve source to absolute path if relative
  if [[ "$src" != /* ]]; then
    src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  fi

  if [[ ! -e "$src" ]]; then
    log_error "Source does not exist: $src"
    return 1
  fi

  # Already correctly linked
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    log_warn "Already linked: $dest"
    return 0
  fi

  # Existing file or wrong symlink — back up
  if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
    mkdir -p "$DOTFILES_BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$dest").$(date +%Y%m%d%H%M%S)"
    mv "$dest" "${DOTFILES_BACKUP_DIR}/${backup_name}"
    log_warn "Backed up existing $dest to ${DOTFILES_BACKUP_DIR}/${backup_name}"
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  ln -s "$src" "$dest"
  log_ok "Linked: $dest -> $src"
}

link_config_dir() {
  local src="$1"
  local dest="$2"

  # Resolve source to absolute path if relative
  if [[ "$src" != /* ]]; then
    src="$(cd "$src" && pwd)"
  fi

  if [[ ! -d "$src" ]]; then
    log_error "Source directory does not exist: $src"
    return 1
  fi

  # Already correctly linked
  if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
    log_warn "Already linked: $dest"
    return 0
  fi

  # Existing dir or wrong symlink — back up
  if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
    mkdir -p "$DOTFILES_BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$dest").$(date +%Y%m%d%H%M%S)"
    mv "$dest" "${DOTFILES_BACKUP_DIR}/${backup_name}"
    log_warn "Backed up existing $dest to ${DOTFILES_BACKUP_DIR}/${backup_name}"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log_ok "Linked: $dest -> $src"
}
