#!/usr/bin/env bash
# Stop hook: 直近のターンの応答に、全部半角英数（ASCII だけ）の文章ブロックがあれば止めて日本語で言い直させる。
set -euo pipefail

input=$(cat)
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[[ -f $transcript ]] || exit 0

# 最後の人の発言（tool_result だけの user 行は除く）より後の応答の文章ブロックのうち、ASCII だけのもの
english=$(jq -rs '
  (map(.type == "user" and ((.message.content | type) == "string"
        or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
  | [.[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]?
     | select(.type == "text") | .text | select(test("^[\\x00-\\x7F]*$"))]
  | .[0] // empty | .[0:80]
' "$transcript")

if [[ -n $english ]]; then
  jq -cn --arg r "英語で応答した（\"$english\"）。日本語で言い直してから終えること。" '{decision: "block", reason: $r}'
fi
