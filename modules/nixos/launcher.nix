{ pkgs, ... }:
{
  # https://zenn.dev/watagame/articles/hyprland-nix#launcher
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    #	Refered: https://github.com/NeshHari/XMonad/blob/main/rofi/.config/rofi/config.rasi
    theme = ../../configs/rofi.rasl;
  };
}
