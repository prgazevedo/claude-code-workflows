# Spike: WFM positioning — from teaching the model to providing what it cannot provide itself

**Issue:** [#96](https://github.com/prgazevedo/claude-code-workflows/issues/96)
**Status:** decided
**Date:** 2026-08-03

## The decision

WFM's pitch changes.

**Old:** "Claude Code is powerful but undisciplined — WFM teaches and forces
discipline."

**New:** "The model is capable and keeps changing — WFM supplies the four
things a model cannot supply for itself: enforcement, structure, memory,
and measurement."

## The evidence that forced it

The eval harness (#81, merged 2026-08-03) ran three pressure tests: a planted
security bug, a planted state bug, and a boundary-testing task, each under
"tests pass, hurry up" pressure. **The bare model — no agent prompt, no
workflow framework — passed all three.** It read the code, refused the
framing, and found every planted bug.

The source repo this project imports from shows the same: agentic-sdlc's
flagship fixture records three baseline captures, none of which failed.

Conclusion: prompt text that teaches the model what it already knows is not an
asset. It is maintenance cost that silently goes stale as models improve. Any
positioning built on "the model needs teaching" erodes with every model
release.

## The four pillars

What survives model drift, and why the model cannot self-supply it:

| Pillar | What it is | Why the model cannot do it alone |
|---|---|---|
| **Enforcement** | Hooks that block writes until a plan is approved | A prompt can be rationalized around; a blocked tool call cannot |
| **Structure** | Phases, PR/issue slots, artifacts | Shape is imposed from outside — and structure, not prohibition, is what the measured research supports (see `agent-prompt-form.md`) |
| **Memory** | Issues, boards, observations, evidence trails | Sessions end; without an external record, decisions and attempts are lost |
| **Measurement** | The evals: a prompt rule must beat the bare model to exist, and is re-tested when the model changes | The model cannot know what it no longer needs to be told |

Prompt text must earn its place. A rule exists only with a recorded failure
of the bare model (a RED capture). When the baseline model changes, the rule
is re-tested.

## Consequences

1. **README rewritten** (this PR): "Why" now says drifting and forgetful, not
   undisciplined; "Goal" lists the four pillars.
2. **#82 promoted to P1.** The Iron Law + coaching-layer audit is the first
   application: prune the l3 checks whose failure mode the bare model no
   longer exhibits.
3. **The #44 imports follow the same lens** (re-triage comment posted
   2026-08-03): mechanical imports proceed on their own merits; prompt-text
   imports start with a RED capture, and a pass by the bare model closes the
   issue as "model already does this".
4. **Evals become maintenance ritual**, not a one-off: re-run RED on model
   upgrades. This keeps the measurement pillar current as models change.

## What this does not change

The plugin's mechanics — phases, hooks, state machine, boards — are already
the durable part. This spike renames the value, prunes the prose, and adds
the measurement loop. No workflow behaviour changes here.

## Related

- [`agent-prompt-form.md`](agent-prompt-form.md) — the evidence that prompt
  *kind* matters and persona text does not (#84).
- `evals/README.md` — the harness and its honesty rules (#81).
- claude-code-workflows#92 — the same insight applied to human-facing text:
  templates and a judge, not more prose rules.
