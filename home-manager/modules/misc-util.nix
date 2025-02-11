
{ config, pkgs, lib, ... }:

{
  programs.autojump = {
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

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = lib.mkAfter (with pkgs; [
    ghq
  ]);

  programs.zsh.initExtra = lib.mkAfter ''
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
}
