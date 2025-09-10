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
      #./modules/nixos/system/apple-silicon-support
      ./nixos-configurations/baremetal.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  networking.hostName = envName; # Define your hostname.

  system.stateVersion = "25.11"; # Did you read the comment?

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    neofetch
  ];
}
