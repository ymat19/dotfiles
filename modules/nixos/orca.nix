{ pkgs, ... }:

let
  pname = "orca-ide";
  version = "1.4.262";
  sources = {
    x86_64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
      hash = "sha256-igLnkE38kjwDHh6H4rgL1ZwnVzMZ8VjiEsuUpJ+Br34=";
    };
    aarch64-linux = {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
      hash = "sha256-2asHH5UZdMKobS7+XODW4wnzFrWVm9//yuYI6bFTh6w=";
    };
  };
  src = pkgs.fetchurl sources.${pkgs.stdenv.hostPlatform.system};
  extracted = pkgs.appimageTools.extractType2 { inherit pname version src; };

  # nixpkgs の `orca` は GNOME のスクリーンリーダーなので、公式 CLI 名の orca-ide で入れる
  orca = pkgs.appimageTools.wrapType2 {
    inherit pname version src;
    extraInstallCommands = ''
      install -Dm444 ${extracted}/${pname}.desktop $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      cp -r ${extracted}/usr/share/icons $out/share/
    '';
  };
in
{
  home.packages = [ orca ];
}
