# Issue Backend Abstraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple WFM issue tracking from hardcoded GitHub `gh` CLI calls by introducing a configurable backend abstraction layer supporting local (git-bug), GitHub, or both.

**Architecture:** A single `infrastructure/issues.sh` script provides backend-agnostic functions (`issue_create`, `issue_close`, `issue_comment`, `issue_list`, `issue_sync`). Phase files call these via `workflow-cmd.sh` instead of `gh` directly. Configuration lives in `.claude/wfm-issue-config.json` (project) with fallback to `~/.claude/wfm-issue-config.json` (global).

**Tech Stack:** Bash, jq, `gh` CLI, `git-bug` CLI

**Spec:** `docs/specs/2026-04-21-issue-backend-abstraction.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugin/scripts/infrastructure/issues.sh` | Backend abstraction layer — config loading, backend dispatch, all issue CRUD functions |
| Modify | `plugin/scripts/workflow-facade.sh:17` | Source `issues.sh` alongside other infrastructure modules |
| Modify | `plugin/scripts/workflow-cmd.sh:82-101` | Add issue functions to the allowlist case statement |
| Modify | `plugin/phases/define/step_3.md:42-54` | Replace `gh issue comment` with `workflow-cmd.sh issue_comment` |
| Modify | `plugin/phases/discuss/step_2.md:51-62` | Replace `gh issue comment` with `workflow-cmd.sh issue_comment` |
| Modify | `plugin/phases/complete/step_7.md:58-84` | Replace `gh issue create/close/label` with `workflow-cmd.sh issue_create/close` |
| Modify | `plugin/phases/complete/step_9.md:26-43` | Replace `gh issue close` with `workflow-cmd.sh issue_close`, add sync prompt |
| Create | `plugin/commands/issue-config.md` | Slash command for configuring issue backend |
| Modify | `plugin/config/skill-registry.json:111` | Register `issue-config` operation |

---

### Task 1: Create `infrastructure/issues.sh` — Config Loading

**Files:**
- Create: `plugin/scripts/infrastructure/issues.sh`

- [ ] **Step 1: Create the file with header, guard, and config loading functions**

```bash
#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Issue backend abstraction — config loading and backend-agnostic CRUD

[ -n "${_WFM_ISSUES_LOADED:-}" ] && return 0
_WFM_ISSUES_LOADED=1

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/state-io.sh"

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

# Cached config values (populated by _load_issue_config)
_ISSUE_BACKEND=""
_GITHUB_REPO=""
_GIT_BUG_REPO=""

_load_issue_config() {
    # Return cached values if already loaded
    if [ -n "$_ISSUE_BACKEND" ]; then return 0; fi

    local project_root
    project_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local project_config="$project_root/.claude/wfm-issue-config.json"
    local global_config="$HOME/.claude/wfm-issue-config.json"

    local config_file=""
    if [ -f "$project_config" ]; then
        config_file="$project_config"
    elif [ -f "$global_config" ]; then
        config_file="$global_config"
    fi

    if [ -n "$config_file" ]; then
        _ISSUE_BACKEND=$(jq -r '.issue_backend // "github"' "$config_file" 2>/dev/null)
        _GITHUB_REPO=$(jq -r '.github_repo // "auto"' "$config_file" 2>/dev/null)
        _GIT_BUG_REPO=$(jq -r '.git_bug_repo // ".claude/wfm-issues"' "$config_file" 2>/dev/null)
    else
        _ISSUE_BACKEND="github"
        _GITHUB_REPO="auto"
        _GIT_BUG_REPO=".claude/wfm-issues"
    fi
}

_resolve_github_repo() {
    _load_issue_config
    if [ "$_GITHUB_REPO" = "auto" ]; then
        local remote_url
        remote_url=$(git remote get-url origin 2>/dev/null) || { echo ""; return 1; }
        # Extract owner/repo from SSH or HTTPS URL
        echo "$remote_url" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s/\.git$//'
    else
        echo "$_GITHUB_REPO"
    fi
}

_resolve_git_bug_dir() {
    _load_issue_config
    local project_root
    project_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    echo "$project_root/$_GIT_BUG_REPO"
}

issue_get_backend() {
    _load_issue_config
    echo "$_ISSUE_BACKEND"
}
```

