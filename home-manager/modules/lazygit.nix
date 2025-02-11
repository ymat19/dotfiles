{ config, pkgs, lib, ... }:

{
  programs.lazygit = {
    enable = true;
  };

  programs.zsh.initExtra = lib.mkAfter ''
      # https://github.com/jesseduffield/lazygit/issues/1330#issuecomment-983826789
      # checks to see if we are in a windows or linux dir
      function isWinDir {
        case $PWD/ in
          /mnt/*) return $(true);;
          *) return $(false);;
        esac
      }
      # wrap the lazygit command to either run windows lazygit or Linux lazygit
      function lazygit {
        if isWinDir
        then
          lazygit.exe "$@"
        else
          command lazygit "$@"
        fi
      }
  '';

  programs.tmux.extraConfig = lib.mkAfter ''
      # https://www.m3tech.blog/entry/dotfiles-bonsai#Tmux%E7%B7%A8
      bind g popup -w90% -h90% -E zsh -c lazygit # (prefix) gでlazygitを起動する
  '';
}
