{
  config,
  pkgs,
  lib,
  onWSL ? false,
  ...
}:

let
  # mosh 1.4.0 はクリップボード(OSC 52)を `52;c;` 形式しか受理せず、
  # tmux のコピーモードが送出する種別フィールド空の `52;;` を破棄する。
  # このため mosh 越しだと tmux でコピーしてもローカルのクリップボードへ
  # 反映されない (SSH は透過なので Windows Terminal 等が直接受理でき動く)。
  # mosh-server 側のパーサを `52;<sel>;` (sel は空でも可) を受理するよう
  # パッチして根本解決する。mosh-client は元々 `52;c;` を端末へ再送出するので
  # ローカル端末側は無改造で動作する。
  moshClipboard = pkgs.mosh.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/mosh-osc52-accept-empty-selection.patch ];
  });

  # WSL 向け mosh-server ラッパー（詳細は scripts/mosh-server-wrap.sh 参照）。
  # ラッパーは実体の mosh-server を $HOME/.nix-profile/bin/mosh-server から探すため、
  # home.packages の moshClipboard により自動的にパッチ版 mosh-server が使われる。
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
      moshClipboard
    ]
  );

  # WSL では mirrored networking のため mosh-server をそのまま使えない。
  # ラッパーを ~/bin に置き、mosh client 側から --server で指定して使う。
  home.file = lib.mkIf onWSL {
    "bin/mosh-server-wrap".source = "${mosh-server-wrap}/bin/mosh-server-wrap";
  };
}
