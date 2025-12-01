---
name: gh-cli
description: Use GitHub CLI (gh) to interact with GitHub repositories, pull requests, issues, CI/CD workflows, and security alerts. Use when the user asks about remote repository status, workflow runs, PR/issue management, or GitHub operations.
---

# GitHub CLI Skill

This skill helps you interact with GitHub using the GitHub CLI (`gh`) to provide functionality similar to the GitHub MCP server. Use it when users ask about repository status, CI/CD workflows, pull requests, issues, or security alerts.

## Instructions

When the user requests GitHub-related information or operations, follow these steps:

### 1. Understand the User's Request

Identify what type of GitHub information or operation they need:
- **Repository info** - viewing repo details, searching code, getting file contents
- **Issues/PRs** - listing, viewing, creating, or managing issues and pull requests
- **CI/CD** - checking workflow runs, viewing logs, monitoring build status
- **Security** - checking Dependabot alerts, security warnings

### 2. Check Authentication

Before running gh commands, ensure the user is authenticated:
```bash
gh auth status
```

If not authenticated, guide them to login:
```bash
gh auth login
```

### 3. Use the Appropriate gh Command

Based on the request type, use the corresponding gh CLI commands:

#### Repository Intelligence
```bash
# View repository information
gh repo view [owner/repo]

# Get file contents (similar to GitHub MCP's get_file_contents)
gh api repos/{owner}/{repo}/contents/{path} --jq '.content' | base64 -d

# Search code
gh search code "query" --repo owner/repo
```

#### Issue and PR Management
```bash
# List and view
gh issue list [--state open|closed]
gh pr list [--state open|closed]
gh pr view <number>

# Create
gh issue create --title "Title" --body "Description"
gh pr create --title "Title" --body "Description"

# Manage PRs
gh pr checks                           # Check CI status
gh pr review <number> --approve        # Review PR
gh pr merge <number> --squash          # Merge PR
gh pr edit <number> --add-reviewer username
```

#### CI/CD Monitoring
```bash
# List workflow runs
gh run list [--limit N] [--status failure]

# View run details and logs (similar to GitHub MCP's get_workflow_run_logs)
gh run view <run-id>
gh run view <run-id> --log
gh run view <run-id> --log-failed

# Manage workflows
gh workflow list
gh workflow run <workflow-name>
gh run rerun <run-id>
```

#### Security Insights
```bash
# Check Dependabot alerts (similar to GitHub MCP's list_dependabot_alerts)
gh api repos/{owner}/{repo}/dependabot/alerts

# Filter open alerts
gh api repos/{owner}/{repo}/dependabot/alerts --jq '.[] | select(.state=="open")'

# Check code scanning alerts
gh api repos/{owner}/{repo}/code-scanning/alerts
```

### 4. Use JSON Output for Programmatic Access

Many gh commands support `--json` and `--jq` for structured output:
```bash
# Get specific fields
gh pr list --json number,title,state,author

# Filter with jq
gh pr list --json state --jq '.[] | select(.state=="OPEN")'

# Custom formatting
gh run list --json status,conclusion,workflowName --jq '.[] | "\(.workflowName): \(.conclusion)"'
```

### 5. Handle Repository Context

- Commands run in a git repository automatically use that repo
- Use `-R owner/repo` to specify a different repository:
  ```bash
  gh pr list -R owner/repo
  ```

## Examples

### Example 1: Check CI/CD Status

**User asks:** "What's the status of the CI/CD workflows?"

**Actions:**
```bash
# List recent workflow runs
gh run list --limit 5

# If there are failures, view details
gh run view <run-id> --log-failed
```

### Example 2: Review Open Pull Requests

**User asks:** "Show me the open PRs and their check status"

**Actions:**
```bash
# List open PRs
gh pr list --state open

# Check specific PR status
gh pr view <number>
gh pr checks <number>
```

### Example 3: Investigate Failed Builds

**User asks:** "Why did the build fail?"

**Actions:**
```bash
# Find failed runs
gh run list --status failure --limit 5

# View the failed run logs
gh run view <run-id> --log-failed

# Provide analysis of the error messages
```

### Example 4: Check Security Alerts

**User asks:** "Are there any security vulnerabilities?"

**Actions:**
```bash
# Check Dependabot alerts
gh api repos/{owner}/{repo}/dependabot/alerts --jq '.[] | select(.state=="open") | {package: .security_advisory.package.name, severity: .security_advisory.severity}'

# Check code scanning alerts
gh api repos/{owner}/{repo}/code-scanning/alerts --jq '.[] | select(.state=="open")'
```

### Example 5: Merge a PR After Review

**User asks:** "Merge PR #42 if all checks pass"

**Actions:**
```bash
# Check PR status
gh pr view 42
gh pr checks 42

# If all checks pass, merge
gh pr merge 42 --squash
```

## Tips

- Use `--help` with any gh command to see detailed options
- Use `--web` to open GitHub pages in browser (e.g., `gh pr view 123 --web`)
- Create aliases with `gh alias` for frequently used commands
- Access the full GitHub API with `gh api <endpoint>`
