#!/usr/bin/env bash
# TeammateIdle quality gate:
#   1. 未コミットの変更があればアイドルを拒否する（先にコミットさせる）。
#   2. クリーンにコミット済みなら、その変更に対応するドキュメント・コメントが
#      最新化されているかを 1 コミットにつき 1 回だけ確認させる。
# Exit 0 = allow idle, Exit 2 = keep working (stderr = feedback to teammate).
set -euo pipefail

# 1. 未コミットの変更を最優先でブロックする。
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "作業中の変更がコミットされていません。コミットしてからアイドルになってください。" >&2
  echo "コミット前に、変更に対応するドキュメント・コード内コメントも最新化すること。" >&2
  exit 2
fi

# 2. ドキュメント/コメント最新化の確認は HEAD コミット単位で 1 回だけ促す。
#    marker に確認済みの sha を記録し、同一コミットでの無限ループを避ける。
git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
head=$(git rev-parse HEAD 2>/dev/null) || exit 0
marker="$git_dir/claude-doc-gate-teammateidle"
if [ "$(cat "$marker" 2>/dev/null)" != "$head" ]; then
  printf '%s' "$head" > "$marker"
  echo "最新コミットの変更に対し、ドキュメント（README 等）とコード内コメントが最新化されているか確認してください。" >&2
  echo "追随が必要なら更新してコミットし、問題なければアイドルして構いません。" >&2
  exit 2
fi

exit 0
