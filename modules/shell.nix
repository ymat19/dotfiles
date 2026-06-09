{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    syntaxHighlighting.enable = true;
    initContent = builtins.readFile ../configs/zshrc;
    # Claude Code の Bash ツールは `zsh -l` で起動するが、親から
    # __HM_SESS_VARS_SOURCED を継承するため hm-session-vars.sh（home.sessionPath の
    # 出力先）がガードで早期 return し PATH が通らない。加えて Bash サンドボックスは
    # settings.json の env.PATH を握り潰す。.zshenv に書かれる envExtra はガード無しで
    # 全 zsh 起動時に必ず実行されるため、ここで nix profile を前置きすれば
    # サンドボックス有無・継承状態に関係なく gh / nix ツールが解決される。
    envExtra = ''
      case ":$PATH:" in
        *":$HOME/.nix-profile/bin:"*) ;;
        *) export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH" ;;
      esac
    '';
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
