{ pkgs }:

let
  version = "1.4.262";
  release = "https://github.com/stablyai/orca/releases/download/v${version}";
  sources = {
    x86_64-linux = {
      gui = {
        url = "${release}/orca-linux.AppImage";
        hash = "sha256-igLnkE38kjwDHh6H4rgL1ZwnVzMZ8VjiEsuUpJ+Br34=";
      };
      server = {
        url = "${release}/orca-server-linux-x64.tar.gz";
        hash = "sha256-4sXZysx48lcNJIAjiqABrukUGojsXEP5fn6+LGEie5M=";
      };
    };
    aarch64-linux = {
      gui = {
        url = "${release}/orca-linux-arm64.AppImage";
        hash = "sha256-2asHH5UZdMKobS7+XODW4wnzFrWVm9//yuYI6bFTh6w=";
      };
      server = {
        url = "${release}/orca-server-linux-arm64.tar.gz";
        hash = "sha256-ULInVi5DLCc6xdZc3b6DDB2UE/wGviamiTwEk0Er3Dw=";
      };
    };
  };
  src = sources.${pkgs.stdenv.hostPlatform.system};

  pname = "orca-ide";
  guiSrc = pkgs.fetchurl src.gui;
  extracted = pkgs.appimageTools.extractType2 {
    inherit pname version;
    src = guiSrc;
  };

  # Orca が PATH に登録する `orca` は、store 内の Electron を node として直接実行するシムである。
  # FHS 環境の外（Orca のターミナル以外）でも動くよう、Electron 本体と付属ライブラリだけを書き換える。
  # 全体を autoPatchelf しないのは、resources/orcad-template 等が内容のハッシュを検査されるため
  app = pkgs.stdenv.mkDerivation {
    pname = "${pname}-app";
    inherit version;
    src = extracted;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libdrm
      libgbm
      libxkbcommon
      nspr
      nss
      pango
      systemd
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
    ];
    dontAutoPatchelf = true;
    dontStrip = true;
    dontPatchELF = true;
    installPhase = ''
      cp -r . $out
    '';
    postFixup = ''
      autoPatchelf $out/${pname} $out/chrome_crashpad_handler $out/*.so $out/*.so.*
    '';
  };

  # ヘッドレス版。GUI と同じ hook 導入処理を持ち、ディスプレイ無しでビルド中に動かせる
  server = pkgs.stdenv.mkDerivation {
    pname = "orca-server";
    inherit version;
    src = pkgs.fetchzip src.server;
    dontStrip = true;
    dontPatchELF = true;
    # orcad/ 配下は起動時に内容のハッシュを検査されるため、autoPatchelfHook で一括して書き換えると
    # 起動を拒否される。検査対象外の node 本体だけを書き換え、ネイティブモジュールの依存は
    # LD_LIBRARY_PATH で解決する
    installPhase = ''
      cp -r . $out
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib \
        $out/runtimes/node-*/bin/node
    '';
  };
in
{
  # 公式の Linux パッケージと同じく `orca-ide` は CLI にし、GUI はデスクトップエントリから起動する。
  # Orca 用スキルが Orca の外から `orca-ide` を CLI として呼ぶため。
  # nixpkgs の `orca` は GNOME のスクリーンリーダーなので `orca` の名前は使わない
  package =
    let
      gui = pkgs.appimageTools.wrapAppImage {
        pname = "orca-ide-desktop";
        inherit version;
        src = app;
      };
      cli = pkgs.writeShellScriptBin pname ''
        exec ${app}/resources/bin/orca-ide "$@"
      '';
    in
    pkgs.symlinkJoin {
      name = "${pname}-${version}";
      paths = [
        gui
        cli
      ];
      postBuild = ''
        install -Dm444 ${extracted}/${pname}.desktop $out/share/applications/${pname}.desktop
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=orca-ide-desktop'
        cp -r ${extracted}/usr/share/icons $out/share/
      '';
    };

  # このビルドに同梱された Agent 用スキル一式を取り出す
  skills = pkgs.runCommand "orca-skills-${version}" { } ''
    export HOME=$TMPDIR/home
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib
    mkdir -p $HOME
    ${server}/bin/orca-ide skills install --all --agent universal
    cp -r $HOME/.agents/skills $out
  '';

  # Orca は起動のたびに ~/.claude/settings.json と ~/.codex/hooks.json へ自分の hook を書き込み、
  # 書けないとエージェントの状態検出が止まる。Nix 管理のファイルは書けないので、ビルド時に
  # Orca 自身に追記させたものを配置する。hook を Nix で手書きしないのは、Orca がファイルの
  # 文字列を自分の出力と比べており、キー順が違うだけでも書き込みに行くため
  withHooks =
    {
      claudeSettings,
      codexHooks,
      # Orca は PATH 上に見つかったエージェントの分しか hook を入れない
      agents,
    }:
    pkgs.runCommand "orca-agent-hooks-${version}" { nativeBuildInputs = agents; } ''
      export HOME=$TMPDIR/home
      export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib
      mkdir -p $HOME/.claude $HOME/.codex
      install -m644 ${claudeSettings} $HOME/.claude/settings.json
      install -m644 ${codexHooks} $HOME/.codex/hooks.json

      ${server}/bin/orca-ide serve --bind 127.0.0.1 --no-pairing >$TMPDIR/orca.log 2>&1 &
      pid=$!
      written() {
        grep -q 'agent-hooks/claude-hook' $HOME/.claude/settings.json &&
          grep -q 'agent-hooks/codex-hook' $HOME/.codex/hooks.json
      }
      for _ in $(seq 120); do
        written && break
        if ! kill -0 $pid 2>/dev/null; then
          cat $TMPDIR/orca.log >&2
          echo "orca serve exited before writing hooks" >&2
          exit 1
        fi
        sleep 0.5
      done
      kill $pid 2>/dev/null || true
      if ! written; then
        cat $TMPDIR/orca.log >&2
        echo "timed out waiting for orca to write hooks" >&2
        exit 1
      fi

      mkdir -p $out
      cp $HOME/.claude/settings.json $out/claude-settings.json
      cp $HOME/.codex/hooks.json $out/codex-hooks.json
    '';
}
