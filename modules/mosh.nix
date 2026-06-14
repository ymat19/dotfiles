{
  config,
  pkgs,
  lib,
  ...
}:

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
}
