{
  pkgs,
  lib,
  ...
}:
let
  pname = "emdash";
  version = "1.1.27";

  # アイコンは arch 非依存。x86_64 AppImage の中身を抽出して流用する
  # （extractType2 は squashfs を展開するだけなので aarch64 上でも動く）。
  appimageSrc = pkgs.fetchurl {
    url = "https://github.com/generalaction/emdash/releases/download/v${version}/emdash-x86_64.AppImage";
    sha256 = "009bn5h8wq09a25gxih03x4hnhcdy7zqrzfl8n878rm822pigqix";
  };
  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version;
    src = appimageSrc;
  };
  icon = "${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/emdash.png";
  desktopItem = pkgs.makeDesktopItem {
    name = "emdash";
    desktopName = "Emdash";
    exec = "emdash %U";
    icon = "emdash";
    comment = "Run AI coding agents in parallel, each in its own git worktree";
    categories = [ "Development" ];
    startupWMClass = "Emdash";
  };

  # x86_64: 公式 AppImage を FHS ラップ（堅牢・軽量）
  emdash-appimage = pkgs.appimageTools.wrapType2 {
    inherit pname version;
    src = appimageSrc;
    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/emdash.desktop -t $out/share/applications
      substituteInPlace $out/share/applications/emdash.desktop \
        --replace-warn 'Exec=AppRun --no-sandbox' 'Exec=emdash'
      install -Dm444 ${icon} $out/share/icons/hicolor/1024x1024/apps/emdash.png
    '';
  };

  # aarch64: 上流が Linux arm64 バイナリを配布していないためソースからビルドする。
  # Electron アプリを electron-builder で組み立て、実行系には nixpkgs の
  # electron_40 を使う（同梱 electron は NixOS 非対応のため）。
  nodejs = pkgs.nodejs_24;
  pnpm = pkgs.pnpm_10.override { inherit nodejs; };
  electron = pkgs.electron_40;
  electronVersion = "40.7.0";
  srcTarball = pkgs.fetchurl {
    name = "emdash-${version}-src.tar.gz";
    # github.com/archive 経由は環境によっては弾かれるため codeload を直接指定
    url = "https://codeload.github.com/generalaction/emdash/tar.gz/refs/tags/v${version}";
    hash = "sha256-6P6xhTmz+Q3sognD+AVeAhK1fQhA9eCffoBg7GYouRY=";
  };
  electronZip = pkgs.fetchurl {
    url = "https://github.com/electron/electron/releases/download/v${electronVersion}/electron-v${electronVersion}-linux-arm64.zip";
    hash = "sha256-/dUAOLRDa5d1hdo94KTxGK79h/Ex7jQqZR1h6R6qFQs=";
  };
  electronDistDir = pkgs.runCommand "emdash-electron-dist" { } ''
    mkdir -p $out
    cp ${electronZip} $out/electron-v${electronVersion}-linux-arm64.zip
  '';
  emdash-source = pkgs.stdenv.mkDerivation {
    inherit pname version;
    src = srcTarball;

    pnpmDeps = pnpm.fetchDeps {
      inherit pname version;
      src = srcTarball;
      fetcherVersion = 1;
      hash = "sha256-SRBV1x0BGgjgX21umMgUH6en+j+rugdM2ecWZv1haC0=";
    };

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpm.configHook
      pkgs.python3
      pkgs.pkg-config
      pkgs.git
      pkgs.dpkg
      pkgs.rpm
      pkgs.makeWrapper
      pkgs.autoPatchelfHook
    ];
    buildInputs = [
      pkgs.libsecret
      pkgs.sqlite
      pkgs.zlib
      pkgs.libutempter
      pkgs.openssl
      pkgs.stdenv.cc.cc.lib # native .node が必要とする libstdc++
    ];

    # pnpm のシンボリックリンク型 node_modules を electron-builder が asar 化すると
    # production 依存コレクタが transitive を取りこぼす (@octokit/endpoint not found)。
    # 完全に npm フラットな node_modules にして全 transitive を top-level へ出す。
    postPatch = ''
      cat >> .npmrc <<'NPMRC'
node-linker=hoisted
shamefully-hoist=true
hoist-pattern[]=*
confirm-modules-purge=false
NPMRC
    '';

    env = {
      npm_config_build_from_source = "true";
      npm_config_manage_package_manager_versions = "false";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
      CI = "true"; # pnpm prune の TTY 確認をスキップ
      # node-gyp が electronjs.org からヘッダをDLしようとして失敗するため、
      # nixpkgs の electron ヘッダをローカル供給する。
      npm_config_nodedir = "${electron.headers}";
    };

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR/emdash-home"
      mkdir -p "$HOME"
      pnpm config set manage-package-manager-versions false

      # cpu-features は ssh2 のオプショナル依存。buildcheck.gypi 未生成で
      # ネイティブビルドが失敗するが、無くても ssh2 は純JSで動くので除去。
      find node_modules -type d -name 'cpu-features*' -prune -exec rm -rf {} + 2>/dev/null || true

      pnpm run build

      # electron-builder は native モジュール (better-sqlite3, node-pty) を
      # electron ABI 向けに node_modules 内でリビルドする。asar 出力は使わない
      # (electron-builder の本番依存コレクタは pnpm の transitive を取りこぼし
      # @octokit/endpoint 等が欠落するため)。リビルド後の完全な node_modules を
      # そのままアプリに同梱する。
      pnpm exec electron-builder --linux --dir \
        -c.electronDist=${electronDistDir} \
        -c.electronVersion=${electronVersion}

      # devDependencies の重い不要物だけ除去（実行時不要・サイズ削減）。
      rm -rf node_modules/electron node_modules/playwright node_modules/playwright-core \
        node_modules/.cache 2>/dev/null || true
      # 上記削除で宙吊りになった .bin シンボリックリンク等を掃除
      # (nixpkgs の noBrokenSymlinks チェックを通すため)。
      find node_modules -xtype l -delete 2>/dev/null || true
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # asar を使わず、production node_modules ごとアプリディレクトリを構成し、
      # nixpkgs の electron で main (out/main/index.js) を起動する。
      appdir="$out/share/emdash/app"
      mkdir -p "$appdir"
      cp -R out package.json "$appdir/"
      [ -d drizzle ] && cp -R drizzle "$appdir/"
      cp -R node_modules "$appdir/node_modules"

      makeWrapper ${electron}/bin/electron "$out/bin/emdash" \
        --add-flags "$appdir" \
        --add-flags "--no-sandbox" \
        --inherit-argv0

      install -Dm444 ${desktopItem}/share/applications/emdash.desktop \
        -t $out/share/applications
      install -Dm444 ${icon} $out/share/icons/hicolor/1024x1024/apps/emdash.png
      runHook postInstall
    '';

    meta = {
      description = "Emdash - multi-agent orchestration desktop app";
      homepage = "https://emdash.sh";
      license = lib.licenses.asl20;
      platforms = [ "aarch64-linux" ];
    };
  };

  emdash =
    if pkgs.stdenv.hostPlatform.isAarch64 then emdash-source else emdash-appimage;
in
{
  # Emdash: AI コーディングエージェントを並列実行するオーケストレーター。
  # x86_64 は公式 AppImage、aarch64 (air) は上流バイナリが無いためソースビルド。
  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ emdash ];
}
