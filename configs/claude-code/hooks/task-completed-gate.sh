#!/usr/bin/env bash
# TaskCompleted quality gate: prevent completion if uncommitted changes exist.
# Exit 0 = allow completion, Exit 2 = reject (stderr = feedback to teammate).
set -euo pipefail

# Check for uncommitted changes
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "未コミットの変更があります。タスク完了前にコミットしてください。" >&2
  exit 2
fi

exit 0
