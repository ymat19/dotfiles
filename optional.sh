#!/bin/bash

set -e

# Add the parent path to ghq.root
PARENT_PATH=$(realpath ../)
echo "The parent path is: $PARENT_PATH"
read -p "Do you want to add this path to ghq.root? (y/N): " RESPONSE
if [[ "$RESPONSE" == "y" ]]; then
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

  read -p "Do you want to make neovim symlink for wsl.exe? (y/N):" RESPONSE
  if [[ "$RESPONSE" == "y" ]]; then
      sudo ln -s $(which nvim) /usr/local/bin/nvim
      echo "Symlink was created"
  fi
fi

