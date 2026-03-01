# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ビルドコマンド

```bash
# NixOS ホストの再構築
sudo nixos-rebuild switch --flake .#<host> --impure
# ホスト名: main, mini, dyna, air, ymat19

# スタンドアロン（非NixOS）環境
home-manager switch --flake . --impure

# 初回rebuild（キャッシュ未設定 NixOS マシン）
sudo nixos-rebuild switch --flake .#<host> --impure \
  --option extra-substituters "https://cache.numtide.com https://nixos-apple-silicon.cachix.org" \
  --option extra-trusted-public-keys "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="

# 初回ビルド（スタンドアロン home-manager、キャッシュ未設定）
# flake.nix の nixConfig を有効にするため、先に trusted-users を設定する
echo "trusted-users = root $(whoami)" | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon
home-manager switch --flake . --impure

# Nix flake の構文チェック
nix flake check --no-build
```

## アーキテクチャ

Nix Flake ベースのドットファイルリポジトリ。単一リポジトリで NixOS（複数ホスト）とスタンドアロン home-manager の両方をサポート。

### エントリーポイント

- **flake.nix**: 全体の入力/出力定義。ホストごとの nixosConfigurations とスタンドアロン用 homeConfigurations を定義
- **configuration.nix**: NixOS システムレベル設定。ハードウェア設定のインポートとシステム共通設定
- **home.nix**: home-manager のルート。`lib/get-nix-files.nix` で `modules/` 内の全 `.nix` ファイルを自動インポート

### モジュール構造

`modules/` 内の `.nix` ファイルは `home.nix` により自動的にインポートされる（手動登録不要）。

- `modules/*.nix` — 全環境共通モジュール（shell, neovim, git-tools, ai-agent 等）
- `modules/nixos/*.nix` — NixOS 環境専用モジュール（kitty, niri, rofi 等）。NixOS 時のみ自動追加
- `modules/nixos/system/*.nix` — NixOS システムレベルモジュール（xremap, nvidia, steam 等）。`flake.nix` でホストごとに明示的にインポート

### ホスト構成

| ホスト | 特有モジュール | 用途 |
|--------|---------------|------|
| main | nvidia, steam | x86_64 デスクトップ |
| mini | steam | x86_64 ミニPC |
| dyna | dotnet | x86_64 ノート |
| air | apple-silicon | MacBook Air |
| ymat19 | なし | WSL/基本設定 |

### 設定ファイル

`configs/` に外部設定ファイルを配置し、各モジュールからシンボリックリンクで参照：
- `configs/kvim/` — Neovim 設定（lazy.nvim ベース、Lua）
- `configs/claude-code/` — Claude Code / MCP サーバー設定
- `configs/zshrc` — Zsh 追加設定

### AI エージェント統合

`modules/ai-agent.nix` が Claude Code、Codex、MCP サーバー群を統合管理。MCP サーバー設定は `configs/claude-code/` に定義し、Nix で動的にパスを解決して `~/.claude.json` 等に書き出す。

## 規約

- Nix フォーマッター: nixfmt（`nixfmt *.nix` で整形）
- Neovim プラグイン追加時: `configs/kvim/lua/custom/plugins/` にファイルを作成
- 新規モジュール追加: `modules/` に `.nix` ファイルを置くだけで自動インポートされる
- NixOS 専用機能は `modules/nixos/` に配置する
