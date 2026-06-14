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
  # 注意: FOD は store path を参照できないため、ここでは無改変のツリーのみ生成し、
  # nix store path を要する patch は後段の overstoryEnv (非FOD) で行う。
  overstoryRaw = pkgs.stdenvNoCC.mkDerivation {
    pname = "overstory-raw";
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
    outputHash = {
      aarch64-linux = "sha256-muXhN/bFFVX94g5x0+ZBylikwXEV6ZCcW4UHlktEEsE=";
      x86_64-linux = "sha256-ykLwEKtNExmD6WqFCIgx63oan5fa+MlyH+dipIyqc9o=";
    }.${pkgs.stdenv.hostPlatform.system};
  };

  # ov は全エージェントセッションの `git push` を無条件ブロックする hook を起動毎に
  # 再生成・上書きする (生成源は下記4ソース)。PRベース統合フローでは feature/worktree
  # ブランチの push が必須のため、「main への push のみブロック」へ恒久緩和する。
  # 判定方式は .overstory/hooks.json と一貫させ「コマンドが git push かつ main を含む時のみ block」。
  # substituteInPlace は検索文字列が見つからないとビルド失敗する (--replace-fail) ため、
  # 文字列はディスク上の実バイト列と厳密一致させ、escapeShellArg で安全に渡す。
  esc = pkgs.lib.escapeShellArg;
  # 共通の reason 文言 (hooks-deployer.ts と pi-guards.ts で同一)。
  pushReasonFrom = "git push is blocked — use ov merge to integrate changes, push manually when ready";
  pushReasonTo = "git push to main is blocked — open a PR with gh pr create instead; pushing feature/worktree branches is allowed";

  # FOD 出力に nix store path を要する patch を適用する後段 (非FOD なので store 参照可)。
  # overstory は tmux セッション spawn で /bin/bash をハードコードするが (worktree/tmux.ts)、
  # NixOS には /bin/bash が無く coordinator/worker の claude 起動が即死する。
  # 実在する nix の bash 絶対パスへ置換する。あわせて push ガードを main 限定へ緩和し、
  # Web UI からサブスク枠 coordinator を操作可能にする patch を適用する。
  # bun 実行 (patch-web-coordinator.ts) のため nativeBuildInputs=[pkgs.bun] と HOME が必要。
  overstoryEnv =
    pkgs.runCommand "overstory-env" { nativeBuildInputs = [ pkgs.bun ]; } ''
      export HOME=$TMPDIR
      cp -R --no-preserve=mode,ownership ${overstoryRaw} $out
      substituteInPlace $out/src/worktree/tmux.ts \
        --replace-quiet '/bin/bash -c' '${pkgs.bash}/bin/bash -c'

      # 1) Claude runtime の hook 生成本体 (deployHooks → settings.local.json)。
      substituteInPlace $out/src/agents/hooks-deployer.ts \
        --replace-fail ${esc "grep -qE '\\\\bgit\\\\s+push\\\\b'; then"} ${esc "grep -qE '\\\\bgit\\\\s+push\\\\b' && echo \\\"$CMD\\\" | grep -qE '\\\\bmain\\\\b'; then"} \
        --replace-fail ${esc pushReasonFrom} ${esc pushReasonTo}

      # 2) `ov init` が書き出す settings.local.json テンプレート。
      substituteInPlace $out/src/commands/init.ts \
        --replace-fail ${esc "grep -qE \\'\\\\bgit\\\\s+push\\\\b\\'; then"} ${esc "grep -qE \\'\\\\bgit\\\\s+push\\\\b\\' && echo \"$CMD\" | grep -qE \\'\\\\bmain\\\\b\\'; then"} \
        --replace-fail ${esc "git push is blocked by overstory — merge locally, push manually when ready"} ${esc "git push to main is blocked by overstory — open a PR with gh pr create instead; pushing feature/worktree branches is allowed"}

      # 3) Pi runtime のバッシュガード。
      substituteInPlace $out/src/runtimes/pi-guards.ts \
        --replace-fail ${esc "if (/\\\\bgit\\\\s+push\\\\b/.test(cmd)) {"} ${esc "if (/\\\\bgit\\\\s+push\\\\b/.test(cmd) && /\\\\bmain\\\\b/.test(cmd)) {"} \
        --replace-fail ${esc pushReasonFrom} ${esc pushReasonTo}

      # 4) 非実装エージェント向け危険コマンド一覧 (DANGEROUS_BASH_PATTERNS) の git push エントリ。
      substituteInPlace $out/src/agents/guard-rules.ts \
        --replace-fail ${esc "\"\\\\bgit\\\\s+push\\\\b\","} ${esc "\"\\\\bgit\\\\s+push\\\\b.*\\\\bmain\\\\b\","}

      # Web UI からサブスク枠 (tmux) coordinator へ send/ask できるようにする patch
      # (既定は tmux-only として Web からの操作を拒否する。詳細は patch スクリプト参照)。
      bun ${../configs/overstory/patch-web-coordinator.ts} \
        $out/src/commands/serve/coordinator-actions.ts
    '';

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

  # os-eco エコシステム CLI 群 (overstory が連携する seeds/mulch/canopy)。
  # いずれも bun TS CLI でビルド不要。npm から固定バージョンを取得し node_modules を
  # FOD で確定させ、各 bin を bun ラッパーで起動する。
  osEcoPkgJson = builtins.toJSON {
    name = "os-eco-clis";
    private = true;
    dependencies = {
      "@os-eco/seeds-cli" = "0.5.10";
      "@os-eco/mulch-cli" = "0.10.7";
      "@os-eco/canopy-cli" = "0.2.6";
    };
  };
  osEcoEnv = pkgs.stdenvNoCC.mkDerivation {
    pname = "os-eco-clis-env";
    version = "0";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.bun
      pkgs.cacert
    ];
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export NODE_EXTRA_CA_CERTS=$SSL_CERT_FILE
      mkdir -p build && cd build
      cp ${pkgs.writeText "os-eco-package.json" osEcoPkgJson} package.json
      bun install --no-progress --ignore-scripts
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R package.json node_modules $out/
      runHook postInstall
    '';
    dontFixup = true;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = {
      aarch64-linux = "sha256-T98SmjCHUTAyi+cHIJwfg9QQzz+ZsKTi3DBBg9tg1IY=";
      x86_64-linux = "sha256-enODnB4NuysHq7z7UoSmLwFcqwgQ8R9rSdmCr7Frvck=";
    }.${pkgs.stdenv.hostPlatform.system};
  };
  osEcoBin =
    name: rel:
    pkgs.writeShellScriptBin name ''
      export PATH=${
        pkgs.lib.makeBinPath [
          pkgs.bun
          pkgs.tmux
          pkgs.git
        ]
      }:$PATH
      exec ${pkgs.bun}/bin/bun ${osEcoEnv}/node_modules/${rel} "$@"
    '';
  os-eco-clis = pkgs.symlinkJoin {
    name = "os-eco-clis";
    paths = [
      (osEcoBin "sd" "@os-eco/seeds-cli/src/index.ts")
      (osEcoBin "mulch" "@os-eco/mulch-cli/src/cli.ts")
      (osEcoBin "ml" "@os-eco/mulch-cli/src/cli.ts")
      (osEcoBin "cn" "@os-eco/canopy-cli/src/index.ts")
    ];
  };
in
{
  home.packages = [
    agent-deck
    overstory
    overstory-ov
    os-eco-clis
  ];
}
