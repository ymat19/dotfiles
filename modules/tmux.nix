
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
    plugins = with pkgs.tmuxPlugins; [
      #tmux-resurrect
      #tmux-continuum
      #tmux-sensible
      #tmux-prefix-highlight
      #tmux-copycat
      sensible
      logging
      {
        plugin = tokyo-night-tmux;
        extraConfig = ''
### Tokyo Night Theme configuration
set -g @tokyo-night-tmux_show_hostname 1
set -g @tokyo-night-tmux_transparent 1
        '';
      }
    ];
  };

}
