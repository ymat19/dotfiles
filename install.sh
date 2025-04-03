#!/bin/bash

set -e

# if nix is installed, remove it
if [ -f /nix/nix-installer ]; then
    /nix/nix-installer uninstall
fi

# setup nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# setup home-manager
nix-shell '<home-manager>' -A install

# apply settings
home-manager switch --flake .#ymat19 --impure -b backup

