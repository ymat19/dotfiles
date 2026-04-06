# AGENT.md

worktreeエージェント向けの情報。変更を適用するにはビルドが必要。

ビルドコマンド・アーキテクチャ・規約については [CLAUDE.md](./CLAUDE.md) を参照。

## 特定環境専用 Claude Code hooks のセットアップ

公開リポジトリに含められない特定環境専用の hooks を追加する仕組み。

### 手順

1. `~/.config/claude-local-hooks.json` を作成する（サンプル: `configs/claude-code/local-hooks.json.sample`）

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "/path/to/company-hook.sh"
        }
      ]
    }
  ]
}
```

2. rebuild する（`sudo nixos-rebuild switch --flake .#<host> --impure`）

### 仕組み

- `modules/ai-agent.nix` が `builtins.readFile` で JSON を読み込み、既存 hooks とリスト結合する
- `--impure` ビルド時のみ有効（既に必須オプション）
- ファイルがなければ既存動作と同一
- JSON の変更・削除は次の rebuild で反映される
