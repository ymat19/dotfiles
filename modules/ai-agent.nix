{
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

  promptEditHook = pkgs.writeShellScript "prompt-edit-hook" ''
    INPUT=$(cat)
    FILE_PATH=$(echo "$INPUT" | ${pkgs.jq}/bin/jq -r '.tool_input.file_path // empty')
    if [ -z "$FILE_PATH" ]; then
      exit 0
    fi
    case "$FILE_PATH" in
      *SKILL.md*|*CLAUDE.md*|*AGENT.md*)
        cat <<'HOOK_JSON'
    {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"⚠️ プロンプトファイルの編集を検出。以下の基準で記述内容を自己レビューすること:\n1. Altitude: 具体的すぎず曖昧すぎない適切な抽象度か\n2. Signal Density: 削除しても効果が変わらないトークンがないか\n3. Structure: ヘッダー分割・論理順序・スキャン容易性\n4. Context Budget: インライン展開を避け、参照ベースの設計か\n5. Compaction Resilience: 各セクションが独立して意味を成すか\n6. Actionability: 具体例・コマンド・完了条件があるか\n根拠: \"Effective Context Engineering for AI Agents\" (Anthropic)\nあなた自身の判断ではなく、上記の原則のみに基づいて記述すること。"}}
    HOOK_JSON
        ;;
    esac
    exit 0
  '';

  codexUserPromptHook = pkgs.writeShellScript "codex-user-prompt-hook" ''
    ${pkgs.jq}/bin/jq -n \
      --arg context 'Codex setup note: prefer rtk wrappers for high-volume shell output when an equivalent exists (for example: rtk git, rtk grep, rtk read, rtk test, rtk npm, rtk cargo). Codex hooks cannot rewrite tool input yet; PreToolUse updatedInput currently fails open, so choose rtk directly when running commands.' \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$context}}'
  '';

  codexPromptEditHook = pkgs.writeShellScript "codex-prompt-edit-hook" ''
    INPUT=$(cat)
    COMMAND=$(echo "$INPUT" | ${pkgs.jq}/bin/jq -r '.tool_input.command // ""')
    case "$COMMAND" in
      *SKILL.md*|*CLAUDE.md*|*AGENTS.md*|*AGENT.md*)
        ${pkgs.jq}/bin/jq -n \
          --arg context 'プロンプトファイルの編集を検出。以下の基準で記述内容を自己レビューすること: 1. Altitude: 具体的すぎず曖昧すぎない適切な抽象度か 2. Signal Density: 削除しても効果が変わらないトークンがないか 3. Structure: ヘッダー分割・論理順序・スキャン容易性 4. Context Budget: インライン展開を避け、参照ベースの設計か 5. Compaction Resilience: 各セクションが独立して意味を成すか 6. Actionability: 具体例・コマンド・完了条件があるか。根拠: "Effective Context Engineering for AI Agents" (Anthropic)。あなた自身の判断ではなく、上記の原則のみに基づいて記述すること。' \
          '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$context}}'
        ;;
    esac
    exit 0
  '';

  agentContext = ''
    # ユーザー設定

    日本語で応答してください。
  ''
  + (lib.optionalString onWSL ''

    ## agent-browser (WSL)

    agent-browser はデフォルト headless で動く (Windows Chrome へ CDP 接続)。ウィンドウ表示が必要なときだけ `--headed` を付けること。

    ### 絶対禁止: chrome / daemon を pkill しない (再発防止)
    agent-browser は **1 daemon が Chrome 1 個を CDP で管理する**構造。`pkill` / `kill -9` で chrome や daemon を横から殺すと、daemon が死んだ Chrome に再接続して **about:blank / wedge** になり、次のコマンドで daemon が再 spawn されて **daemon・孤児 Chrome が多重化**し、コマンドがどのインスタンスに当たるか不定の不安定状態になる (過去にこれで大量のトークンと時間を浪費した)。

    - リセットは **`agent-browser close --all` のみ**。`pkill -9 chrome` / `pkill agent-browser` は使わない。
    - 調査・計測シーケンスの**途中で kill しない**。1 インスタンスを壊さず使い続ける。
    - about:blank 等の異常を見たら、結論を出す前に必ず自分の環境を疑う: `pgrep -fc 'chrome-linux64/chrome'` (健全な単一インスタンス = 6〜8 procs) と daemon 数を確認。多重化していたら掃除してから再開する。
    - 「アプリが遅い/壊れている」と結論する前に、backend 応答 (`curl -w` で時間計測) と自環境のプロセス数を切り分ける。
  '');

