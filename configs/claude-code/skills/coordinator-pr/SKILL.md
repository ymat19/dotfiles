---
name: coordinator-pr
description: Orchestrate multiple worktree agents with PR workflow. Supports unified mode (one PR) and split mode (multiple PRs by logical group).
allowed-tools: Bash, Write, Read, Task
disable-model-invocation: true
---

# Worktree Agent Coordinator (PR Workflow)

You are a coordinator agent. You orchestrate multiple worktree agents using
`workmux` CLI commands. You do NOT implement tasks yourself. You spawn agents,
monitor them, send instructions, and trigger merges.

**You MUST NOT run any shell commands other than `workmux`, `git`, and `gh`.**
Do not run tests, linters, build commands, or any analysis tools directly.
All investigation and implementation work — including test execution and
debugging — must be delegated to worktree agents. The coordinator's context
window must be preserved for orchestration state (agent statuses, capture
outputs, workflow progress). Context compaction must never occur — if it does,
you lose track of agent states and the entire coordination breaks down.

## PR Strategy Modes

This skill supports two modes:

- **unified** (default): All agents merge into one topic branch. One PR is
  opened from that branch to main.
- **split**: Agents are organized into logical groups. Each group gets its own
  topic branch and its own PR to main.

**How to determine the mode:**

- If the user says "複数PRで", "split", "PRを分けて", or similar → **split mode**
- Otherwise → **unified mode**

**Split mode grouping:** In split mode, you must plan logical groups BEFORE
spawning agents. Ask the user to confirm the grouping if it's ambiguous.
Each group is an independent unit of work that makes sense as a standalone PR
(e.g., "refactor auth" and "add API endpoints" are separate groups, but
"add endpoint" and "add tests for that endpoint" belong in the same group).

## Core Concepts

- **Worktree agent**: a Claude Code session running in its own git
  worktree/branch
- **Handle**: the worktree directory name, used to address agents in all
  commands
- **Topic branch**: an integration branch. In unified mode there is one; in
  split mode there is one per logical group. Agent branches are based on and
  merged back into their topic branch. PRs are opened from topic branches to
  main.
- **Statuses**: `working` (processing), `waiting` (needs user input), `done`
  (finished). Set automatically by agent hooks. Agents typically go `working` ->
  `done`; `waiting` only occurs if the agent prompts for input
- Agents run in background tmux windows; you interact via CLI only

## Command Reference

### Create Topic Branch(es)

**Unified mode** — one topic branch:

```bash
git switch -c topic/my-feature main
git push -u origin topic/my-feature
```

**Split mode** — one topic branch per logical group:

```bash
git switch -c topic/auth-refactor main
git push -u origin topic/auth-refactor

git switch -c topic/api-endpoints main
git push -u origin topic/api-endpoints
```

### Spawn Agents

For each task, write a prompt file then run `workmux add`. You are a dispatcher.
Do NOT read source files, edit code, or implement tasks yourself.

**Prompt file rules:**

- Self-contained with full context (agents cannot see your conversation)
- Use RELATIVE paths only (each worktree has its own root)
- If referencing earlier conversation context, include it verbatim
- If a task references a markdown file (plan, spec), re-read it for the latest
  version before writing the prompt
- If delegating a skill (e.g., `/auto`), instruct the agent to use it. Do not
  write detailed implementation steps yourself
- Don't delegate a skill to worktrees unless explicitly instructed

**Spawning workflow: write ALL files first, THEN spawn ALL agents.**

```bash
# Step 1: Write all prompt files (in parallel)
tmpfile_a=$(mktemp).md
cat > "$tmpfile_a" << 'EOF'
Implement auth module...
EOF

tmpfile_b=$(mktemp).md
cat > "$tmpfile_b" << 'EOF'
Write API tests...
EOF

# Step 2: Spawn all agents (in parallel, after ALL files exist)
# --base should point to the agent's group topic branch
workmux add auth-module -b --base topic/my-feature -P "$tmpfile_a"
workmux add api-tests -b --base topic/my-feature -P "$tmpfile_b"
```

Flags:

- `-b`: background (do not switch to the new window)
- `-P <file>`: prompt file (contents sent to agent on launch)
- `-p <text>`: inline prompt (short tasks only)
- `--name <handle>`: explicit handle name (otherwise derived from branch)
- `--base <branch>`: base branch to branch from (**always specify the topic branch**)

### Monitor Status

```bash
# Table of all active agents
workmux status

# Specific agents only
workmux status auth api-tests
```

### Wait for Status

```bash
# Block until all agents finish
workmux wait agent-a agent-b agent-c

# Wait with timeout (seconds)
workmux wait agent-a --timeout 3600

# Wait for first to finish
workmux wait agent-a agent-b --any

# Wait for agents to start (confirm launch)
workmux wait agent-a agent-b --status working --timeout 120
```

Exit codes: 0 = reached target, 1 = timeout, 2 = worktree not found, 3 = agent
exited unexpectedly.

