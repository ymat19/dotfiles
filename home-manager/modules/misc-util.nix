
{ config, pkgs, ... }:

{
  programs.autojump = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.lazygit = {
    enable = true;
  };

  programs.bat = {
    enable = true;
  };
}
