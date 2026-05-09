# 9Router

[9Router](https://github.com/decolua/9router) is an AI coding router and token saver that connects CLI tools (Claude Code, Codex, OpenClaw, etc.) to 40+ AI providers with automatic fallback.

## NixOS Module

Enable in your home-manager config:

```nix
programs._9router = {
  enable = true;
  port = 20128;  # default
};
```

When enabled:
- `9router` command is available
- systemd user service auto-starts on login (`--no-browser --log`)
- Claude Code's `ANTHROPIC_BASE_URL` is set to `http://localhost:20128/v1`

## Usage

After rebuild, 9router starts automatically. Open the dashboard:

```
http://localhost:20128
```

Connect providers in the dashboard (Kiro AI = free Claude, OpenCode Free = no auth, etc.).

## Features

- **RTK Token Saver** - Auto-compress tool_result content, save 20-40% tokens
- **Auto fallback** - Subscription → Cheap → Free, zero downtime
- **Multi-account** - Round-robin between accounts per provider
- **Universal** - Works with Claude Code, Codex, Cursor, Cline, OpenClaw, etc.