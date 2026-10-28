{ pkgs, lib, ... }:

let
  version = "1.3.0";

  arch = if pkgs.stdenv.hostPlatform.isAarch64 then "linux-arm64" else "linux";
  hashes = {
    linux = "sha256-FrkEfofGW0Gh+O3uJv0zL/4Tvx9crLFjFAdPgX3t7Yo=";
    linux-arm64 = "sha256-zbaK2uamJLiISMhhisHhnjNHiVwwAobR/TMhxGE6NxU=";
  };

  # 本体 (C# の NativeAOT) と Mozc ヘルパーはリリース成果物を使う。
  # ソースからだと .NET の NuGet 依存の固定と Mozc の Bazel ビルドが要り、割に合わない。
  prebuilt = pkgs.fetchzip {
    url = "https://github.com/yksr-melt/Meltype/releases/download/v${version}/Meltype-${version}-${arch}.zip";
    hash = hashes.${arch};
  };

  # fcitx5 アドオンだけはソースからビルドする。リリースの meltype.so は Ubuntu の
  # fcitx5 向けにビルドされており、nixpkgs の fcitx5 とは C++ ABI が一致する保証がない。
  meltype = pkgs.stdenv.mkDerivation {
    pname = "fcitx5-meltype";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "yksr-melt";
      repo = "Meltype";
      rev = "v${version}";
      hash = "sha256-WihlGZQCejXSdhRQD7WJQnamwrxmjqLNecop7mDlk9s=";
    };
    sourceRoot = "source/linux/fcitx5";

    # 上流はターミナルの入力欄をコード入力 (コメント・文字列の外は英数のまま通す) にするが、
    # Linux 版にはコードの行を日本語へ切り替える手段が無く、ターミナル上の AI エージェントへ
    # 日本語の文章を打てない。英単語は Meltype が見分けて英字のまま出すので、常に通常の入力にする。
    postPatch = ''
      substituteInPlace meltype.cpp \
        --replace-fail 'ic->capabilityFlags().test(fcitx::CapabilityFlag::Terminal) ? 1 : 0' '0'
    '';

    nativeBuildInputs = with pkgs; [
      cmake
      autoPatchelfHook
    ];
    buildInputs = with pkgs; [
      fcitx5
      stdenv.cc.cc.lib
    ];

    cmakeFlags = [ "-DMELTYPE_DIR=${placeholder "out"}/lib/meltype" ];

    # CMakeLists.txt に install ルールが無いので手で置く
    installPhase = ''
      runHook preInstall
      install -Dm755 meltype.so $out/lib/fcitx5/meltype.so
      install -Dm644 ../meltype-addon.conf $out/share/fcitx5/addon/meltype.conf
      install -Dm644 ../meltype.conf $out/share/fcitx5/inputmethod/meltype.conf
      substituteInPlace $out/share/fcitx5/inputmethod/meltype.conf \
        --replace-fail '@DIR@' "$out/lib/meltype"

      install -Dm755 ${prebuilt}/libMeltypeNative.so -t $out/lib/meltype
      install -Dm644 ${prebuilt}/icon.png -t $out/lib/meltype
      install -Dm755 ${prebuilt}/mozc/meltype_mozc_helper -t $out/lib/meltype/mozc
      runHook postInstall
    '';

    # .NET ランタイムは ICU と OpenSSL を NEEDED ではなく dlopen で探すため、
    # autoPatchelf では拾われない。dlopen は呼び出し元の RUNPATH を見るので足しておく。
    postFixup = ''
      patchelf --add-rpath ${
        lib.makeLibraryPath [
          pkgs.icu
          pkgs.openssl
        ]
      } $out/lib/meltype/libMeltypeNative.so
    '';

    meta = {
      description = "Japanese input method that auto-switches between Japanese and English (fcitx5 addon)";
      homepage = "https://github.com/yksr-melt/Meltype";
      license = lib.licenses.gpl3Plus;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  };
in
{
  i18n.inputMethod.fcitx5 = {
    addons = [ meltype ];

    # 設定すると ~/.config/fcitx5 全体が store への symlink になり、fcitx5-configtool での
    # 変更は保存されなくなる。入力メソッドの一覧はここで管理する。
    # mozc は Meltype がプレビュー版のうちの逃げ道として残す。
    settings.inputMethod = {
      GroupOrder."0" = "Default";
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "meltype";
      };
      "Groups/0/Items/0".Name = "keyboard-us";
      "Groups/0/Items/1".Name = "meltype";
      "Groups/0/Items/2".Name = "mozc";
    };
  };
}
