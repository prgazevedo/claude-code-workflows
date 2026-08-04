# Issue Backend Abstraction — Design Spec

**Date:** 2026-04-21
**Status:** Draft
**Scope:** WFM issue tracking decoupling and backend abstraction

## Problem

WFM's issue tracking is hardcoded to GitHub Issues via direct `gh` CLI calls spread across 4 phase files (`define/step_3`, `discuss/step_2`, `complete/step_7`, `complete/step_9`). This creates two problems:

1. **Coupling to project repo:** Work items are personal productivity tracking, not project-level concerns. They shouldn't live in the upstream project's GitHub Issues.
2. **Disseminated logic:** Adding a second backend (or changing the existing one) requires modifying all 4 phase files, duplicating conditional logic in each.

## Approaches Considered (DISCUSS phase — diverge)

### Approach A: Thin Abstraction Layer (Chosen)

A single `infrastructure/issues.sh` that exposes backend-agnostic functions. Phase files call these functions via `workflow-cmd.sh` without knowing which backend is active.

- **Pros:** Minimal new code, follows existing WFM infrastructure patterns, easy to test, extensible.
- **Cons:** Shell scripting limits — no real interfaces, just convention.

### Approach B: Backend Scripts + Dispatcher

Separate scripts per backend (`issues-github.sh`, `issues-gitbug.sh`) with a dispatcher. Each backend implements the same function signatures.

- **Pros:** Clean per-backend isolation.
- **Cons:** Over-engineered for two backends with similar CRUD semantics. Premature abstraction.

### Approach C: Phase-Level Conditionals

Add `if/elif` blocks directly in each phase markdown file.

- **Pros:** No new files, fast to implement.
- **Cons:** Duplicated logic across 4 files. Every backend change touches all phases. Fragile and expensive to maintain.

## Decision (DISCUSS phase — converge)

- **Chosen approach:** Approach A — Thin Abstraction Layer
- **Rationale:** Matches existing WFM infrastructure patterns (`tracking.sh`, `state-io.sh`), centralizes backend logic in one file, keeps phase files clean.
- **Trade-offs accepted:** Shell-based abstraction relies on convention rather than enforced interfaces.
- **Risks identified:** git-bug is v0.x and could have breaking changes. Mitigated by isolating all git-bug calls in one file.
- **Constraints applied:** Must preserve current `github` mode as default — zero behavior change for users who don't configure issue backends.
- **Tech debt acknowledged:** Autonomy gating is duplicated across phases (separate refactoring, out of scope).

## Configuration

### Config File

**Project-level:** `.claude/wfm-issue-config.json`
**Global fallback:** `~/.claude/wfm-issue-config.json`
**Resolution order:** Project > Global > Hardcoded defaults

```json
{
  "issue_backend": "github",
  "github_repo": "auto",
  "git_bug_repo": ".claude/wfm-issues"
}
```

### Fields

| Field | Values | Default | Description |
|-------|--------|---------|-------------|
| `issue_backend` | `"local"` \| `"both"` \| `"github"` | `"github"` | Which backend(s) to use |
| `github_repo` | `"auto"` or `"owner/repo"` | `"auto"` | Target GitHub repo. `"auto"` detects from `git remote get-url origin`. |
| `git_bug_repo` | Relative path | `".claude/wfm-issues"` | Path to git-bug bare repo, relative to project root. |

### Defaults

Default config (`github` / `auto` / `.claude/wfm-issues`) preserves current WFM behavior — zero change for existing users.

## Abstraction Layer: `infrastructure/issues.sh`

**Location:** `plugin/scripts/infrastructure/issues.sh`

### Internal Functions

- `_load_issue_config` — Reads project config, falls back to global, falls back to defaults. Caches in shell variables.
- `_resolve_github_repo` — If `github_repo` is `"auto"`, extracts `owner/repo` from `git remote get-url origin`.

### Public Functions (exposed via `workflow-cmd.sh`)

| Function | Description | local | github | both |
|----------|-------------|-------|--------|------|
| `issue_create <title> <body> [--label X]` | Create an issue, return ID/URL | git-bug | gh | git-bug (primary) |
| `issue_close <id> [--comment X]` | Close an issue | git-bug | gh | git-bug (primary) |
| `issue_comment <id> <body>` | Add a comment to an issue | git-bug | gh | git-bug (primary) |
| `issue_list [--status open]` | List issues | git-bug | gh | git-bug (primary) |
| `issue_sync` | Push git-bug state to GitHub via bridge | no-op | no-op | git-bug bridge push |
| `issue_get_backend` | Return current backend mode | config read | config read | config read |

### Backend Dispatch

- `local`: git-bug only. GitHub calls skipped. `issue_sync` is a no-op.
- `github`: `gh --repo <owner/repo>` only. git-bug calls skipped.
- `both`: git-bug is primary (always called first). GitHub sync is manual via `issue_sync`.

### Dependency Checks

- `github` / `both`: Checks `gh auth status`. If unavailable, warns and degrades gracefully.
- `local` / `both`: Checks `command -v git-bug`. If unavailable, errors with message to run `/issue-config`.

### Integration with `tracking.sh`

Existing functions (`set_issue_mapping`, `get_issue_url`, `get_issue_mappings`, `clear_issue_mapping`) are unchanged. They remain backend-agnostic — they store observation-to-issue ID/URL mappings regardless of which backend produced the issue. `issues.sh` calls them after creating/closing issues.

