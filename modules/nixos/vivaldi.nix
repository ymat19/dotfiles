{ pkgs, ... }:

let
  # Browse: 普段の Vivaldi をエージェントに操作させる MCP サーバー（拡張機能と対で動く）。
  # npm 版は Node のランチャーがプラットフォーム別パッケージのバイナリを起動するだけなので、
  # Node を挟まずにバイナリのパッケージを直接取り込む
  browse =
    let
      version = "0.1.5";
      platforms = {
        x86_64-linux = {
          arch = "x64";
          hash = "sha256-i6c/FjIqQlRMrTqXSQv9FJV7l7EItY9DkT5soIijzdc=";
        };
        aarch64-linux = {
          arch = "arm64";
          hash = "sha256-C1UOi2YjmUqUe8mYcEtLxeeW4wcyPeX5R81KvXx9fas=";
        };
      };
      platform = platforms.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.stdenv.mkDerivation {
      pname = "browse";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@opencode/browse-linux-${platform.arch}/-/browse-linux-${platform.arch}-${version}.tgz";
        inherit (platform) hash;
      };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      installPhase = ''
        install -Dm755 bin/browse $out/bin/browse
      '';
    };
in
{
  programs.vivaldi = {
    enable = true;
    # Web Store の ID を宣言すると External Extensions 経由で自動インストールされる
    extensions = [
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
      { id = "mfnicocicmmlkpjnaffgihfjhdgjkdjg"; } # Browse
    ];
  };

  home.packages = [ browse ];

  # browse は既定で自分自身を npm やインストールスクリプトで上書き更新しようとする。
  # Nix 管理下ではバージョンを flake で固定するので自動更新を止める
  home.sessionVariables.OPENCODE_BROWSER_AUTO_UPDATE = "off";

  # `browse install` は各エージェントの設定ファイルを直接書き換えるため使わず、
  # programs.mcp 経由で Claude Code / Codex / OpenCode にまとめて登録する
  programs.mcp.servers.browse = {
    command = "${browse}/bin/browse";
    args = [ "mcp" ];
    env.OPENCODE_BROWSER_AUTO_UPDATE = "off";
  };
}
