#!/usr/bin/env bash
# PreToolUse guard: ユーザスコープ (~/.claude) の設定とフックをエージェントに触らせない。
#
# ~/.claude/settings.json と ~/.claude/hooks/ は dotfiles (modules/ai-agent.nix,
# configs/claude-code/hooks/) が唯一の正であり、各リポジトリで動くエージェントが
# 実行時に書き換えてよい場所ではない。home-manager はここを読み取り専用の store
# symlink として張るので、その場書き換えは symlink を実ファイルへ壊し、次の
# nixos-rebuild switch を activation ごと落とす。
#
# **なぜ Bash の検出が緩いのか。** 任意のコマンドから書き込みには到達できるので、
# 完全な検出は原理的に不可能である。ここで止めるのは「うっかり書く」までとし、
# 検出漏れと Claude Code 自身の実行時書き込みは home-manager.backupCommand の
# タイムスタンプ退避で受け止める（防御は二段構えで、片方の完全性に頼らない）。
#
# **なぜ読み取りまで巻き込むのか。** 保護パスを読んで別の場所へリダイレクトする
# コマンドも拒否される。書き込み先をコマンド文字列から正確に切り出すのは
# クォートと変数展開のせいで信用できないため、誤検知を許して取りこぼしを減らす側に
# 倒している。読むだけなら Read ツールを使えばよい。
set -euo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

reason='~/.claude/settings.json と ~/.claude/hooks/ はユーザスコープの設定であり、dotfiles リポジトリ (modules/ai-agent.nix, configs/claude-code/hooks/) が唯一の正である。エージェントが実行時に書き換えてはならない。変更が必要なら dotfiles を編集して nixos-rebuild switch せよ。読むだけなら Read ツールを使え。'

deny() {
  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Write | Edit | NotebookEdit)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    case "$path" in
      "$HOME"/.claude/settings.json | "$HOME"/.claude/hooks | "$HOME"/.claude/hooks/*) deny ;;
    esac
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    # プロジェクト側の .claude/hooks/ は各リポジトリの持ち物なので巻き込まない。
    # ホーム直下を指す書き方 (~ / $HOME / 絶対パス) に限って拾う。
    user_scope="(~|\\\$HOME|\\\$\\{HOME\\}|${HOME})/\\.claude/(settings\\.json|hooks)"
    write_ops='(>|\btee\b|\bmv\b|\bcp\b|\brm\b|\binstall\b|\bln\b|\btouch\b|\bchmod\b|\btruncate\b|\bdd\b|\bsed\b[^|;]*-[[:alnum:]]*i)'
    if printf '%s' "$cmd" | grep -Eq "$user_scope" \
      && printf '%s' "$cmd" | grep -Eq "$write_ops"; then
      deny
    fi
    ;;
esac

exit 0
