# AGENTS.md

日本語で応答してください。

このリポジトリのビルドコマンド、構成、規約は `CLAUDE.md` を参照してください。

## Codex セットアップ

- `modules/ai-agent.nix` で Codex / Claude Code / MCP / agent skills を管理する。
- NixOS で変更を反映するには `CLAUDE.md` のフルパス指定で `sudo -n` による再構築を実行する。
- エージェントのシェルで `NoNewPrivs` により `sudo` が拒否された場合は、`systemd-run --user --wait --pipe --collect --expand-environment=no --working-directory="$PWD"` で `/run/current-system/sw/bin/zsh -lc` を起動する。ホスト名と対象コマンドの sudo 許可を確認し、許可済みの作業はそのシェルで反映・検証まで行う。
- Codex hooks に環境固有の追加が必要な場合は `~/.config/codex-local-hooks.json` を作成する。形式は `configs/claude-code/codex-local-hooks.json.sample` を参照。
- Codex hooks は Claude Code hooks と完全互換ではない。特に tool input rewrite は使わない。
