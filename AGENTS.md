# AGENTS.md

日本語で応答してください。

このリポジトリのビルドコマンド、構成、規約は `CLAUDE.md` を参照してください。

## Codex セットアップ

- `modules/ai-agent.nix` で Codex / Claude Code / MCP / agent skills を管理する。
- NixOS で変更を反映するには `sudo nixos-rebuild switch --flake .#$(hostname) --impure` を実行する。
- Codex hooks に環境固有の追加が必要な場合は `~/.config/codex-local-hooks.json` を作成する。形式は `configs/claude-code/codex-local-hooks.json.sample` を参照。
- Codex hooks は Claude Code hooks と完全互換ではない。特に tool input rewrite は使わず、必要なら `rtk` wrapper を直接選ぶ。
