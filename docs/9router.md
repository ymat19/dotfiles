# 9Router

[9Router](https://github.com/decolua/9router) is an AI coding router and token saver that connects CLI tools (Claude Code, Codex, Cursor, Cline, OpenClaw, etc.) to 40+ AI providers with automatic fallback.

## NixOS Module

Enable in your home-manager config:

```nix
programs._9router = {
  enable = true;
  port = 20128;
};
```

After enabling, rebuild and run:

```bash
9router  # Dashboard: http://localhost:20128
```

## OpenClaw Integration

```
gateway.providers.anthropic.baseUrl = http://localhost:20128/v1
```

## Features

- **RTK Token Saver** - Auto-compress tool_result content, save 20-40% tokens
- **Auto fallback** - Subscription → Cheap → Free, zero downtime
- **Multi-account** - Round-robin between accounts per provider
- **Universal** - Works with Claude Code, Codex, Cursor, Cline, OpenClaw, etc.