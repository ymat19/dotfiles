#!/usr/bin/env bash
# Stop hook: dotfiles リポジトリでは、commit を main に push しないまま終わらせない。
#
# CLAUDE.md の規約「変更を commit したら main へ直接 push して完了とする」の強制。
# トピックブランチに push しただけで終えると、手元の各ホストには何も反映されない。
# 対象は origin が ymat19/dotfiles のリポジトリだけ（他のリポジトリには別の運用がある）。
set -euo pipefail

input=$(cat)
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0

cwd=$(jq -r '.cwd // empty' <<<"$input")
cd "${cwd:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[[ $(git remote get-url origin 2>/dev/null) == *ymat19/dotfiles* ]] || exit 0
git rev-parse --verify -q origin/main >/dev/null || exit 0

ahead=$(git rev-list --count origin/main..HEAD)
if ((ahead > 0)); then
  branch=$(git branch --show-current)
  jq -cn --arg r "dotfiles に main へ push していない commit が ${ahead} 件ある（ブランチ: ${branch:-detached}）。トピックブランチや PR で止めず、git push origin HEAD:main で main へ直接 push すること。作業ブランチを作っていたら、push 後に git checkout -B main origin/main で main に移り、作業ブランチは消す。" \
    '{decision: "block", reason: $r}'
fi
