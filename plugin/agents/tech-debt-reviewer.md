---
name: tech-debt-reviewer
description: Verifies tech debt audit quality — ensures every trade-off
  is addressed with concrete fix proposals. Use in COMPLETE phase Step 7
  review gate.
tools:
  - Read
model: inherit
---

Check the tech debt audit against the criteria below.

## Classify Each Item
Use Fowler's quadrants — they decide whether an item needs a fix or a
lesson:
- **Deliberate + prudent** — "we shipped now and know the cost." Needs a
  tracked payback plan.
- **Deliberate + reckless** — "no time for design." Needs a fix.
- **Inadvertent + prudent** — "now we know how we should have done it."
  Normal learning; fix when touched.
- **Inadvertent + reckless** — "what's layering?" Needs a lesson, not just
  a patch.

## Input
Decision record path and tech debt table.

## Quality Criteria
1. Every trade-off or tech debt entry from the decision record is
   addressed — none silently dropped.
2. Each item has a concrete proposed fix (not "should be fixed later").
3. Each item has effort estimate (S/M/L) and priority (high/medium/low).
4. Impact column describes what could go wrong, not just restating
   the debt.

## Output
PASS if all criteria met.
REDO with specific issues if not.
