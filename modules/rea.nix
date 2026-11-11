{
  pkgs,
  inputs,
  ...
}:

let
  # REA は起動時に engines（^22.23.4 || ^24.22.1 || >=26.12.1）を厳密に検査して終了する。
  # 固定中の nixpkgs の Node はどれも届かないが、nixpkgs 全体の更新は影響が大きいので
  # REA の実行環境だけ新しい nixpkgs から取る
  node = inputs.nixpkgs-node.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nodejs_24;

  # Nix でビルドせず npx で取得する。ネイティブバインディングと生成物を含む npm パッケージで、
  # buildNpmPackage 化すると更新の追従コストが見合わないため。
  # バージョンは skill の入力（flake.nix の rea）と揃えて固定する
  rea-mcp = pkgs.writeShellApplication {
    name = "rea-mcp";
    # rea.mjs の shebang は env node なので PATH 先頭の Node が使われる。
    # Linux ではプロセス所有確認に procps の ps が要る
    runtimeInputs = [
      node
      pkgs.procps
    ];
    text = ''
      exec npx -y rea-agents@6.8.0 mcp "$@"
    '';
  };
in
{
  programs.mcp.servers.rea.command = "${rea-mcp}/bin/rea-mcp";

  programs.agent-skills = {
    sources.rea = {
      path = inputs.rea;
      subdir = ".agents/skills";
    };
    skills.enable = [ "reverse-engineer-anything" ];
  };
}
