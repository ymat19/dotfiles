{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    syntaxHighlighting.enable = true;
    initExtra = ''
      bindkey -v
      bindkey 'jj' vi-cmd-mode
    '';
    oh-my-zsh = {
      enable = true;
      # 管理が面倒なのでモノがあるかどうかは保証せず、あったら嬉しいものをとりあえず並べておく
      plugins = [
        "git"
        "vi-mode"
        "fzf"
        "asdf"
        "docker"
        "terraform"
        "aws"
      ];
    };
  };

  programs.bash.bashrcExtra = "";

  #powerline-go
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
