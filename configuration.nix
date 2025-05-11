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
    python313
    pnpm
    wl-clipboard
    neofetch
  ];
}