- [ ] **Step 2: Verify the file is syntactically valid**

Run: `bash -n plugin/scripts/infrastructure/issues.sh`
Expected: No output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add plugin/scripts/infrastructure/issues.sh
```
```bash
git commit -m "feat: add issues.sh config loading and resolution functions

Introduces the issue backend abstraction layer with config loading
from project-level and global fallback, plus github repo and
git-bug directory resolution."
```

---

### Task 2: Add Dependency Check and GitHub Backend Functions

**Files:**
- Modify: `plugin/scripts/infrastructure/issues.sh`

- [ ] **Step 1: Add dependency check helpers after `issue_get_backend`**

Append to `issues.sh`:

```bash
# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

_check_gh() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "WARN: gh CLI not found. GitHub issue operations skipped." >&2
        return 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "WARN: gh not authenticated. GitHub issue operations skipped." >&2
        return 1
    fi
    return 0
}

_check_git_bug() {
    if ! command -v git-bug >/dev/null 2>&1; then
        echo "ERROR: git-bug not found. Run /issue-config to install." >&2
        return 1
    fi
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    if [ ! -d "$bug_dir" ]; then
        echo "ERROR: git-bug repo not initialized at $bug_dir. Run /issue-config to set up." >&2
        return 1
    fi
    return 0
}
```

- [ ] **Step 2: Add GitHub backend functions**

Append to `issues.sh`:

```bash
# ---------------------------------------------------------------------------
# GitHub backend
# ---------------------------------------------------------------------------

_gh_issue_create() {
    local title="$1" body="$2" label="${3:-}"
    local repo
    repo=$(_resolve_github_repo) || return 1
    if [ -z "$repo" ]; then
        echo "WARN: Could not resolve GitHub repo. Skipping issue creation." >&2
        return 1
    fi
    if [ -n "$label" ]; then
        # Ensure label exists
        gh label create "$label" --repo "$repo" --description "" 2>/dev/null || true
        gh issue create --repo "$repo" --title "$title" --body "$body" --label "$label"
    else
        gh issue create --repo "$repo" --title "$title" --body "$body"
    fi
}

_gh_issue_close() {
    local issue_id="$1" comment="${2:-}"
    local repo
    repo=$(_resolve_github_repo) || return 1
    if [ -z "$repo" ]; then return 1; fi
    if [ -n "$comment" ]; then
        gh issue close "$issue_id" --repo "$repo" --comment "$comment"
    else
        gh issue close "$issue_id" --repo "$repo"
    fi
}

_gh_issue_comment() {
    local issue_id="$1" body="$2"
    local repo
    repo=$(_resolve_github_repo) || return 1
    if [ -z "$repo" ]; then return 1; fi
    gh issue comment "$issue_id" --repo "$repo" --body "$body"
}

_gh_issue_list() {
    local status="${1:-open}"
    local repo
    repo=$(_resolve_github_repo) || return 1
    if [ -z "$repo" ]; then return 1; fi
    gh issue list --repo "$repo" --state "$status"
}
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n plugin/scripts/infrastructure/issues.sh`
Expected: No output (clean parse)

- [ ] **Step 4: Commit**

```bash
git add plugin/scripts/infrastructure/issues.sh
```
```bash
git commit -m "feat: add dependency checks and GitHub backend functions to issues.sh

Adds _check_gh, _check_git_bug helpers and GitHub-specific CRUD
functions that resolve the target repo from config."
```

---

### Task 3: Add git-bug Backend Functions

**Files:**
- Modify: `plugin/scripts/infrastructure/issues.sh`

- [ ] **Step 1: Add git-bug backend functions**

Append to `issues.sh`:

```bash
# ---------------------------------------------------------------------------
# git-bug backend
# ---------------------------------------------------------------------------

_gb_issue_create() {
    local title="$1" body="$2" label="${3:-}"
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    local result
    result=$(GIT_DIR="$bug_dir" git bug add --title "$title" --message "$body" 2>&1)
    local issue_id
    issue_id=$(echo "$result" | grep -oE '[0-9a-f]{7,}' | head -1)
    if [ -n "$label" ] && [ -n "$issue_id" ]; then
        GIT_DIR="$bug_dir" git bug label add "$issue_id" "$label" 2>/dev/null || true
    fi
    echo "$issue_id"
}

