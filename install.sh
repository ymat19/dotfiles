#!/bin/bash

set -e

# setup nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# setup home-manager
nix-shell '<home-manager>' -A install -b backup

# setup home dir func
echo "\"$HOME\"" > home-manager/home-dir.nix

# apply settings
home-manager -f home-manager/home.nix switch -b backup