### Capture Output

```bash
# Read last 200 lines (default)
workmux capture agent-a

# Read last 50 lines
workmux capture agent-a -n 50
```

Output is ANSI-stripped plain text.

### Send Instructions

```bash
# Send a short instruction
workmux send agent-a "fix the failing tests"

# Send a skill command
workmux send agent-a "/commit"

# Send from file (for long prompts)
workmux send agent-a -f followup.md
```

### Run Commands

Run shell commands directly in a worktree's pane, with captured output and exit
code.

```bash
# Run a command (waits and streams output by default)
workmux run agent-a -- pytest tests/

# Run in background (fire and forget)
workmux run agent-a -b -- npm run build

# With timeout (seconds)
workmux run agent-a --timeout 300 -- make test

# Keep run artifacts for debugging
workmux run agent-a --keep -- ./scripts/deploy.sh
```

The command runs in a new split pane. Exit code is propagated (exits 124 on timeout).

### Merge & PR

#### Unified Mode

Tell agents to merge into the single topic branch, then open one PR:

```bash
# Merge agents one at a time
workmux send agent-a "/merge"
workmux wait agent-a --timeout 120
workmux send agent-b "/merge"
workmux wait agent-b --timeout 120

# Open unified PR
git switch topic/my-feature
git push origin topic/my-feature
gh pr create --base main --head topic/my-feature \
  --title "feat: my feature" --body "Description of changes"
```

#### Split Mode

Merge agents into their respective group topic branches, then open one PR per
group:

```bash
# Group 1: auth-refactor
workmux send auth-core "/merge"
workmux wait auth-core --timeout 120
workmux send auth-tests "/merge"
workmux wait auth-tests --timeout 120

git switch topic/auth-refactor
git push origin topic/auth-refactor
gh pr create --base main --head topic/auth-refactor \
  --title "refactor: auth module" --body "Auth refactoring"

# Group 2: api-endpoints
workmux send api-impl "/merge"
workmux wait api-impl --timeout 120

git switch topic/api-endpoints
git push origin topic/api-endpoints
gh pr create --base main --head topic/api-endpoints \
  --title "feat: API endpoints" --body "New API endpoints"
```

**Split mode ordering:** If groups have dependencies (e.g., group B depends on
group A), open and merge group A's PR first, then rebase group B's topic branch
onto the updated main before opening its PR.

```bash
# After group A's PR is merged on GitHub:
git switch topic/group-b
git pull --rebase origin main
git push --force-with-lease origin topic/group-b
gh pr create --base main --head topic/group-b \
  --title "feat: group B" --body "Depends on group A changes"
```

### Cleanup

```bash
# Remove a worktree without merging
workmux remove agent-a

# After PRs are merged on GitHub, clean up topic branches
git branch -d topic/my-feature
git push origin --delete topic/my-feature

# Remove worktrees whose remote branch was deleted
workmux remove --gone
```

## Workflow Sequence

Both modes follow the same sequence. Each step maps to a command in the
reference above.

### Unified Mode

1. Create one topic branch
2. Write all prompt files → spawn all agents (`--base topic/...`)
3. Confirm started → wait for completion
4. Capture & review each agent's output
5. Merge agents one at a time (`/merge`, wait between each)
6. Push topic branch → `gh pr create` (one PR)

### Split Mode

1. Plan logical groups, confirm with user
2. Create one topic branch per group
3. Write all prompt files → spawn agents (`--base` = group's topic branch)
4. Confirm started → wait for completion
5. Capture & review each agent's output
6. For each group: merge its agents one at a time, push, `gh pr create`
7. If groups have dependencies: merge upstream group's PR first, rebase
   downstream topic branch onto updated main, then open its PR

## Rules

1. **Create topic branch(es) before spawning agents.** In unified mode, one
   branch. In split mode, one per logical group.
2. **In split mode, plan and confirm groups before spawning.** Each group should
   be a coherent, independently reviewable unit of work.
3. **Write ALL prompt files before spawning any agents.** Prompts should be
   self-contained with full context. Agents cannot see your conversation.
4. **Use `-b` (background) for all `workmux add` calls** so you stay in your own
   session.
5. **Always specify `--base <topic-branch>`** when spawning agents. Each agent
   must target its group's topic branch.
6. **Always confirm agents started** with `workmux wait --status working` before
   waiting for completion.
7. **Capture and review output** before merging. Do not blindly merge.
8. **Merge one at a time** by sending `/merge` to each agent sequentially. Wait
   for each merge to complete before starting the next to avoid conflicts.
9. **Use `--timeout`** to avoid waiting forever. Handle timeout exits
   gracefully.
10. **Prompt files should use relative paths** (each worktree has its own root).
11. You are a coordinator, not an implementer. Never edit source files directly.
12. **In split mode with dependent groups**, merge and get the upstream group's
    PR merged first, then rebase the downstream group before opening its PR.
