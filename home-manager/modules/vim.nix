{ config, pkgs, lib, ... }:

{
  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile ../configs/.vimrc;
  };
}
