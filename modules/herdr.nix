{ inputs, pkgs, ... }:

{
  # 公式リポジトリの flake を直接参照する（旧 herdr-nix はアーカイブ済み）。
  # プリビルドバイナリではなくソースビルドになるため、初回 rebuild は時間がかかる。
  home.packages = [
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;
}
