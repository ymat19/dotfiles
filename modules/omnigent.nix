{
  lib,
  pkgs,
  ...
}:
# omnigent (Databricks の OSS メタハーネス) を導入する。
#
# omnigent はまだ nixpkgs / llm-agents.nix のどちらにもパッケージ化されていない
# alpha 段階の Python ツールなので、uv tool で導入する (bootstrap 方式)。
# Nix では実行に必要なシステム依存だけを宣言的に揃え、本体は activation script で
# `uv tool install` する。シムは ~/.local/bin に置かれ、既に PATH 上にある。
#
# 依存: uv, python3.12+, Node.js 22+ (内部ハーネス起動用), tmux (native wrapper),
#       git, bubblewrap (Linux の OS レベルサンドボックス。必須)。
#       uv / tmux / git は別モジュールで導入済み。
let
  # 実行時に PATH へ通す依存。omnigent 本体が子プロセスとして呼ぶ。
  runtimeDeps = [
    pkgs.uv
    pkgs.nodejs_22
    pkgs.git
    pkgs.tmux
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];
in
{
  home.packages = [
    pkgs.nodejs_22
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];

  # uv tool で omnigent を導入する。未導入のときだけ install し、毎回の rebuild を
  # ネットワーク依存にしない (失敗しても switch 全体を止めない)。更新は明示的に
  # `uv tool upgrade omnigent` で行う。
  home.activation.installOmnigent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${lib.makeBinPath runtimeDeps}:$PATH"
    if ! ${pkgs.uv}/bin/uv tool list 2>/dev/null | grep -q '^omnigent'; then
      echo "omnigent: 未導入のため uv tool install を実行します..."
      $DRY_RUN_CMD ${pkgs.uv}/bin/uv tool install --python 3.12 omnigent \
        || echo "omnigent: uv tool install に失敗しました。ネットワーク接続を確認のうえ 'uv tool install --python 3.12 omnigent' を手動実行してください。" >&2
    fi
  '';
}
