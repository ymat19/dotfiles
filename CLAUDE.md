# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ビルドコマンド

```bash
# NixOS ホストの再構築（`hostname` でホスト名を確認してから実行）
sudo nixos-rebuild switch --flake .#$(hostname) --impure
# ホスト名: main, mini, dyna, air, ymat19

# スタンドアロン（非NixOS）環境
home-manager switch --flake . --impure

# 初回rebuild（キャッシュ未設定 NixOS マシン）
sudo nixos-rebuild switch --flake .#<host> --impure \
  --option extra-substituters "https://cache.numtide.com https://nixos-apple-silicon.cachix.org" \
  --option extra-trusted-public-keys "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="

# 初回ビルド（スタンドアロン home-manager、キャッシュ未設定）
# flake.nix の nixConfig を有効にするため、先に trusted-users を設定する
# Determinate Nix の場合は nix.custom.conf に追加（nix.conf は自動生成で上書きされる）
echo "trusted-users = root $(whoami)" | sudo tee -a /etc/nix/nix.custom.conf
sudo systemctl restart nix-daemon
home-manager switch --flake . --impure

# Nix flake の構文チェック
nix flake check --no-build

# 旧 kvim 構成のデータを削除（kvim → nvim 統合後、各ホストで1回実行）
rm -rf ~/.local/share/kvim ~/.local/state/kvim ~/.cache/kvim
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
- `modules/nixos/*.nix` — NixOS 環境専用モジュール（alacritty, niri, rofi 等）。NixOS 時のみ自動追加
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
- `configs/nvim/` — Neovim 設定（lazy.nvim ベース、Lua）
- `configs/claude-code/` — Claude Code / MCP サーバー設定
- `configs/zshrc` — Zsh 追加設定

### AI エージェント統合

`modules/ai-agent.nix` が Claude Code、Codex、MCP サーバー群を統合管理。MCP サーバー設定は `configs/claude-code/` に定義し、Nix で動的にパスを解決して `~/.claude.json` 等に書き出す。

## 規約

- Nix フォーマッター: nixfmt（`nixfmt *.nix` で整形）
- Neovim プラグイン追加時: `configs/nvim/lua/custom/plugins/` にファイルを作成
- 新規モジュール追加: `modules/` に `.nix` ファイルを置くだけで自動インポートされる
- NixOS 専用機能は `modules/nixos/` に配置する

<!-- mulch:start -->
## Project Expertise (Mulch)
<!-- mulch-onboard:v0.10.7 -->

This project uses [Mulch](https://github.com/jayminwest/mulch) v0.10.7 for structured expertise management.

**At the start of every session**, run:
```bash
ml prime
```

Injects project-specific conventions, patterns, decisions, failures, references, and guides into
your context. Run `ml prime --files src/foo.ts` before editing a file to load only records
relevant to that path (per-file framing, classification age, and confirmation scores included).

For monolith projects where dumping every record wastes context, set
`prime.default_mode: manifest` in `.mulch/mulch.config.yaml` (or pass `--manifest`) to emit a
quick reference + domain index. Agents then scope-load with `ml prime <domain>` or
`ml prime --files <path>`.

**Before completing your task**, record insights worth preserving — conventions discovered,
patterns applied, failures encountered, or decisions made:
```bash
ml record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
```

Evidence auto-populates from git (current commit + changed files). Link explicitly with
`--evidence-seeds <id>` / `--evidence-gh <id>` / `--evidence-linear <id>` / `--evidence-bead <id>`,
`--evidence-commit <sha>`, or `--relates-to <mx-id>`. Upserts of named records merge outcomes
instead of replacing them; validation failures print a copy-paste retry hint with missing fields
pre-filled.

Run `ml status` for domain health, `ml doctor` to check record integrity (add `--fix` to strip
broken file anchors), `ml --help` for the full command list. Write commands use file locking and
atomic writes, so multiple agents can record concurrently. Expertise survives `git worktree`
cleanup — `.mulch/` resolves to the main repo.

`ml prune` soft-archives stale records to `.mulch/archive/` instead of deleting them; pass
`--hard` for true deletion. Restore an archived record with `ml restore <id>`. Do not read
`.mulch/archive/` directly — those records are stale by definition. If you need historical
context, run `ml search --archived <query>`.

### Before You Finish

If you discovered conventions, patterns, decisions, or failures worth preserving during
this session, record them before closing:

```bash
ml learn                                                                    # see what files changed
ml record <domain> --type <convention|pattern|failure|decision|reference|guide> --description "..."
ml sync                                                                     # validate, stage, commit
```

Skip if no insight surfaced. Unrecorded learnings are lost; ritual filler records are also noise.
<!-- mulch:end -->

<!-- seeds:start -->
## Issue Tracking (Seeds)
<!-- seeds-onboard:v0.5.10 -->
<!-- seeds-onboard-schema:7 -->

This project uses [Seeds](https://github.com/jayminwest/seeds) v0.5.10 for git-native issue tracking.

**At the start of every session**, run:
```
sd prime
```

This injects session context: rules, command reference, and workflows. Pass `--format json|compact|markdown|plain|ids` on any command for agent-friendly output.

**Quick reference:**
- `sd ready` — Find unblocked work
- `sd search <query>` — Full-text search across titles + descriptions
- `sd create --title "..." --type task --priority 2` — Create issue
- `sd update <id> --status in_progress` — Claim work
- `sd close <id>` — Complete work
- `sd dep add <id> <depends-on>` — Add dependency between issues
- `sd sync` — Sync with git (run before pushing)

### Planning
Use `sd plan` when work is large or ambiguous enough that an LLM benefits from structured decomposition. Submit spawns one child seed per step; `step.blocks` uses forward semantics (step i with `blocks: [j]` means step i blocks step j, and step j gets step i's id in its `blockedBy`).

- `sd plan templates` — List built-ins (`feature`, `bug`, `refactor`) plus custom templates
- `sd plan prompt <seed-id>` — Emit a structured prompt the LLM fills in
- `sd plan submit <seed-id> --plan <file>` — Validate + spawn child seeds
- `sd plan show <pl-id>` — View sections, children, sub-plans
- `sd plan edit <id> [--name | --section <name> <text> | --step <i> --title/--priority/--type]` — In-place field edits; bumps revision
- `sd plan outcome <pl-id> --result success|partial|failure` — Record outcome (storage-only)
- `sd plan review <pl-id> --by <name>` — Record reviewer (informational)

### Before You Finish
1. Close completed issues: `sd close <id>`
2. File issues for remaining work: `sd create --title "..."`
3. Sync and push: `sd sync && git push`
<!-- seeds:end -->

<!-- canopy:start -->
## Prompt Management (Canopy)
<!-- canopy-onboard-v:2 -->

This project uses [Canopy](https://github.com/jayminwest/canopy) for git-native prompt management.

**At the start of every session**, run:
```
cn prime
```

This injects prompt workflow context: commands, conventions, and common workflows.

**Quick reference:**
- `cn list` — List all prompts
- `cn render <name>` — View rendered prompt (resolves inheritance)
- `cn emit --all` — Render prompts to files
- `cn update <name>` — Update a prompt (creates new version)
- `cn sync` — Stage and commit .canopy/ changes

**Do not manually edit emitted files.** Use `cn update` to modify prompts, then `cn emit` to regenerate.

**Mulch metadata:** Prompts can declare expertise dependencies via `mulch.prime.domains`, `mulch.prime.files`, `mulch.budget`, `mulch.on_empty`, plus a top-level `extends_mulch` flag (override-by-default; merge with parent when `true`). Canopy never shells out to `ml` — `cn render --json` surfaces the resolved declaration in a top-level `mulch` field for consumers to act on. See SPEC.md "Mulch Metadata".
<!-- canopy:end -->
