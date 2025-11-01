{ pkgs, lib, username, homeDirectory, onNixOS, ... }:


{
  environment.systemPackages = lib.mkAfter
    (with pkgs; [
      wl-kbptr
    ]
    );

  # Enable ydotool with proper permissions
  programs.ydotool.enable = true;

  home-manager.users.${username} = {
    xdg.configFile."wl-kbptr/config".source = ../../../configs/wl-kbptr.conf;
  };
}
