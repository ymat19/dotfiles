#!/usr/bin/env bash
# Stop hook: 直近のターンの応答に、全部半角英数（ASCII だけ）の文章ブロックがあれば止めて日本語で言い直させる。
set -euo pipefail

input=$(cat)
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[[ -f $transcript ]] || exit 0

# 最後の人の発言（tool_result だけの user 行は除く）より後の応答の文章ブロックのうち、ASCII だけのもの
# jq -s で丸ごと読まないのは、トランスクリプトに NUL で埋まった壊れた行が混ざることがあり、
# 1 行でも壊れているとそのセッションの間ずっとチェックが効かなくなるため。壊れた行は飛ばす
english=$(jq -nrR '
  [inputs | fromjson?]
  | (map(.type == "user" and ((.message.content | type) == "string"
        or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
  | [.[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]?
     | select(.type == "text") | .text | select(test("^[\\x00-\\x7F]*$"))]
  | .[0] // empty | .[0:80]
' "$transcript")

if [[ -n $english ]]; then
  # 「言い直せ」だけだと、訳を添えて済ませ違反を軽く扱うので、違反であることを強く突きつける
  jq -cn --arg r "日本語で応答しろという明示の指示を無視して、英語で書いた（\"$english\"）。これは明確な指示違反だ。訳を添えて済むと思うな。和訳を並べるだけの応答や軽い謝罪で流すことは許さない。違反したことを認め、以降は思考の独り言でも作業の合間の一言でも英語の文を一切書くな。" '{decision: "block", reason: $r}'
fi
