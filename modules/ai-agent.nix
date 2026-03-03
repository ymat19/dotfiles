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

  stopSessionHook = pkgs.writeShellScript "stop-session-hook" ''
    cat > /dev/null
    COMMITS=$(git log --oneline --since="1 hour ago" 2>/dev/null || true)
    if [ -n "$COMMITS" ]; then
      mkdir -p "$HOME/.claude"
      echo "$COMMITS" > "$HOME/.claude/.last-session"
    fi
    exit 0
  '';

  userPromptReflectHook = pkgs.writeShellScript "user-prompt-reflect-hook" ''
    cat > /dev/null
    SESSION_FILE="$HOME/.claude/.last-session"
    if [ -f "$SESSION_FILE" ] && [ -s "$SESSION_FILE" ]; then
      COMMITS=$(cat "$SESSION_FILE")
      rm -f "$SESSION_FILE"
      cat <<EOF
    [振り返り] 前回セッションの作業:
    ''${COMMITS}

    SKILL化の検討基準（該当がなければ何も言わないこと）:
    - 同一パターンの作業を2回以上実施 → SKILL候補
    - 複雑な多段階プロセスの標準化 → SKILL候補
    - 暗黙知の発見 → 文書化候補
    確実な効果が見込まれる場合のみ、タスク完了時に1-2文で提案すること。
    EOF
    fi
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
    ];

  home.file.".claude/statusline.sh" = {
    source = ../configs/claude-code/statusline.sh;
    executable = true;
  };

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

  mcp-servers.programs = {
    filesystem = {
      enable = true;
      args = [
        "/home"
        "/tmp"
      ];
    };
    git.enable = true;
    sequential-thinking.enable = true;
    time.enable = true;
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
    '';
    settings = {
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
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "${userPromptReflectHook}";
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
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "${stopSessionHook}";
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
