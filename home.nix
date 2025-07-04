{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

let
  getNixFiles = import ./lib/get-nix-files.nix;

  modules = getNixFiles ./modules
    ++
    (if onNixOS then
      getNixFiles ./modules/nixos
    else [ ]);
in
{
  imports = modules;

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "24.11";

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    gh
    wget
    unzip
    gcc
    stdenv
    gnumake
    marp-cli
    parallel
    wl-clipboard
    xsel
    claude-code
  ];

  home.file = { };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

  home.shellAliases = { };
}
