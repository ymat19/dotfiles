{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [ (import ../../lib/orca.nix { inherit pkgs; }).package ];

  # エージェントが Orca を操作する `orca` コマンド。Orca は PATH 上の `orca` が自分の作るシムを
  # 直接指すリンクかどうかで導入済みかを判定し、そうでなければ毎回導入を勧める。
  # home.file だと store を経由したリンクになり判定に通らないので、activation で直接張る。
  # シムは Orca が起動時に作るので、初回起動まではリンク切れになる
  home.activation.linkOrcaCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "${config.xdg.configHome}/orca/linux-orca-cli-shim/orca" "$HOME/.local/bin/orca"
  '';
}
