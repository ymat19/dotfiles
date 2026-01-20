#!/usr/bin/env bash
set -euo pipefail

# gitリポジトリ外ならエラー
git rev-parse --is-inside-work-tree &>/dev/null || { echo "Error: Not in git repo"; exit 1; }

# リポジトリ名取得
REPO_NAME=$(basename "$(dirname "$(realpath "$(git rev-parse --git-common-dir)")")")

# リモート最新化
git fetch --all --prune 2>/dev/null || true

# ブランチ一覧を優先度順に生成
worktree_branches=$(gwq list --json 2>/dev/null | jq -r '.[].branch' | sort -u)
local_branches=$(git branch --format='%(refname:short)' | sort -u)
remote_branches=$(git branch -r --format='%(refname:short)' | sed 's|^origin/||' | { grep -v '^HEAD$' || true; } | sort -u)

# 優先度順にマージ（重複除去）
branch_list=$(
{
    echo "[+] Create new branch"
    echo "$worktree_branches" | while read -r b; do
        [[ -n "$b" ]] && echo "[WT] $b" || true
    done
    echo "$local_branches" | while read -r b; do
        { [[ -n "$b" ]] && ! echo "$worktree_branches" | grep -qx "$b" && echo "[local] $b"; } || true
    done
    echo "$remote_branches" | while read -r b; do
        { [[ -n "$b" ]] && ! echo "$local_branches" | grep -qx "$b" && ! echo "$worktree_branches" | grep -qx "$b" && echo "[remote] $b"; } || true
    done
}
)

selected=$(echo "$branch_list" | fzf --height=80% --layout=reverse --border --ansi \
    --header="Select branch (Repo: $REPO_NAME)" \
    --preview='
        if [[ {} == "[+] Create new branch" ]]; then
            echo "Create a new branch from current HEAD"
        else
            b=$(echo {} | sed "s/^\[[^]]*\] //")
            git log --oneline --graph --color=always -20 "$b" 2>/dev/null || git log --oneline --graph --color=always -20 "origin/$b"
        fi
    '
) || exit 0

[[ -z "$selected" ]] && exit 0

# マーカーを除去してブランチ名取得
if [[ "$selected" == "[+] Create new branch" ]]; then
    read -rp "New branch name: " branch
    [[ -z "$branch" ]] && exit 0
    git branch "$branch"
else
    branch=$(echo "$selected" | sed 's/^\[[^]]*\] //')
fi

# セッション名: リポジトリ名-ブランチ名（特殊文字を-に変換）
sanitized=$(echo "$branch" | tr '/:.' '-')
SESSION_NAME="${REPO_NAME}-${sanitized}"

# 既存セッションがあれば切り替え
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$SESSION_NAME"
    else
        tmux attach-session -t "$SESSION_NAME"
    fi
    exit 0
fi

# worktree存在確認
WORKTREE_PATH=$(gwq list --json 2>/dev/null | jq -r --arg b "$branch" '.[] | select(.branch == $b) | .path' | head -1)

# なければ作成
if [[ -z "$WORKTREE_PATH" ]] || [[ ! -d "$WORKTREE_PATH" ]]; then
    gwq add "$branch"
    WORKTREE_PATH=$(gwq list --json 2>/dev/null | jq -r --arg b "$branch" '.[] | select(.branch == $b) | .path' | head -1)
fi

[[ -z "$WORKTREE_PATH" ]] && { echo "Error: Failed to get worktree path"; exit 1; }

# セッション作成・切り替え
tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_PATH"
if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION_NAME"
else
    tmux attach-session -t "$SESSION_NAME"
fi
