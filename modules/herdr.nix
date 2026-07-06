{ inputs, pkgs, ... }:

{
  # herdr: エージェント対応ターミナルマルチプレクサ（旧 tmux の後継）。
  # Cachix (herdr-nix.cachix.org) 付き community flake からプリビルドバイナリを取得する。
  home.packages = [
    inputs.herdr-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # 設定は ~/.config/herdr/config.toml を参照する
  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;
}
