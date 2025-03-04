{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    delta.enable = true;
    userName = "ymat19";
    userEmail = "ymat19@example.com";
  };

  home.packages = lib.mkAfter (with pkgs; [
    ghq
  ]);

  programs.zsh.initExtra = lib.mkAfter ''
      # https://qiita.com/tomoyamachi/items/e51d2906a5bb24cf1684
      function ghq-fzf() {
        local src=$(ghq list -p | fzf --preview "bat --color=always --style=header,grid --line-range :80 {}/README.*")
        if [ -n "$src" ]; then
          BUFFER="cd $src"
          zle accept-line
        fi
        zle -R -c
      }
      zle -N ghq-fzf
      bindkey '^]' ghq-fzf
  '';
}
