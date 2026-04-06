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

# Set zsh as default shell
ZSH_PATH=$(which zsh)
if [ -n "$ZSH_PATH" ]; then
  read -p "Do you want to set zsh as default shell? (y/N): " RESPONSE
  if [[ "$RESPONSE" == "y" ]]; then
    if ! grep -qxF "$ZSH_PATH" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    chsh -s "$ZSH_PATH"
    echo "Default shell changed to zsh. Re-login to apply."
  fi
fi
