{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "";
      size = 14;
    };
    settings = {
      background_opacity = 0.8;
      confirm_os_window_close = "0";
    };
    extraConfig = builtins.readFile ../../configs/kitty.conf;
  };
}
