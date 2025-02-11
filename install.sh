#!/bin/sh

# setup nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# setup home-manager
nix-shell '<home-manager>' -A install

# setup home dir func
echo "\"$HOME\"" > home-manager/home-dir.nix

# apply
home-manager -f home-manager/home.nix switch

# Prompt the user with the parent path in English
PARENT_PATH=$(realpath ../)
echo "The parent path is: $PARENT_PATH"
read -p "Do you want to add this path to ghq.root? (y/N): " RESPONSE

# Check the user's response
if [[ "$RESPONSE" == "y" ]]; then
    # Add the path to ghq.root
    git config --global --add ghq.root "$PARENT_PATH"
    echo "The path has been added to ghq.root."
else
    echo "The path was not added to ghq.root."
fi

# Linux only
if [[ "$(uname)" == "Linux" ]]; then
  # enable clipboard on linux
  sudo apt-get install xsel

  # fix lazygit error on linux
  sudo chmod a+rw /dev/tty
fi
