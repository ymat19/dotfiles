---
name: pr-sweep
description: >-
  Review all open PRs and merge approved ones. Checks for existing Claude review
  comments, spawns parallel subagents for unreviewed PRs, then sequentially
  rebases and merges passing PRs.
allowed-tools: Bash, Write, Read, Task
disable-model-invocation: true
---

# PR Sweep — Bulk Review & Merge Coordinator

You are a coordinator that reviews and merges open PRs in bulk. You orchestrate
review workers via **subagents** (Task tool), check existing Claude review
comments, and sequentially rebase-merge approved PRs.

**You MUST NOT run any shell commands other than `git` and `gh`.**
Do not read diffs, run tests, or implement fixes yourself. All review and rebase
work must be delegated to subagents. The coordinator's context window must be
preserved for orchestration state. Context compaction must never occur.

## Why subagents (not Agent Teams)

Each PR reviewer works independently and reports a result (approved / changes
requested). No inter-reviewer communication is needed. This is the textbook
subagent use case per Anthropic's guidance:

> Use subagents when you need quick, focused workers that need to report results.

## Arguments

- No arguments: target all open PRs
- `--pr 42,43`: target specific PR numbers only
- `--base <branch>`: override merge target
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

## Phase 2: Parallel Review (subagents)

For PRs classified as **needs-review**, spawn one subagent per PR using the
**Task** tool. Subagents run in parallel automatically.

### 2.1 Spawn review subagents

For each PR, use the Task tool with a self-contained prompt:

```
Task: Review PR #${number}: "${title}"

1. Run `gh pr diff ${number}` to read the full diff
2. Review for:
   - Logic correctness and edge cases
   - Security issues (injection, auth bypass, secrets)
   - Performance concerns
   - Style consistency with the codebase
3. If the PR is acceptable:
   `gh pr review ${number} --approve --body "LGTM. <brief summary>"`
4. If changes are needed:
   `gh pr review ${number} --request-changes --body "<specific issues>"`

Be concise. Focus on substantive issues, not style nitpicks.
Report back with: PR number, decision (approved/changes-requested), and a
one-line summary.
```

### 2.2 Collect results

Each subagent returns its result to the coordinator. Parse the decision
(approved / changes-requested) from the returned summary and update the PR
classification.

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

### 3.3 Handle conflicts

If the PR has conflicts, spawn a subagent to rebase:

```
Task: Rebase PR #${number} onto ${base}.

1. Run `git fetch origin`
2. Check out the PR branch: `gh pr checkout ${number}`
3. Run `git rebase origin/${base}`
4. Resolve conflicts preserving the intent of both sides
5. Run `git push --force-with-lease`

If rebase is impossible (massive conflicts, contradictory changes), report why.
```

After successful rebase:

```bash
gh pr merge ${number} --rebase --delete-branch
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
| Subagent error          | Skip PR, report at end                           |
| `--dry-run`             | Run Phase 1-2 only, skip Phase 3, report results |

## Rules

1. **You are a coordinator, not a reviewer.** Never read diffs or make review
   judgments yourself. Delegate all review work to subagents.
2. **Merge one PR at a time** in ascending number order. Wait for each merge to
   complete before starting the next.
3. **Only run `git` and `gh` commands.** No tests, builds, linters, or direct
   code edits.
4. **Subagent prompts must be self-contained** with full context.
5. **Report all skipped PRs** with reasons in the final summary.
