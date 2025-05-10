{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "Hyprland";
        user = username;
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet - -time - -cmd Hyprland";
        user = username;
      };
    };
  };
}
