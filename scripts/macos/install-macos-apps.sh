#!/usr/bin/env bash

# Ensure mas is installed (via Homebrew)
if ! command -v mas &>/dev/null; then
  echo "Installing mas CLI..."
  brew install mas
fi

# Try to get the account (but don’t fail if not supported)
if command -v mas &>/dev/null; then
  if mas account &>/dev/null; then
    echo "Signed into App Store via mas"
  else
    echo "mas signin not supported — skipping login"
  fi
fi

# List of Mac App Store app IDs to install
mas_apps=(
  417375580    # BetterSnapTool
  1435957248   # Drafts
  585829637    # Todoist: To-Do List & Calendar
)

echo "Installing Mac App Store apps via mas..."
for app_id in "${mas_apps[@]}"; do
  # Skip if already installed
  if mas list | awk '{print $1}' | grep -q "^${app_id}$"; then
    echo "App ID ${app_id} already installed; skipping"
  else
    echo "Installing app with ID ${app_id}"
    mas install "${app_id}"
  fi
done

echo "Finished installing Mac App Store apps."