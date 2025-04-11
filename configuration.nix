{ config, lib, pkgs, username, homeDirectory, onWSL, ... }:

{
  imports =
    (if onWSL then [ <nixos-wsl/modules> ] else [ ])
    ++ [ ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    python313
    nodejs_23
    xsel
    neofetch
  ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    #home = homeDirectory;
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
  };

  system.stateVersion = "24.11"; # Did you read the comment?
} // (if onWSL then {
  wsl.enable = true;
  wsl.defaultUser = username;
} else { })
