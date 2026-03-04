---
name: pr-sweep
description: >-
  Review all open PRs and merge approved ones. Checks for existing Claude review
  comments, spawns parallel workmux agents for unreviewed PRs, then sequentially
  rebases and merges passing PRs.
allowed-tools: Bash, Write, Read, Task
disable-model-invocation: true
---

# PR Sweep — Bulk Review & Merge Coordinator

You are a coordinator agent that reviews and merges open PRs in bulk. You
orchestrate review agents via `workmux`, check existing Claude review comments,
and sequentially rebase-merge approved PRs.

**You MUST NOT run any shell commands other than `workmux`, `git`, and `gh`.**
Do not read diffs, run tests, or implement fixes yourself. All review and rebase
work must be delegated to worktree agents. The coordinator's context window must
be preserved for orchestration state. Context compaction must never occur.

## Arguments

- No arguments: target all open PRs
- `--pr 42,43`: target specific PR numbers only
- `--base <branch>`: override merge target (used when called from coordinator-pr)
- `--dry-run`: review only, do not merge

## Phase 1: Discovery

Gather PR state and classify each PR.

```bash
# 1. List open PRs
gh pr list --state open --json number,title,headRefName,baseRefName,author,reviewDecision,url,mergeable,isDraft

# 2. For each PR, fetch formal reviews AND issue comments
gh api repos/{owner}/{repo}/pulls/{number}/reviews
gh api repos/{owner}/{repo}/issues/{number}/comments

# 3. Discard drafts. Identify Claude activity (user.login contains "claude") from both sources.
#    Issue comments: match "### Verdict: <VERDICT>" in body to extract verdict.
#    Formal reviews take precedence over issue comments.
# 4. Classify:
```

| Classification        | Condition                                            | Action         |
| --------------------- | ---------------------------------------------------- | -------------- |
| **approved**          | Formal review APPROVED, OR comment verdict PASS or PASS_REVIEW_REQUIRED | → Phase 3      |
| **changes-requested** | Formal review CHANGES_REQUESTED, OR verdict FAIL     | → Skip         |
| **needs-review**      | No Claude review in either source                    | → Phase 2      |

If `--pr` is specified, filter to only those PR numbers. Print a summary table
of all PRs with their classification before proceeding.

## Phase 2: Parallel Review (workmux)

For PRs classified as **needs-review**, spawn review agents in parallel.

### 2.1 Write prompt files

For each PR, write a self-contained prompt file:

```bash
tmpfile=$(mktemp).md
cat > "$tmpfile" << EOF
You are reviewing PR #${number}: "${title}"
Base branch: ${baseRefName}

## Instructions

1. Run \`gh pr diff ${number}\` to read the full diff
2. Review for:
   - Logic correctness and edge cases
   - Security issues (injection, auth bypass, secrets)
   - Performance concerns
   - Style consistency with the codebase
3. If the PR is acceptable:
   \`gh pr review ${number} --approve --body "LGTM. <brief summary>"\`
4. If changes are needed:
   \`gh pr review ${number} --request-changes --body "<specific issues>"\`

Be concise. Focus on substantive issues, not style nitpicks.
EOF
```

### 2.2 Spawn agents

Write ALL prompt files first, THEN spawn ALL agents.

```bash
workmux add --pr ${number} --name review-pr-${number} -b -P "$tmpfile"
```

### 2.3 Wait and collect results

```bash
# Confirm agents started
workmux wait review-pr-${number1} review-pr-${number2} --status working --timeout 120

# Wait for all to finish
workmux wait review-pr-${number1} review-pr-${number2} --timeout 3600

# Capture results (minimal lines to prevent context bloat)
workmux capture review-pr-${number} -n 80
```

### 2.4 Classify results and clean up

Parse each capture output to determine if the agent approved or requested
changes. Update the PR classification accordingly. Then remove agents:

```bash
workmux remove review-pr-${number}
```

## Phase 3: Sequential Merge

Process **approved** PRs one at a time, in ascending PR number order. Skip this
phase entirely if `--dry-run` is specified.

For each approved PR:

### 3.1 Check mergeability

```bash
gh pr view ${number} --json mergeable,mergeStateStatus
```

### 3.2 Merge if clean

```bash
gh pr merge ${number} --rebase --delete-branch
```

### 3.3 Handle conflicts via workmux

If the PR has conflicts, delegate rebase to a workmux agent:

```bash
tmpfile=$(mktemp).md
cat > "$tmpfile" << 'REBASE_EOF'
Rebase this branch onto the target base branch and resolve any conflicts.

1. Run `git fetch origin`
2. Run `git rebase origin/${base}`
3. Resolve conflicts preserving the intent of both sides
4. Run `git push --force-with-lease`

If rebase is impossible (massive conflicts, contradictory changes), exit with a
message explaining why.
REBASE_EOF

workmux add --pr ${number} --name rebase-pr-${number} -b -P "$tmpfile"
workmux wait rebase-pr-${number} --status working --timeout 120
workmux wait rebase-pr-${number} --timeout 600
workmux capture rebase-pr-${number} -n 50
```

After successful rebase:

```bash
gh pr merge ${number} --rebase --delete-branch
workmux remove rebase-pr-${number}
```

### 3.4 Skip on failure

On merge or rebase failure, add the PR to the skip list and continue.

## Phase 4: Summary

Print a final report:

```
## PR Sweep Summary

### Merged
- #42 feat: add auth module
- #43 fix: resolve race condition

### Skipped (changes requested)
- #44 refactor: database layer — reviewer requested changes

### Skipped (merge/rebase failed)
- #45 feat: new API — conflict with #42 changes

### Reviewed (dry-run, not merged)
- #46 docs: update README — approved
```

## Edge Cases

| Case                    | Handling                                         |
| ----------------------- | ------------------------------------------------ |
| No open PRs             | Print message and exit                           |
| All PRs already reviewed | Skip Phase 2                                    |
| All PRs rejected        | Skip Phase 3, print summary                     |
| Rebase fails            | Skip PR, continue to next, report at end         |
| Agent timeout           | Capture output → remove agent → skip PR          |
| `--dry-run`             | Run Phase 1-2 only, skip Phase 3, report results |

## Rules

1. **You are a coordinator, not a reviewer.** Never read diffs or make review
   judgments yourself. Delegate all review work to workmux agents.
2. **Merge one PR at a time** in ascending number order. Wait for each merge to
   complete before starting the next.
3. **Only run `workmux`, `git`, and `gh` commands.** No tests, builds, linters,
   or direct code edits.
4. **Prompt files must be self-contained** with full context. Agents cannot see
   your conversation.
5. **Use relative paths** in prompt files (each worktree has its own root).
6. **Capture with minimal line count** (`-n 50` to `-n 80`) to prevent context
   compaction.
7. **Always confirm agent startup** with `workmux wait --status working` before
   waiting for completion.
8. **Use `--timeout`** on all wait commands. Handle timeouts gracefully by
   capturing, removing, and skipping.
9. **Never force-push from the coordinator.** Only agents in their own worktrees
   may force-push their own branches.
10. **Report all skipped PRs** with reasons in the final summary.
