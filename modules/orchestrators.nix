{
  pkgs,
  inputs,
  ...
}:
let
  # agent-deck: Go 製のマルチエージェント統括ツール (conductor が子セッションを統括)。
  # web UI 用の CSS は internal/web/static/styles.css がコミット済みで go:embed されるため、
  # tailwind ビルドは不要。subPackages で本体バイナリのみビルドする。
  agent-deck = pkgs.buildGoModule {
    pname = "agent-deck";
    version = "0-unstable-2026-06-14";
    src = inputs.agent-deck;
    vendorHash = "sha256-GyG71/iR2R4mq1vOYcL4rGXh0RQIMNeWj+WtjF75KCg=";
    subPackages = [ "cmd/agent-deck" ];
    # テストは tmux / claude / ネットワークを要求するためビルド時はスキップ。
    doCheck = false;
    env.GOTOOLCHAIN = "local";
    ldflags = [
      "-s"
      "-w"
      "-X main.Version=nix-unstable"
    ];
    # tmux / git を実行時 PATH に確保 (子セッションの spawn・worktree 操作に必要)。
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/agent-deck \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.tmux
            pkgs.git
          ]
        }
    '';
  };

  # overstory: bun 製のマルチエージェント統括 CLI (Orchestrator Agent + ov serve の web UI)。
  # CLI は src/index.ts を bun で直接実行する形態。web UI (ov serve) は ui/dist を必要とするが
  # 未コミットのため、FOD (ネットワーク許可ビルド) 内で bun install と ui ビルドを実行し、
  # node_modules と ui/dist を含んだソースツリーを固定出力として確定させる。
  overstoryEnv = pkgs.stdenvNoCC.mkDerivation {
    pname = "overstory-env";
    version = "0.11.0";
    src = inputs.overstory;
    nativeBuildInputs = [
      pkgs.bun
      pkgs.cacert
    ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export NODE_EXTRA_CA_CERTS=$SSL_CERT_FILE
      bun install --frozen-lockfile --no-progress
      # ui の devDep に npm 版 bun パッケージがあり postinstall が aarch64 バイナリ取得に
      # 失敗するため --ignore-scripts で回避 (native optional deps の解決は維持される)。
      # ビルドは型チェック (tsc, node 依存) を避け、バンドル本体の build.ts を bun で直接実行。
      ( cd ui && bun install --frozen-lockfile --no-progress --ignore-scripts && bun ./build.ts )
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R . $out/
      # ランタイムでは不要な ui のビルド用 node_modules を削減 (ui/dist は残す)。
      rm -rf $out/ui/node_modules $out/.git
      runHook postInstall
    '';
    dontFixup = true;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-muXhN/bFFVX94g5x0+ZBylikwXEV6ZCcW4UHlktEEsE=";
  };

  overstory = pkgs.writeShellScriptBin "overstory" ''
    export PATH=${
      pkgs.lib.makeBinPath [
        pkgs.bun
        pkgs.tmux
        pkgs.git
      ]
    }:$PATH
    exec ${pkgs.bun}/bin/bun ${overstoryEnv}/src/index.ts "$@"
  '';
  # `ov` は overstory の公式短縮エイリアス。
  overstory-ov = pkgs.runCommand "overstory-ov" { } ''
    mkdir -p $out/bin
    ln -s ${overstory}/bin/overstory $out/bin/ov
  '';
in
{
  home.packages = [
    agent-deck
    overstory
    overstory-ov
  ];
}
