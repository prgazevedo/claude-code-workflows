# L1 Coaching Crash Fix — Design Specification

**GitHub Issue:** #43 (L1 coaching never delivered — _PROJECT_ROOT unbound variable)

## Problem

L1 phase coaching (objectives, phase instructions, auto-transition guidance) is never delivered after phase transitions. The PostToolUse hook crashes silently because `post-tool-delivery.sh` references `_PROJECT_ROOT`, a variable that is never set anywhere in the codebase.

## Root Cause (Two Bugs)

**Bug A — Classifier misclassification:** The tool classifier regex at `tool-classifier.sh:29` doesn't account for quoted paths. Claude Code sends commands like `"/path/to/workflow-cmd.sh" agent_set_phase`, but the regex expects `workflow-cmd.sh agent_set_phase` (no quote between `.sh` and space). Phase transitions fall through to `infrastructure-query`, skipping L1 entirely.

**Bug B — Unbound variable:** Even if classified correctly, `_deliver_l1()` crashes at `PROJECT_ROOT="$_PROJECT_ROOT"` (line 34 of `post-tool-delivery.sh`). `_PROJECT_ROOT` is never set anywhere. Under `set -euo pipefail`, this is a fatal error. The hook exits silently — Claude Code does not surface PostToolUse errors.

Both bugs must be fixed together for coaching to work.

## Why Only L1 Is Affected

- **L2/L3** use `COACHING_DIR="$PLUGIN_ASSETS_ROOT/coaching"` set in `post-tool-coaching.sh:41` — works correctly
- **L1** uses its own `_emit_phase_coaching()` which independently resolves paths via `PROJECT_ROOT` — this is the broken path

## Path Convention Mismatch

`_emit_phase_coaching()` constructs:
```
$project_root/plugin/coaching/   # expects project root, appends plugin/
$project_root/plugin/phases/
```

But `PLUGIN_ASSETS_ROOT` already IS the `plugin/` directory:
```
dev mode:    PLUGIN_ASSETS_ROOT = <project>/plugin
production:  PLUGIN_ASSETS_ROOT = <cache>/plugin
```

## Fix

Three files, three edits:

### 0. `plugin/scripts/infrastructure/tool-classifier.sh` (lines 29, 40)

Fix regex to allow optional closing quote after `.sh`:

```diff
-        if echo "$cmd" | grep -qE '(^|/)workflow-cmd\.sh[[:space:]]+agent_set_phase';
+        if echo "$cmd" | grep -qE '(^|/)workflow-cmd\.sh"?[[:space:]]+agent_set_phase';
```

```diff
-        if echo "$cmd" | grep -qE '(^|/)workflow-cmd\.sh';
+        if echo "$cmd" | grep -qE '(^|/)workflow-cmd\.sh"?($|[[:space:]])';
```

Also fix the `user-set-phase.sh` and `agent-set-phase.sh` patterns for consistency:

```diff
-        if echo "$cmd" | grep -qE 'user-set-phase\.sh';
+        if echo "$cmd" | grep -qE 'user-set-phase\.sh"?';
-        if echo "$cmd" | grep -qE 'agent-set-phase\.sh';
+        if echo "$cmd" | grep -qE 'agent-set-phase\.sh"?';
```

The following two edits are in the L1 coaching path:

### 1. `plugin/scripts/l1/post-tool-delivery.sh` (line 34)

```diff
-    PROJECT_ROOT="$_PROJECT_ROOT"
+    PROJECT_ROOT="$PLUGIN_ASSETS_ROOT"
```

Also update the comment on line 12:
```diff
-#   PHASE, MESSAGES, _PROJECT_ROOT
+#   PHASE, MESSAGES, PLUGIN_ASSETS_ROOT
```

### 2. `plugin/scripts/l1/phase-coaching.sh` (lines 25-27)

Since `PROJECT_ROOT` now points to `plugin/` (not the project root), remove the `plugin/` suffix:

```diff
-    local project_root="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
-    local coaching_dir="$project_root/plugin/coaching"
-    local phases_dir="$project_root/plugin/phases"
+    local plugin_root="${PROJECT_ROOT:-$PLUGIN_ASSETS_ROOT}"
+    local coaching_dir="$plugin_root/coaching"
+    local phases_dir="$plugin_root/phases"
```

Also update the comment on line 17:
```diff
-# Uses: PROJECT_ROOT (must be set by caller)
+# Uses: PROJECT_ROOT (set to PLUGIN_ASSETS_ROOT by caller)
```

### 3. Deploy to plugin cache

Copy modified files to the active plugin cache so the fix takes effect in the current session.

## Verification

After the fix, trigger a phase transition and confirm:
1. No crash in hook logs (`~/.claude/logs/wfm-*.log`)
2. L1 coaching content appears in `additionalContext`
3. `message_shown` flips to `true` in state file
4. All phases deliver coaching (test at least discuss and implement)

## Scope

- `tool-classifier.sh`, `post-tool-delivery.sh`, and `phase-coaching.sh` are modified
- L2/L3 coaching paths are untouched (already working)
- No state file schema changes
