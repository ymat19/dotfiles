# modules

home-manager のモジュール置き場。`home.nix` が `lib/get-nix-files.nix` を使ってディレクトリ内の `.nix` ファイルを読み込むため、ファイルを配置するだけで自動的にインポートされる（手動登録は不要）。`get-nix-files.nix` は階層を再帰せず、指定したディレクトリ直下の `.nix` のみを対象とする。

## 3階層の構成

| 階層 | 役割 | インポート方法 | 例 |
|------|------|----------------|-----|
| `modules/*.nix` | 全環境共通モジュール | `home.nix` が常に自動インポート | `ai-agent`, `shell`, `neovim`, `git-tools`, `tmux` |
| `modules/nixos/*.nix` | NixOS 環境専用モジュール | `home.nix` が `onNixOS` のときのみ自動追加 | `alacritty`, `niri`, `rofi`, `vscode` |
| `modules/nixos/system/*.nix` | NixOS システムレベルモジュール | `flake.nix` でホストごとに明示的にインポート | `nvidia`, `steam`, `xremap`, `dotnet` |

## 補足

- `modules/*.nix` と `modules/nixos/*.nix` は home-manager（ユーザー）レベルの設定。`modules/nixos/system/*.nix` は NixOS システムレベルの設定で、自動インポートの対象外。各ホストに必要なものだけを `flake.nix` で選んでインポートする。
- 新規モジュールを追加するときは、対象の階層に `.nix` ファイルを置く。共通設定なら `modules/`、NixOS 専用なら `modules/nixos/`、システム設定なら `modules/nixos/system/`（あわせて `flake.nix` への追記が必要）。
- このディレクトリ直下の `README.md` は `.nix` ではないため、自動インポートには含まれない。
