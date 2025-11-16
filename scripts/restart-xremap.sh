#!/usr/bin/env bash

# Restart xremap systemd service

if sudo systemctl restart xremap; then
  sleep 0.5  # Wait for DBUS connection to stabilize
  @libnotify@/bin/notify-send "Xremap" "Service restarted successfully!" --icon=dialog-information
else
  sleep 0.5  # Wait for DBUS connection to stabilize
  @libnotify@/bin/notify-send "Xremap" "Failed to restart service!" --icon=dialog-error --urgency=critical
fi
