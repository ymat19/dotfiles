#!/usr/bin/env bash
# WSL 向け mosh-server ラッパー。
# WSL の mirrored networking 環境では LAN から WSL への直接 UDP が通らないため、
# 実体の mosh-server を 127.0.0.1 の 60001-60010 に bind させ、announce される
# "MOSH CONNECT <port>" を <port>+OFFSET に書き換える。これにより mosh client は
# ホスト側の UDP フォワーダポート (61001-61010) を狙い、そこから 127.0.0.1:<port>
# へ中継される。
OFFSET=1000

REAL=""
for c in "$HOME/.nix-profile/bin/mosh-server" "$(command -v mosh-server 2>/dev/null)" /usr/bin/mosh-server /usr/local/bin/mosh-server "$HOME/.local/bin/mosh-server"; do
  if [ -n "$c" ] && [ -x "$c" ]; then REAL="$c"; break; fi
done
if [ -z "$REAL" ]; then echo "mosh-server not found in this distro" >&2; exit 127; fi

args=()
ins=0
for a in "$@"; do
  if [ "$a" = "--" ] && [ "$ins" = "0" ]; then
    args+=( -p 60001:60010 -- )
    ins=1
  else
    args+=( "$a" )
  fi
done
[ "$ins" = "0" ] && args+=( -p 60001:60010 )

out="$("$REAL" "${args[@]}" 2>&1)"
printf '%s\n' "$out" | awk -v off="$OFFSET" \
  '/^MOSH CONNECT/{printf "MOSH CONNECT %d %s\n", $3+off, $4; next} {print}'
