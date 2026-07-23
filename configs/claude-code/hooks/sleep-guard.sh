#!/usr/bin/env bash
# PreToolUse:Bash gate for `sleep` — 待機によるトークン/時間の浪費を抑止する。
#
#   - 3分(180秒)を超える sleep         → 即却下 (バイパス不可)
#   - 180秒以下の sleep                 → 強制レビュー (下記チェックを自答するまで却下)
#
# 短時間の待機が本当に必要なら、切り分けを言語化した上で
# コマンド末尾に `# sleep-justified: <理由>` を付けて再実行すると許可される。
# これにより「無条件の待機」を禁じつつ、正当な短待機の逃げ道を1回のレビューで残す。
#
# Exit 0 かつ JSON 出力で PreToolUse の判定を返す。依存が無ければ黙って素通り。
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# `sleep` がコマンド位置 (行頭 / ; & | ( / && || / パス区切り) に現れる時だけ対象とする。
# 変数名やコメント中の "sleep" で誤発火しないようにする。
if ! echo "$CMD" | grep -qE '(^|[;&|(/]|&&|\|\|)[[:space:]]*sleep([[:space:]]|$)'; then
  exit 0
fi

# 各 `sleep` 呼び出しの待機秒数を算出し、最大値を採る。
# sleep は複数の duration 引数を合算する (`sleep 1m 30s` = 90s) ため、
# 連続する duration トークンを 1 回の待機として合計する。
SEGMENTS=$(echo "$CMD" | grep -oE 'sleep([[:space:]]+[0-9]+(\.[0-9]+)?[smhd]?)+')
MAX=$(echo "$SEGMENTS" | awk '
  function tosec(tok,   n, u) {
    if (tok ~ /[smhd]$/) { u = substr(tok, length(tok)); n = substr(tok, 1, length(tok)-1) }
    else                 { u = "s"; n = tok }
    n = n + 0
    if      (u == "m") return n * 60
    else if (u == "h") return n * 3600
    else if (u == "d") return n * 86400
    else               return n
  }
  {
    total = 0
    # $1 は "sleep"。$2 以降の duration トークンを連続する限り合算する。
    for (i = 2; i <= NF; i++) {
      if ($i ~ /^[0-9]+(\.[0-9]+)?[smhd]?$/) total += tosec($i)
      else break
    }
    if (total > maxv) maxv = total
  }
  END { printf "%.3f", maxv + 0 }
')

DISPLAY=$(awk -v m="$MAX" 'BEGIN { printf "%g", m }')
OVER=$(awk -v m="$MAX" 'BEGIN { print (m > 180) ? 1 : 0 }')

if [ "$OVER" = 1 ]; then
  jq -n --arg n "$DISPLAY" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("3分(180秒)を超える sleep (" + $n + "秒) は即却下。固定の長時間待機は禁止。\n" +
        "待機そのものを消すこと: 状態ポーリング / 完了通知 / イベント待ちに置き換える。\n" +
        "待機が本質的に不可避なら 180 秒以下に分割し、各回で状態を確認して条件を満たしたら即座に抜けること。\n" +
        "「とりあえず長めに待つ」は認めない。")
    }
  }'
  exit 0
fi

# 既にレビュー済みの正当化マーカーがあれば通す。
if echo "$CMD" | grep -qE 'sleep-justified:'; then
  exit 0
fi

# 180秒以下の待機は強制レビュー。切り分け完了を自答させてから続行させる。
jq -n --arg n "$DISPLAY" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("sleep (" + $n + "秒) を検知。待機はトークンと時間を浪費しやすいため強制レビュー。\n" +
      "以下を自答してから続行すること:\n" +
      "1. 切り分けは完了したか — 待つ以外の原因究明(ログ確認 / 状態ポーリング / ドキュメント参照)を全てやり切ったか。\n" +
      "2. この待機で何が見込まれるのか — 待つことで状態が変わる根拠は何か。変わらないなら待つ意味はない。\n" +
      "3. 待つ以外の手段はないか — 完了通知 / 状態ポーリング / イベント待ちで代替できないか。\n" +
      "4. この " + $n + " 秒間に並行して進められる生産的作業はないか。\n" +
      "上記を検討し、切り分けを全て終えた上で本当に待機が必要なら、\n" +
      "コマンド末尾に `# sleep-justified: <待つ理由と、何を待っているか>` を付けて再実行すれば許可される。")
  }
}'
exit 0
