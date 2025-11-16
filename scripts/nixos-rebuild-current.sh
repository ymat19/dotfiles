#!/usr/bin/env bash

# NixOS rebuild script for current environment
# This script will be templated by Nix with proper paths

set -o pipefail  # Ensure pipeline failures are detected

cd "@homeDirectory@/repos/dotfiles" || exit 1

if sudo nixos-rebuild switch --flake ".#@envName@" --impure 2>&1 | tee /tmp/nixos-rebuild.log; then
  @libnotify@/bin/notify-send "NixOS Rebuild" "System rebuild completed successfully!" --icon=dialog-information
else
  @libnotify@/bin/notify-send "NixOS Rebuild" "System rebuild failed! Check /tmp/nixos-rebuild.log" --icon=dialog-error --urgency=critical
fi
