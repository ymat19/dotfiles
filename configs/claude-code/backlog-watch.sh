#!/usr/bin/env bash
# backlog-watch.sh — Watch backlog/tasks/ for changes and report new To Do tasks.
# Blocks until a filesystem change is detected, then outputs the current To Do list.
# Designed to be called via Bash run_in_background from coordinator-backlog skill.
#
# Usage: backlog-watch.sh [timeout_seconds]
# Exit codes: 0 = change detected, 1 = timeout, 2 = backlog dir missing

set -euo pipefail

BACKLOG_DIR="backlog/tasks"
TIMEOUT="${1:-0}"

if [ ! -d "$BACKLOG_DIR" ]; then
  mkdir -p "$BACKLOG_DIR"
fi

INOTIFY_ARGS=(-r -e create -e modify -e delete -e moved_to -e moved_from "$BACKLOG_DIR")
if [ "$TIMEOUT" -gt 0 ] 2>/dev/null; then
  INOTIFY_ARGS=(-t "$TIMEOUT" "${INOTIFY_ARGS[@]}")
fi

# Block until change
inotifywait -q "${INOTIFY_ARGS[@]}" >/dev/null 2>&1
INOTIFY_EXIT=$?

if [ "$INOTIFY_EXIT" -eq 2 ]; then
  echo "timeout"
  exit 1
fi

# Output current To Do tasks
backlog task list -s "To Do" --plain 2>/dev/null || echo "No tasks found."
