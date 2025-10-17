#!/usr/bin/env bash
set -euo pipefail

# Plugin names
plugins=( nodejs python )

# Plugin URLs (same index)
plugin_urls=( "https://github.com/asdf-vm/asdf-nodejs.git" "https://github.com/asdf-community/asdf-python.git" )

# Versions
plugin_versions=( "22.20.0" "3.14.0" )

for i in "${!plugins[@]}"; do
  plugin="${plugins[i]}"
  url="${plugin_urls[i]}"
  version="${plugin_versions[i]}"

  # Add plugin if missing
  if ! asdf plugin list | grep -q "^${plugin}$"; then
    echo "Adding plugin $plugin"
    asdf plugin add "$plugin" "$url"
  fi

  echo "Installing $plugin version $version"
  asdf install "$plugin" "$version"
  echo "Setting global $plugin -> $version"
  asdf set -u "$plugin" "$version"
done

asdf reshim

echo "ASDF setup complete: $(asdf current)"