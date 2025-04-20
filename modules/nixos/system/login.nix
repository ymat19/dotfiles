{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd Hyprland";
        user = username;
      };
    };
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    greetd.tuigreet
  ]);
}
