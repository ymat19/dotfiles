# Dotfiles

[![CI/Test](https://github.com/ymat19/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/test.yml)
[![CI/Update](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml)

このリポジトリは、[Nix](https://nixos.org/) と [home-manager](https://github.com/nix-community/home-manager) を使用して管理された個人用のドットファイル集です。スタンドアロンの home-manager と NixOS の両方に対応しており、特に WSL 環境にも配慮しています。

## 特徴

- **宣言的な構成管理**: Nix Flakes による再現可能な環境構築
- **モジュラー設計**: 機能ごとに分離されたモジュール構成
- **マルチプラットフォーム対応**: NixOS、WSL、スタンドアロン home-manager をサポート
- **マルチマシン対応**: x86_64 デスクトップ (main/mini/dyna) と Apple Silicon (air) に対応
- **充実した開発環境**: Neovim (LSP/Treesitter)、Tmux、Zsh、Git ツールなど
- **デスクトップ環境**: Hyprland (Wayland)、Waybar、Rofi など (NixOS のみ)

## クイックスタート

### 自動インストール

```bash
./install.sh
```

### 手動インストール

#### スタンドアロン home-manager のセットアップ

1. Nix をインストール:

```bash
curl -L https://install.determinate.systems/nix | sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

2. 構成を適用:

```bash
home-manager switch --flake .
```

#### NixOS のセットアップ

1. ハードウェア設定をバックアップし、このリポジトリにコピー:

```bash
# ハードウェア設定を適切なディレクトリにコピー
# 例: hardware-configuration/main/ または hardware-configuration/air/ など
cp /etc/nixos/hardware-configuration.nix ./hardware-configuration/<hostname>/
```

2. 既存の `/etc/nixos` をバックアップし、このリポジトリをリンク:

```bash
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s $(realpath $(pwd)) /etc/nixos
```

3. NixOS の構成をビルドして適用:

```bash
sudo nixos-rebuild switch --flake .#<hostname> --impure
```

利用可能なホスト名: `ymat19` (基本)、`main` (NVIDIA+Steam)、`mini` (Steam)、`dyna` (.NET)、`air` (Apple Silicon)

4. システムを再起動:

```bash
sudo reboot
```

## アーキテクチャ

### Nix ファイル構成

```mermaid
graph TD
    A["flake.nix<br/>Entry Point"] --> B["nixpkgs<br/>home-manager<br/>xremap<br/>zen-browser"]

    A -->|Standalone| C["homeConfigurations"]
    A -->|NixOS| D["nixosConfigurations<br/>ymat19/main/mini/dyna/air"]

    C --> E["home.nix"]

    D --> F["configuration.nix"]
    F --> G["hardware-configuration/<br/>envName/"]
    F --> H["nixos-configurations/<br/>baremetal.nix"]
    F -->|WSL| I["nixos-configurations/<br/>wsl.nix"]
    F --> J["home-manager<br/>integration"]

    J --> E

    E --> K["lib/get-nix-files.nix<br/>Auto-discover modules"]
    K --> L["modules/*<br/>Universal"]
    K --> M["modules/nixos/*<br/>NixOS-only"]

    L --> L1["shell.nix<br/>Zsh/Bash/Starship"]
    L --> L2["neovim.nix<br/>Editor"]
    L --> L3["tmux.nix<br/>Multiplexer"]
    L --> L4["git-tools.nix<br/>Git/Delta/GHQ"]
    L --> L5["misc-util.nix<br/>CLI Tools"]

    M --> M1["hyprland.nix<br/>WM"]
    M --> M2["waybar.nix<br/>Status Bar"]
    M --> M3["rofi.nix<br/>Launcher"]
    M --> M4["system/*<br/>Login/NVIDIA/Steam"]

    M1 --> O["configs/<br/>hyprland.conf<br/>rofi.rasl<br/>tmux.conf"]

    style A fill:#ff9999
    style E fill:#ffcc99
    style F fill:#ffff99
    style L fill:#ccccff
    style M fill:#ffccff
```

### 主要コンポーネント

#### Universal Modules (全環境)
- **shell.nix**: Zsh/Bash + Starship プロンプト + Oh-my-zsh
- **neovim.nix**: Neovim (LSP/Treesitter/Copilot)
- **vim.nix**: 基本的な Vim 設定
- **tmux.nix**: ターミナルマルチプレクサ (Vi モード)
- **git-tools.nix**: Git + Delta + GHQ + Git LFS
- **misc-util.nix**: fzf、ripgrep、fd、bat、lsd、autojump
- **tui-tools.nix**: Lazygit、Lazydocker
- **direnv.nix**: Direnv + nix-direnv
- **mise.nix**: バージョンマネージャ
- **aws.nix**: AWS CLI

#### NixOS-only Modules
- **hyprland.nix**: Hyprland WM + Hypridle + Hyprlock + FCitx5 + Kitty
- **waybar.nix**: ステータスバー (システムトレイ、時計、ワークスペース)
- **rofi.nix**: アプリケーションランチャー
- **screenshot.nix**: Grimblast + Swappy
- **cliphist.nix**: クリップボード履歴
- **zen-browser.nix**: Zen Browser (Firefox フォーク)
- **vscode.nix**: VS Code
- **remmina.nix**: リモートデスクトップ

#### System Modules (システムレベル)
- **login.nix**: Greetd ログインマネージャ
- **xremap.nix**: キーボードリマッピング (CapsLock→Ctrl、Alt+HJKL→矢印キーなど)
- **nvidia.nix**: NVIDIA ドライバ + Wayland サポート
- **steam.nix**: Steam ゲーミングプラットフォーム
- **dotnet.nix**: .NET 8.0 SDK
- **dolphin.nix**: KDE Dolphin ファイルマネージャ

### Neovim (kvim) 構成

```mermaid
graph TD
    A["kvim/init.lua<br/>Main Entry"] --> B["lazy.nvim<br/>Plugin Manager"]

    A --> C["Core Settings<br/>Options/Keymaps"]
    A --> D["LSP Setup<br/>lspconfig"]
    A --> E["Treesitter<br/>Syntax"]
    A --> F["Colorscheme<br/>tokyonight"]

    A --> G["lua/custom/core.lua<br/>Custom Settings"]

    B --> H["custom/plugins/"]
    B --> I["kickstart/plugins/"]

    H --> H1["snacks.lua<br/>Dashboard/Picker"]
    H --> H2["bufferline.lua<br/>Buffer Tabs"]
    H --> H3["copilot.lua<br/>AI Completion"]
    H --> H4["diffview.lua<br/>Git Diff"]
    H --> H5["essentials.lua<br/>Motion Plugins"]
    H --> H6["glance.lua<br/>LSP References"]

    I --> I1["autopairs.lua<br/>Auto Brackets"]
    I --> I2["neo-tree.lua<br/>File Explorer"]
    I --> I3["debug.lua<br/>DAP Debug"]
    I --> I4["lint.lua<br/>Linting"]

    D --> D1["mason<br/>LSP Installer"]
    D --> D2["conform<br/>Formatter"]
    D --> D3["nvim-cmp<br/>Completion"]

    H5 --> H5A["leap<br/>Motion"]
    H5 --> H5B["surround<br/>Surroundings"]
    H5 --> H5C["substitute<br/>Replace"]

    style A fill:#ff6b6b
    style B fill:#4ecdc4
    style H fill:#ffe66d
    style I fill:#95e1d3
```

### 主要な Neovim プラグイン

#### LSP & 補完
- **nvim-lspconfig** + **mason**: LSP サーバー管理 (lua_ls, nil, typescript-language-server)
- **nvim-cmp** + **LuaSnip**: 自動補完とスニペット
- **conform.nvim**: コードフォーマッター (stylua, prettier, nixpkgs-fmt)
- **copilot.lua**: GitHub Copilot AI 補完

#### UI & ナビゲーション
- **snacks.nvim**: ダッシュボード、ファイルピッカー、ターミナル統合
- **bufferline.nvim**: バッファタブ表示
- **neo-tree.nvim**: ファイルツリーエクスプローラー (`\` で切替)
- **which-key.nvim**: キーマップヒント表示

#### Git 統合
- **gitsigns.nvim**: Git 差分表示とハンク操作
- **diffview.nvim**: 差分ビューアー (`<leader>dd/da/dc`)

#### 編集とモーション
- **leap.nvim**: 高速移動 (`s`/`S`)
- **nvim-surround**: 囲み文字操作 (`cs`/`ds`/`ys`)
- **substitute.nvim**: 置換オペレータ (`rr`/`R`/`RR`)
- **dial.nvim**: インクリメント/デクリメント (`<C-a>`/`<C-x>`)
- **clever-f.vim**: 改善された f/t ジャンプ

#### 診断と品質
- **tiny-inline-diagnostic.nvim**: インライン診断表示
- **lsp_signature.nvim**: 関数シグネチャヒント
- **nvim-lint**: リンティング (markdownlint)
- **nvim-dap**: デバッグサポート (F5-F7)

### 主要なキーバインド

| カテゴリ | プレフィックス | 機能 |
|----------|---------------|------|
| **ファイル** | `<leader>f` | バッファ、設定、ファイル検索、Git ファイル、最近使用 |
| **検索** | `<leader>s` | バッファ行、grep、診断、ヘルプなど |
| **LSP** | `<leader>l` | コードアクション、リネーム、ホバー、定義、参照など |
| **Git** | `<leader>g` | ブランチ、ログ、ステータス、差分、lazygit |
| **トグル** | `<leader>u` | スペル、折り返し、行番号、診断など |
| **差分** | `<leader>d` | 差分を開く、すべて開く、閉じる |

リーダーキー: `<space>`

## 環境別の適用例

### スタンドアロン home-manager (非 NixOS)
```bash
home-manager switch --flake .
```

### NixOS デスクトップ (main - ゲーミング環境)
```bash
sudo nixos-rebuild switch --flake .#main
```
含まれるもの: NVIDIA ドライバ + Steam + Hyprland + すべての開発ツール

### MacBook Air (Apple Silicon)
```bash
sudo nixos-rebuild switch --flake .#air
```
含まれるもの: Apple Silicon サポート + すべての開発ツール

### WSL 環境
```bash
sudo nixos-rebuild switch --flake .#ymat19
```

## WSL 環境での注意点

Neovim のシンボリックリンクを作成:

```bash
sudo ln -s $(which nvim) /usr/local/bin/nvim
```

## その他のセットアップコマンド

```bash
# ghq ベースディレクトリを設定
git config --global --add ghq.root $(realpath ../)

# gitconfig を作成
touch ~/.gitconfig
```

## 構成ファイルの場所

- **Nix 設定**: `flake.nix`, `home.nix`, `configuration.nix`, `modules/`, `nixos-configurations/`
- **ハードウェア設定**: `hardware-configuration/`
- **外部設定ファイル**: `configs/`
  - Hyprland: `configs/hyprland.conf`
  - Rofi: `configs/rofi.rasl`
  - Tmux: `configs/tmux.conf`
  - Zsh: `configs/zshrc`
  - Neovim: `configs/kvim/` (機能豊富)、`configs/nvim/` (VSCode 統合用)

## Claude Code 統合

`modules/ai-agent.nix` が Claude Code・Codex・MCP サーバー・スキルを統合管理している。Nix Flake の入力として以下を使用:

- **[llm-agents-nix](https://github.com/numtide/llm-agents.nix)**: Claude Code 本体および CLI ツール群のパッケージ提供
- **[mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)**: MCP サーバーの宣言的管理
- **[agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix)**: スキルの宣言的管理・デプロイ

### MCP サーバー

| サーバー名 | 用途 |
|------------|------|
| **filesystem** | ファイルシステムへの読み書きアクセス（`/home`, `/tmp`） |
| **git** | Git リポジトリ操作（status, diff, commit, branch 等） |
| **sequential-thinking** | 段階的な思考プロセスによる問題分解・分析 |
| **time** | タイムゾーン間の時刻取得・変換 |
| **serena** | セマンティックなコード解析・シンボル操作（LSP ベース） |
| **context7** | ライブラリの最新ドキュメント取得 |

### スキル（SKILL）

4 つのソースからスキルがデプロイされる:

| ソース | スキル名 | 用途 |
|--------|----------|------|
| **local** | screenshot | クリップボードからスクリーンショットを取得・分析 |
| **anthropic** | algorithmic-art | p5.js を使ったアルゴリズミックアート生成 |
| | brand-guidelines | Anthropic ブランドガイドラインの適用 |
| | canvas-design | コードによるビジュアルアート・デザイン作成 |
| | doc-coauthoring | ドキュメント共同執筆ワークフロー |
| | docx | Word ドキュメント (.docx) の作成・編集 |
| | dogfood | Web アプリの探索的テスト・バグ発見 |
| | frontend-design | プロダクション品質のフロントエンド UI 作成 |
| | internal-comms | 社内コミュニケーション文書の作成 |
| | mcp-builder | MCP サーバーの構築ガイド |
| | pdf | PDF ファイルの操作全般 |
| | pptx | PowerPoint プレゼンテーションの操作 |
| | skill-creator | スキルの作成・改善・評価 |
| | slack | Slack ワークスペースのブラウザ自動操作 |
| | slack-gif-creator | Slack 向けアニメーション GIF 作成 |
| | theme-factory | アーティファクトへのテーマ適用 |
| | web-artifacts-builder | React/Tailwind/shadcn を使った複雑な Web アーティファクト構築 |
| | webapp-testing | Playwright を使った Web アプリテスト |
| | xlsx | スプレッドシート (.xlsx) の操作 |
| **agent-browser** | agent-browser | ブラウザ自動操作 CLI |
| **local** | coordinator-pr | Agent Teams による並列 PR 実装オーケストレーション |
| | pr-sweep | Agent Teams による一括 PR レビュー＆マージ |

### フック（Hooks）

| イベント | マッチャー | 処理内容 |
|----------|-----------|----------|
| **PreToolUse** | `Bash` | **rtk-rewrite**: Bash コマンドを自動的に [rtk](https://github.com/numtide/rtk) 経由に書き換え。git, cargo, npm, docker, kubectl, curl 等の主要コマンドをラップし、出力のトークン節約・レート制限を実現 |

### サードパーティ CLI ツール

`llm-agents-nix` からインストールされるツール:

| ツール名 | 用途 |
|----------|------|
| **claude-code** | Anthropic 公式の CLI エージェント |
| **codex** | OpenAI Codex CLI エージェント |
| **agent-browser** | AI エージェント向けブラウザ自動操作 CLI |
| **ccusage** | Claude Code の使用量トラッキング |
| **rtk** | コマンド出力のトークン節約ラッパー（フックと連携） |
| **workmux** | git worktree ラッパー（手動利用のみ、AI エージェントからは使用しない） |

### Neovim 連携

**sidekick.nvim** (`configs/kvim/lua/custom/plugins/agent.lua`): Neovim から Claude Code / Codex を tmux スプリットで操作。

| キーバインド | 機能 |
|-------------|------|
| `<leader>aa` | Sidekick トグル |
| `<leader>ac` | Claude Code トグル |
| `<leader>ao` | Codex トグル |
| `<leader>as` | ツール選択 |
| `<leader>ad` | セッション切断 |
| `<leader>at` | カーソル下の単語/選択範囲を送信 |
| `<leader>af` | 現在のファイルを送信 |
| `<leader>ap` | プロンプトピッカー |
| `<Tab>` | NES (Next Edit Suggestions) の適用/ジャンプ |

### その他の設定

- **ステータスライン**: モデル名、コンテキスト使用率バー、コスト、API 時間を表示（`configs/claude-code/statusline.sh`）
- **パーミッション**: `bypassPermissions` モード（読み取り系コマンド、git、WebSearch 等は自動許可）
- **環境変数**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（チーム機能の有効化）

## 参考リンク

- [Home Manager Options Search](https://home-manager-options.extranix.com/?query=&release=release-24.05)
- [Nixpkgs Packages Search](https://search.nixos.org/packages?channel=24.11)
- [NixOS Options](https://search.nixos.org/options?channel=unstable)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

## ライセンス

詳細は [LICENSE.md](LICENSE.md) を参照してください。
