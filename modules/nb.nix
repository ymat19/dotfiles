{ pkgs, lib, ... }:

{
  home.packages = lib.mkAfter (with pkgs; [
    nb
  ]);

  home.shellAliases = lib.mkAfter {
    ne = "nb e 1";
    nl = "nb tasks";
  };

  programs.zsh.initExtra = ''
    # タスクを追加
    na() {
      echo "- [ ] $1" | nb edit 1
    }

    # タスクのdo/undoをfzfで選択してトグル（複数選択可）
    nd() {
      local selections tid tnum tstate
      selections=$(nb tasks --no-color | \
        sed 's/\x1b\[[?0-9]*[a-zA-Z]//g' | \
        grep -E '^\[[0-9]+ [0-9]+\]' | \
        fzf -m)

      [ -z "$selections" ] && return

      while read -r line; do
        eval "$(echo "$line" | sed -E 's/^\[([0-9]+) ([0-9]+)\].*\[(.)\].*/tid=\1 tnum=\2 tstate=\3/')"

        if [ "$tstate" = "x" ]; then
          nb todo undo "$tid" "$tnum"
        else
          nb todo do "$tid" "$tnum"
        fi
      done <<< "$selections"
    }
  '';
}
