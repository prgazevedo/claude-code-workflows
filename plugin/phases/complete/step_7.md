# Step 7: Tech Debt Audit

**First, check open GitHub issues from prior sessions:**

```bash
gh issue list --state open --json number,title,labels,createdAt --limit 50
```

Review the open issues and for each:
- **Resolved this session?** → mark as RESOLVED in the table below
- **Still open?** → mark as OPEN in the table below

## Collect and Categorize Findings

Gather all findings from these sources:
- Plan's "accepted trade-offs" and "tech debt acknowledged" entries
- Review phase findings (if review was run)
- Steps 1-3 validation results (boundary tester, devil's advocate findings)

Group findings into these categories:

| Category | GitHub Label | What goes here |
|----------|-------------|---------------|
| Security | `security` | Bypass vectors, injection risks, secret exposure, auth gaps |
| Robustness | `robustness` | Race conditions, error handling, fail-open/closed, resilience |
| Feature | `feature` | Missing capabilities, incomplete implementations |
| Tech Debt | `tech-debt` | Code quality, duplication, pattern inconsistency |
| Documentation | `documentation` | Stale references, missing docs, README drift |

**Skip empty categories.** Only present categories that have findings.

## Present Categorized Table

For each non-empty category:

**[Category] ([N] items):**

| Item | Impact | Proposed Fix | Effort | Priority |
|---|---|---|---|---|
| <description> | <what could go wrong> | <specific fix> | S/M/L | High/Medium/Low |

## Save Category Observations

For each non-empty category, save a single claude-mem observation:
- **Title:** `Open Issue — [Category]: [summary] (YYYY-MM-DD)`
- **Type:** `discovery`
- **Project:** derived from git remote
- **Narrative:** All items with details, effort estimates, priority. Include `Issue #N` for any related GH issue so observations cross-reference issues.

Autonomy gating for observations:
- **auto (▶▶▶):** Auto-save all category observations
- **ask (▶▶):** Auto-save all category observations
- **off (▶):** Ask per-category "Save observation? (y/n)"

## GitHub Issue Creation

After saving observations, create GitHub issues per category:

- **auto (▶▶▶):** Auto-create for High/Medium priority categories. Skip Low.
- **ask (▶▶):** Ask per-category "Create GitHub issue? (y/n)"
- **off (▶):** Ask per-item "Create GitHub issue? (y/n)"

For each issue to create:
1. Check `gh` is available: `gh auth status 2>&1`. If not, skip gracefully.
2. Ensure label exists: `gh label create "<label>" --description "<desc>" 2>/dev/null || true`
3. Create: `gh issue create --title "[Category] Summary" --body "<details>" --label "<category-label>"`
4. Note the observation ID in the issue body for cross-reference.

## GitHub Issue Reconciliation

For each RESOLVED issue found at the start of this step:
- Close: `gh issue close <number> --comment "Resolved in commit $(git rev-parse --short HEAD)."`

Autonomy gating:
- **auto (▶▶▶):** Auto-close resolved issues.
- **ask (▶▶):** Ask per-issue for closures.
- **off (▶):** Ask per-item for both.

Mark reconciliation milestone:
```bash
.claude/hooks/workflow-cmd.sh set_completion_field "issues_reconciled" "true"
```

**CHECKPOINT — Report to user before proceeding.**

## Temp File Cleanup

```bash
rm .claude/tmp/* 2>/dev/null || true
```

#### Step 7 Review Gate

Dispatch a **review agent** — read `plugin/agents/tech-debt-reviewer.md`, then dispatch as `general-purpose`:

Context: "Plan: [PLAN_PATH]. Categorized tech debt table: [TABLE]."

If REDO: fix and re-dispatch. Max 3 iterations, then surface to user.
Present summary: "Step 7 review: [findings found / no issues]. Fixed: [what changed]. Verdict: PASS."

Mark milestone:
```bash
.claude/hooks/workflow-cmd.sh set_completion_field "tech_debt_audited" "true"
```
