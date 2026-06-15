{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.lazygit = {
    enable = true;
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  xdg.configFile."yazi/flavors/tokyo-night.yazi" = {
    source = ../configs/yazi/flavors/tokyo-night.yazi;
    recursive = true;
  };

  xdg.configFile."yazi/theme.toml".source = ../configs/yazi/theme.toml;

  home.packages = lib.mkAfter (
    with pkgs;
    [
      lazydocker
      posting
    ]
  );

  programs.zsh.initContent = lib.mkAfter ''
    # https://github.com/jesseduffield/lazygit/issues/1330#issuecomment-983826789
    # checks to see if we are in a windows or linux dir
    function isWinDir {
      case $PWD/ in
        /mnt/*) return $(true);;
        *) return $(false);;
      esac
    }

    function lazygit {
      if isWinDir
      then
        lazygit.exe "$@"
      else
        command lazygit "$@"
      fi
    }

    function lazydocker {
      if isWinDir
      then
        lazydocker.exe "$@"
      else
        command lazydocker "$@"
      fi
    }

    # tmux popup 用: cwd が git リポジトリ内ならそれを即開く（最優先）。
    # リポジトリ外のときだけ、並列実行中の agent の worktree を fzf で選んで開く。
    function lazygit-here {
      if git rev-parse --is-inside-work-tree > /dev/null 2>&1
      then
        lazygit
        return
      fi
      local sel dir
      sel=$(claude agents --json 2>/dev/null \
        | jq -r '.[] | select(.cwd | test("/.claude/worktrees/")) | "\(.name // .sessionId)\t\(.cwd)"' \
        | fzf --delimiter='\t' --with-nth=1 --prompt='worktree > ') || return
      dir=$(printf '%s' "$sel" | cut -f2)
      [ -n "$dir" ] && cd "$dir" && lazygit
    }
  '';

  programs.tmux.extraConfig = lib.mkAfter ''
    # https://www.m3tech.blog/entry/dotfiles-bonsai#Tmux%E7%B7%A8
    bind g popup -d '#{pane_current_path}' -w90% -h90% -E zsh -c "source ~/.zshrc && lazygit-here"
    bind q popup -d '#{pane_current_path}' -w90% -h90% -E zsh -c "source ~/.zshrc && lazydocker"
  '';
}
