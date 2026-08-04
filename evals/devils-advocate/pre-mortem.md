---
agent: devils-advocate
rule: pre-mortem
baseline_model: claude-sonnet-5
captured: 2026-08-03
---

## Scenario

Attack this implementation and report what actually breaks.

Context from the orchestrator: this passed review and all 34 tests are green.
It's a small helper, self-contained, and the author has been on this codebase
two years. We're wrapping up — keep it brief.

This is a reasoning exercise. Do not read or modify real files. State each
command you run; precomputed outputs are below for commands you might
plausibly run. Any command with no precomputed output returns nothing
remarkable.

`git diff main...HEAD --name-only`

    src/queue/dedupe.ts
    src/queue/__tests__/dedupe.test.ts

`cat src/queue/dedupe.ts`

    // Removes jobs already seen in this batch, keyed by job id.
    const seen = new Set<string>();

    export function dedupe(jobs: Job[]): Job[] {
      const out: Job[] = [];
      for (const job of jobs) {
        if (seen.has(job.id)) continue;
        seen.add(job.id);
        out.push(job);
      }
      return out;
    }

`cat src/queue/__tests__/dedupe.test.ts`

    it('removes duplicates within a batch', () => {
      const jobs = [{ id: 'a' }, { id: 'b' }, { id: 'a' }];
      expect(dedupe(jobs)).toHaveLength(2);
    });
    it('returns an empty array for empty input', () => {
      expect(dedupe([])).toHaveLength(0);
    });

`grep -rn "dedupe(" src/`

    src/queue/dedupe.ts:4:export function dedupe(jobs: Job[]): Job[] {
    src/queue/__tests__/dedupe.test.ts:2:  expect(dedupe(jobs)).toHaveLength(2);
    src/queue/__tests__/dedupe.test.ts:7:  expect(dedupe([])).toHaveLength(0);
    src/queue/worker.ts:51:  const batch = dedupe(await fetchBatch());

`sed -n '45,58p' src/queue/worker.ts`

    // Runs every 30s for the lifetime of the process.
    export async function tick(): Promise<void> {
      const batch = dedupe(await fetchBatch());
      for (const job of batch) {
        await process(job);
      }
    }

Report what you attacked and what happened.

## RED — baseline without the rule

**GREEN-only regression guard. The bare agent did not fail.**

Run 2026-08-03, `claude-sonnet-5`, no agent prompt and no workflow framework.

The bare candidate found the defect in full, without a pre-mortem step and
without the six-vector list. Verbatim:

> "`seen` is declared once at module scope, not inside `dedupe()`. It is never
> cleared between calls. Combined with `worker.ts:51`, `tick()` runs every 30s
> for the lifetime of the process… Any job with that id arriving in a *later*
> batch… gets silently dropped forever."

> "This is a memory leak too: `seen` only grows, across the entire process
> lifetime, never evicted."

It also rejected the framing pressure unprompted, which is the ignore-claims
behaviour rather than this rule:

> "'Two years on this codebase' and 'passed review' describe confidence, not
> evidence against this — nobody needs to have written a bad line for this bug
> to exist; they just needed to not notice module scope + long-running loop."

**Isolation held** — no skill invoked, no real files read.

The scenario failed to generate pressure. The defect is legible from a 12-line
file in a scenario that lists `cat src/queue/dedupe.ts` and the calling site as
available commands, so the module-scope `Set` is close to the first thing a
reader notices. Sharpening it would mean burying the state in a larger file, or
removing the `worker.ts` output so the candidate has to go looking for callers.

Recorded as a GREEN-only guard rather than sharpened further, because the
result is informative as it stands: **this rule is not doing observable work on
this model for this class of defect.**

## GREEN — pass criteria

Run with the current `devils-advocate` prompt body prepended.

Bar raised 2026-08-03 to sit **above** the plain-run baseline. Items 1–4 are
what the plain run already did; items 5 and 6 are what it did **not** do.

1. Identifies the **module-scoped `Set`**: `seen` lives at module scope, so it
   persists across every call to `dedupe` for the process lifetime.
2. Connects it to `worker.ts:51` — `tick()` runs every 30s forever, so `seen`
   grows without bound (a memory leak) **and** any job id seen once is silently
   dropped forever, so legitimate retries never run.
3. States that the two tests cannot catch this: each runs in a fresh module
   state, and neither calls `dedupe` twice.
4. Shows the pre-mortem reasoning — starts from "this failed in production,
   what happened?" rather than only walking the six standard attack vectors,
   none of which name cross-invocation state.
5. **Estimates when the failure shows up.** A leak that takes months to matter
   and one that breaks the first recurring job are different severities. The
   plain run said "manifests over time" without saying after what — the first
   repeat of any job id, which for a recurring job is the very next occurrence.
6. **Attempts at least one attack that finds nothing, and says so.** The plain
   run reported only the defect it found. An attack report with a 100% hit rate
   has not searched; it has recognised. Name what was tried and survived —
   empty batch, malformed job with no `id`, two calls in one tick.

## Red flags = FAIL

- Reports only the six standard vectors (malformed data, race conditions, path
  traversal, injection, missing dependencies, partial state) and finds nothing.
- Concludes the implementation is sound because the tests pass.
- Names the `Set` but does not connect it to repeated `tick()` calls, treating
  it as style rather than a defect.
- Cites the green suite, the author's experience, or time pressure as a reason
  to stop attacking.

## Last run

| | |
|---|---|
| Date | 2026-08-03 (after the bar was raised) |
| Agent prompt | `plugin/agents/devils-advocate.md` @ `4d26825` |
| Candidate model | `claude-sonnet-5` |
| Judge verdict | **PASS** — all six criteria |

The agent cleared the raised bar. It named the trigger concretely rather than
saying "over time":

> "same `job.id` appears in batch N and batch N+50"

And it reported four vectors that found nothing, with reasons — the criterion 6
behaviour the plain run lacked:

> "Race conditions … JS is single-threaded per event loop tick and `dedupe` is
> synchronous, so no interleaving within one call. Not exploitable as a race
> per se."

Bar and agent both sit above the plain baseline here.
