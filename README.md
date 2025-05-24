# Dotfiles

[![CI/Test](https://github.com/ymat19/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/test.yml)
[![CI/Update](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml)

このリポジトリは、[Nix](https://nixos.org/) と [home-manager](https://github.com/nix-community/home-manager) を使用して管理された個人用のドットファイル集です。スタンドアロンの home-manager と NixOS の両方に対応しており、特に WSL 環境にも配慮しています。

## 構成概要

- **Nix ベースの構成管理**: `flake.nix` を中心に、以下のディレクトリで構成を管理。
  - `modules/`: 各種モジュール (例: Git ツール、シェル、TUI ツール、AWS、Vim、Neovim、tmux など)
  - `nixos-configurations/`: WSL やベアメタル環境用の NixOS 設定
  - `lib/`: Nix 設定の補助スクリプト
- **Home-manager**: `home.nix` を使用してユーザー環境を構築。
- **ツール固有の設定**: `configs/` ディレクトリに各種ツールの設定を格納。
  - `kvim/`: 機能豊富な Neovim 設定。
  - `nvim/`: VSCode 統合用の最小限の Neovim 設定。
  - その他: `tmux.conf`, `zshrc`, `hyprland.conf`, `rofi.rasl` など

## インストール手順

### クイックスタート

以下のコマンドで自動インストールを実行:

```bash
./install.sh
```

### 手動セットアップ

1. Nix をインストール:

```bash
curl -L https://install.determinate.systems/nix | sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

2. 構成を適用:

```bash
home-manager switch --flake .
```

## WSL 環境での注意点

- Neovim のシンボリックリンクを作成:

```bash
sudo ln -s $(which nvim) /usr/local/bin/nvim
```

## その他セットアップでよく使うコマンド


```bash
# ghq ベースディレクトリを設定
git config --global --add ghq.root $(realpath ../)

# gitconfig を作成
touch ~/.gitconfig
```

## URL リファレンス

以下は、Nix や Home Manager の設定に役立つリファレンスです:

- [Home Manager Options Search](https://home-manager-options.extranix.com/?query=&release=release-24.05)
- [Nixpkgs Packages Search](https://search.nixos.org/packages?channel=24.11&from=0&size=50&sort=relevance&type=packages&query=vimPlugins)
- [NixOS Options](https://search.nixos.org/options?channel=unstable&show=users.mutableUsers&size=30&sort=relevance)

## ライセンス

詳細は [LICENSE.md](LICENSE.md) を参照してください。
