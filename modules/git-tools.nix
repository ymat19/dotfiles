{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ ".direnv/" ".playwright-mcp/" ".serena/" ".memory.json" ];
    settings = {
      user = {
        name = "ymat19";
        email = "ymat19@example.com";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  home.packages = lib.mkAfter (with pkgs; [
    ghq
    git-lfs
    act
  ]);

  programs.zsh.initContent = lib.mkAfter ''
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
