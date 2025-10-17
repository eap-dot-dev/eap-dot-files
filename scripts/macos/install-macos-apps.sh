#!/usr/bin/env bash

# Ensure mas is installed (via Homebrew)
if ! command -v mas &>/dev/null; then
  echo "Installing mas CLI..."
  brew install mas
fi

# Sign into App Store (mas will prompt if needed)
# (Requires the user’s Apple ID credentials)
echo "Ensuring you are signed into the Mac App Store..."
mas account || true  # this will show current Apple ID or prompt you

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