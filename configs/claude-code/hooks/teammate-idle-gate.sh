#!/usr/bin/env bash
# TeammateIdle quality gate: prevent idle if uncommitted changes exist.
# Exit 0 = allow idle, Exit 2 = keep working (stderr = feedback to teammate).
set -euo pipefail

# Check for uncommitted changes in the working tree
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "作業中の変更がコミットされていません。コミットしてからアイドルになってください。" >&2
  exit 2
fi

exit 0
