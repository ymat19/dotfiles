{ pkgs, username, homeDirectory, ... }:

let
  moduleDir = ./modules;
  modules = builtins.map (fileName: moduleDir + "/${fileName}") (builtins.attrNames (builtins.readDir moduleDir));
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
