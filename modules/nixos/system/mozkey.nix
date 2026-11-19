{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  inherit (pkgs.mozc) bazel mkVendorDeps setupBazelVendor;

  pname = "ibus-mozkey";
  version = "1.1.0";
  src = pkgs.fetchFromGitHub {
    owner = "koyasi777";
    repo = "mozkey";
    rev = "7f8af6b852907aab93d1551530407a434c6f044c";
    hash = "sha256-0e4HYAz8gl/EWOWJDc5ERMqYh7dcZ82dWPNbK5HDtZI=";
  };

  nativeBuildInputs = [
    bazel
    pkgs.pkg-config
    pkgs.python3
    pkgs.qt6.wrapQtAppsHook
    pkgs.unzip
    pkgs.writableTmpDirAsHomeHook
  ];
  buildInputs = with pkgs; [
    glib
    ibus
    libglvnd
    qt6.qtbase
  ];
  bazelArgs = pkgs.mozc.bazelCommonArgs ++ [
    "--action_env=C_INCLUDE_PATH=${lib.makeIncludePath buildInputs}"
    "--action_env=CPLUS_INCLUDE_PATH=${lib.makeIncludePath buildInputs}"
    "--action_env=LIBRARY_PATH=${lib.makeLibraryPath buildInputs}"
    "//gui/tool:mozc_tool"
    "//renderer/qt:mozc_renderer"
    "//server:mozc_server"
    "//unix:icons"
    "//unix/ibus:ibus_mozc"
  ];
  vendorDeps = mkVendorDeps {
    inherit
      pname
      version
      src
      nativeBuildInputs
      buildInputs
      bazelArgs
      ;
    hash = "sha256-Nm1WX7wex8Pvy6CHSlZzIlwVzxFaDkwZMWzxHXJqgA8=";
  };

  mozkey = pkgs.stdenv.mkDerivation {
    inherit
      pname
      version
      src
      nativeBuildInputs
      buildInputs
      ;

    strictDeps = true;
    __structuredAttrs = true;
    env.USE_BAZEL_VERSION = bazel.version;
    env.USER = "nixbld";

    postPatch = ''
      cd src
      ${setupBazelVendor vendorDeps}

      substituteInPlace config.bzl \
        --replace-fail "/usr/bin/xdg-open" "${pkgs.xdg-utils}/bin/xdg-open" \
        --replace-fail "/usr/" "$out/"

      # Qt 6.12 の uic は .ui のクラス名に先頭の名前空間区切りを許さない。
      substituteInPlace gui/dictionary_tool/dictionary_tool.ui \
        --replace-fail '::mozc::gui::DictionaryContentTableWidget' 'mozc::gui::DictionaryContentTableWidget'

      # リリースタグが参照する daily 辞書はローカル生成物なので、同梱の sample を使う。
      substituteInPlace data/dictionary_oss/BUILD.bazel \
        --replace-fail 'mozcdic_ut_daily_local' 'mozcdic_ut_sample'
    '';

    buildPhase = ''
      runHook preBuild
      nice -n 19 bazel --host_jvm_args="-XX:ActiveProcessorCount=$NIX_BUILD_CORES" build \
        --jobs="$NIX_BUILD_CORES" --action_env=HOME \
        --lockfile_mode=error --vendor_dir=vendor_dir ${lib.escapeShellArgs bazelArgs}
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm555 bazel-bin/server/mozc_server "$out/lib/mozkey/mozc_server"
      install -Dm555 bazel-bin/gui/tool/mozc_tool "$out/lib/mozkey/mozc_tool"
      install -Dm555 bazel-bin/renderer/qt/mozc_renderer "$out/lib/mozkey/mozc_renderer"
      install -Dm555 bazel-bin/unix/ibus/ibus_mozc "$out/lib/ibus-mozkey/ibus-engine-mozkey"
      install -Dm444 bazel-bin/unix/ibus/mozkey.xml "$out/share/ibus/component/mozkey.xml"
      install -Dm444 data/images/product_icon_32bpp-128.png "$out/share/ibus-mozkey/product_icon.png"
      mkdir -p "$out/share/icons/mozkey"
      unzip -q bazel-bin/unix/icons.zip -d "$out/share/icons/mozkey"
      install -Dm444 ../LICENSE "$out/share/licenses/$pname/LICENSE"

      runHook postInstall
    '';

    # Qt の自動ラッパーは lib/mozkey を走査しない。
    postFixup = ''
      wrapQtApp "$out/lib/mozkey/mozc_tool"
      wrapQtApp "$out/lib/mozkey/mozc_renderer"
    '';

    passthru = { inherit vendorDeps; };
    meta = {
      homepage = "https://github.com/koyasi777/mozkey";
      description = "Japanese input method with delayed live conversion for IBus";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.linux;
      isIbusEngine = true;
    };
  };
in
{
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus = {
      engines = [ mozkey ];
      waylandFrontend = true;
    };
  };

  home-manager.users.${username} = {
    # NixOS の既定の起動コマンドでは Niri の Wayland 入力プロトコルに接続しない。
    xdg.configFile."autostart/ibus-daemon.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=IBus
      Exec=${config.i18n.inputMethod.package}/bin/ibus start --type wayland
    '';

    dconf.settings = {
      "desktop/ibus/general".preload-engines = [
        "xkb:us::eng"
        "mozkey-on"
      ];
      # IBus 既定の Super+Space は Niri のスクラッチパッドと競合する。
      "desktop/ibus/general/hotkey".triggers = [ "<Control>space" ];
    };
  };
}
