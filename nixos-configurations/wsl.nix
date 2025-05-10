{ config, lib, pkgs, username, homeDirectory, onWSL, envName, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = username;
}
