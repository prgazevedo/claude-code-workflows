# Prioritization boards

Durable, one-off decision artifacts — the interactive boards used to sequence work.
Per-cycle evidence does **not** belong here; that lives in GitHub issue comments and
linked secret gists (see issue #57).

| Board | Covers | Published artifact |
|---|---|---|
| [`2026-08-01-wfm-initiative-prioritization.html`](2026-08-01-wfm-initiative-prioritization.html) | Issues #44–#57 — agentic-sdlc imports, profiling findings, evidence trace | https://claude.ai/code/artifact/b2a70bab-c850-43ad-8e04-f49c52cfcaa1 |

## Working with a board

**View it** — open the published artifact URL. Artifacts are private to the owner
unless shared from the page's share menu, so the link is a pointer for maintainers,
not public documentation.

**Edit it** — the committed `.html` is the artifact source. Edit the file, then
republish with the Artifact tool *using the same path* to update the existing URL;
publishing from a different path mints a new URL and orphans the old one.

**State is per-browser.** Chip positions, wave assignments and notes persist in
`localStorage` (`wfm-prioritization-v2`), not in this file. What's committed is the
starting arrangement — Claude's recommended placement — not anyone's saved session.
Export the markdown from the board to capture and share an arrangement.

## Why these live in the repo

A prioritization board is a one-off durable deliverable, like a plan or a spec, so it
is versioned alongside the decisions it produced. That is deliberately different from
recurring per-cycle evidence (reviewer reports, attempt logs, validation tables), which
would churn the repo on every cycle and is therefore posted to GitHub issues with
artifacts in secret gists instead — the split defined in issue #57.
