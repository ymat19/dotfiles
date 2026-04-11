#!/usr/bin/env bash
# Notification / Stop hook: tmux 内で OSC 9 がブロックされる問題を回避し、
# D-Bus 経由で Claude Code のターン終了通知を出す。
set -euo pipefail

command -v notify-send >/dev/null 2>&1 || exit 0

payload="$(cat)"
event=""
message=""
transcript=""
if command -v jq >/dev/null 2>&1; then
  event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty')"
  message="$(printf '%s' "$payload" | jq -r '.message // empty')"
  transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty')"
fi

summary=""
if [ "$event" = "Stop" ] && [ -n "$transcript" ] && [ -f "$transcript" ] && command -v jq >/dev/null 2>&1; then
  summary="$(jq -r '
    select(.type == "assistant")
    | [.message.content[]? | select(.type == "text") | .text]
    | join(" ")
  ' "$transcript" 2>/dev/null | awk 'NF' | tail -n 1)"
fi

case "$event" in
  Stop)
    title="Claude Code"
    body="${summary:-${message:-ターンが返ってきました}}"
    ;;
  Notification)
    title="Claude Code"
    body="${message:-通知}"
    ;;
  *)
    title="Claude Code"
    body="${message:-通知}"
    ;;
esac

if [ "${#body}" -gt 200 ]; then
  body="${body:0:200}…"
fi

icon="$HOME/.claude/assets/claude-icon.png"
[ -f "$icon" ] || icon="dialog-information"

notify-send --app-name="Claude Code" --icon="$icon" "$title" "$body" >/dev/null 2>&1 || true
exit 0
