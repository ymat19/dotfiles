{ lib, pkgs, inputs, ... }:
let
  servers = inputs.mcp-servers-nix.packages.${pkgs.system};

  memoryWrapper = pkgs.writeShellScript "mcp-server-memory-wrapper" ''
    export MEMORY_FILE_PATH="$PWD/.memory.json"
    exec ${servers.mcp-server-memory}/bin/mcp-server-memory "$@"
  '';

  mcpServersJson = pkgs.substitute {
    src = ../configs/claude-code/mcp-servers.json;
    substitutions = [
      "--replace" "@PLAYWRIGHT_BIN@" "${servers.playwright-mcp}/bin/mcp-server-playwright"
      "--replace" "@CHROMIUM_BIN@" "${pkgs.chromium}/bin/chromium"
      "--replace" "@FILESYSTEM_BIN@" "${servers.mcp-server-filesystem}/bin/mcp-server-filesystem"
      "--replace" "@GIT_BIN@" "${servers.mcp-server-git}/bin/mcp-server-git"
      "--replace" "@MEMORY_BIN@" "${memoryWrapper}"
      "--replace" "@SEQUENTIAL_THINKING_BIN@" "${servers.mcp-server-sequential-thinking}/bin/mcp-server-sequential-thinking"
      "--replace" "@TIME_BIN@" "${servers.mcp-server-time}/bin/mcp-server-time"
      "--replace" "@SERENA_BIN@" "${servers.serena}/bin/serena"
      "--replace" "@CONTEXT7_BIN@" "${servers.context7-mcp}/bin/context7-mcp"
    ];
  };

  settingsJson = pkgs.substitute {
    src = ../configs/claude-code/settings.json;
    substitutions = [
      "--replace" "@NIXFMT@" "${pkgs.nixfmt-rfc-style}/bin/nixfmt"
    ];
  };
in
{
  home.packages = lib.mkAfter (with pkgs; [ claude-code codex ]);

  home.file.".claude/CLAUDE.md".source = ../configs/claude-code/CLAUDE.md;
  home.file.".claude/skills".source = ../configs/claude-code/skills;
  home.file.".claude/settings.json".source = settingsJson;
  home.file.".codex/AGENTS.md".source = ../configs/claude-code/CLAUDE.md;

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

  home.activation.mergeCodexMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"
    export MCP_SERVERS_JSON="${mcpServersJson}"

    mkdir -p "$CODEX_HOME"

    ${pkgs.python3}/bin/python - <<'PY'
import json
import os
import re
import tomllib
from pathlib import Path

codex_home = Path(os.environ["CODEX_HOME"])
config_path = codex_home / "config.toml"

def format_key(key: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
        return key
    return json.dumps(key)

def format_value(value):
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[" + ", ".join(format_value(v) for v in value) + "]"
    if isinstance(value, dict):
        return None
    raise TypeError(f"Unsupported type for TOML serialization: {type(value)}")

def dump_table(prefix: str, table: dict, lines: list[str]) -> None:
    simple = {}
    subtables = {}
    for key, val in table.items():
        if isinstance(val, dict):
            subtables[key] = val
        else:
            simple[key] = val

    if prefix:
        lines.append(f"[{prefix}]")

    for key, val in simple.items():
        rendered = format_value(val)
        if rendered is None:
            continue
        lines.append(f"{format_key(key)} = {rendered}")

    if prefix and (simple or subtables):
        lines.append("")

    for key, val in subtables.items():
        child_prefix = f"{prefix}.{format_key(key)}" if prefix else format_key(key)
        dump_table(child_prefix, val, lines)

def to_toml(data: dict) -> str:
    result: list[str] = []
    dump_table("", data, result)
    while result and result[-1] == "":
        result.pop()
    return "\n".join(result) + ("\n" if result else "")

config: dict = {}
if config_path.exists():
    config = tomllib.loads(config_path.read_text())

with open(os.environ["MCP_SERVERS_JSON"], "r", encoding="utf-8") as f:
    mcp_servers = json.load(f)

config["mcp_servers"] = config.get("mcp_servers", {})
config["mcp_servers"].update(mcp_servers)

config_path.write_text(to_toml(config))
PY
  '';
}
