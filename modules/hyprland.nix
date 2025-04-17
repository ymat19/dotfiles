{ config, pkgs, lib, onNixOS, ... }:

(if onNixOS
then
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
    i18n.inputMethod = {
      enabled = "fcitx5";
      fcitx5.addons = with pkgs; [ fcitx5-mozc fcitx5-configtool ];
    };

    home.sessionVariables = lib.mkAfter ({
      XMODIFIERS = "@im=fcitx";
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      INPUT_METHOD = "fcitx";
    });
  }
else
  { })
