# Step 8: Handover (Claude-Mem Observation)

Dispatch a **Handover writer agent** — read `plugin/agents/handover-writer.md`, then dispatch as `general-purpose`:

Context: "Prepare a claude-mem handover observation. Project name: [derived from git remote get-url origin]. Plan: [PLAN_PATH]. Include commit hash, verification results, key decisions, gotchas, files modified, tech debt. Reference any GH issue numbers worked on this session (e.g., 'Issue #40'). Note relevant observation IDs in the handover for cross-reference."

Save via the `save_observation` MCP tool. **Set `project` to the GitHub repo name.** Derive it: `git remote get-url origin 2>/dev/null | sed 's/.*[:/]\([^/]*\)\.git$/\1/' | sed 's/.*[:/]\([^/]*\)$/\1/'`

#### Step 8 Review Gate

After saving the handover observation, dispatch a **review agent** — read `plugin/agents/handover-reviewer.md`, then dispatch as `general-purpose`:

Context: "Review the handover observation just saved."

If REDO: fix and re-save the observation, then re-dispatch. Max 3 iterations, then surface to user.
Present summary: "Step 8 review: [findings found / no issues]. Fixed: [what changed]. Verdict: PASS."

Mark milestone:
```bash
.claude/hooks/workflow-cmd.sh set_completion_field "handover_saved" "true"
```
