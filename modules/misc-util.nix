{ config, pkgs, lib, ... }:

{
  programs.autojump = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.fd = {
    enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat.enable = true;
  programs.lsd.enable = true;
  home.shellAliases = lib.mkAfter {
    tree = "lsd --tree";
  };
}
