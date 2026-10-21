#!/usr/bin/env bash
# PreToolUse guard: ユーザスコープ (~/.claude) の設定とフックをエージェントに編集させない。
#
# ~/.claude/settings.json と ~/.claude/hooks/ は dotfiles (modules/ai-agent.nix,
# configs/claude-code/hooks/) が唯一の正であり、home-manager は読み取り専用の store
# symlink として張る。その場書き換えは symlink を実ファイルへ壊し、次の
# nixos-rebuild switch を activation ごと落とす。
#
# Bash は見ない。コマンド文字列から書き込みを推定する検出は読み取りまで止める誤検知が
# 多かったため。検出漏れは home-manager.backupCommand のタイムスタンプ退避で受け止める。
set -euo pipefail

path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
case "$path" in
  "$HOME"/.claude/settings.json | "$HOME"/.claude/hooks | "$HOME"/.claude/hooks/*)
    jq -cn --arg r '~/.claude/settings.json と ~/.claude/hooks/ は dotfiles (modules/ai-agent.nix, configs/claude-code/hooks/) で管理している。変更は dotfiles を編集して nixos-rebuild switch せよ。' \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    ;;
esac
