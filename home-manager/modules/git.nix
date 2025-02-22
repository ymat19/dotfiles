{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    userName = "ymat19";
    userEmail = "ymat19@example.com";
  };
}
