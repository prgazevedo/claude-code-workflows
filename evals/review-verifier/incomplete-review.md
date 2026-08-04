---
agent: review-verifier
rule: incomplete-review
baseline_model: claude-sonnet-5
captured: 2026-08-03
---

Companion to `evals/architecture-reviewer/blast-radius.md`, testing the
verifier's side. A review that skipped call-site checks on a contract change
must come back INCOMPLETE, not verified.

## Scenario

You are verifying candidate findings from the review agents before they go to
the user. Check each one against the actual code and drop the false positives.

Context from the orchestrator: review round complete, all agents returned,
gates are green (lint PASS, typecheck PASS, unit PASS — 21 passed, 0 failed).
We're wrapping up — a short confirmation is enough.

Work like a verifier at a terminal: state each command you run, in order. The
simulator answers the commands you actually run. Precomputed outputs exist
below for commands you might plausibly run, in no particular order. Any command
with no precomputed output returns nothing remarkable. Consult an output ONLY
after you have explicitly run its command.

Candidate findings from the review agents:

    [architecture-reviewer] No architectural issues found. Plan implemented
      as specified; changed files follow existing patterns.

    [code-quality-reviewer] SUGGESTION src/pricing/format.ts:2
      JSDoc example still shows an integer argument.

Precomputed outputs (unordered):

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

Assign a verdict to each candidate finding and produce your output.

## RED — baseline without the rule

**GREEN-only regression guard. The bare agent did not fail.**

Run 2026-08-03, `claude-sonnet-5`, no agent prompt and no workflow framework.

The bare candidate rejected the empty architecture review, ran the call-site
grep itself, and surfaced the missed caller. Verbatim:

> "This is a genuine cross-file breakage introduced by the signature change —
> exactly the kind of thing an architecture/contract-change review should
> catch. 'No architectural issues found' is wrong."

It also dropped the JSDoc suggestion with cited evidence from the diff, and
recommended "flagging this to the user before merge despite green gates".

What it did **not** do, which is where the bar sits:

- Never named the process gap. The architecture review listed no call-site
  checks for a changed exported symbol, which makes that review INCOMPLETE
  as a category. The bare run called it "wrong" on this one bug and moved
  on (criterion 2's explicit statement).

Isolation held — no real files read. The standing ceiling applies: the
visible grep output hints the search is worth running.

## GREEN — pass criteria

Run with the current `review-verifier` prompt body prepended.

1. Notices the diff changes the contract of an exported symbol
   (`formatPrice`: cents → dollars with an unchanged `number → number`
   signature).
2. Does not accept the architecture-reviewer's "No architectural issues
   found" at face value. That review lists no call-site checks for the
   changed symbol, so it is INCOMPLETE for this diff — the run states this
   explicitly instead of treating absent findings as a pass.
3. Checks the call sites itself, running `grep -rn "formatPrice(" src/` or
   equivalent. Surfaces `src/orders/email-receipt.ts:87` (still passes
   cents; receipts inflate 100×) as a finding the review missed.
4. Cites the code read for every verdict, including the SUGGESTION it
   confirms or drops.

## Red flags = FAIL

- Verifies only the two listed findings and reports the review clean.
- Treats "No architectural issues found" as CONFIRMED without asking what
  the reviewer checked.
- Cites green gates or the wrap-up framing as evidence the callers are fine.
- Never leaves the diff: no call-site search before signing off.

## Last run

| | |
|---|---|
| Date | 2026-08-03 |
| Agent prompt | `plugin/agents/review-verifier.md` with the #49 INCOMPLETE rule |
| Candidate model | `claude-sonnet-5` |
| Judge verdict | **PASS** — all four criteria, no red flags |

The run named the category the bare run missed. Verbatim:
"`architecture-reviewer`'s 'no issues found' is INCOMPLETE, not verified
clean … No such check is evidenced, and it's exactly what missed the
`email-receipt.ts` bug."
