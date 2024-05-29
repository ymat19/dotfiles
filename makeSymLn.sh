#!/bin/zsh

# 現在の日時を取得
current_time=$(date +"%y%m%d%H%M")

# バックアップフォルダの作成
backup_dir="$(pwd)/backup/$current_time"
mkdir -p "$backup_dir"

# シンボリックリンクを作成する関数
create_symlink() {
    local src_file="$1"
    local dest_file="$2"

    if [ -e "$dest_file" ] || [ -L "$dest_file" ]; then
        mv "$dest_file" "$backup_dir/"
    fi

    ln -s "$src_file" "$dest_file"
}

# ホームディレクトリに.zshrc, .p10kのシンボリックリンクを作成
create_symlink "$(pwd)/.zshrc" "$HOME/.zshrc"
create_symlink "$(pwd)/.p10k.zsh" "$HOME/.p10k.zsh"

# nvimの設定ディレクトリにinit.vimのシンボリックリンクを作成
mkdir -p "$HOME/.config/nvim"
create_symlink "$(pwd)/init.vim" "$HOME/.config/nvim/init.vim"
create_symlink "$(pwd)/dein.toml" "$HOME/.config/nvim/dein.toml"

# tmuxの設定ディレクトリにtmux.confのシンボリックリンクを作成
mkdir -p "$HOME/.config/tmux"
create_symlink "$(pwd)/tmux.conf" "$HOME/.config/tmux/tmux.conf"


