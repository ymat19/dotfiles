{ config, pkgs, lib, ... }:

{
  home.packages = lib.mkAfter (with pkgs; [
    hyprland
    wofi
    kitty
  ]);

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      bind = [
        "SUPER, R, exec, wofi --show drun"
        "SUPER, Q, exec, kitty"
      ];
    };
  };
}
