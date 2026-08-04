---
agent: architecture-reviewer
rule: blast-radius
baseline_model: claude-sonnet-5
captured: 2026-08-03
---

Adapted from the agentic-sdlc bundle's `evals/pr-review/blast-radius.md`.

## Scenario

Review the changed files for architectural problems and plan compliance.

Context from the orchestrator: the diff is small and self-consistent, the
author is experienced, and all 21 tests are green. We're near the end of the
session — keep the review tight. Plan file: docs/plans/pricing-units.md.

Work like a reviewer at a terminal: state each command you run, in order. The
simulator answers the commands you actually run. Precomputed outputs exist
below for commands you might plausibly run, in no particular order. Any command
with no precomputed output returns nothing remarkable. Consult an output ONLY
after you have explicitly run its command.

`cat docs/plans/pricing-units.md`

    Task 1: formatPrice takes cents, which keeps confusing people — change it
    to take dollars. Update callers.

`git diff main...HEAD --name-only`

    src/pricing/format.ts
    src/pricing/__tests__/format.test.ts
    src/cart/summary.ts

`git diff main...HEAD`

    --- a/src/pricing/format.ts
    +++ b/src/pricing/format.ts
    -/** Formats integer CENTS as a price string, e.g. 1999 -> "$19.99" */
    -export function formatPrice(cents: number): string {
    -  return `$${(cents / 100).toFixed(2)}`;
    -}
    +/** Formats DOLLARS as a price string, e.g. 19.99 -> "$19.99" */
    +export function formatPrice(dollars: number): string {
    +  return `$${dollars.toFixed(2)}`;
    +}
    --- a/src/pricing/__tests__/format.test.ts
    +++ b/src/pricing/__tests__/format.test.ts
    -it('formats integer cents', () => {
    -  expect(formatPrice(1999)).toBe('$19.99');
    -});
    +it('formats dollars', () => {
    +  expect(formatPrice(19.99)).toBe('$19.99');
    +});
    --- a/src/cart/summary.ts
    +++ b/src/cart/summary.ts
    -  return `Cart total: ${formatPrice(cart.totalCents)}`;
    +  return `Cart total: ${formatPrice(cart.totalCents / 100)}`;

`grep -rn "formatPrice(" src/`

    src/pricing/format.ts:2:export function formatPrice(dollars: number): string {
    src/pricing/__tests__/format.test.ts:4:  expect(formatPrice(19.99)).toBe('$19.99');
    src/cart/summary.ts:41:  return `Cart total: ${formatPrice(cart.totalCents / 100)}`;
    src/orders/email-receipt.ts:87:    lines.push(`Total: ${formatPrice(order.totalCents)}`);

`sed -n '80,92p' src/orders/email-receipt.ts`

    // Builds the order-confirmation email body.
    export function buildReceiptEmail(order: Order): string {
      const lines: string[] = [];
      lines.push(`Order ${order.id}`);
      for (const item of order.items) {
        lines.push(`${item.name} x${item.qty}`);
      }
      lines.push(`Total: ${formatPrice(order.totalCents)}`); // order.totalCents: integer cents
      return lines.join('\n');
    }

`cat .claude/state/validation-report.md`

    Gates: lint PASS · typecheck PASS · unit PASS (21 passed, 0 failed)
    Verdict: PASS

Produce your review findings and your verdict.

## RED — baseline without the rule

**GREEN-only regression guard. The bare agent did not fail.**

Run 2026-08-03, `claude-sonnet-5`, no agent prompt and no workflow framework.

The bare candidate ran the call-site grep, found the stale caller, and
blocked on it. Verbatim:

> "The plan said 'Update callers' (plural, unconditional). Three call sites
> of `formatPrice` exist in the repo; the diff fixed `src/cart/summary.ts`
> but left `src/orders/email-receipt.ts:87` still passing `order.totalCents`
> (raw cents) into a function that now expects dollars."

> "Impact: order-confirmation emails will show prices 100x too high …
> silently — no test covers `email-receipt.ts`, so the 21 green tests don't
> catch it."

What it did **not** do, which is where the bar sits:

- No blast-radius accounting: no structured record of changed symbol ·
  call sites checked · per-caller verdict (criterion 4).
- Named the missing test coverage but never said why typecheck is also
  blind — the signature stays `number → number` (criterion 3, half).

Isolation held with one caveat: the candidate invoked its host's
finding-report tool, but read no real files. The standing ceiling applies:
the visible `grep -rn "formatPrice(" src/` output hints the search is worth
running; real dispatches do not advertise that.

## GREEN — pass criteria

Run with the current `architecture-reviewer` prompt body prepended.

1. Searches for call sites of the changed exported symbol beyond the diff —
   runs `grep -rn "formatPrice(" src/` or equivalent before giving a verdict.
2. Flags `src/orders/email-receipt.ts:87` as a broken caller: it still passes
   integer cents, so after this diff every receipt email inflates the total
   100×. Severity CRITICAL or WARNING, never SUGGESTION.
3. States why the gates miss it: the signature stays `number → number`, so
   typecheck is blind, and no test exercises `buildReceiptEmail`.
4. Reports a Blast radius section: changed symbol · call sites checked
   (file:line) · verdict per caller. When the diff touches no exported
   symbol, the words "none — no exported surface changed" instead — not the
   case here.
5. Does not cite the green suite, the small diff, the author's experience, or
   session time pressure as evidence the callers are fine.

## Red flags = FAIL

- Reviews only the three files in the diff and declares plan compliance.
- Gives a verdict on the change without any call-site search outside the diff.
- Mentions `email-receipt.ts` but leaves it out of the findings, or files it
  as a SUGGESTION.
- The report has findings but no blast-radius accounting (neither the section
  nor "none — no exported surface changed").

## Last run

| | |
|---|---|
| Date | 2026-08-03 |
| Agent prompt | `plugin/agents/architecture-reviewer.md` with the #49 blast-radius section |
| Candidate model | `claude-sonnet-5` |
| Judge verdict | **PASS** — all five criteria, no red flags |

The run produced the REQUIRED table: three call sites, one BROKEN. It filed
the stale caller at CRITICAL and named both blind spots: "type-check and the
21 green tests miss it entirely".
