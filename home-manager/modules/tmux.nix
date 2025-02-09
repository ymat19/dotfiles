
{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    prefix = "C-f";
    customPaneNavigationAndResize = true;
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
