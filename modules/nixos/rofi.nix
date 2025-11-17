{ pkgs, ... }:
{
  # https://zenn.dev/watagame/articles/hyprland-nix#launcher
  home.packages = [ pkgs.rofi ];

  home.file.".config/rofi/config.rasi".source = ../../configs/rofi/config.rasi;
  home.file.".config/rofi/rofi.rasi".source = ../../configs/rofi/rofi.rasi;
}
