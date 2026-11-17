# winq-emu のゲスト側で Windows のランチャー（niri-vm.exe）とつなぐスクリプト一式。
# Try Omarchy for Windows（flake の入力 try-omarchy-windows、MIT License）の scripts/guest/ をそのまま使う:
#   clipboard-bridge  クリップボード連携（テキスト・PNG 画像・ファイル/フォルダ、双方向）
#   clipboard-files   ファイルのクリップボード用の小さな ZIP スナップショット（file-transfer が読み込む）
#   file-transfer     ファイル/フォルダの検証付きストリーミング転送
#   reboot-notify     シャットダウン時に、再起動か電源オフかをランチャーに知らせる（上流では
#                     guest-build のパッチの中にしか無いので、このディレクトリに置いている）
# 使い方は nixos-configurations/winq-emu.nix の systemd サービスを参照。
{
  lib,
  tryOmarchy,
  stdenvNoCC,
  makeWrapper,
  bash,
  python3,
  coreutils,
  gnugrep,
  util-linux,
  socat,
  wl-clipboard,
  libnotify,
  systemd,
}:

stdenvNoCC.mkDerivation {
  pname = "winq-guest-bridge";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./reboot-notify
      ./LICENSE
    ];
  };

  nativeBuildInputs = [ makeWrapper ];
  # patchShebangs が #!/bin/bash と #!/usr/bin/env python3 をここから書き換える
  buildInputs = [
    bash
    python3
  ];

  dontConfigure = true;
  dontBuild = true;

  # file-transfer は同じディレクトリの clipboard-files を Python のモジュールとして読み込むので、
  # Python のスクリプトはラップしない（ラッパーの bash スクリプトを読もうとして壊れる）。
  # 外部コマンドは clipboard-bridge のラッパーで PATH に入れ、子のプロセスはそれを引き継ぐ。
  installPhase = ''
    runHook preInstall
    install -Dm755 ${tryOmarchy}/scripts/guest/clipboard-bridge.sh $out/bin/clipboard-bridge
    install -Dm755 ${tryOmarchy}/scripts/guest/clipboard-files $out/bin/clipboard-files
    install -Dm755 ${tryOmarchy}/scripts/guest/file-transfer $out/bin/file-transfer
    install -Dm755 reboot-notify $out/bin/reboot-notify
    install -Dm644 LICENSE $out/share/licenses/winq-guest-bridge/LICENSE
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/clipboard-bridge --prefix PATH : ${
      lib.makeBinPath [
        coreutils
        gnugrep
        util-linux
        socat
        wl-clipboard
        libnotify
      ]
    }:$out/bin
    wrapProgram $out/bin/reboot-notify --prefix PATH : ${
      lib.makeBinPath [
        coreutils
        gnugrep
        socat
        systemd
      ]
    }
  '';

  meta = {
    description = "Guest side of the clipboard bridge and lifecycle notices for the winq-emu VM (from Try Omarchy for Windows)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
