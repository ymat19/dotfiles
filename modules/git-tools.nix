{ config, pkgs, lib, ... }:

let
  gwq = pkgs.buildGoModule rec {
    pname = "gwq";
    version = "unstable-2025-01-10";
    src = pkgs.fetchFromGitHub {
      owner = "d-kuro";
      repo = "gwq";
      rev = "c33ab3e9935df70c8a0a9eb1932ed9b24f5ab877";
      hash = "sha256-Sl4oBvyjbM1rPPgSe3xf/PDF2whLzyBY9a9h2zsTNaU=";
    };
    vendorHash = "sha256-c1vq9yETUYfY2BoXSEmRZj/Ceetu0NkIoVCM3wYy5iY=";
    subPackages = [ "cmd/gwq" ];
    meta = {
      description = "Git Worktree Manager";
      homepage = "https://github.com/d-kuro/gwq";
    };
  };
in
{
  programs.git = {
    enable = true;
    ignores = [ ".direnv/" ".playwright-mcp/" ".serena/" ".memory.json" ];
    settings = {
      user = {
        name = "ymat19";
        email = "ymat19@example.com";
      };
      ghq = {
        root = "/home/ymat19/repos";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  home.packages = lib.mkAfter ([
    gwq
  ] ++ (with pkgs; [
    ghq
    git-lfs
    act
  ]));

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
