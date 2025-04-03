{ config, pkgs, lib, ... }:

{
  programs.lazygit = {
    enable = true;
  };

  home.packages = lib.mkAfter (with pkgs; [
    lazydocker
  ]);

  programs.zsh.initExtra = lib.mkAfter ''
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
  '';

  programs.tmux.extraConfig = lib.mkAfter ''
      # https://www.m3tech.blog/entry/dotfiles-bonsai#Tmux%E7%B7%A8
      bind g popup -d '#{pane_current_path}' -w90% -h90% -E zsh -c "source ~/.zshrc && lazygit"
      bind q popup -d '#{pane_current_path}' -w90% -h90% -E zsh -c "source ~/.zshrc && lazydocker"
  '';
}