## `/issue-config` Command

**Location:** `plugin/commands/issue-config.md`

### Interactive Flow (`/issue-config`)

1. Ask: "Issue tracking mode? (local / both / github)" — show current setting
2. If `local` or `both`:
   - Check `command -v git-bug`. If missing: "git-bug not found. Install via Homebrew? (y/n)" → `brew install git-bug`
   - If `.claude/wfm-issues/` doesn't exist: init (`git init --bare .claude/wfm-issues`, `GIT_DIR=.claude/wfm-issues git bug user create`)
   - Add `.claude/wfm-issues/` to `.gitignore` if not present
3. If `both` or `github`:
   - Detect remote: `git remote get-url origin` → extract `owner/repo`
   - Ask: "GitHub repo? (default: auto → `owner/repo`)" — user accepts or types explicit `owner/repo`
   - Validate explicit repos with `gh api repos/owner/repo --silent`
4. If `both`: configure git-bug bridge → `GIT_DIR=.claude/wfm-issues git bug bridge configure github --target <owner/repo> --token $(gh auth token)`
5. Write config to `.claude/wfm-issue-config.json`
6. Confirm: "Issue tracking configured: mode=X, github_repo=Y"

### Direct Overrides

- `/issue-config mode <local|both|github>` — switch mode, run dependency checks
- `/issue-config repo <owner/repo>` — set explicit GitHub repo target
- `/issue-config repo auto` — reset to auto-detect from origin
- `/issue-config global` — run interactive flow, write to `~/.claude/wfm-issue-config.json`
- `/issue-config show` — display current effective config (resolved values)
- `/issue-config sync` — manually trigger `issue_sync` (convenience alias)

### Skill Registration

Added to `plugin/config/skill-registry.json`:

```json
"issue-config": {
  "phase": ["any"],
  "process_skill": null,
  "reference_skills": [],
  "description": "Configure issue tracking backend (local/both/github)"
}
```

## Phase Refactoring

### Changes Per Phase

| Phase file | Before | After |
|------------|--------|-------|
| `define/step_3.md` | `gh issue comment <NUM> --body ...` | `workflow-cmd.sh issue_comment <id> <body>` |
| `discuss/step_2.md` | `gh issue comment <NUM> --body ...` | `workflow-cmd.sh issue_comment <id> <body>` |
| `complete/step_7.md` | `gh issue create ...`, `gh issue close ...`, `gh label create ...` | `workflow-cmd.sh issue_create ...`, `workflow-cmd.sh issue_close ...` |
| `complete/step_9.md` | `gh issue close ...` | `workflow-cmd.sh issue_close ...` |

### New: Sync Prompt in COMPLETE (step 9)

After the open issues summary, if `issue_backend` is `"both"`:

> "Sync local issues to GitHub? (y/n)"

Autonomy gating:
- **auto (▶▶▶):** Auto-sync
- **ask (▶▶):** Ask once
- **off (▶):** Ask with explanation

If user declines, remind: "You can sync later with `/issue-config sync`."

### Label Handling

Currently `complete/step_7.md` creates labels via `gh label create`. This moves into `issue_create`:
- `github` / `both`: Labels created on GitHub via `gh label create --repo`
- `local`: git-bug labels via `git bug label add`

## git-bug Integration

### Repo Initialization

During `/issue-config` when `local` or `both` is selected:

```bash
git init --bare .claude/wfm-issues
GIT_DIR=.claude/wfm-issues git bug user create \
  --name "$(git config user.name)" \
  --email "$(git config user.email)"
```

### Command Execution

All git-bug commands use `GIT_DIR` to target the project-local repo:

```bash
GIT_DIR=.claude/wfm-issues git bug add --title "..." --message "..."
GIT_DIR=.claude/wfm-issues git bug status close <id>
GIT_DIR=.claude/wfm-issues git bug comment add <id> --message "..."
GIT_DIR=.claude/wfm-issues git bug ls --status open
```

### Bridge Setup (both mode)

Configured during `/issue-config`:

```bash
GIT_DIR=.claude/wfm-issues git bug bridge configure github \
  --target <owner/repo> --token "$(gh auth token)"
```

Reuses `gh auth token` — no second auth flow required.

### Sync

```bash
GIT_DIR=.claude/wfm-issues git bug bridge push
```

### ID Mapping

- git-bug uses hex IDs (e.g., `00e03a757d`)
- GitHub uses numeric IDs / URLs
- `tracking.sh` stores whichever ID the primary backend returns: git-bug hex in `local`/`both`, GitHub URL in `github` mode
- In `both` mode, `issue_create` returns the git-bug hex ID immediately. The corresponding GitHub issue ID is only available after `issue_sync`. The bridge maintains its own internal mapping between git-bug and GitHub IDs.

## .gitignore

`.claude/wfm-issues/` is added to `.gitignore` during initialization. Personal work items should not be committed to the project repo.

## Backward Compatibility

- Default config (`github` / `auto`) preserves exact current behavior
- No git-bug dependency unless user explicitly configures `local` or `both`
- Existing `tracking.sh` mappings are unaffected
- Phase files continue to work identically — they just call `workflow-cmd.sh` instead of `gh` directly
