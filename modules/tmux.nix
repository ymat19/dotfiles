
{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-f";
    mouse = true;
    customPaneNavigationAndResize = true;
    shell = "${pkgs.zsh}/bin/zsh";
    extraConfig = builtins.readFile ../configs/tmux.conf;
  };
}
