{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # 組み込みのキーバインドにワークスペース並べ替えが無く、CLI にも無いため socket API を直接叩く。
  # 組み込みの previous/next_workspace も含め herdr には連打の仕組みが無いため、
  # popup 内でキーを読み続けることで prefix を押し直さずに連打できるようにする。
  herdr-workspace-move = pkgs.writeShellApplication {
    name = "herdr-workspace-move";
    runtimeInputs = with pkgs; [
      jq
      socat
      util-linux
    ];
    text = ''
      # usage: herdr-workspace-move <reorder|focus> <up|down>
      #        herdr-workspace-move focus-wait    (workspace-nav plugin の popup 内で使う)
      mode=$1

      api() {
        printf '%s\n' "$1" | socat -t2 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"
      }

      # 押されたキーを up/down に変換して返す。それ以外のキー・Esc・2 秒放置では失敗を返す
      read_step() {
        local saved key
        saved=$(stty -g)
        # -icrnl: Enter(CR) を C-j(LF) と区別するため
        stty -icanon -echo -icrnl
        IFS= read -rsn1 -d "" -t 2 key || key=""
        stty "$saved"
        case $key in
          $'\n' | j | J) echo down ;;
          $'\v' | k | K) echo up ;;
          *) return 1 ;;
        esac
      }

      if [[ $mode == focus-wait ]]; then
        printf ' %s' "$HERDR_NAV_STATUS"
        if dir=$(read_step); then
          # 次の popup を開く前にこの popup を閉じる必要があるため、自分の終了後も生き残るよう切り離す
          setsid -f herdr-workspace-move focus "$dir" </dev/null >/dev/null 2>&1
        fi
        exit 0
      fi

      list=$(api '{"id":"list","method":"workspace.list","params":{}}')
      mapfile -t ids < <(jq -r '.result.workspaces[].workspace_id' <<<"$list")
      mapfile -t labels < <(jq -r '.result.workspaces[].label' <<<"$list")
      n=''${#ids[@]}
      if [[ $mode == focus ]]; then
        # plugin 経由の起動では HERDR_ACTIVE_WORKSPACE_ID が渡らないため、サーバ側の focus を基準にする
        ws=$(jq -r '.result.workspaces[] | select(.focused) | .workspace_id' <<<"$list")
      else
        ws=''${HERDR_ACTIVE_WORKSPACE_ID:?}
      fi
      for idx in "''${!ids[@]}"; do [[ ''${ids[idx]} == "$ws" ]] && break; done

      step() {
        local next
        case $1 in
          up) next=$((idx > 0 ? idx - 1 : idx)) ;;
          down) next=$((idx < n - 1 ? idx + 1 : idx)) ;;
        esac
        if ((next != idx)); then
          if [[ $mode == reorder ]]; then
            # insert_index は移動前のリスト上の挿入位置として解釈されるため、下へは +2 になる
            api "$(jq -nc --arg ws "$ws" --argjson i "$((next > idx ? next + 1 : next))" \
              '{id: "move", method: "workspace.move", params: {workspace_id: $ws, insert_index: $i}}')" >/dev/null
          else
            api "$(jq -nc --arg ws "''${ids[next]}" \
              '{id: "focus", method: "workspace.focus", params: {workspace_id: $ws}}')" >/dev/null
          fi
        fi
        idx=$next
      }

      step "$2"
      status="$((idx + 1))/$n ''${labels[idx]}"

      if [[ $mode == focus ]]; then
        # popup を開いたまま focus を移すと popup が見えなくなり入力も受けなくなる（実測）ため、
        # 切り替えのたびに移動先で plugin の popup を開き直して連打を受け付ける
        api '{"id":"close","method":"popup.close","params":{}}' >/dev/null || true
        api "$(jq -nc --arg s "$status" \
          '{id: "open", method: "plugin.pane.open", params: {plugin_id: "ymat19.workspace-nav", entrypoint: "wait", env: {HERDR_NAV_STATUS: $s}}}')" >/dev/null
        exit 0
      fi

      printf '\r\033[K %s' "$status"
      while dir=$(read_step); do
        step "$dir"
        printf '\r\033[K %d/%d %s' "$((idx + 1))" "$n" "''${labels[idx]}"
      done
    '';
  };
in
{
  # 公式リポジトリの flake を直接参照する（旧 herdr-nix はアーカイブ済み）。
  # プリビルドバイナリではなくソースビルドになるため、初回 rebuild は時間がかかる。
  home.packages = [
    herdr
    herdr-workspace-move
  ];

  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;

  # plugin の登録先は herdr が管理する状態ファイルで宣言的に置けないため、activation で登録する。
  # 同じパスへの link は冪等で、サーバ停止中でも登録できる
  home.file.".local/share/herdr-plugins/workspace-nav".source =
    ../configs/herdr/plugins/workspace-nav;
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${herdr}/bin/herdr plugin link "$HOME/.local/share/herdr-plugins/workspace-nav" >/dev/null
  '';
}
