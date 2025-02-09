# ベースとなる公式のUbuntuイメージを使用
FROM ubuntu:latest

# パッケージインストール時の対話モードを無効化
ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージを更新・インストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# dotfilesリポジトリをクローン
RUN git clone https://github.com/ymat19/dotfiles.git /root/dotfiles

# 作業ディレクトリをdotfilesリポジトリに変更
WORKDIR /root/dotfiles

# dotfilesをインストール（リポジトリにインストールスクリプトがあると仮定）
RUN chmod +x install.sh && ./install.sh

# デフォルトでzshを実行
CMD ["zsh"]
