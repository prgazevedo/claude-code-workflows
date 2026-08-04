# GH Issues as Source of Truth — Design Specification

**GitHub Issue:** #40 (GH Issues as source of truth for work tracking)
**Status:** Implementing — #43 fixed, L1 coaching confirmed working.

## Problem

Two parallel tracking systems run disconnected:
- claude-mem observations with opaque IDs tracked in the statusline (`Open:[#5670]`)
- GitHub issues — durable, browsable, linkable

This caused stale issues to go unnoticed and observation IDs in the statusline with no clear connection to actionable work.

## Decision

GH issues become the single source of truth for work tracking. claude-mem remains the deep memory layer for decisions, debugging context, and rationale. Observations cross-reference GH issue numbers in their narrative; GH issues can reference observation IDs for deep context.

## Outcomes

1. `/issues` command shows open GH issues with date and type (already implemented)
2. `/obs-track` and `/obs-untrack` commands removed — no longer needed
3. Statusline drops `Open:[#5670]` observation tracker
4. Complete phase (steps 7-8) reconciles against GH issues, not tracked observations
5. Coaching instructs: create GH issue first, reference it in observations, reference observations in issues
6. `tracking.sh` removes tracked observation functions; keeps `last_observation_id` and issue mapping functions
7. `workflow-cmd.sh` removes tracked observation command entries

## Scope

### A. Already done
- `plugin/commands/issues.md` — created and committed

### B. Commands to remove
- `plugin/commands/obs-track.md` — delete
- `plugin/commands/obs-untrack.md` — delete

### C. Statusline cleanup
- `plugin/statusline/statusline.sh` — remove the `Open:[...]` tracked observations rendering (lines 262-278)
- Remove the tracked observations debug log field

### D. State infrastructure cleanup
- `plugin/scripts/infrastructure/tracking.sh` — remove `get_tracked_observations`, `set_tracked_observations`, `add_tracked_observation`, `remove_tracked_observation`; keep `last_observation_id` functions and issue mapping functions
- `plugin/scripts/workflow-cmd.sh` — remove `get_tracked_observations|set_tracked_observations|add_tracked_observation|remove_tracked_observation` from the command whitelist

### E. Complete phase coaching updates

**`plugin/phases/complete/step_7.md`:**
- Replace "review tracked observations" with "reconcile GH issues"
- Check open issues with `gh issue list`, not `get_tracked_observations`
- Close resolved issues with `gh issue close`
- Keep the categorized findings table and observation saving
- When saving observations, include the GH issue number in the narrative
- Remove `set_tracked_observations` calls

**`plugin/phases/complete/step_8.md`:**
- Handover references GH issue numbers for open work, not observation IDs
- Remove the "build final tracked observations list" section
- Keep handover observation saving (it's deep context)

### F. Phase coaching additions

Add GH issue workflow guidance to phase coaching:

**`plugin/coaching/objectives/discuss.md`** (or phase instructions):
- "If no GH issue exists for this work, create one first"
- "Reference the GH issue number in claude-mem observations"

**`plugin/phases/complete/step_7.md`:**
- "When creating observations for findings, include `Issue #N` in the narrative for cross-reference"
- "When creating GH issues for findings, note relevant observation IDs in the issue body"

### G. State file cleanup
- Remove `tracked_observations` from `setup.sh` initial state template
- Remove `tracked_observations` from state reset in `agent-set-phase.sh` and `user-set-phase.sh` (these preserve it during transitions — no longer needed)

## What stays unchanged
- `last_observation_id` tracking — claude-mem still records the last observation for reference
- Issue mapping functions (`set_issue_mapping`, `get_issue_url`, etc.) — still useful for obs↔issue cross-referencing
- claude-mem observations — still the deep memory layer
- `/obs-read` command — still useful for reading observations by ID
- `/issues` command — already implemented

## Implementation order
1. Delete command files (obs-track, obs-untrack)
2. Clean statusline
3. Clean tracking.sh and workflow-cmd.sh
4. Update complete phase steps 7 and 8
5. Add GH issue guidance to coaching
6. Clean state templates (setup.sh, phase transitions)
7. Deploy to cache
8. Version bump
