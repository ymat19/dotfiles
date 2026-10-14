#!/usr/bin/env bash
# PreToolUse guard: 共有チェックアウト（リポジトリ本体の作業ツリー）を編集させない。
#
# 共有チェックアウトはユーザーや他エージェントと共用しており、そこで編集・コミット・
# ブランチ切り替えをすると他者の作業と衝突する。編集を伴う作業はワークツリーで行う規則
# （CLAUDE.md「共有チェックアウトとワークツリー」）を、指示だけでなく機械的にも止める。
#
# **共有チェックアウトの判定。** git-dir と git-common-dir が一致する作業ツリーを本体とみなす。
# linked worktree（.claude/worktrees/* 等）では両者が異なるので止めない。
#
# **なぜ Bash の検出が緩いのか。** user-scope-guard.sh と同じく、任意のコマンドから書き込みには
# 到達できるので完全な検出は不可能である。git の作業ツリー・HEAD を変える操作と、よくある
# ファイル書き込みの書き方だけを拾い、取りこぼしを減らす側に倒して誤検知は許す。
set -euo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

# 引数のディレクトリ（存在しなければ存在する親）が共有チェックアウト内なら、その toplevel を返す
shared_toplevel() {
  local d=$1 dirs
  while [[ -n $d && ! -d $d ]]; do d=$(dirname "$d"); done
  [[ -n $d ]] || return 1
  mapfile -t dirs < <(git -C "$d" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null) || return 1
  ((${#dirs[@]} == 3)) || return 1
  [[ ${dirs[0]} == "${dirs[1]}" ]] || return 1
  printf '%s\n' "${dirs[2]}"
}

deny() {
  local reason="$1 は共有チェックアウトであり読み取り専用である（CLAUDE.md「共有チェックアウトとワークツリー」）。ファイル編集・コミット・ブランチ切り替え・stash 等の作業ツリーや HEAD を変える操作はしない。編集を伴う作業は EnterWorktree でワークツリーを作ってそこで行え。git pull と読み取りは許可されている。"
  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Write | Edit | NotebookEdit)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [[ $path == /* ]] || path="$cwd/$path"
    if top=$(shared_toplevel "$(dirname "$path")"); then deny "$top"; fi
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    git_mutation='\bgit\b[^|;&]*[[:space:]](commit|add|rm|mv|restore|checkout|switch|reset|stash|merge|rebase|cherry-pick|revert|apply|am|clean)\b'
    write_ops='(\bsed\b[^|;&]*[[:space:]]-[[:alnum:]]*i|\btee\b|\bmv\b|\bcp\b|\brm\b|\btouch\b|\bmkdir\b|>|\bopen\([^)]*["'"'"'][wa])'
    # 相対パスへの書き込み。cwd が共有チェックアウトでも /tmp やスクラッチパッドへの書き込みは
    # 日常的に行うため、mv / cp 等は絶対パスの判定だけに任せ、書き先が相対パスと読める形に絞る
    rel_write_ops='(>[[:space:]]*[^&[:space:]/$~]|\bsed\b[^|;&]*[[:space:]]-[[:alnum:]]*i[^|;&]*[[:space:]][^-/$~[:space:]][^[:space:]]*$|\bopen\([[:space:]]*["'"'"'][^/"'"'"'$~][^)]*["'"'"'][wa])'

    # 操作対象になり得るディレクトリ: cwd と、コマンド中の cd / git -C の引数
    targets=("$cwd")
    while read -r d; do
      d=${d/#\~/$HOME}
      [[ $d == /* ]] || d="$cwd/$d"
      targets+=("$d")
    done < <(printf '%s' "$cmd" | grep -oE '(\bcd|\bgit[[:space:]]+-C)[[:space:]]+[^[:space:];&|]+' | awk '{print $NF}' | tr -d "\"'")

    for d in "${targets[@]}"; do
      top=$(shared_toplevel "$d") || continue
      if printf '%s' "$cmd" | grep -Eq "$git_mutation"; then deny "$top"; fi
      # cwd が共有チェックアウト内のときは相対パスへの書き込みも拾う
      if [[ $d == "$cwd" ]] && printf '%s' "$cmd" | grep -Eq "$rel_write_ops"; then deny "$top"; fi
    done

    # 絶対パスで共有チェックアウト内を指す書き込み。cwd が linked worktree でも本体を直接書けるため、
    # コマンド中の絶対パスごとに判定する（linked worktree 配下のパスは shared_toplevel が弾く）
    if printf '%s' "$cmd" | grep -Eq "$write_ops"; then
      while read -r p; do
        if top=$(shared_toplevel "$p"); then deny "$top"; fi
      done < <(printf '%s' "$cmd" | grep -oE '/[^[:space:];&|<>"'"'"'()]+' | sort -u)
    fi
    ;;
esac

exit 0
