#!/bin/sh
# tmux-agent-sidebar の表示順 (repo basename 昇順 → tmux list-panes 順) を
# 再現し、現在位置の次 (next) または前 (prev) のエージェントペインへ
# switch する。prefix+J / prefix+K の bind から呼ばれる。
#
# 並び順は src/group.rs の group_panes_by_repo に揃える:
#   1. group key = git --show-toplevel (worktree は親 repo に集約)、なければ cwd
#   2. display name = basename(group key) を case-insensitive 昇順
#   3. グループ内は list-panes -a の出現順を維持 (stable sort)

set -u
direction=${1:-next}

current_pane=$(tmux display -p '#{pane_id}')

# エージェントペイン (sidebar pane は除外) の "cwd<TAB>pane_id" を列挙
raw=$(tmux list-panes -aF '#{?#{&&:#{!=:#{@pane_agent},},#{!=:#{@pane_role},sidebar}},#{?#{!=:#{@pane_cwd},},#{@pane_cwd},#{pane_current_path}}	#{pane_id},}' | grep .)
[ -z "$raw" ] && exit 0

# 各行に sort key (repo basename, lower-case) を付与して安定ソート、pane_id だけ残す。
# sidebar (src/group.rs) と同じく worktree は親 repo に集約する:
#   --git-common-dir は main worktree の .git を指すので、その親 = repo root
ordered=$(printf '%s\n' "$raw" | while IFS='	' read -r cwd pane; do
  common=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$common" ]; then
    case "$common" in
      /*) abs=$common ;;
      *)  abs=$cwd/$common ;;
    esac
    repo=$(dirname "$abs")
  else
    repo=$cwd
  fi
  name=$(basename "$repo" | tr '[:upper:]' '[:lower:]')
  printf '%s\t%s\n' "$name" "$pane"
done | sort -s -k1,1 -t '	' | cut -f2)

n=$(printf '%s\n' "$ordered" | wc -l)
[ "$n" -lt 2 ] && exit 0

idx=$(printf '%s\n' "$ordered" | awk -v t="$current_pane" '$0==t{print NR; exit}')
if [ -z "$idx" ]; then
  # 現在ペインがエージェント外: next なら先頭、prev なら末尾から
  case "$direction" in
    prev) next_idx=$n ;;
    *)    next_idx=1 ;;
  esac
else
  case "$direction" in
    prev) next_idx=$(( (idx + n - 2) % n + 1 )) ;;
    *)    next_idx=$(( idx % n + 1 )) ;;
  esac
fi

target=$(printf '%s\n' "$ordered" | sed -n "${next_idx}p")
[ -z "$target" ] && exit 0

info=$(tmux list-panes -aF '#{pane_id}|#{session_name}|#{window_id}' | awk -F'|' -v t="$target" '$1==t{print; exit}')
s=$(printf '%s\n' "$info" | cut -d'|' -f2)
w=$(printf '%s\n' "$info" | cut -d'|' -f3)
[ -n "$s" ] && tmux switch-client -t "$s"
[ -n "$w" ] && tmux select-window -t "$w"
tmux select-pane -t "$target"
