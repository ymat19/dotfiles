#!/bin/bash

# Oh My Zshの導入
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# zsh-autosuggestionsの導入
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# autojumpとfzfのインストール
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y zsh neovim tmux autojump fzf 
elif command -v brew >/dev/null 2>&1; then
    brew update
    brew install autojump fzf
else
    echo "apt-getもbrewも見つかりませんでした。手動でautojumpとfzfをインストールしてください。"
fi

# snapがあってdockerがなければsnapでdockerをインストール
if command -v snap >/dev/null 2>&1; then
    if ! command -v docker >/dev/null 2>&1; then
        sudo snap install docker
    fi
fi

# snapのパスをzshに追加
echo 'export PATH=$PATH:/snap/bin' >> ~/.zshrc

# gitのデフォルトエディタをnvimに設定
git config --global core.editor "nvim"

