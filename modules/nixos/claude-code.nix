{ lib, pkgs, ... }:
{
  home.packages = lib.mkAfter (with pkgs; [
    claude-code
  ]);

  # User-scoped CLAUDE.md
  home.file.".claude/CLAUDE.md".source = ../../configs/claude-code/CLAUDE.md;

  # Skills
  home.file.".claude/skills/screenshot/SKILL.md".source = ../../configs/claude-code/skills/screenshot/SKILL.md;

  # MCP servers configuration for dotfiles project
  home.file."repos/dotfiles/.mcp.json".text = builtins.toJSON {
    mcpServers = {
      playwright = {
        command = "${pkgs.nodejs_22}/bin/npx";
        args = [ "@playwright/mcp@latest" ];
      };
    };
  };
}