_gb_issue_close() {
    local issue_id="$1" comment="${2:-}"
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    if [ -n "$comment" ]; then
        GIT_DIR="$bug_dir" git bug comment add "$issue_id" --message "$comment" 2>/dev/null || true
    fi
    GIT_DIR="$bug_dir" git bug status close "$issue_id"
}

_gb_issue_comment() {
    local issue_id="$1" body="$2"
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    GIT_DIR="$bug_dir" git bug comment add "$issue_id" --message "$body"
}

_gb_issue_list() {
    local status="${1:-open}"
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    GIT_DIR="$bug_dir" git bug ls --status "$status"
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n plugin/scripts/infrastructure/issues.sh`
Expected: No output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add plugin/scripts/infrastructure/issues.sh
```
```bash
git commit -m "feat: add git-bug backend functions to issues.sh

Adds git-bug CRUD using GIT_DIR to target the project-local
bare repo. Supports create, close, comment, list operations."
```

---

### Task 4: Add Public Dispatch Functions and Sync

**Files:**
- Modify: `plugin/scripts/infrastructure/issues.sh`

- [ ] **Step 1: Add the public dispatch functions**

Append to `issues.sh`:

```bash
# ---------------------------------------------------------------------------
# Public API — backend dispatch
# ---------------------------------------------------------------------------

issue_create() {
    local title="$1" body="$2" label="${3:-}"
    _load_issue_config

    case "$_ISSUE_BACKEND" in
        local)
            _check_git_bug || return 1
            _gb_issue_create "$title" "$body" "$label"
            ;;
        github)
            _check_gh || return 1
            _gh_issue_create "$title" "$body" "$label"
            ;;
        both)
            _check_git_bug || return 1
            local gb_id
            gb_id=$(_gb_issue_create "$title" "$body" "$label")
            echo "$gb_id"
            ;;
    esac
}

issue_close() {
    local issue_id="$1" comment="${2:-}"
    _load_issue_config

    case "$_ISSUE_BACKEND" in
        local)
            _check_git_bug || return 1
            _gb_issue_close "$issue_id" "$comment"
            ;;
        github)
            _check_gh || return 1
            _gh_issue_close "$issue_id" "$comment"
            ;;
        both)
            _check_git_bug || return 1
            _gb_issue_close "$issue_id" "$comment"
            ;;
    esac
}

issue_comment() {
    local issue_id="$1" body="$2"
    _load_issue_config

    case "$_ISSUE_BACKEND" in
        local)
            _check_git_bug || return 1
            _gb_issue_comment "$issue_id" "$body"
            ;;
        github)
            _check_gh || return 1
            _gh_issue_comment "$issue_id" "$body"
            ;;
        both)
            _check_git_bug || return 1
            _gb_issue_comment "$issue_id" "$body"
            ;;
    esac
}

issue_list() {
    local status="${1:-open}"
    _load_issue_config

    case "$_ISSUE_BACKEND" in
        local)
            _check_git_bug || return 1
            _gb_issue_list "$status"
            ;;
        github)
            _check_gh || return 1
            _gh_issue_list "$status"
            ;;
        both)
            _check_git_bug || return 1
            _gb_issue_list "$status"
            ;;
    esac
}

issue_sync() {
    _load_issue_config
    if [ "$_ISSUE_BACKEND" != "both" ]; then
        echo "Sync is only available in 'both' mode (current: $_ISSUE_BACKEND)."
        return 0
    fi
    _check_git_bug || return 1
    local bug_dir
    bug_dir=$(_resolve_git_bug_dir)
    GIT_DIR="$bug_dir" git bug bridge push
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n plugin/scripts/infrastructure/issues.sh`
Expected: No output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add plugin/scripts/infrastructure/issues.sh
```
```bash
git commit -m "feat: add public dispatch functions and sync to issues.sh

Completes the abstraction layer with issue_create, issue_close,
issue_comment, issue_list, and issue_sync. Each dispatches to
the configured backend (local/github/both)."
```

---

### Task 5: Wire `issues.sh` into `workflow-facade.sh` and `workflow-cmd.sh`

**Files:**
- Modify: `plugin/scripts/workflow-facade.sh:17`
- Modify: `plugin/scripts/workflow-cmd.sh:82-101`

- [ ] **Step 1: Add `issues.sh` to `workflow-facade.sh`**

In `plugin/scripts/workflow-facade.sh`, add after line 17 (`source "$SCRIPT_DIR/infrastructure/tracking.sh"`):

```bash
source "$SCRIPT_DIR/infrastructure/issues.sh"
```

- [ ] **Step 2: Add issue functions to `workflow-cmd.sh` allowlist**

In `plugin/scripts/workflow-cmd.sh`, in the case statement, add after the `set_issue_mapping|get_issue_url|get_issue_mappings|clear_issue_mapping|\` line (line 99):

```bash
    issue_create|issue_close|issue_comment|issue_list|issue_sync|issue_get_backend|\
```

- [ ] **Step 3: Verify both files parse cleanly**

Run: `bash -n plugin/scripts/workflow-facade.sh && bash -n plugin/scripts/workflow-cmd.sh`
Expected: No output (clean parse)

- [ ] **Step 4: Test the wiring**

Run: `plugin/scripts/workflow-cmd.sh issue_get_backend`
Expected: `github` (default when no config file exists)

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/workflow-facade.sh plugin/scripts/workflow-cmd.sh
```
```bash
git commit -m "feat: wire issues.sh into workflow facade and command allowlist

Sources issues.sh from workflow-facade.sh and adds all issue_*
functions to workflow-cmd.sh's case statement."
```

---

### Task 6: Refactor `define/step_3.md` — Replace `gh` with Abstraction

**Files:**
- Modify: `plugin/phases/define/step_3.md:34-54`

- [ ] **Step 1: Replace the "Decision Record to Issue Linking" section**

Replace lines 34-54 of `plugin/phases/define/step_3.md` with:

```markdown
### Decision Record to Issue Linking

Get the commit hash and link the plan to the originating issue (if one exists):

```bash
COMMIT_HASH=$(git rev-parse --short HEAD)
```

If there are tracked observation IDs with issue mappings, or if the user mentioned a specific issue number, post a comment:

```bash
.claude/hooks/workflow-cmd.sh issue_comment <ISSUE_ID> "## Problem Defined

**Commit:** <COMMIT_HASH>
**Plan:** \`<DECISION_RECORD_PATH>\`

Problem: <one-line problem statement>
Outcomes: <N> measurable outcomes defined"
```

If no issue is mapped, skip this step silently.
```

- [ ] **Step 2: Commit**

```bash
git add plugin/phases/define/step_3.md
```
```bash
git commit -m "refactor: replace gh issue comment with workflow-cmd.sh issue_comment in define/step_3

Part of issue backend abstraction — phase files now use the
backend-agnostic API instead of gh directly."
```

---

### Task 7: Refactor `discuss/step_2.md` — Replace `gh` with Abstraction

**Files:**
- Modify: `plugin/phases/discuss/step_2.md:51-62`

- [ ] **Step 1: Replace the "Spec to Issue Linking" GitHub section**

Replace lines 51-62 of `plugin/phases/discuss/step_2.md` with:

```markdown
Check if this work maps to an existing issue. If there are tracked observation IDs with issue mappings, or if the user mentioned a specific issue number, post a comment linking to the spec and commit:

```bash
.claude/hooks/workflow-cmd.sh issue_comment <ISSUE_ID> "## Design

**Commit:** <COMMIT_HASH>
**Spec:** \`<SPEC_PATH>\`

Approach: <chosen approach name>"
```

If no issue is mapped, skip this step silently — not all work originates from an issue.
```

- [ ] **Step 2: Commit**

```bash
git add plugin/phases/discuss/step_2.md
```
```bash
git commit -m "refactor: replace gh issue comment with workflow-cmd.sh issue_comment in discuss/step_2

Part of issue backend abstraction — phase files now use the
backend-agnostic API instead of gh directly."
```

---

### Task 8: Refactor `complete/step_7.md` — Replace GitHub Issue Creation and Reconciliation

**Files:**
- Modify: `plugin/phases/complete/step_7.md:58-84`

- [ ] **Step 1: Replace the "GitHub Issue Creation" section (lines 58-71)**

Replace with:

```markdown
## Issue Creation

After saving observations, create issues per category:

- **auto (▶▶▶):** Auto-create for High/Medium priority categories. Skip Low.
- **ask (▶▶):** Ask per-category "Create issue? (y/n)"
- **off (▶):** Ask per-item "Create issue? (y/n)"

For each issue to create:
1. Create: `.claude/hooks/workflow-cmd.sh issue_create "[Category] Summary" "<details>" "<category-label>"`
2. Capture the returned ID/URL
3. Store mapping: `.claude/hooks/workflow-cmd.sh set_issue_mapping "<obs_id>" "<issue_id>"`
```

- [ ] **Step 2: Replace the "GitHub Issue Reconciliation" section (lines 73-84)**

Replace with:

```markdown
## Issue Reconciliation

For each `RESOLVED_ID`, check if it has a linked issue and close it:
- Close: `.claude/hooks/workflow-cmd.sh issue_close <issue_id> "Resolved in commit $(git rev-parse --short HEAD)."`
- Clear mapping: `.claude/hooks/workflow-cmd.sh clear_issue_mapping "<obs_id>"`

For each `KEEP_ID` with a linked issue, verify the issue is still open.

Autonomy gating:
- **auto (▶▶▶):** Auto-close resolved issues.
- **ask (▶▶):** Ask per-issue for closures.
- **off (▶):** Ask per-item for both.
```

- [ ] **Step 3: Commit**

```bash
git add plugin/phases/complete/step_7.md
```
```bash
git commit -m "refactor: replace gh issue create/close with workflow-cmd.sh in complete/step_7

Removes direct gh CLI calls for issue creation, label management,
and reconciliation. Uses backend-agnostic issue_create/issue_close."
```

---

### Task 9: Refactor `complete/step_9.md` — Replace Issue Closure and Add Sync Prompt

**Files:**
- Modify: `plugin/phases/complete/step_9.md:26-43`

- [ ] **Step 1: Replace the "Issue Closure" section**

Replace lines 26-43 of `plugin/phases/complete/step_9.md` with:

```markdown
## Issue Closure

After presenting the summary, close any issues that were resolved by this work:

1. Check issue mappings: `.claude/hooks/workflow-cmd.sh get_issue_mappings`
2. Get the shipping commit hash: `git rev-parse --short HEAD`
3. For each mapped issue that was fully resolved:

```bash
.claude/hooks/workflow-cmd.sh issue_close <ISSUE_ID> "Shipped in commit <HASH> on branch <BRANCH>.

Spec: <SPEC_PATH>
Plan: <PLAN_PATH>"
```

Only close issues where all tasks are completed. If partial, add a progress comment instead using `.claude/hooks/workflow-cmd.sh issue_comment`.

## Issue Sync

Check the current backend:

```bash
BACKEND=$(.claude/hooks/workflow-cmd.sh issue_get_backend)
```

If backend is `both`, prompt for sync:

Autonomy gating:
- **auto (▶▶▶):** Auto-sync: `.claude/hooks/workflow-cmd.sh issue_sync`
- **ask (▶▶):** Ask: "Sync local issues to GitHub? (y/n)"
- **off (▶):** Ask with explanation: "You have local issues that can be synced to GitHub. Sync now? (y/n)"

If user declines, remind: "You can sync later with `/issue-config sync`."

If backend is not `both`, skip this section silently.
```

- [ ] **Step 2: Commit**

```bash
git add plugin/phases/complete/step_9.md
```
```bash
git commit -m "refactor: replace gh issue close with workflow-cmd.sh and add sync prompt in complete/step_9

Uses backend-agnostic issue_close. Adds sync prompt for 'both'
mode with autonomy gating in the session wrap-up."
```

---

### Task 10: Create `/issue-config` Command

**Files:**
- Create: `plugin/commands/issue-config.md`

- [ ] **Step 1: Create the command file**

```markdown
---
description: Configure issue tracking backend (local/both/github)
disable-model-invocation: true
---
<!-- Do NOT invoke this command via the Skill tool. Use the native /command path only. -->

Parse the ARGUMENTS to determine the subcommand:

**No arguments or unrecognized** → run interactive flow:

1. Show current config: run `.claude/hooks/workflow-cmd.sh issue_get_backend` to get mode, then read `.claude/wfm-issue-config.json` (project) or `~/.claude/wfm-issue-config.json` (global) for full settings. If no config exists, show defaults: mode=github, repo=auto.

2. Ask: "Issue tracking mode? (local / both / github)"

3. If user picks `local` or `both`:
   - Check `command -v git-bug`. If missing, ask: "git-bug is required but not installed. Install via Homebrew? (y/n)"
   - If yes: run `brew install git-bug`
   - Check if `.claude/wfm-issues/` exists. If not, run:
     - `git init --bare .claude/wfm-issues`
     - `GIT_DIR=.claude/wfm-issues git bug user create --name "$(git config user.name)" --email "$(git config user.email)"`
   - Check if `.claude/wfm-issues/` is in `.gitignore`. If not, append it.

4. If user picks `both` or `github`:
   - Detect: `git remote get-url origin 2>/dev/null` → extract owner/repo
   - Ask: "GitHub repo? (default: auto → detected-owner/repo)" — user types owner/repo or presses enter for auto
   - If explicit, validate: `gh api repos/<owner/repo> --silent`

5. If user picks `both`:
   - Configure bridge: `GIT_DIR=.claude/wfm-issues git bug bridge configure github --target <owner/repo> --token "$(gh auth token)"`

6. Write config to `.claude/wfm-issue-config.json`:
   ```json
   {"issue_backend": "<mode>", "github_repo": "<auto-or-owner/repo>", "git_bug_repo": ".claude/wfm-issues"}
   ```

7. Confirm: "Issue tracking configured: mode=<X>, github_repo=<Y>"

**`show`** → Display current effective config with resolved values (resolve "auto" to actual owner/repo).

**`mode <local|both|github>`** → Switch mode. Run dependency checks for the new mode. Update config file.

**`repo <owner/repo>`** → Set explicit GitHub repo. Update config file.

**`repo auto`** → Reset to auto-detect. Update config file.

**`global`** → Run interactive flow but write to `~/.claude/wfm-issue-config.json` instead of project-level.

**`sync`** → Run `.claude/hooks/workflow-cmd.sh issue_sync`. Report result.
```

- [ ] **Step 2: Commit**

```bash
git add plugin/commands/issue-config.md
```
```bash
git commit -m "feat: add /issue-config command for issue backend configuration

Supports interactive setup, direct overrides (mode/repo/global/show/sync),
git-bug installation, repo initialization, and bridge configuration."
```

---

### Task 11: Register `issue-config` in Skill Registry

**Files:**
- Modify: `plugin/config/skill-registry.json`

- [ ] **Step 1: Add `issue-config` to the operations object**

In `plugin/config/skill-registry.json`, add after the `"git-worktrees"` entry (before the closing `}` of `"operations"`):

```json
    ,
    "issue-config": {
      "phase": ["any"],
      "process_skill": null,
      "reference_skills": [],
      "description": "Configure issue tracking backend (local/both/github)"
    }