in
{
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
    inputs.mcp-servers-nix.homeManagerModules.default
  ];

  home.packages =
    let
      llmPkg = name: inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.${name};
      agentBrowserBin = llmPkg "agent-browser";
      #
      # WSL から Windows 側の Chrome に CDP 接続する設計。WSL 内に Chromium を起動しない
      # (WSLg 経由の描画オーバーヘッドと多重起動による負荷を避けるため)。
      #
      # ## 必要な Windows / WSL 側セットアップ (このラッパーの動作前提)
      #
      # ### 1. %USERPROFILE%\.wslconfig
      #
      #     [wsl2]
      #     networkingMode=mirrored
      #
      #     [experimental]
      #     hostAddressLoopback=true
      #
      # mirrored mode により WSL 内 `localhost` が Windows host の `localhost` と一致し、
      # Windows Chrome の CDP に到達できる。変更後 `wsl --shutdown` で反映。
      #
      # ### 2. Windows netsh portproxy (v4tov6)
      #
      # Chrome の `--remote-debugging-port` は IPv6 (`[::1]:<port>`) のみで listen するため、
      # 同じ port 番号で IPv4→IPv6 ブリッジを張る (管理者 PowerShell):
      #
      #     netsh interface portproxy add v4tov6 listenaddress=0.0.0.0 listenport=9222 \
      #       connectaddress=::1 connectport=9222
      #     netsh interface portproxy add v4tov6 listenaddress=0.0.0.0 listenport=9223 \
      #       connectaddress=::1 connectport=9223
      #
      # 9222 = headed (`--headed` 指定時)、9223 = headless (デフォルト)。
      # 両 mode を独立に常駐させるため別 port + 別 user-data-dir で分離している。
      #
      # ### 3. Hyper-V Firewall (mirrored mode で必須)
      #
      # mirrored mode の DefaultInboundAction=Block を WSL VM (VMCreatorId は固定値) で許可:
      #
      #     New-NetFirewallHyperVRule -Name 'WSL-Chrome-Debug' \
      #       -DisplayName 'WSL Chrome Debug' \
      #       -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' \
      #       -Direction Inbound -Protocol TCP -LocalPorts 9222,9223 -Action Allow
      #
      # ### 4. Chrome 専用プロファイル
      #
      # 普段使いの Chrome と分離するため `%LOCALAPPDATA%\chrome-agent-profile`
      # (headed) と `chrome-agent-profile-headless` (headless) を `--user-data-dir`
      # に指定 (初回起動時に自動作成)。Chrome は同じ profile を 2 プロセスで開けない
      # ため headed/headless でディレクトリを分離している。Windows username は
      # whoami.exe から動的取得しているので個人情報のハードコードは無い。
      #
      # ## このラッパーの役割
      #
      # - デフォルトは headless (port 9223, `--headless=new`)、`--headed` 指定時のみ
      #   headed (port 9222) に切り替えて Windows Chrome を on-demand 起動
      # - 接続先を明示するため agent-browser には `--cdp <port>` を常に渡す
      #   (AGENT_BROWSER_AUTO_CONNECT は使わない: 両モードが同時起動した際に
      #   ユーザが意図しない方の Chrome に繋がる事故を防ぐ)
      # - `NO_PROXY`: 企業内プロキシを bypass (localhost をプロキシ経由しない)
      # - `XDG_RUNTIME_DIR` fallback: WSL の `/run/user/$UID` が無い環境向け
      agentBrowserPkg =
        if onWSL then
          pkgs.writeShellScriptBin "agent-browser" ''
            export NO_PROXY="''${NO_PROXY:-localhost,127.0.0.1,::1}"
            export no_proxy="''${no_proxy:-localhost,127.0.0.1,::1}"
            if [ -z "''${XDG_RUNTIME_DIR:-}" ] || [ ! -d "''${XDG_RUNTIME_DIR:-}" ]; then
              export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
              mkdir -p "$XDG_RUNTIME_DIR"
              chmod 700 "$XDG_RUNTIME_DIR"
            fi

            # `--headed` の有無でモード判定。`--` 以降はサブコマンド引数なので走査しない。
            wants_headed=0
            for arg in "$@"; do
              case "$arg" in
                --) break ;;
                --headed) wants_headed=1 ;;
              esac
            done

            if [ "$wants_headed" = 1 ]; then
              cdp_port=9222
              profile_subdir=chrome-agent-profile
              chrome_mode_args=()
            else
              cdp_port=9223
              profile_subdir=chrome-agent-profile-headless
              chrome_mode_args=(--headless=new)
            fi

            cdp_probe() {
              ${pkgs.curl}/bin/curl -sf --max-time 1 --noproxy '*' \
                "http://localhost:$cdp_port/json/version" >/dev/null 2>&1
            }
            if ! cdp_probe; then
              # 並行起動でのレース回避用 lock (200ms 単位で取得試行、3秒で諦め)
              lock="/tmp/agent-browser-chrome-launch-$cdp_port.lock"
              for _ in $(seq 1 15); do
                if ( set -C; : > "$lock" ) 2>/dev/null; then
                  trap 'rm -f "$lock"' EXIT
                  break
                fi
                cdp_probe && break
                sleep 0.2
              done

              if ! cdp_probe; then
                # cmd.exe は WSL cwd (UNCパス) で起動できないため、WSL Interop で chrome.exe を直接 spawn。
                # Windows username は whoami.exe から動的取得 (DOMAIN\user 形式の user 部分)。
                win_user=$(/mnt/c/Windows/System32/whoami.exe 2>/dev/null | sed 's/.*\\//' | tr -d '\r\n')
                '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe' \
                  --remote-debugging-port=$cdp_port \
                  "--user-data-dir=C:\\Users\\''${win_user}\\AppData\\Local\\''${profile_subdir}" \
                  --no-first-run --no-default-browser-check \
                  "''${chrome_mode_args[@]}" \
                  </dev/null >/dev/null 2>&1 &
                disown
                # 起動完了待ち (最大 20 秒、Chrome の初回起動は重い)
                for _ in $(seq 1 100); do
                  cdp_probe && break
                  sleep 0.2
                done
              fi
            fi

            # 接続できない場合は agent-browser CLI に渡さず即終了する。
            # CLI 本体は --cdp 失敗時に自前 chromium を WSL 内へ install/起動する
            # フォールバックを持つため、ここで止めないと WSL 内に Linux chromium が
            # 落ちてきて意図しない経路が走る。
            if ! cdp_probe; then
              echo "agent-browser: Windows Chrome on port $cdp_port did not become reachable. Check Windows-side setup (portproxy / Hyper-V firewall / chrome.exe path)." >&2
              exit 1
            fi

            exec ${agentBrowserBin}/bin/agent-browser --cdp "$cdp_port" "$@"
          ''
        else
          agentBrowserBin;
    in
    [
      agentBrowserPkg
      (llmPkg "ccusage")
      (llmPkg "codex-acp")
      (llmPkg "oh-my-codex")
      (llmPkg "rtk")
    ];

  home.file.".agent-browser/config.json".source = jsonFormat.generate "agent-browser-config.json" {
    # WSL: ラッパーが `--cdp <port>` を渡して Windows Chrome に接続するため設定不要。
    # 非WSL環境では agent-browser CLI が自前でブラウザを起動する (デフォルト headless)。
  };

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

  home.file.".claude/hooks/teammate-idle-gate.sh" = {
    source = ../configs/claude-code/hooks/teammate-idle-gate.sh;
    executable = true;
  };

  home.file.".claude/hooks/task-completed-gate.sh" = {
    source = ../configs/claude-code/hooks/task-completed-gate.sh;
    executable = true;
  };

  home.file.".claude/hooks/rtk-rewrite.sh" = {
    source = ../configs/claude-code/hooks/rtk-rewrite.sh;
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
      effortLevel = "high";
      editorMode = "normal";
      autoMemoryEnabled = true;
      skipDangerousModePermissionPrompt = true;
      hooks = mergeHooks {
        PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "bash ~/.claude/hooks/rtk-rewrite.sh";
              }
            ];
          }
        ];
        PostToolUse = [
          {
            matcher = "Write|Edit";
            hooks = [
              {
                type = "command";
                command = "${promptEditHook}";
              }
            ];
          }
        ];
        TeammateIdle = [
          {
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/teammate-idle-gate.sh";
              }
            ];
          }
        ];
        TaskCompleted = [
          {
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/task-completed-gate.sh";
              }
            ];
          }
        ];
      };
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
      statusLine = {
        type = "command";
        command = "~/.claude/statusline.sh";
      };
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
      features = {
        codex_hooks = true;
        multi_agent = true;
        skills = true;
      };
    };
  };

  # programs.codex は ~/.codex/config.toml を read-only な nix store symlink (0444) として管理するが、
  # omnigent の codex-native harness は config.toml を shutil.copy2 でコピー (権限も複製) してから
  # MCP 設定を write_text で追記するため、0444 のコピーへの書き込みが PermissionError で失敗する。
  # store の内容を保ったまま writable な実ファイル (0600) として materialize して回避する。
  home.activation.materializeCodexConfigToml = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    cfg="$HOME/.codex/config.toml"
    if [ -L "$cfg" ]; then
      src="$(readlink -f "$cfg")"
      run rm -f "$cfg"
      run install -m 600 "$src" "$cfg"
    fi
  '';

  home.file.".codex/hooks.json".source = jsonFormat.generate "codex-hooks.json" {
    hooks = mergeCodexHooks {
      UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = "${codexUserPromptHook}";
              timeout = 5;
              statusMessage = "Loading Codex turn guidance";
            }
          ];
        }
      ];
      PostToolUse = [
        {
          matcher = "Edit|Write|apply_patch";
          hooks = [
            {
              type = "command";
              command = "${codexPromptEditHook}";
              timeout = 10;
              statusMessage = "Reviewing prompt-file edits";
            }
          ];
        }
      ];
    };
  };

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

  programs.agent-skills = {
    enable = true;
    sources.local.path = ../configs/claude-code/skills;
    sources.agent-browser = {
      path = inputs.agent-browser;
      subdir = "skills";
    };
    skills.enable = [
      "prompt-review"
      "agent-browser"
      "herdr"
    ];
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
