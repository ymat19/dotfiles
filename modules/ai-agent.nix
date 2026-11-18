{
  config,
  lib,
  pkgs,
  inputs,
  onWSL ? false,
  onNixOS ? false,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  codexPackage = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  opencodePackage = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

  # ~/.config/claude-local-hooks.json が存在すれば読み込み、既存 hooks とリスト結合する
  # ファイル形式: { "PreToolUse": [{ "matcher": "...", "hooks": [...] }], ... }
  extraHooksFile = /home/ymat19/.config/claude-local-hooks.json;
  codexExtraHooksFile = /home/ymat19/.config/codex-local-hooks.json;

  readHooksFile =
    path: if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else { };

  extraHooks = readHooksFile extraHooksFile;
  codexExtraHooks = readHooksFile codexExtraHooksFile;

  mergeHookSets =
    extra: base:
    lib.mapAttrs (name: baseList: baseList ++ (extra.${name} or [ ])) base
    // lib.filterAttrs (name: _: !(base ? ${name})) extra;

  mergeHooks = mergeHookSets extraHooks;
  mergeCodexHooks = mergeHookSets codexExtraHooks;

  codexHooks = mergeCodexHooks {
    SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${herdrAgentStateHook "~/.codex/herdr-agent-state.sh"}";
            timeout = 10;
          }
        ];
      }
    ];
  };
  codexHooksFile = jsonFormat.generate "codex-hooks.json" { hooks = codexHooks; };

  # Orca (modules/nixos/orca.nix) の hook を足した設定。home-manager が生成する settings.json と
  # 同じ内容を作って Orca に通す（home.file の値を参照すると自己参照になるため作り直している）
  orca = import ../lib/orca.nix { inherit pkgs; };
  orcaHooked = orca.withHooks {
    claudeSettings = jsonFormat.generate "claude-code-settings.json" (
      config.programs.claude-code.settings
      // {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      }
    );
    codexHooks = codexHooksFile;
    agents = [
      config.programs.claude-code.finalPackage
      codexPackage
    ];
  };
  # Orca の hook も Codex に信頼させるため、Orca が書いた後の hooks.json から信頼を計算する。
  # 中身が参照する store path は hooks.json 自体が依存として保持するので、ここでは文脈を捨ててよい
  trustedCodexHooks =
    if onNixOS then
      (builtins.fromJSON (
        builtins.unsafeDiscardStringContext (builtins.readFile "${orcaHooked}/codex-hooks.json")
      )).hooks
    else
      codexHooks;

  # Codex は config.toml に信頼を記録した hook しか動かさないが、config.toml は rebuild のたびに
  # 作り直されて対話で与えた信頼が消えるため、Codex と同じ計算で信頼を前もって書いておく。
  # 計算は codex-rs/hooks/src/engine/discovery.rs の hook_key / hook_hash に合わせている。
  # キーは hooks.json のパス・イベント名（snake_case）・グループ番号・hook 番号で、
  # 値は省略値を補った hook 定義をキー順に並べた JSON の SHA-256。
  # Nix の builtins.toJSON はキー順・空白なしで出力するので serde_json と同じ文字列になる
  codexHooksJsonPath = "${config.home.homeDirectory}/.codex/hooks.json";
  codexHookEventLabel =
    event:
    lib.concatStrings (
      lib.imap0 (i: c: if lib.toLower c != c then (if i == 0 then "" else "_") + lib.toLower c else c) (
        lib.stringToCharacters event
      )
    );
  codexHookTrustState = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        event: groups:
        lib.concatLists (
          lib.imap0 (
            groupIndex: group:
            lib.imap0 (
              hookIndex: hook:
              let
                label = codexHookEventLabel event;
                identity = {
                  event_name = label;
                  hooks = [
                    (
                      {
                        type = "command";
                        inherit (hook) command;
                        timeout = hook.timeout or 600;
                        async = hook.async or false;
                      }
                      // lib.optionalAttrs (hook ? statusMessage) { inherit (hook) statusMessage; }
                    )
                  ];
                }
                // lib.optionalAttrs (group ? matcher) { inherit (group) matcher; };
              in
              lib.nameValuePair "${codexHooksJsonPath}:${label}:${toString groupIndex}:${toString hookIndex}" {
                trusted_hash = "sha256:${builtins.hashString "sha256" (builtins.toJSON identity)}";
              }
            ) group.hooks
          ) groups
        )
      ) trustedCodexHooks
    )
  );

  # herdr のサイドバーは行を折り返さず 1 行に切り詰めるため、要約を表示幅で切って
  # $task1..$task3 の複数トークンに分け、rows 側で 1 トークン 1 行に並べる。
  # 幅はサイドバー既定幅 26 から右境界線 1・2 行目以降のインデント 3・スクロールバー 1 を引いた値。
  # 前回より短い要約で古い行が残らないよう、使わなかったトークンは消す
  herdrTask = pkgs.writeShellApplication {
    name = "herdr-task";
    text = ''
      # usage: herdr-task <要約>
      [[ -n ''${HERDR_PANE_ID:-} && -n ''${HERDR_BIN_PATH:-} ]] || exit 0
      # hook から呼ばれると locale が未設定のことがあり、その場合は文字数ではなくバイト数で数えてしまう
      export LC_ALL=C.UTF-8
      width=21
      max_lines=3
      text=$1
      lines=()
      line=""
      w=0
      for ((i = 0; i < ''${#text}; i++)); do
        c=''${text:i:1}
        printf -v cp '%d' "'$c"
        # East Asian Wide の厳密な判定はせず、ASCII 以外を全角とみなす（日本語の要約が前提）
        cw=$((cp < 128 ? 1 : 2))
        if ((w + cw > width)); then
          lines+=("$line")
          ((''${#lines[@]} < max_lines)) || break
          line=""
          w=0
        fi
        line+=$c
        w=$((w + cw))
      done
      if [[ -n $line ]] && ((''${#lines[@]} < max_lines)); then lines+=("$line"); fi

      args=(--clear-token task)
      for ((n = 1; n <= max_lines; n++)); do
        if ((n <= ''${#lines[@]})); then
          args+=(--token "task$n=''${lines[n - 1]}")
        else
          args+=(--clear-token "task$n")
        fi
      done
      "$HERDR_BIN_PATH" pane report-metadata "$HERDR_PANE_ID" --source claude-task "''${args[@]}" >/dev/null
    '';
  };

  # herdr の Agents パネルに作業内容の要約を出す。
  #
  # Claude Code が自動生成する端末タイトルは初回プロンプトから作られ、以後更新されない。
  # 「Issue 219 に着手」のような指示だと中身の無いタイトルになるため、Issue 等を読んで
  # 作業内容を把握した Claude 自身に要約させて herdr の $task1..$task3 トークンへ書かせる。
  # 1 セッション 1 回しか要らない指示を CLAUDE.md に常駐させたくないので、
  # session_id ごとのマーカーで初回プロンプトにだけ差し込む。
  # Claude が報告するまでの間も空欄にならないよう、プロンプト本文を仮の値として先に入れる。
  herdrTaskHook = pkgs.writeShellScript "herdr-task-hook" ''
    [ -n "$HERDR_PANE_ID" ] && [ -n "$HERDR_BIN_PATH" ] || exit 0
    INPUT=$(cat)
    SESSION=$(echo "$INPUT" | ${pkgs.jq}/bin/jq -r '.session_id // empty')
    [ -n "$SESSION" ] || exit 0

    MARKER_DIR="''${XDG_RUNTIME_DIR:-/tmp}/claude-herdr-task"
    mkdir -p "$MARKER_DIR"
    [ -e "$MARKER_DIR/$SESSION" ] && exit 0
    touch "$MARKER_DIR/$SESSION"

    PROMPT=$(echo "$INPUT" | ${pkgs.jq}/bin/jq -r '.prompt // ""' | tr '\n' ' ')
    ${herdrTask}/bin/herdr-task "$PROMPT" >/dev/null 2>&1 || true

    ${pkgs.jq}/bin/jq -n \
      --arg context "herdr のサイドバーに表示する作業内容の要約を登録すること。作業内容を把握した時点で（Issue 番号や URL だけの指示なら、それを読んで中身を理解した後に）、何をするセッションかが一目で分かる 30 字程度の日本語の要約を作り、Bash で次を 1 回だけ実行する: herdr-task '<要約>'。Issue 番号があれば要約の先頭に #番号 を付ける。ユーザーへの報告は不要。" \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$context}}'
    exit 0
  '';

  # herdr サーバー再起動時にエージェントのペインを各自の resume コマンドで復帰させる公式 integration。
  #
  # `herdr integration install <agent>` は settings.json / hooks.json / tui.json を直接書き換えるため、
  # Nix 管理の設定とは共存できない。スクリプトだけをビルド時に herdr 自身に生成させ、
  # 登録は各エージェントの Nix 設定で行う。本文をリポジトリへ複製しないのは、herdr の flake 更新で
  # integration version が上がったとき自動で追従させるため。
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdrIntegrations = pkgs.runCommand "herdr-integrations" { } ''
    export HOME="$TMPDIR"
    # インストーラはエージェントの設定ディレクトリが無いと拒否する
    mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"
    for agent in claude codex opencode; do
      ${herdrPackage}/bin/herdr integration install "$agent" >/dev/null
    done
    mkdir -p "$out/opencode/plugins"
    cp "$HOME/.claude/hooks/herdr-agent-state.sh" "$out/claude-agent-state.sh"
    cp "$HOME/.codex/herdr-agent-state.sh" "$out/codex-agent-state.sh"
    cp "$HOME/.config/opencode/herdr-tui-session.js" "$out/opencode/"
    cp "$HOME/.config/opencode/plugins/herdr-agent-state.js" "$out/opencode/plugins/"
  '';
  # 生成スクリプトは python3 を PATH から探し、無ければ黙って exit 0 する。
  # 環境に python3 を常駐させたくないので、フック実行時だけ PATH に足す。
  herdrAgentStateHook =
    script:
    pkgs.writeShellScript "herdr-agent-state-hook" ''
      PATH=${pkgs.python3}/bin:$PATH exec ${pkgs.bash}/bin/bash ${script} session
    '';

  agentContext = ''
    # ユーザー設定

    日本語で応答してください。

    ## ドキュメント記述の役割分担

    各媒体に書くべき情報を取り違えないこと:

    - コード: How（どう実現しているか）
    - テストコード: What（何を満たすべきか）
    - コミットログ: Why（なぜこの変更が必要か）
    - コードコメント: Why not（なぜ一般的な手段を採らなかったか）

    コメントは全行・全関数に付けるものではない。一般的・自明な実装には書かず、
    非自明な選択（定石を外した、直感に反する、罠を避けた等）をした箇所に限り、
    「なぜ普通のやり方にしなかったか」を残すこと。自明なコメントはノイズなので付けない。

    ## 共有チェックアウトとワークツリー

    共有チェックアウト（リポジトリ本体のディレクトリ）はユーザーや他エージェントと共用している。そこで編集すると他者の作業と衝突する。

    - **共有チェックアウトは常に main を指す**。別ブランチへ切り替えない。
    - **共有チェックアウトは読み取り専用**。ファイル編集・コミット・ブランチ切り替え・stash 等、作業ツリーや HEAD を変える操作はしない。
    - **`git pull` は例外的にいつでもしてよく、あらゆる作業の最初に必ず実行する**。古い状態を読んで調査・実装を始めない。
    - **編集を伴う作業はワークツリー必須**。作成は `EnterWorktree` で行い、既定の場所に作らせる。`git worktree add` で `/tmp` や任意のディレクトリなど訳の分からない場所に雑に作らない。

    ## テストの実行単位

    ローカルであれ CI であれ、いきなりテストを全件実行するのは極めて愚かな行為であり、時間とマシン資源の浪費である。

    - **まず手元で差分に対応する個々のテストだけを実行し、pass を担保する**。ここを省略して全件へ進むことは許されない。
    - 個別の green を確認して初めて全件実行へ進む。
    - **全件実行はマシン負荷を鑑み、極力 CI 上で回す**。ローカルでの全件実行は CI が使えない場合の最終手段である。

    ## 全コアを使い切るな

    ユーザーは同じマシンで並行して作業している。テスト・ビルド・lint 等で全コアを占有するとマシン全体が固まり、ユーザーの作業を止める。

    - **並列度はコア数の半分（`$(( $(nproc) / 2 ))`）以下に抑える**。多くのツールはデフォルトで全コアを使うので、デフォルトに任せず必ず明示的に指定する。
      - 例: `make -j4`、`cargo build -j 4`、`pytest -n 4`、`jest --maxWorkers=50%`、`go test -p 4`、`nix build --max-jobs 2 --cores 4`
    - 長時間かかる重い処理には `nice -n 19` を付けて優先度を下げる。
    - 重い処理を同時に複数走らせない。background 実行やサブエージェントで並列化する場合も、合計の並列度で上限を守る。

    ## パブリックリポジトリへの書き込み

    パブリックリポジトリへの書き込みは全世界に公開され、取り消しても複製やキャッシュが残る。

    - **ユーザーの明示的な許可なしに、パブリックリポジトリへ書き込む操作をしない**。push、PR 作成、issue 作成、コメント投稿、release 作成など、リモートに痕跡を残す操作すべてが対象。
    - 許可はその都度・その操作に限る。過去に一度許可されたことを根拠に別の操作へ広げない。
    - clone、fetch、pull、issue や PR の閲覧など読み取りだけの操作は許可不要。

    ## 待機は失敗を即座に検知する形でしか書くな

    「成功するまで待つ」ループで最大数分〜十数分ブロックし、その間に対象が失敗し続けていても気づかない待ち方は、ユーザーの時間を捨てる最悪の行為である（過去、自動再起動で失敗を繰り返すサービスを 9 分待ち続けた）。

    - **待つ前に、何を・なぜ・最長どれだけ待つかをユーザーに一言伝える**。黙って長時間ブロックしない。
    - **成功条件だけでなく失敗条件も必ず拾う**。ログのエラー、プロセスの終了、再起動回数の増加などを監視対象に含める。systemd の `Restart=` 付きユニットは失敗しても `failed` にならず `activating` のまま再起動を繰り返すので、状態だけを見て失敗を判定しない。
    - **ポーリング間隔は最大 3 分**。自分から状態とログを見に行く間隔が 3 分を超えることは絶対に許さない。
      - 3 分を超える sleep、3 分を超えるタイムアウトを付けた 1 本の待機、`gh run watch` のように完了まで戻ってこないコマンド、3 分を超える遅延の wakeup 予約は禁止。
      - **バックグラウンドに投げて完了通知を待つだけの待機は禁止**。background で走らせた処理やサブエージェントも、3 分以内の間隔で自分から出力・ログ・状態を確認しに行く。
    - **ポーリングのたびに考察し、正常か異常かを判断する**。状態を見て次の待機へ進むだけの機械的なループにしない。
      - 前回の確認から何が進んだか（ログの新しい行、進捗表示、ジョブのステップ、出力ファイルの増加、CPU やネットワークの動き）を比べ、想定どおりのペースで進んでいるかを判断する。
      - エラーや警告、リトライ・再起動、前回から何も進んでいない、想定より明らかに遅い、のいずれかなら異常とみなす。
      - **異常なら次のポーリングを待たずに即座に動く**。止める・原因を調べる・直す・ユーザーに報告する、のいずれかをその場で行う。「もう少し待てば進むかも」で様子見を続けない。
      - 判断の結果（正常／異常とその根拠）をユーザーに一言で伝える。
    - 失敗するたびに重い処理をやり直す自動再起動は、初回セットアップ中は無効にするか、失敗したら止まる形にする。

    ## 「無い」「できない」は確かめてから言え

    確かめずに「無い」「動かない」と断定し、それを前提に作業を飛ばしたり、要らない回り道をユーザーに提案したりするのは、ユーザーの時間を捨てる最悪の行為である（過去、手元に `chromium` も `google-chrome` もあるのに、Playwright の `~/.cache/ms-playwright` が空というだけで「NixOS では Chromium を動かせない」と書いて E2E を飛ばし、mise や nix での入れ直しまで質問を重ねた）。

    - **「無い」「入っていない」「動かない」「できない」と書く前に、それを直接示す確認を実際に走らせる**。コマンドなら `command -v` や `--version`、ファイルなら実在の確認、動作なら実行そのもの。確認していないなら断定しない。
    - **一つの場所に無いことを、マシン全体に無いことと取り違えない**。ツール専用のキャッシュやパッケージマネージャ管理下が空でも、システムの PATH や nix store、別名（`chromium` / `chromium-browser` / `google-chrome-stable` 等）にあることは普通にある。
    - **直前の失敗から「この環境だから無理」と一般化しない**。別のものが失敗した事実は、いま扱うものが動かない根拠にならない。
    - **README・設定・既存スクリプトに回避策や代替手段が書いてあれば、まずそれを試す**。見つけたのに試さず別の手段を提案しない。
    - **作業を飛ばす・環境を作り直す・ユーザーに選択を迫る前に、前提の「無い」「できない」を確かめたかを見直す**。確かめていない前提でユーザーに質問しない。
    - 本当に確かめても無い・動かない場合は、何をどう確かめたか（実行したコマンドと結果）を添えて報告する。
  '';

in
{
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
    inputs.mcp-servers-nix.homeManagerModules.default
  ];

  home.packages =
    let
      llmPkg = name: inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.${name};
    in
    [
      herdrTask
      (llmPkg "ccusage")
      (llmPkg "codex-acp")
      (llmPkg "oh-my-codex")
    ];

  # WSL 上の Claude Code が頻繁に powershell.exe を起こして Windows プロファイルを
  # 取得しに行く挙動を抑制する。参考: https://zenn.dev/momonga/articles/ee5b114e038938
  # zshenv / bashrc 双方で適用 (Claude Code 起動シェルがどちらでもよいように)。
  programs.zsh.envExtra = lib.mkIf onWSL ''
    export CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1
    if [ -z "''${USERPROFILE:-}" ] && [ -x /mnt/c/Windows/System32/whoami.exe ]; then
      __wsl_win_user=$(/mnt/c/Windows/System32/whoami.exe 2>/dev/null | sed 's/.*\\//' | tr -d '\r\n')
      if [ -n "$__wsl_win_user" ] && [ -d "/mnt/c/Users/$__wsl_win_user" ]; then
        export USERPROFILE="/mnt/c/Users/$__wsl_win_user"
      fi
      unset __wsl_win_user
    fi
  '';

  programs.bash.bashrcExtra = lib.mkIf onWSL ''
    export CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1
    if [ -z "''${USERPROFILE:-}" ] && [ -x /mnt/c/Windows/System32/whoami.exe ]; then
      __wsl_win_user=$(/mnt/c/Windows/System32/whoami.exe 2>/dev/null | sed 's/.*\\//' | tr -d '\r\n')
      if [ -n "$__wsl_win_user" ] && [ -d "/mnt/c/Users/$__wsl_win_user" ]; then
        export USERPROFILE="/mnt/c/Users/$__wsl_win_user"
      fi
      unset __wsl_win_user
    fi
  '';

  home.file.".claude/statusline.sh" = {
    source = ../configs/claude-code/statusline.sh;
    executable = true;
  };

  home.file.".claude/hooks/user-scope-guard.sh" = {
    source = ../configs/claude-code/hooks/user-scope-guard.sh;
    executable = true;
  };

  home.file.".claude/hooks/japanese-only-guard.sh" = {
    source = ../configs/claude-code/hooks/japanese-only-guard.sh;
    executable = true;
  };

  home.file.".claude/hooks/dotfiles-push-guard.sh" = {
    source = ../configs/claude-code/hooks/dotfiles-push-guard.sh;
    executable = true;
  };

  # `herdr integration status` はこのパスで導入有無と version を判定するため、生成物をここへ置く
  home.file.".claude/hooks/herdr-agent-state.sh" = {
    source = "${herdrIntegrations}/claude-agent-state.sh";
    executable = true;
  };

  home.file.".claude/assets/claude-icon.png" = {
    source = ../configs/claude-code/assets/claude-icon.png;
  };

  # rebuild 時に ~/.claude.json の mcpServers と autoCompactEnabled を Nix 管理の設定で同期
  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_JSON="$HOME/.claude.json"
    MCP_JSON="$HOME/.config/mcp/mcp.json"
    if [ -f "$CLAUDE_JSON" ] && [ -f "$MCP_JSON" ]; then
      ${pkgs.jq}/bin/jq --slurpfile mcp "$MCP_JSON" '
        .mcpServers = $mcp[0].mcpServers |
        .autoCompactEnabled = true
      ' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
        && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    fi
  '';

  # rebuild 時に Claude Code の settings.local.json から hooks を剥がす。
  # フックは Nix 管理 (~/.claude/settings.json) が正であり、local 側に入る hooks は
  # 外部ツール（overstory 等）が注入した残骸なので一律除去する。permissions 等は保持。
  # 対象は ~/.claude/settings.local.json だけ。各リポジトリの settings.local.json のフックは
  # そのリポジトリが置いたもので、rebuild のたびに消すと復元と消去を繰り返す。
  home.activation.pruneClaudeLocalHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for f in "$HOME/.claude/settings.local.json"; do
      [ -f "$f" ] || continue
      if ${pkgs.jq}/bin/jq -e 'has("hooks")' "$f" >/dev/null 2>&1; then
        ${pkgs.jq}/bin/jq 'del(.hooks)' "$f" > "$f.tmp" \
          && mv "$f.tmp" "$f" \
          && echo "pruned stale hooks from $f"
      fi
    done
  '';

  mcp-servers.programs = {
    context7.enable = true;
  };

  programs.mcp.enable = true;

  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    enableMcpIntegration = true;
    context = agentContext;
    settings = {
      promptSuggestionEnabled = false;
      editorMode = "normal";
      autoMemoryEnabled = true;
      # セッション記録は LLM Wiki の夜間ジョブが読む素材。既定の 30 日では処理が追いつく前に消える
      cleanupPeriodDays = 3650;
      skipDangerousModePermissionPrompt = true;
      env.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      hooks = mergeHooks {
        PreToolUse = [
          {
            matcher = "Write|Edit|NotebookEdit";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/user-scope-guard.sh";
              }
            ];
          }
        ];
        UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = "${herdrTaskHook}";
              }
            ];
          }
        ];
        # 英語で応答したまま終わらせない・dotfiles の commit を main に入れずに終わらせない
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/japanese-only-guard.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/dotfiles-push-guard.sh";
              }
            ];
          }
        ];
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "${herdrAgentStateHook "~/.claude/hooks/herdr-agent-state.sh"}";
                timeout = 10;
              }
            ];
          }
        ];
      };
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
      };
      # 既定の fullscreen レンダラーは代替画面に描画してマウスを掴むため、alacritty のスクロールバックにも
      # herdr のコピーモードにも会話が残らず、ホイールも Claude Code に吸われる。従来のレンダラーに固定する
      tui = "default";
      permissions = {
        defaultMode = "bypassPermissions";
        allow = [
          "Bash(cat:*)"
          "Bash(ls:*)"
          "Bash(grep:*)"
          "Bash(find:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(less:*)"
          "Bash(git:*)"
          "Bash(journalctl:*)"
          "Bash(socat - UNIX-CONNECT:/run/user/1000/colorshell.sock)"
          "WebFetch(domain:benz.gitbook.io)"
          "WebSearch"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:www.pomerium.com)"
          "WebFetch(domain:code.claude.com)"
          "WebFetch(domain:dev.to)"
          "Read(*)"
          "Glob(*)"
          "Grep(*)"
        ];
      };
    };
  };

  programs.codex = {
    enable = true;
    package = codexPackage;
    enableMcpIntegration = true;
    context = agentContext;
    settings = {
      model_reasoning_effort = "high";
      approval_policy = "never";
      sandbox_mode = "danger-full-access";
      notice = {
        hide_full_access_warning = true;
      };
      tui = {
        status_line = [
          "model-with-reasoning"
          "git-branch"
          "context-used"
          "context-remaining"
          "used-tokens"
          "context-window-size"
          "five-hour-limit"
          "weekly-limit"
        ];
      };
      agents = {
        max_threads = 6;
        max_depth = 1;
        job_max_runtime_seconds = 1800;
      };
      tools = {
        web_search = true;
      };
      hooks.state = codexHookTrustState;
      features = {
        codex_hooks = true;
        multi_agent = true;
        skills = true;
      };
    };
  };

  programs.opencode = {
    enable = true;
    package = opencodePackage;
    # programs.mcp.servers（context7 等）を ~/.config/opencode/opencode.json の mcp キーへ反映
    enableMcpIntegration = true;
    # 共通の agentContext を ~/.config/opencode/AGENTS.md として配置
    context = agentContext;
    settings = {
      # パッケージは Nix 管理なので opencode 自身の自動更新は無効化
      autoupdate = false;
    };
  };

  # herdr の integration。サーバー再起動後に `opencode --session <id>` で復帰させる。
  # programs.opencode.tui は tui.json に書くが、herdr は tui.jsonc しか見ずに needs repair と判定するため直接置く
  xdg.configFile."opencode/tui.jsonc".text = builtins.toJSON {
    plugin = [ "./herdr-tui-session.js" ];
  };

  # `herdr integration status` は各エージェントの設定ディレクトリ内のこのパスで導入有無と version を判定する
  home.file.".codex/herdr-agent-state.sh" = {
    source = "${herdrIntegrations}/codex-agent-state.sh";
    executable = true;
  };
  xdg.configFile."opencode/herdr-tui-session.js".source =
    "${herdrIntegrations}/opencode/herdr-tui-session.js";
  xdg.configFile."opencode/plugins/herdr-agent-state.js".source =
    "${herdrIntegrations}/opencode/plugins/herdr-agent-state.js";

  # programs.codex は ~/.codex/config.toml を read-only な nix store symlink (0444) として管理するが、
  # omnigent の codex-native harness は config.toml を shutil.copy2 でコピー (権限も複製) してから
  # MCP 設定を write_text で追記するため、0444 のコピーへの書き込みが PermissionError で失敗する。
  # store の内容を保ったまま writable な実ファイル (0600) として materialize して回避する。
  #
  # ただし materialize すると config.toml は symlink ではない実ファイルになるため、次回の
  # switch で home-manager の checkLinkTargets が「symlink を作る位置に実ファイルがある」と判断し
  # config.toml.backup へ退避しようとする。backup が既にあると clobber エラーで switch が失敗する。
  # materialize 後の実ファイルの内容は store と同一なので、link 検査前に安全に削除して
  # home-manager が改めて symlink を張り直せるようにする（stale backup も掃除する）。
  home.activation.cleanupCodexConfigTomlBeforeLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    cfg="$HOME/.codex/config.toml"
    if [ -e "$cfg" ] && [ ! -L "$cfg" ]; then
      run rm -f "$cfg"
    fi
    run rm -f "$cfg.backup" "$cfg.backup.stale"
  '';

  home.activation.materializeCodexConfigToml = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    cfg="$HOME/.codex/config.toml"
    if [ -L "$cfg" ]; then
      src="$(readlink -f "$cfg")"
      run rm -f "$cfg"
      run install -m 600 "$src" "$cfg"
    fi
  '';

  home.file.".codex/hooks.json".source =
    if onNixOS then "${orcaHooked}/codex-hooks.json" else codexHooksFile;
  home.file."${config.programs.claude-code.configDir}/settings.json".source = lib.mkIf onNixOS (
    lib.mkForce "${orcaHooked}/claude-settings.json"
  );

  home.file.".codex/agents/pr-reviewer.toml".text = ''
    name = "pr_reviewer"
    description = "PR reviewer focused on correctness, regressions, security, and missing tests."
    model_reasoning_effort = "high"
    sandbox_mode = "read-only"
    developer_instructions = """
    Review code like an owner.
    Lead with concrete findings ordered by severity, cite files and lines, and avoid style-only comments unless they hide a real bug.
    Focus on correctness, behavior regressions, security, reliability, and missing tests.
    Do not edit files.
    """
    nickname_candidates = ["Reviewer", "Risk", "Audit"]
  '';

  home.file.".codex/agents/code-mapper.toml".text = ''
    name = "code_mapper"
    description = "Read-only codebase explorer for mapping relevant files, symbols, and execution paths."
    model_reasoning_effort = "medium"
    sandbox_mode = "read-only"
    developer_instructions = """
    Stay in exploration mode.
    Use fast search and targeted file reads to map the relevant execution path.
    Return concise evidence with file references and avoid making changes.
    """
    nickname_candidates = ["Mapper", "Trace", "Scope"]
  '';

  home.file.".codex/agents/worker-committer.toml".text = ''
    name = "worker_committer"
    description = "Implementation worker that makes scoped changes and commits when explicitly asked."
    model_reasoning_effort = "high"
    sandbox_mode = "workspace-write"
    developer_instructions = """
    Own only the files assigned by the parent agent.
    Make the smallest defensible change, validate the changed behavior, and keep unrelated files untouched.
    Commit only when the user or parent agent explicitly asks for a commit.
    """
    nickname_candidates = ["Builder", "Patch", "Implementer"]
  '';

  # modern-web-guidance の CLI は検索クエリや取得した指針の ID を Google に送る。
  # DISABLE_TELEMETRY=1 で止まる（Claude Code など同じ変数を見る他ツールも止まる）
  home.sessionVariables.DISABLE_TELEMETRY = "1";

  programs.agent-skills = {
    enable = true;
    sources.local.path = ../configs/claude-code/skills;
    # herdr 本体に同梱の SKILL.md を直接参照する。
    # 手元にコピーを置くとバージョン追従が手動になり、CLI 変更に追いつけなくなるため。
    sources.herdr = {
      path = inputs.herdr;
      subdir = "skills";
    };
    sources.stop-describing-ui = {
      path = inputs.stop-describing-ui;
      subdir = "skills";
    };
    # Chrome / Edge / Firefox / MDN チームによる最新 Web プラットフォームの指針。
    # SKILL.md は実行時に CLI（modern-web-guidance@latest）で指針を検索・取得する
    sources.modern-web-guidance = {
      path = inputs.modern-web-guidance;
      subdir = "skills";
    };
    # Orca 同梱の版をそのまま使う。Orca の更新に合わせて中身も変わる
    sources.orca = lib.mkIf onNixOS { path = orca.skills; };
    skills.enable = [
      "prompt-review"
      "herdr"
      "stop-describing-ui"
      "modern-web-guidance"
      "chrome-extensions"
    ]
    # 同梱スキルの増減に追従させるため、名前を列挙せずビルド結果から拾う
    ++ lib.optionals onNixOS (builtins.attrNames (builtins.readDir orca.skills));
    targets.claude.enable = true;
    targets.codex = {
      enable = true;
      dest = "$HOME/.agents/skills";
      structure = "symlink-tree";
    };
    targets.codex-legacy = {
      enable = true;
      dest = "$HOME/.codex/skills";
      structure = "symlink-tree";
    };
  };
}
