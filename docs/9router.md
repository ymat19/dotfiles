# 9Router

[9Router](https://github.com/decolua/9router) is an AI coding router and token saver that connects CLI tools (Claude Code, Codex, Cursor, Cline, OpenClaw, etc.) to 40+ AI providers with automatic fallback.

## Setup

```bash
# Install globally
npm install -g 9router

# Start (dashboard opens at http://localhost:20128)
9router

# Connect a FREE provider in the dashboard (Kiro AI, OpenCode Free, etc.)
```

## OpenClaw Integration

Set these in your OpenClaw config:

```
gateway.providers.anthropic.baseUrl = http://localhost:20128/v1
```

## NixOS Module

Enable in your home-manager config:

```nix
programs._9router = {
  enable = true;
  port = 20128;
};
```

## Features

- **RTK Token Saver** - Auto-compress tool_result content, save 20-40% tokens
- **Auto fallback** - Subscription → Cheap → Free, zero downtime
- **Multi-account** - Round-robin between accounts per provider
- **Universal** - Works with Claude Code, Codex, Cursor, Cline, OpenClaw, etc.