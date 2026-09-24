{ inputs, pkgs, ... }:

let
  # 組み込みのキーバインドにワークスペース並べ替えが無く、CLI にも無いため socket API を直接叩く。
  # popup 内でキーを読み続けることで、prefix を押し直さずに連打で移動できるようにする。
  herdr-workspace-move = pkgs.writeShellApplication {
    name = "herdr-workspace-move";
    runtimeInputs = with pkgs; [
      jq
      socat
    ];
    text = ''
      ws=''${HERDR_ACTIVE_WORKSPACE_ID:?}

      api() {
        printf '%s\n' "$1" | socat -t2 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"
      }

      move() {
        local idx n target
        read -r idx n < <(
          api '{"id":"list","method":"workspace.list","params":{}}' |
            jq -r --arg ws "$ws" '.result.workspaces | [(map(.workspace_id) | index($ws)), length] | @tsv'
        )
        # insert_index は移動前のリスト上の挿入位置として解釈されるため、下へは +2 になる
        case $1 in
          up) ((idx > 0)) && target=$((idx - 1)) && idx=$((idx - 1)) ;;
          down) ((idx < n - 1)) && target=$((idx + 2)) && idx=$((idx + 1)) ;;
        esac
        if [[ -n ''${target:-} ]]; then
          api "$(jq -nc --arg ws "$ws" --argjson i "$target" \
            '{id: "move", method: "workspace.move", params: {workspace_id: $ws, insert_index: $i}}')" >/dev/null
        fi
        printf '\r\033[K %d / %d   C-j/C-k: 移動  他キー: 終了' "$((idx + 1))" "$n"
      }

      saved=$(stty -g)
      trap 'stty "$saved"' EXIT
      # -icrnl: Enter(CR) を C-j(LF) と区別するため
      stty -icanon -echo -icrnl

      move "$1"
      while IFS= read -rsn1 -d "" -t 2 key; do
        case $key in
          $'\n' | j) move down ;;
          $'\v' | k) move up ;;
          *) break ;;
        esac
      done
    '';
  };
in
{
  # 公式リポジトリの flake を直接参照する（旧 herdr-nix はアーカイブ済み）。
  # プリビルドバイナリではなくソースビルドになるため、初回 rebuild は時間がかかる。
  home.packages = [
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    herdr-workspace-move
  ];

  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;
}
