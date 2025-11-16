{ config, lib, pkgs, username, homeDirectory, onWSL, envName, ... }:

{
  imports =
    (if onWSL then [
      <nixos-wsl/modules>
      ./nixos-configurations/wsl.nix
    ] else [
    ])
    ++
    (if envName == "" then [
      ./hardware-configuration.nix
    ] else [
      ./hardware-configuration/${envName}/hardware-configuration.nix
    ])
    ++
    [
      ./nixos-configurations/baremetal.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = envName; # Define your hostname.

  system.stateVersion = "24.11"; # Did you read the comment?

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    neofetch
  ];

  # Allow nixos-rebuild and systemctl restart xremap without password
  security.sudo.extraRules = [{
    users = [ username ];
    commands = [
      {
        command = "/run/current-system/sw/bin/nixos-rebuild";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/run/current-system/sw/bin/systemctl restart xremap";
        options = [ "NOPASSWD" ];
      }
    ];
  }];
}
