# https://zenn.dev/watagame/articles/hyprland-nix#screenshot
{ lib, pkgs, config, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    grimblast
    swappy
  ]);

  # Ensure Pictures directory exists
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    pictures = "${config.home.homeDirectory}/Pictures";
  };

  # Swappy configuration
  xdg.configFile."swappy/config".text = ''
    [Default]
    save_dir=$HOME/Pictures
    save_filename_format=%Y-%m-%dT%H:%M:%S.png
  '';

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    bind = $mainMod, S, exec, grimblast save active - | swappy -f -
    bind = $mainMod SHIFT, S, exec, grimblast save area - | swappy -f -
  '';
}
