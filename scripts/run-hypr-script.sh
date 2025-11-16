#!/usr/bin/env bash

# Script to dynamically run scripts from ~/.config/hypr/scripts/
# This script will be templated by Nix with proper paths

SCRIPT_DIR="@homeDirectory@/.config/hypr/scripts"

# Create directory if it doesn't exist
mkdir -p "$SCRIPT_DIR"

# Get list of executable scripts
SCRIPTS=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -executable -o -type l -executable | sort)

if [ -z "$SCRIPTS" ]; then
  @libnotify@/bin/notify-send "No Scripts" "No executable scripts found in $SCRIPT_DIR" --icon=dialog-warning
  exit 0
fi

# Show rofi menu with script basenames
SELECTED=$(echo "$SCRIPTS" | xargs -n1 basename | @rofi@/bin/rofi -dmenu -i -p 'Run Script')

if [ -n "$SELECTED" ]; then
  # Run selected script in background
  nohup "$SCRIPT_DIR/$SELECTED" > /tmp/hypr-script-"$SELECTED".log 2>&1 &
fi
