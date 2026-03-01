{ lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
    inputs.mcp-servers-nix.homeManagerModules.default
  ];

  mcp-servers.programs = {
    playwright = {
      enable = true;
      args = [ "--isolated" ];
    };
    filesystem = {
      enable = true;
      args = [ "/home" "/tmp" ];
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
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
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
    skills.enableAll = true;
    targets.claude.enable = true;
    targets.codex = {
      enable = true;
      dest = "$HOME/.codex/skills";
      structure = "symlink-tree";
    };
  };
}
