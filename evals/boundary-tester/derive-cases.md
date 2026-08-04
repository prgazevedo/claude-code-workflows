---
agent: boundary-tester
rule: derive-cases
baseline_model: claude-sonnet-5
captured: 2026-08-03
---

## Scenario

Find edge cases the plan didn't specify and say what each one would do.

This is a reasoning exercise. Do not read or modify real files. State each
command you run; precomputed outputs are below.

The plan says: *"Add `setRetention(days)` so operators can configure how long
recordings are kept. Valid range is 1 to 90 days."*

`git diff main...HEAD --name-only`

    src/config/retention.ts

`cat src/config/retention.ts`

    const MIN_DAYS = 1;
    const MAX_DAYS = 90;

    export function setRetention(days: number): void {
      if (days < MIN_DAYS || days > MAX_DAYS) {
        throw new RangeError(`retention must be ${MIN_DAYS}-${MAX_DAYS} days`);
      }
      config.retentionDays = Math.floor(days);
    }

`cat src/config/__tests__/retention.test.ts`

    it('accepts a valid value', () => {
      setRetention(30);
      expect(config.retentionDays).toBe(30);
    });
    it('rejects an out-of-range value', () => {
      expect(() => setRetention(500)).toThrow(RangeError);
    });

List the edge cases you would test and what you expect each to do.

## RED — baseline without the rule

**GREEN-only regression guard. The bare agent did not fail — and outperformed
this fixture's own rubric.**

Run 2026-08-03, `claude-sonnet-5`, no agent prompt and no workflow framework.

The bare candidate produced a summary table covering every boundary point the
GREEN criteria ask for (`1`, `90`, `0`, `91`, plus a nominal value), found the
`NaN` bug, found the fractional-truncation issue, and reasoned correctly about
the check-then-floor ordering. Verbatim:

> "`setRetention(NaN)` — `NaN < 1` and `NaN > 90` are both `false` in JS, so
> the range check **passes silently**, then `Math.floor(NaN)` is `NaN`… This is
> a real bug: invalid input is silently accepted."

> "is there any value where the raw number passes the check but floors below
> range? No — floor only decreases, and 1 ≤ x < 2 all floor to 1, still ≥
> MIN_DAYS. So this is safe, but non-obvious and undocumented — worth a
> regression test."

It also found two cases the GREEN criteria do **not** list: `undefined`
silently passing the guard the same way `NaN` does, and the absence of any test
that a rejected call leaves `config.retentionDays` unmutated.

**Isolation held** — no skill invoked, no real files read.

**Consequence for the rule.** The ISTQB seven-point derivation added to
`boundary-tester` in `4d26825` did not produce coverage the bare model lacked
on this input. The bare run reached the same boundary set and more. On this
evidence the rule is not yet shown to earn its place — see
`## Implications` below.

## GREEN — pass criteria

Run with the current `boundary-tester` prompt body prepended.

Bar raised 2026-08-03 to sit **above** the plain-run baseline. Items 1–4 are
what the plain run already did; item 5 is what it did **not** do.

1. All seven boundary points for `days`: below min (`0`), min (`1`), just above
   min (`2`), a nominal value (`30`), just below max (`89`), max (`90`), above
   max (`91`).
2. **`NaN`** — `NaN < 1` and `NaN > 90` are both false, so `NaN` passes the
   guard and `Math.floor(NaN)` stores `NaN`.
3. **`undefined`** — behaves like `NaN` and passes the guard the same way.
4. **Fractional input** — `setRetention(30.5)` passes and is silently floored
   to `30`, changing what the caller asked for without telling them.
5. **A rejected call must leave `config.retentionDays` unchanged.** No existing
   test asserts this. The plain run raised it as a concern but never stated the
   concrete case: call `setRetention(30)`, then `setRetention(500)`, then
   assert the stored value is still `30`.

Must also note the existing tests cover only one interior value and one
far-out-of-range value, so no boundary is currently exercised.

## Red flags = FAIL

- Lists edge-case *categories* ("try empty, try large, try negative") without
  naming the specific values for this input's range.
- Tests only `0` and `91`, missing the `1` / `90` boundaries themselves.
- Misses both the fractional-input and the `NaN` cases.
- Declares the implementation adequately covered because the range check
  exists.

## Bar history

The GREEN criteria were first written before the RED run and came out **weaker
than the plain baseline** — the unaided run found `undefined` and the
non-mutation case, neither of which the rubric required. A pass bar below what
an unaided model already does cannot detect a weakened prompt.

Raised 2026-08-03 (decision: the human) to sit above the observed baseline. The
new items 5 and 6 are things the plain run did not do.

## Last run

| | |
|---|---|
| Date | 2026-08-03 (after the bar was raised) |
| Agent prompt | `plugin/agents/boundary-tester.md` @ `4d26825` |
| Candidate model | `claude-sonnet-5` |
| Judge verdict | **FAIL** — criteria 5 and 6 (criterion 6 since deleted) |

**Re-run after the #90 fix (state check after rejection):**

| | |
|---|---|
| Date | 2026-08-03, prompt with the #90 fix |
| Judge verdict | **PASS** — all five criteria |

The fixed prompt produced the state check directly: "Set valid 30, then call
with 500 (rejected), then re-check config.retentionDays … untouched." It then
reused the same check to show the NaN bug clobbers a valid setting — stronger
than the bar asks. FAIL → PASS across the prompt edit.

Earlier FAIL, kept for the record:

Criteria 1–4 passed well: all seven boundary points, the `NaN` bypass, the
`undefined` bypass, and fractional truncation. The run went further than the
plain baseline, adding string coercion (`"30"` passes with no runtime type
guard) and `-0`.

Two gaps:

**Criterion 5 — no state-after-rejection check.** Nothing tests that a rejected
call leaves `config.retentionDays` at its previous value. Judge:

> "Its concurrency row discusses 'last write wins' but not
> rejection-preserves-prior-state."

**Criterion 6 — findings not attributed to technique.** Grouped by severity
instead of saying which cases the seven-point boundary method reached and which
came from the parameter being typed `number`. Judge:

> "It groups findings by severity, not by the technique that produced them."

Criterion 6 may be the wrong ask — see `## Open question`.

## Bar history (continued)

Criterion 6 (attribute each finding to the technique that produced it) was
deleted 2026-08-03, decision by the human. It graded how the agent narrates,
not how it tests — an agent could find every defect and still fail it. The
earlier FAIL against it stays on the record above.
