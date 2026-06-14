{
  config,
  pkgs,
  lib,
  ...
}:

{
  # mosh は client (mosh / mosh-client) と server (mosh-server) の両方を含む。
  # 全ホストに入れておき、どのマシンからでも接続元・接続先になれるようにする。
  # NixOS ホストのファイアウォール (UDP 60000-61000) は
  # modules/nixos/system/mosh.nix で開放する。
  home.packages = lib.mkAfter (
    with pkgs;
    [
      mosh
    ]
  );
}
