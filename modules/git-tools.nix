{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;
    ignores = [
      ".direnv/"
      ".playwright-mcp/"

      ".memory.json"
    ];
    settings = {
      user = {
        name = "ymat19";
        email = "45934497+ymat19@users.noreply.github.com";
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

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        inherit (config.programs.git.settings.user) name email;
      };
      ui = {
        # delta は git 形式の diff しか解釈できないため、jj 独自形式ではなく :git で出す
        pager = "delta";
        diff-formatter = ":git";
      };
    };
  };

  home.packages = lib.mkAfter (
    with pkgs;
    [
      ghq
      git-lfs
      act
    ]
  );

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
