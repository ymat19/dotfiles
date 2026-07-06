{
  config,
  pkgs,
  lib,
  onWSL ? false,
  ...
}:

let
  # WSL 向け mosh-server ラッパー（詳細は scripts/mosh-server-wrap.sh 参照）。
  # ラッパーは実体の mosh-server を $HOME/.nix-profile/bin/mosh-server から探す。
  mosh-server-wrap = pkgs.writeShellScriptBin "mosh-server-wrap" (
    builtins.readFile ../scripts/mosh-server-wrap.sh
  );
in
{
  # mosh は client (mosh / mosh-client) と server (mosh-server) の両方を含む。
  # 全ホストにクライアントとして入れておく。
  # サーバとして使う場合は別途 mosh-server 用 UDP (60000-61000) を
  # ファイアウォールで開放する必要があるが、現状クライアント用途のみ。
  home.packages = lib.mkAfter (
    with pkgs;
    [
      mosh
    ]
  );

  # WSL では mirrored networking のため mosh-server をそのまま使えない。
  # ラッパーを ~/bin に置き、mosh client 側から --server で指定して使う。
  home.file = lib.mkIf onWSL {
    "bin/mosh-server-wrap".source = "${mosh-server-wrap}/bin/mosh-server-wrap";
  };
}
