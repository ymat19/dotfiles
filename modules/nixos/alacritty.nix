{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ../../configs/alacritty.toml);
  };

  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