```

- [ ] **Step 2: Verify valid JSON**

Run: `jq . plugin/config/skill-registry.json >/dev/null`
Expected: No output (valid JSON)

- [ ] **Step 3: Commit**

```bash
git add plugin/config/skill-registry.json
```
```bash
git commit -m "feat: register issue-config in skill registry

Available in any phase — allows configuring issue backend
without entering a workflow."
```

---

### Task 12: Version Bump

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Read current versions from all three files**

Read all three files to confirm current version (expected: 2.3.0).

- [ ] **Step 2: Bump version to 2.4.0 in all three files**

This is a minor version bump — new feature (issue backend abstraction) with backward compatibility.

Update the `"version"` field from `"2.3.0"` to `"2.4.0"` in:
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `plugin/.claude-plugin/plugin.json`

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json
```
```bash
git commit -m "feat: bump version to 2.4.0 for issue backend abstraction

New feature: configurable issue tracking (local/github/both)
with backend abstraction layer and /issue-config command."
```

---

## Open Issues

- **git-bug v0.x stability:** All git-bug calls are isolated in `issues.sh`. If git-bug introduces breaking CLI changes, only one file needs updating.
- **Autonomy gating refactoring:** Currently duplicated across phases. Flagged for a future session — not in scope here.
- **git-bug `GIT_DIR` behavior:** Needs manual testing to confirm `GIT_DIR` works correctly with all git-bug subcommands. The `git bug` CLI may not respect `GIT_DIR` for all operations — if not, fall back to `cd`-ing into the bare repo directory.
