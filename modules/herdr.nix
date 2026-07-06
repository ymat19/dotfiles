{ inputs, pkgs, ... }:

{
  # herdr-nix: Cachix (herdr-nix.cachix.org) 付き community flake のプリビルドバイナリ
  home.packages = [
    inputs.herdr-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;
}
