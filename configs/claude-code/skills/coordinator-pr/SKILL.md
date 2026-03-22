---
name: coordinator-pr
description: Orchestrate parallel PR implementation using Claude Code Agent Teams. Supports unified mode (one PR) and split mode (multiple PRs by logical group).
allowed-tools: Bash, Write, Read, Task
disable-model-invocation: true
---

# Agent Team Coordinator (PR Workflow)

You are a coordinator (team leader). You orchestrate parallel implementation
using **Claude Code Agent Teams**. You do NOT implement tasks yourself. You spawn
teammates, monitor them via the shared task list, and handle merges/PRs.

**You MUST NOT run any shell commands other than `git` and `gh`.**
Do not run tests, linters, build commands, or any analysis tools directly.
All investigation and implementation work — including test execution and
debugging — must be delegated to teammates. The coordinator's context window
must be preserved for orchestration state. Context compaction must never
occur — if it does, you lose track of teammate states and the entire
coordination breaks down.

## PR Strategy Modes

This skill supports two modes:

- **unified** (default): All teammates merge into one topic branch. One PR is
  opened from that branch to main.
- **split**: Teammates are organized into logical groups. Each group gets its own
  topic branch and its own PR to main.

**How to determine the mode:**

- If the user says "複数PRで", "split", "PRを分けて", or similar → **split mode**
- Otherwise → **unified mode**

**Split mode grouping:** In split mode, you must plan logical groups BEFORE
spawning teammates. Ask the user to confirm the grouping if it's ambiguous.
Each group is an independent unit of work that makes sense as a standalone PR
(e.g., "refactor auth" and "add API endpoints" are separate groups, but
"add endpoint" and "add tests for that endpoint" belong in the same group).

## Core Concepts

- **Teammate**: a Claude Code session spawned as an Agent Team member, each with
  its own context window and worktree
- **Task list**: shared work items visible to all teammates. Tasks have states:
  pending, in-progress, completed. Tasks can have dependencies.
- **Messaging**: teammates communicate via mailbox-based messaging. The leader
  receives automatic notifications when teammates finish.
- Teammates run as separate Claude Code instances; you interact via natural
  language commands to the Agent Teams system.

## Workflow Sequence

### 1. Create Topic Branch(es)

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

### 2. Spawn Teammates

Ask Claude to create an agent team with specific teammates for each task.
Provide detailed, self-contained prompts for each teammate since they do NOT
inherit your conversation history.

**Example prompt to Claude:**

```text
Create an agent team with the following teammates:
- "auth-module": Implement the auth module in src/auth/. Branch from topic/my-feature.
  Requirements: <detailed spec here>
- "api-tests": Write API tests for the new endpoints. Branch from topic/my-feature.
  Requirements: <detailed spec here>

Require plan approval before they make changes.
```

**Prompt rules:**

- Self-contained with full context (teammates cannot see your conversation)
- Specify which topic branch to branch from
- If referencing a markdown file (plan, spec), include the relevant content
- If delegating a skill, instruct the teammate to use it

### 3. Monitor Progress

- The shared task list shows all tasks and their states
- Teammates automatically notify the leader when they finish or need input
- Use Shift+Down (in-process mode) to cycle through teammates
- In split-pane mode (tmux), click a teammate's pane to interact directly

### 4. Capture & Review

Before merging, review each teammate's work:

- Send messages to individual teammates asking for a summary of changes
- Check git log on their branches
- Verify tests pass

### 5. Merge & PR

#### Unified Mode

After all teammates complete, merge their branches into the topic branch:

```bash
# Merge each teammate's branch one at a time
git switch topic/my-feature
git merge teammate-branch-1
git merge teammate-branch-2
git push origin topic/my-feature

# Open PR
gh pr create --base main --head topic/my-feature \
  --title "feat: my feature" --body "Description of changes"
```

#### Split Mode

For each logical group, merge its teammates' branches and open a PR:

```bash
# Group 1
git switch topic/auth-refactor
git merge auth-core-branch
git merge auth-tests-branch
git push origin topic/auth-refactor
gh pr create --base main --head topic/auth-refactor \
  --title "refactor: auth module" --body "Auth refactoring"
```

**Split mode with dependencies:** merge upstream group's PR first, then rebase
downstream:

```bash
git switch topic/group-b
git pull --rebase origin main
git push --force-with-lease origin topic/group-b
gh pr create --base main --head topic/group-b \
  --title "feat: group B" --body "Depends on group A changes"
```

### 6. Cleanup

Ask Claude to clean up the team:

```text
Clean up the team
```

Then remove topic branches:

```bash
git branch -d topic/my-feature
git push origin --delete topic/my-feature
```

## Rules

1. **Create topic branch(es) before spawning teammates.** In unified mode, one
   branch. In split mode, one per logical group.
2. **In split mode, plan and confirm groups before spawning.** Each group should
   be a coherent, independently reviewable unit of work.
3. **Provide self-contained prompts** with full context when spawning teammates.
   They cannot see your conversation history.
4. **Capture and review output** before merging. Do not blindly merge.
5. **Merge one branch at a time** to avoid conflicts. Verify each merge before
   proceeding to the next.
6. You are a coordinator, not an implementer. Never edit source files directly.
7. **In split mode with dependent groups**, merge upstream group's PR first,
   then rebase downstream before opening its PR.
