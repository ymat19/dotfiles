{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    syntaxHighlighting.enable = true;
    initContent = builtins.readFile ../configs/zshrc;
    oh-my-zsh = {
      enable = true;
      # 管理が面倒なのでモノがあるかどうかは保証せず、あったら嬉しいものをとりあえず並べておく
      plugins = [
        "git"
        "vi-mode"
        "fzf"
        "docker"
        "terraform"
        "aws"
      ];
    };
  };

  programs.bash = {
    enable = true;
  };

  #powerline-go
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
