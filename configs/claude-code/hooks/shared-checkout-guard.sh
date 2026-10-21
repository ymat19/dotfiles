#!/usr/bin/env bash
# PreToolUse guard: 共有チェックアウト（リポジトリ本体の作業ツリー）のファイルを編集させない。
#
# git-dir と git-common-dir が一致する作業ツリーを本体とみなす。linked worktree
# （.claude/worktrees/* 等）では両者が異なるので止めない。
#
# Bash は見ない。コマンド文字列から書き込みを推定する検出は誤検知が多く、
# 読み取りや git pull まで止めて作業を妨げたため。
set -euo pipefail

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[[ -n $path ]] || exit 0
[[ $path == /* ]] || path="$(printf '%s' "$input" | jq -r '.cwd')/$path"

d=$(dirname "$path")
while [[ ! -d $d ]]; do d=$(dirname "$d"); done
mapfile -t dirs < <(git -C "$d" rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null) || exit 0
((${#dirs[@]} == 3)) && [[ ${dirs[0]} == "${dirs[1]}" ]] || exit 0

jq -cn --arg r "${dirs[2]} は共有チェックアウトなので編集できない。EnterWorktree でワークツリーを作ってそこで編集せよ。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
