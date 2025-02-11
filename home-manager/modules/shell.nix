{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    syntaxHighlighting.enable = true;
    initExtra = ''
      bindkey -v
      bindkey 'jj' vi-cmd-mode

      # https://qiita.com/tomoyamachi/items/e51d2906a5bb24cf1684
      function ghq-fzf() {
        local src=$(ghq list | fzf --preview "bat --color=always --style=header,grid --line-range :80 $(ghq root)/{}/README.*")
        if [ -n "$src" ]; then
          BUFFER="cd $(ghq root)/$src"
          zle accept-line
        fi
        zle -R -c
      }
      zle -N ghq-fzf
      bindkey '^]' ghq-fzf
    '';
    oh-my-zsh = {
      enable = true;
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

  #powerline-go
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
