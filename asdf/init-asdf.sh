#!/usr/bin/env bash
set -euo pipefail

# Ensure asdf is in PATH (Homebrew-installed one)
# On Homebrew, asdf is often installed under brew prefix, e.g. $(brew --prefix asdf)

# Source asdf
# If installed by brew, asdf.sh is under libexec
if command -v brew &>/dev/null; then
  ASDF_LIBEXEC="$(brew --prefix asdf)/libexec"
  if [ -f "$ASDF_LIBEXEC/asdf.sh" ]; then
    . "$ASDF_LIBEXEC/asdf.sh"
  fi
  if [ -f "$ASDF_LIBEXEC/completions/asdf.bash" ]; then
    . "$ASDF_LIBEXEC/completions/asdf.bash"
  fi
  if [ -f "$ASDF_LIBEXEC/completions/asdf.zsh" ]; then
    . "$ASDF_LIBEXEC/completions/asdf.zsh"
  fi
else
  # fallback: if asdf was installed by clone method, source from ~/.asdf
  . "${HOME}/.asdf/asdf.sh"
  if [ -f "${HOME}/.asdf/completions/asdf.zsh" ]; then
    . "${HOME}/.asdf/completions/asdf.zsh"
  fi
fi

# legacy version file config
if ! grep -q "legacy_version_file" "${HOME}/.asdfrc" 2>/dev/null; then
  echo "legacy_version_file = yes" >> "${HOME}/.asdfrc"
fi

# Plugins + desired versions
plugins=( nodejs python )
declare -A plugin_urls=(
  [nodejs]="https://github.com/asdf-vm/asdf-nodejs.git"
  [python]="https://github.com/asdf-community/asdf-python.git"
)
declare -A plugin_versions=(
  [nodejs]="22.20.0"
  [python]="3.14.0"
)

for plugin in "${plugins[@]}"; do
  if ! asdf plugin list | grep -q "^${plugin}$"; then
    echo "Adding plugin $plugin"
    asdf plugin add "$plugin" "${plugin_urls[$plugin]}"
  else
    echo "Plugin $plugin already present"
  fi

  version="${plugin_versions[$plugin]}"
  echo "Installing $plugin $version"
  asdf install "$plugin" "$version"
  echo "Setting global $plugin -> $version"
  asdf global "$plugin" "$version"
done

asdf reshim

echo "asdf (via brew) setup done. Current versions:"
asdf current
