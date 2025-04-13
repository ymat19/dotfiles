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
        "SUPER, D, exec, wofi --show drun"
        "SUPER, Return, exec, kitty"
        "SUPER, Q, killactive"
        "SUPER, h, movefocus, l"
        "SUPER, l, movefocus, r"
        "SUPER, j, movefocus, d"
        "SUPER, k, movefocus, u"
        "SUPER, space, togglefloating"
        "SUPER_SHIFT, E, exit"
      ];
    };
  };
}
