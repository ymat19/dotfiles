{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # サイドバーの spaces 区画は設定でも境界線のドラッグでも消せず、agents と同じ一覧が二重に出るため、
  # 描画しないパッチを当てる（上流に区画の表示・並び順の設定は無い: herdrdev/herdr discussions #2466, #1408）
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/herdr-hide-spaces.patch ];
  });

  # 組み込みのキーバインドにワークスペース並べ替えが無く、CLI にも無いため socket API を直接叩く。
  # 組み込みの previous/next_agent も含め herdr には連打の仕組みが無いため、
  # popup 内でキーを読み続けることで prefix を押し直さずに連打できるようにする。
  herdr-workspace-move = pkgs.writeShellApplication {
    name = "herdr-workspace-move";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      socat
      util-linux
    ];
    text = ''
      # usage: herdr-workspace-move <reorder|focus> <up|down>
      #        herdr-workspace-move focus-wait    (workspace-nav plugin の popup 内で使う)
      #        herdr-workspace-move reopen <status>  (focus-wait から切り離して呼ぶ)
      mode=$1

      api() {
        printf '%s\n' "$1" | socat -t2 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"
      }

      # 押されたキーを up/down に変換して返す。それ以外のキーでは失敗を返す。
      # 連打の途中で考えている間に popup が消えると、次のキーがペインへ誤入力されるためタイムアウトは設けない
      read_step() {
        local saved key
        saved=$(stty -g)
        # -icrnl: Enter(CR) を C-j(LF) と区別するため。
        # bash の read -n は自前で ICRNL を立て直して CR を LF に化けさせるため、dd で 1 バイト読む
        stty -icanon -echo -icrnl min 1 time 0
        key=$(dd bs=1 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
        stty "$saved"
        # 0a=C-j 6a=j 4a=J / 0b=C-k 6b=k 4b=K
        case $key in
          0a | 6a | 4a) echo down ;;
          0b | 6b | 4b) echo up ;;
          *) return 1 ;;
        esac
      }

      # popup を開いたまま focus を移すと popup が見えなくなり入力も受けなくなる（実測）ため、
      # 切り替えのたびに移動先で plugin の popup を開き直して連打を受け付ける
      reopen() {
        api '{"id":"close","method":"popup.close","params":{}}' >/dev/null || true
        api "$(jq -nc --arg s "$1" \
          '{id: "open", method: "plugin.pane.open", params: {plugin_id: "ymat19.workspace-nav", entrypoint: "wait", env: {HERDR_NAV_STATUS: $s}}}')" >/dev/null
      }

      if [[ $mode == reopen ]]; then
        reopen "$2"
        exit 0
      fi

      # agent_panel_sort が既定の spaces なら、agent.list の順はワークスペース順→タブ順→ペイン順で
      # サイドバーの agents 一覧の表示順と一致する
      load() {
        list=$(api '{"id":"list","method":"workspace.list","params":{}}')
        agents=$(api '{"id":"agents","method":"agent.list","params":{}}')
        mapfile -t ids < <(jq -r '.result.workspaces[].workspace_id' <<<"$list")
        mapfile -t labels < <(jq -r '.result.workspaces[].label' <<<"$list")
        n=''${#ids[@]}
        declare -gA rank=() has_agent=()
        for i in "''${!ids[@]}"; do rank[''${ids[i]}]=$i; done
        mapfile -t panes < <(jq -r '.result.agents[].pane_id' <<<"$agents")
        mapfile -t aws < <(jq -r '.result.agents[].workspace_id' <<<"$agents")
        mapfile -t atabs < <(jq -r '.result.agents[].tab_id' <<<"$agents")
        mapfile -t names < <(jq -r '.result.agents[] | .tokens.task // .terminal_title_stripped // .agent' <<<"$agents")
        m=''${#panes[@]}
        for w in "''${aws[@]}"; do has_agent[$w]=1; done
      }
      load

      agent_status() {
        printf '%d/%d %s: %s' "$(($1 + 1))" "$m" "''${labels[rank[''${aws[$1]}]]}" "''${names[$1]}"
      }

      focus_step() {
        local cur next fw a r
        ((m > 0)) || return 1
        cur=$(jq -r '[.result.agents[].focused] | index(true) // empty' <<<"$agents")
        if [[ -n $cur ]]; then
          case $1 in
            up) next=$((cur > 0 ? cur - 1 : cur)) ;;
            down) next=$((cur < m - 1 ? cur + 1 : cur)) ;;
          esac
        else
          # agent 以外のペインにいるときは、現在のワークスペース位置から最寄りの agent へ移る。
          # plugin 経由の起動では HERDR_ACTIVE_WORKSPACE_ID が渡らないため、サーバ側の focus を基準にする
          fw=$(jq -r '.result.workspaces[] | select(.focused) | .workspace_id' <<<"$list")
          next=""
          for a in "''${!panes[@]}"; do
            r=''${rank[''${aws[a]}]}
            case $1 in
              down) if ((r >= rank[$fw])); then next=$a; break; fi ;;
              up) if ((r <= rank[$fw])); then next=$a; fi ;;
            esac
          done
          [[ -n $next ]] || return 1
        fi
        if [[ $next != "$cur" ]]; then
          api "$(jq -nc --arg p "''${panes[next]}" \
            '{id: "focus", method: "pane.focus", params: {pane_id: $p}}')" >/dev/null
        fi
        status=$(agent_status "$next")
      }

      if [[ $mode == focus-wait ]]; then
        printf ' %s' "$HERDR_NAV_STATUS"
        # popup が閉じてから次が開くまでに打たれたキーはペインへ誤入力されるため、
        # 一覧取得や focus 移動は popup を開いたまま済ませ、閉じて開き直す区間を最短にする。
        # popup.close はこの popup 自身のプロセスも終わらせるため、閉じ直しは切り離したプロセスに任せる
        if dir=$(read_step) && focus_step "$dir"; then
          setsid -f herdr-workspace-move reopen "$status" </dev/null >/dev/null 2>&1
        fi
        exit 0
      fi

      if [[ $mode == focus ]]; then
        focus_step "$2" && reopen "$status"
        exit 0
      fi

      # reorder: agent 単位の並べ替え API は無いため、隣の agent との位置関係に応じて
      # ワークスペース / タブ / ペインのどれかを入れ替えて agents 一覧上の順序を変える
      pane=''${HERDR_ACTIVE_PANE_ID:?}
      ws=''${HERDR_ACTIVE_WORKSPACE_ID:?}

      # insert_index は移動前のリスト上の挿入位置として解釈されるため、下へは +1 する
      insert_index() {
        echo $(($2 > $1 ? $2 + 1 : $2))
      }

      move_ws() {
        local idx=''${rank[$ws]} next=$1
        api "$(jq -nc --arg ws "$ws" --argjson i "$(insert_index "$idx" "$next")" \
          '{id: "move", method: "workspace.move", params: {workspace_id: $ws, insert_index: $i}}')" >/dev/null
      }

      cur_agent() {
        local a
        for a in "''${!panes[@]}"; do
          if [[ ''${panes[a]} == "$pane" ]]; then
            echo "$a"
            return
          fi
        done
      }

      step() {
        local cur nb tabs ti tn next
        cur=$(cur_agent)
        if [[ -z $cur ]]; then
          # agent 以外のペインからは、agent のいないワークスペースを飛ばしてワークスペースごと動かす
          next=''${rank[$ws]}
          while :; do
            case $1 in
              up) ((next > 0)) || return 0; next=$((next - 1)) ;;
              down) ((next < n - 1)) || return 0; next=$((next + 1)) ;;
            esac
            [[ -n ''${has_agent[''${ids[next]}]:-} ]] && break
          done
          move_ws "$next"
        else
          case $1 in
            up) ((cur > 0)) || return 0; nb=$((cur - 1)) ;;
            down) ((cur < m - 1)) || return 0; nb=$((cur + 1)) ;;
          esac
          if [[ ''${aws[cur]} != "''${aws[nb]}" ]]; then
            # 同じワークスペースの他の agent も一緒に動く
            move_ws "''${rank[''${aws[nb]}]}"
          elif [[ ''${atabs[cur]} != "''${atabs[nb]}" ]]; then
            # タブ内の他のペインも一緒に動く
            tabs=$(api "$(jq -nc --arg ws "$ws" '{id: "tabs", method: "tab.list", params: {workspace_id: $ws}}')")
            ti=$(jq -r --arg t "''${atabs[cur]}" '[.result.tabs[].tab_id] | index($t)' <<<"$tabs")
            tn=$(jq -r --arg t "''${atabs[nb]}" '[.result.tabs[].tab_id] | index($t)' <<<"$tabs")
            api "$(jq -nc --arg t "''${atabs[cur]}" --argjson i "$(insert_index "$ti" "$tn")" \
              '{id: "move", method: "tab.move", params: {tab_id: $t, insert_index: $i}}')" >/dev/null
          else
            # レイアウト上の位置は変えずに中身を入れ替えるため、画面上の配置も入れ替わる
            api "$(jq -nc --arg s "$pane" --arg t "''${panes[nb]}" \
              '{id: "swap", method: "pane.swap", params: {source_pane_id: $s, target_pane_id: $t}}')" >/dev/null
          fi
        fi
        load
      }

      show() {
        local cur
        cur=$(cur_agent)
        if [[ -n $cur ]]; then
          printf '\r\033[K %s' "$(agent_status "$cur")"
        else
          printf '\r\033[K %d/%d %s' "$((rank[$ws] + 1))" "$n" "''${labels[rank[$ws]]}"
        fi
      }

      step "$2"
      show
      while dir=$(read_step); do
        step "$dir"
        show
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
