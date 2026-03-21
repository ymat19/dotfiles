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

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.extra-substituters = [
    "https://cache.numtide.com"
    "https://nixos-apple-silicon.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  nixpkgs.config.allowUnfree = true;

  networking.hostName = envName; # Define your hostname.

  system.stateVersion = "24.11"; # Did you read the comment?

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    fastfetch
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
