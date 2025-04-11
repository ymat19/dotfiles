# Dotfiles

[![CI/Test](https://github.com/ymat19/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/test.yml)
[![CI/Update](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml)

このリポジトリは[Nix](https://nixos.org/)と[home-manager](https://github.com/nix-community/home-manager)で管理される個人の設定ファイル（dotfiles）です。スタンドアロンのhome-manager環境とNixOS環境の両方をサポートし、WSL環境にも対応しています。

## 特徴

- 📦 Nixベースの設定管理
- 🔄 インストールスクリプトによる自動セットアップ
- 🐧 スタンドアロンhome-managerとNixOSの両対応
- 🪟 WSL（Windows Subsystem for Linux）互換
- 🛠️ 事前設定された開発ツール群：
  - デュアルNeovim設定（IDE風環境とVSCode統合）
  - tmux
  - zsh
  - Git設定
  - 各種CLIユーティリティ

## ディレクトリ構成

- `configs/` - ツール固有の設定
  - `kvim/` - フル機能のNeovim設定（IDE風セットアップ）
  - `nvim/` - 最小限のNeovim設定（VSCode統合用）
  - その他の設定ファイル（.vimrc, tmux.conf, zshrc）
- `modules/` - Nix設定モジュール
- `flake.nix` - メインのNix flake設定
- `home.nix` - home-manager設定
- `install.sh` - 自動インストールスクリプト

## Neovim設定

本リポジトリには2つの異なるNeovim設定があり、それぞれ異なる`NVIM_APPNAME`環境で管理されています：

### 1. フル機能IDE風設定（kvim）
`configs/kvim/`に配置され、[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)をベースとした機能豊富な設定です。

- **使用方法**: `kvim`（エイリアスコマンド）
- **機能**:
  - `nvim-lspconfig`によるLSP統合
  - `nvim-treesitter`による構文ハイライト
  - `tokyonight-nvim`テーマによるモダンUI
  - `quick-scope`、`clever-f-vim`、`leap-nvim`による強化された移動機能
  - テキスト操作ツール：`substitute-nvim`、`nvim-surround`、`dial-nvim`
  - GitHub Copilotとチャット機能の統合
  - 追加ツール：Mermaidダイアグラムサポート、Nix言語サーバー

### 2. VSCode統合設定（nvim）
`configs/nvim/`に配置され、VSCode Neovim拡張機能での使用に特化した最小限の設定です。

- **使用方法**: VSCode使用時の通常の`nvim`コマンド
- **機能**:
  - `quick-scope`、`clever-f-vim`、`leap-nvim`による強化された移動機能
  - テキスト操作：`substitute-nvim`、`nvim-surround`、`dial-nvim`
  - LSPとtreesitterのサポート（`nvim-lspconfig`、`nvim-treesitter`）
  - 基本設定：大文字小文字を区別しない検索、ソフトタブ、クリップボード統合
- **目的**: VSCodeのVimエミュレーションを拡張しつつ、互換性を維持

## インストール

### クイックスタート

自動インストールスクリプトを実行：
```bash
./install.sh
```

このスクリプトは以下を実行します：
1. 既存のNixインストールを削除
2. Determinate Systemsインストーラーを使用してNixをインストール
3. home-managerをセットアップ
4. 設定を適用

### 手動セットアップ

#### スタンドアロンhome-managerセットアップ

1. Nixのインストール：
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

2. home-managerのセットアップ：
```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

3. 設定の適用：
```bash
home-manager switch --flake . --impure -b backup
```

#### NixOSセットアップ

1. 設定のバックアップとリンク：
```bash
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s $(realpath $(pwd)) /etc/nixos
```

2. 設定の適用：
```bash
sudo nixos-rebuild switch --impure
```

## 追加セットアップ手順

### WSL固有のセットアップ
```bash
# WSL用のneovimシンボリックリンク作成（VSCode Neovimに必要）
sudo ln -s $(which nvim) /usr/local/bin/nvim
```

### 一般的なユーティリティ
```bash
# Linux上でクリップボードを有効化
sudo apt-get install xsel

# Linuxでのlazygitエラーを修正
sudo chmod a+rw /dev/tty

# ghqベースディレクトリの設定
git config --global --add ghq.root $(realpath ../)

# 必要に応じてasdfのshimsを再構築
asdf reshims
```

## 参考ドキュメント

- [Home Manager オプション検索](https://home-manager-options.extranix.com/?query=&release=release-24.05)
- [Nixpkgs パッケージ検索](https://search.nixos.org/packages?channel=24.11&from=0&size=50&sort=relevance&type=packages&query=vimPlugins)

## ライセンス

詳細は[LICENSE.md](LICENSE.md)を参照してください。