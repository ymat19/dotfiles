# 基本となるイメージ
FROM ubuntu:latest

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y zsh curl git tmux neovim language-pack-en

# Oh My Zshのインストール
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /root/.zshrc && \
    echo "bindkey -v" >> /root/.zshrc && \
    echo "bindkey 'jj' vi-cmd-mode" >> /root/.zshrc

# zshをデフォルトシェルに設定
RUN chsh -s $(which zsh)

# Neovimの設定ファイルをコンテナにコピー
COPY ./init.vim /root/.config/nvim/init.vim

# 作業ディレクトリの設定
WORKDIR /workspace

# コンテナ起動時のコマンド
CMD ["tmux", "new-session", "zsh"]

