#!/usr/bin/env bash
# lib/hosts.sh — Parse host TOML config files
# Source this file; do not execute directly.
# Requires: lib/log.sh sourced first.

# Parse a section from a host TOML file and call a callback for each key=value pair.
# Usage: parse_host_section <toml_file> <section_prefix> <callback_fn>
# The callback receives: key, value, section_name
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
