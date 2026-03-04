{
  lib,
  pkgs,
  inputs,
  ...
}:
let
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
      (llmPkg "agent-browser")
      (llmPkg "ccusage")
      (llmPkg "rtk")
      (llmPkg "workmux")
      (llmPkg "backlog-md")
      pkgs.inotify-tools
    ];

  home.file.".claude/statusline.sh" = {
    source = ../configs/claude-code/statusline.sh;
    executable = true;
  };

  home.file.".claude/backlog-watch.sh" = {
    source = ../configs/claude-code/backlog-watch.sh;
    executable = true;
  };

  # backlog-md default project config (avoids `backlog init`)
  xdg.configFile."backlog-md/default-config.yml".text = ''
    project_name: "default"
    default_status: "To Do"
    statuses: ["To Do", "In Progress", "Done"]
    labels: []
    date_format: yyyy-mm-dd
    max_column_width: 20
    auto_open_browser: false
    default_port: 6420
    remote_operations: false
    auto_commit: false
    bypass_git_hooks: false
    check_active_branches: false
    active_branch_days: 30
    task_prefix: "task"
  '';

  # workmux global config
  xdg.configFile."workmux/config.yaml".text = ''
    nerdfont: true
    agent: claude
    merge_strategy: rebase
    mode: session
    panes:
      - command: <agent>
        focus: true
      - split: horizontal
  '';

  # rebuild 時に ~/.claude.json の mcpServers を Nix 管理の設定で同期
  home.activation.syncClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_JSON="$HOME/.claude.json"
    MCP_JSON="$HOME/.config/mcp/mcp.json"
    if [ -f "$CLAUDE_JSON" ] && [ -f "$MCP_JSON" ]; then
      ${pkgs.jq}/bin/jq --slurpfile mcp "$MCP_JSON" '
        .mcpServers = ($mcp[0].mcpServers + {
          "backlog-md": {
            "command": "backlog",
            "args": ["mcp", "start"]
          }
        })
      ' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
        && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    fi
  '';

  mcp-servers.programs = {
    serena = {
      enable = true;
      enableWebDashboard = false;
    };
    context7.enable = true;
  };

  programs.mcp.enable = true;

  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    enableMcpIntegration = true;
    memory.text = ''
      # ユーザー設定

      日本語で応答してください。

      # コンテキスト管理

      Auto compact は無効化されている。コンテキストウィンドウの溢れはセッションの
      死を意味する。大きなタスクや調査は必ず Agent ツール（サブエージェント）や
      workmux に委譲し、メインコンテキストを温存すること。diff の直接読み込み、
      大量のファイル読み込み、長いコマンド出力の取得は避け、サブエージェントに
      任せる。
    '';
    settings = {
      editorMode = "vim";
      skipDangerousModePermissionPrompt = true;
      hooks = {
        PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/rtk-rewrite.sh";
              }
            ];
          }
        ];
        UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status working";
              }
            ];
          }
        ];
        Notification = [
          {
            matcher = "permission_prompt|elicitation_dialog";
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status waiting";
              }
            ];
          }
        ];
        PostToolUse = [
          {
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status working";
              }
            ];
          }
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
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status done";
              }
            ];
          }
        ];
      };
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "100";
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
    package = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
    enableMcpIntegration = true;
    custom-instructions = ''
      # ユーザー設定

      日本語で応答してください。
    '';
    settings = {
      model_reasoning_effort = "high";
      tools = {
        web_search = true;
      };
      features = {
        skills = true;
      };
    };
  };

  programs.agent-skills = {
    enable = true;
    sources.local.path = ../configs/claude-code/skills;
    sources.anthropic = {
      path = inputs.anthropic-skills;
      subdir = "skills";
    };
    sources.agent-browser = {
      path = inputs.agent-browser;
      subdir = "skills";
    };
    sources.workmux = {
      path = inputs.workmux-skills;
      subdir = "skills";
    };
    skills.enableAll = true;
    targets.claude.enable = true;
    targets.codex = {
      enable = true;
      dest = "$HOME/.codex/skills";
      structure = "symlink-tree";
    };
  };
}
