#!/usr/bin/env bash
# PostToolUseFailure:Bash — コマンド実行が失敗した直後に、切り分けと原因究明を強制する。
# 無為なリトライや憶測によるオプション修正を禁じる旨を additionalContext で注入する。
#
# PostToolUseFailure はツール失敗時のみ発火するため、exit code を自前で判定する必要はない。
# additionalContext は非ブロッキングでモデルに届く (実行済みの失敗を止めるのではなく、次の行動を矯正する)。
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# 非ゼロ終了が「エラー」でなく通常結果である定番コマンドは矯正しない (grep のノーマッチ等)。
# これらまで発火させると注入がノイズ化し、本当のエラー時の信号が薄れる。
FIRST=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]*//' | awk '{print $1}')
case "$FIRST" in
  grep | rg | egrep | fgrep | ag | diff | test | '[' | '[[' | find | which | pgrep)
    exit 0
    ;;
esac
# 明示的に失敗を握り潰している場合も対象外。
case "$CMD" in
  *"|| true"* | *"|| :"*) exit 0 ;;
esac

read -r -d '' MSG <<'EOF'
⚠️ コマンドが失敗しました。無為なリトライや憶測によるオプション修正は禁止。以下を強制する:

1. エラーメッセージ全文を読む — 「何が(症状)」「どこで(箇所)」を先に特定する。出力を読まずに再実行しない。
2. 原因の切り分け — 前提(パス / 権限 / 依存の有無 / 環境変数 / 作業ディレクトリ / 入力の形式)を1つずつ確認し、真因を突き止める。
3. 真因を1文で言語化してから対処する。原因が不明なまま同じコマンドを再実行しない。
4. オプションやフラグを当てずっぽうで変えて通そうとしない。挙動が不明なら `--help` や公式ドキュメント(context7 等)で確認してから直す。

切り分けと原因究明を先に行い、根拠のある修正だけを行うこと。同じ失敗を繰り返す前に、まず原因を1つ確定させる。
EOF

jq -n --arg ctx "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUseFailure",
    additionalContext: $ctx
  }
}'
exit 0
