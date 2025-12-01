{ lib, pkgs, inputs, ... }:
let
  servers = inputs.mcp-servers-nix.packages.${pkgs.system};

  mcpServersJson = pkgs.substitute {
    src = ../../configs/claude-code/mcp-servers.json;
    substitutions = [
      "--replace" "@PLAYWRIGHT_BIN@" "${servers.playwright-mcp}/bin/mcp-server-playwright"
      "--replace" "@CHROMIUM_BIN@" "${pkgs.chromium}/bin/chromium"
      "--replace" "@FETCH_BIN@" "${servers.mcp-server-fetch}/bin/mcp-server-fetch"
      "--replace" "@FILESYSTEM_BIN@" "${servers.mcp-server-filesystem}/bin/mcp-server-filesystem"
      "--replace" "@GIT_BIN@" "${servers.mcp-server-git}/bin/mcp-server-git"
      "--replace" "@MEMORY_BIN@" "${servers.mcp-server-memory}/bin/mcp-server-memory"
      "--replace" "@SEQUENTIAL_THINKING_BIN@" "${servers.mcp-server-sequential-thinking}/bin/mcp-server-sequential-thinking"
      "--replace" "@TIME_BIN@" "${servers.mcp-server-time}/bin/mcp-server-time"
      "--replace" "@SERENA_BIN@" "${servers.serena}/bin/serena"
      "--replace" "@CONTEXT7_BIN@" "${servers.context7-mcp}/bin/context7-mcp"
    ];
  };

  settingsJson = pkgs.substitute {
    src = ../../configs/claude-code/settings.json;
    substitutions = [
      "--replace" "@NIXFMT@" "${pkgs.nixfmt-rfc-style}/bin/nixfmt"
    ];
  };
in
{
  home.packages = lib.mkAfter (with pkgs; [ claude-code ]);

  home.file.".claude/CLAUDE.md".source = ../../configs/claude-code/CLAUDE.md;
  home.file.".claude/skills".source = ../../configs/claude-code/skills;
  home.file.".claude/settings.json".source = settingsJson;

  home.activation.mergeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    CLAUDE_JSON="$HOME/.claude.json"
    MCP_SERVERS="${mcpServersJson}"

    if [ -f "$CLAUDE_JSON" ]; then
      # 既存のファイルがある場合、mcpServersだけを上書き
      ${pkgs.jq}/bin/jq --slurpfile mcp "$MCP_SERVERS" '. + {"mcpServers": $mcp[0]}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
      mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
      # 既存のファイルがない場合、mcpServersだけを含むJSONを作成
      ${pkgs.jq}/bin/jq -n --slurpfile mcp "$MCP_SERVERS" '{"mcpServers": $mcp[0]}' > "$CLAUDE_JSON"
    fi
  '';
}
