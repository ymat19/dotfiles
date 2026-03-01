# AGENT.md

worktreeエージェント向けの情報。変更を適用するにはビルドが必要。

## ビルドコマンド

```bash
# NixOS 環境（現在のホスト: air）
sudo nixos-rebuild switch --flake .#air --impure

# HomeManager スタンドアロン環境（非NixOS）
home-manager switch --flake . --impure

# 構文チェックのみ（ビルドなし）
nix flake check --no-build
```

ホスト名は環境に応じて変更すること: main, mini, dyna, air, ymat19
