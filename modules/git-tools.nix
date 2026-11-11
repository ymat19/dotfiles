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
      "**/.claude/settings.local.json"
    ];
    settings = {
      user = {
        name = "ymat19";
        email = "45934497+ymat19@users.noreply.github.com";
      };
      # `gh auth setup-git` は ~/.gitconfig に書くが、そこは下で読み取り専用にするので Nix 側で持つ
      credential = lib.genAttrs [ "https://github.com" "https://gist.github.com" ] (_: {
        helper = [
          ""
          "!${lib.getExe pkgs.gh} auth git-credential"
        ];
      });
      ghq = {
        root = "/home/ymat19/repos";
      };
    };
  };

  # git は ~/.config/git/config より後に ~/.gitconfig を読むので、そこに [user] が入ると
  # Nix の名義が黙って上書きされる（nb が stdin のデータを名義として書き込んだ）。
  # rebuild 時に剥がすだけでは次の rebuild まで改ざんされたままなので、ストアへの
  # symlink にして `git config --global` を含む書き込みそのものを失敗させる
  home.file.".gitconfig".text = "# 設定は ~/.config/git/config（Nix 管理）に置く\n";

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
