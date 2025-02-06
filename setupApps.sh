#!/bin/zsh

# Oh My Zshの導入
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# zsh-autosuggestionsの導入
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# fzfインストール
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
source <(fzf --zsh)

# autojumpとfzfのインストール
if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y tmux autojump unzip
    # バグ回避
    ln -s $HOME/.oh-my-zsh/lib/key-bindings.zsh /usr/share/doc/fzf/examples/key-bindings.zsh
    # neovim insatall
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    rm -rf /opt/nvim
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    rm nvim-linux-x86_64.tar.gz
elif command -v brew >/dev/null 2>&1; then
    brew update
    brew install neovim tmux autojump
else
    echo "apt-getもbrewも見つかりませんでした。手動でautojumpとfzfをインストールしてください。"
fi
