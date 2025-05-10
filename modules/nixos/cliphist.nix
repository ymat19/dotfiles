{ lib, ... }:
{
  services.cliphist = {
    enable = true;
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    bind = $mainMod, V, exec, rofi -modi clipboard:cliphist-rofi-img -show clipboard -show-icons
  '';
}
