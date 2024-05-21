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
    apt-get install -y neovim tmux autojump
    # バグ回避
    ln -s $HOME/.oh-my-zsh/lib/key-bindings.zsh /usr/share/doc/fzf/examples/key-bindings.zsh
elif command -v brew >/dev/null 2>&1; then
    brew update
    brew install neovim tmux autojump
else
    echo "apt-getもbrewも見つかりませんでした。手動でautojumpとfzfをインストールしてください。"
fi

# snapがあってdockerがなければsnapでdockerをインストール
if command -v snap >/dev/null 2>&1; then
    if ! command -v docker >/dev/null 2>&1; then
        snap install docker
    fi
fi

# snapのパスをzshに追加
echo 'export PATH=$PATH:/snap/bin' >> ~/.zshrc

# gitのデフォルトエディタをnvimに設定
git config --global core.editor "nvim"

