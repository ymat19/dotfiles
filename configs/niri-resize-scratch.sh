#!/usr/bin/env bash
# Resize niri scratchpad window to match screen resolution

# Get kitty-scratch window ID
WINDOW_ID=$(niri msg windows -j 2>/dev/null | jq -r '.[] | select(.app_id == "kitty-scratch") | .id')

if [ -z "$WINDOW_ID" ]; then
    exit 0
fi

# Resize window to 75% width and 60% height
niri msg action set-window-width --id "$WINDOW_ID" "75%" 2>/dev/null
niri msg action set-window-height --id "$WINDOW_ID" "60%" 2>/dev/null
