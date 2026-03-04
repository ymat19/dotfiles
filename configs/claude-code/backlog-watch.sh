#!/usr/bin/env bash
# backlog-watch.sh — Watch backlog/tasks/ for changes and report new To Do tasks.
# Blocks indefinitely (no timeout) until a filesystem change is detected,
# then outputs the current To Do list.
# Designed to be called via Bash run_in_background from coordinator-backlog skill.
#
# Exit codes: 0 = change detected

set -euo pipefail

BACKLOG_DIR="backlog/tasks"

if [ ! -d "$BACKLOG_DIR" ]; then
  mkdir -p "$BACKLOG_DIR"
fi

# Block forever until a change occurs (no timeout)
inotifywait -q -r -e create -e modify -e delete -e moved_to -e moved_from \
  "$BACKLOG_DIR" >/dev/null 2>&1

# Output current To Do tasks
backlog task list -s "To Do" --plain 2>/dev/null || echo "No tasks found."
