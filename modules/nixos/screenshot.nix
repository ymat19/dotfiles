# https://zenn.dev/watagame/articles/hyprland-nix#screenshot
{ lib, pkgs, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    grimblast
    swappy
    zenity
  ]);

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    bind = $mainMod, S, exec, grimblast save active - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"
    bind = $mainMod SHIFT, S, exec, grimblast save area - | swappy -f - -o /tmp/screenshot.png && zenity --question --text="Save?" && cp /tmp/screenshot.png "$HOME/Pictures/$(date +%Y-%m-%dT%H:%M:%S).png"
  '';
}
