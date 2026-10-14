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

  # 組み込みのキーバインドにも CLI にも agent の並べ替えが無いため socket API を直接叩く。
  # agent_panel_sort が既定の spaces なら agent.list の順はワークスペース順→タブ順→ペイン順で
  # サイドバーの agents 一覧の表示順と一致し、agent 単位で並べ替える API も無いため、
  # 隣の agent との位置関係に応じてワークスペース / タブ / ペインのどれかを入れ替える
  herdr-agent-move = pkgs.writeShellApplication {
    name = "herdr-agent-move";
    runtimeInputs = with pkgs; [
      jq
      socat
    ];
    text = ''
      # usage: herdr-agent-move <up|down>
      dir=$1
      pane=''${HERDR_ACTIVE_PANE_ID:?}
      ws=''${HERDR_ACTIVE_WORKSPACE_ID:?}

      api() {
        printf '%s\n' "$1" | socat -t2 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"
      }

      list=$(api '{"id":"list","method":"workspace.list","params":{}}')
      agents=$(api '{"id":"agents","method":"agent.list","params":{}}')
      mapfile -t ids < <(jq -r '.result.workspaces[].workspace_id' <<<"$list")
      n=''${#ids[@]}
      declare -A rank=() has_agent=()
      for i in "''${!ids[@]}"; do rank[''${ids[i]}]=$i; done
      mapfile -t panes < <(jq -r '.result.agents[].pane_id' <<<"$agents")
      mapfile -t aws < <(jq -r '.result.agents[].workspace_id' <<<"$agents")
      mapfile -t atabs < <(jq -r '.result.agents[].tab_id' <<<"$agents")
      m=''${#panes[@]}
      for w in "''${aws[@]}"; do has_agent[$w]=1; done

      # insert_index は移動前のリスト上の挿入位置として解釈されるため、下へは +1 する
      insert_index() {
        echo $(($2 > $1 ? $2 + 1 : $2))
      }

      move_ws() {
        api "$(jq -nc --arg ws "$ws" --argjson i "$(insert_index "''${rank[$ws]}" "$1")" \
          '{id: "move", method: "workspace.move", params: {workspace_id: $ws, insert_index: $i}}')" >/dev/null
      }

      cur=""
      for a in "''${!panes[@]}"; do
        [[ ''${panes[a]} == "$pane" ]] && cur=$a && break
      done

      if [[ -z $cur ]]; then
        # agent 以外のペインからは、agent のいないワークスペースを飛ばしてワークスペースごと動かす
        next=''${rank[$ws]}
        while :; do
          case $dir in
            up) ((next > 0)) || exit 0; next=$((next - 1)) ;;
            down) ((next < n - 1)) || exit 0; next=$((next + 1)) ;;
          esac
          [[ -n ''${has_agent[''${ids[next]}]:-} ]] && break
        done
        move_ws "$next"
        exit 0
      fi

      case $dir in
        up) ((cur > 0)) || exit 0; nb=$((cur - 1)) ;;
        down) ((cur < m - 1)) || exit 0; nb=$((cur + 1)) ;;
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
    '';
  };
in
{
  # 公式リポジトリの flake を直接参照する（旧 herdr-nix はアーカイブ済み）。
  # プリビルドバイナリではなくソースビルドになるため、初回 rebuild は時間がかかる。
  home.packages = [
    herdr
    herdr-agent-move
  ];

  home.file.".config/herdr/config.toml".source = ../configs/herdr/config.toml;

  # 以前 prefix+J/K の連打用に link していた plugin の登録を外す。登録は herdr の状態ファイルにあり、
  # link 先が消えても残るため
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${herdr}/bin/herdr plugin unlink ymat19.workspace-nav >/dev/null 2>&1 || true
  '';
}
