{ pkgs, lib, username, homeDirectory, onNixOS, ... }:

let
  getNixFiles = dir:
    builtins.map
      (name: dir + "/${name}")
      (builtins.filter
        (name: lib.strings.hasSuffix ".nix" name)
        (builtins.attrNames (builtins.readDir dir)));

  commonModuleDir = ./modules;
  nixOSModuleDir = ./modules/nixos;
  modules = getNixFiles commonModuleDir
    ++
    (if onNixOS then
      getNixFiles
        nixOSModuleDir
    else [ ]);
in
{
  imports = modules;

  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    gh
    wget
    unzip
    gcc
    stdenv
    gnumake
    #llvmPackages
  ];

  home.file = { };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

}
