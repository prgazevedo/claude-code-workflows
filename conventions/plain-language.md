# Plain Language Rules

**Version:** 1.9.0
**Scope:** All AI-authored text in `azevedo-home-lab` repos: PR bodies, issue
bodies, summaries, doc prose, chat replies. Approved 2026-08-03 (issue #92).

The glossary bans words. This file fixes shape. They are different problems:
text can be pure jargon while containing zero banned words.

Three parts: the recipe (the standard), the templates (inserted
mechanically), and the judge (a check that can fail a draft).

## The recipe

**The standard: a tired reader who reads it once.**

1. **Lead with the answer.** The first sentence is the result or the
   question; verdict before evidence, everywhere.
2. **One idea per sentence.** A sentence needing a second comma usually
   wants splitting.
3. **Never invent a name.** Say the thing in existing words. If a real name
   exists (OWASP, SemVer), use it.
4. **A number or example beats an adjective.** Not "significantly better" —
   "went from FAIL to PASS".
5. **Choose the common word.** "Kept growing", not "grew by accretion".
   If a plainer word says the same thing, use it.

## The templates

`.github/PULL_REQUEST_TEMPLATE.md` and `.github/ISSUE_TEMPLATE/` carry four
required slots that GitHub inserts automatically.

| Slot | Budget |
|---|---|
| What changed | 2 sentences |
| Why | 2 sentences |
| Proof it works | test output, eval verdict, or the words "not tested" |
| What I need from you | a decision, or "nothing — merge if it looks right" |

Detail beyond the budgets goes under a `<details>` fold or in a linked doc,
never in the main body.

**Features and epics use the Requirement template**
(`.github/ISSUE_TEMPLATE/requirement.md`). Its slots: Context (4
sentences), Goal (2), Acceptance Criteria (8 bullets), Scope in/out,
optional Open questions and Dependencies. Tasks and Bugs keep the
forms above. A reader test on the same content in both shapes decided
this rule (#128, 2026-08-04). Readers of the old shape invented the
scope boundaries; readers of the Requirement shape reproduced the
author's intent. Never leave "Scope: out" empty — it is the section
the old shape lost.

**The Feature judge.** Before filing a Feature issue, run
`tools/judge/precheck.sh <draft> --feature`. It runs the prose
mechanics plus six content checks from the pinned prompt
`tools/judge/feature-checks-prompt.txt`: clear, concise, focused,
actionable, and the two halves of safe. "Safe" was defined by the
human on 2026-08-04 as both halves at once. **Secret hygiene**: no
credential values, tokens, or keys in the body — names and RFC1918
addresses are fine. **Impact awareness**: the body names the existing
behavior the change touches, or says it touches none. The judge is
calibrated per #129's method
(`tools/judge/feature-calibration/RESULTS.md`); editing its prompt
means re-running that calibration. Like every judge here, it
recommends — the human is the final arbiter.

## The judge

The judge has two halves with different powers (issue #127: model
findings flipped across rounds on identical text, so verdicts moved to
arithmetic).

**Mechanical half — the only source of FAIL.** The script
`tools/judge/judge_checks.py` (canonical copy: `claude-code-workflows`)
computes slot presence, slot sentence budgets, and per-sentence word
counts. It skips code fences, tables, block quotes, HTML comments, and
frontmatter; backticked spans and URLs count as one word. Its last line
is `MECHANICAL: PASS` or `MECHANICAL: FAIL`, and that is the verdict.
The same text always gets the same verdict.

**Model half — recommendations only.** A model reads the draft with the
pinned prompt `tools/judge/model-checks-prompt.txt` for the judgment
checks. Those are: do the first two sentences carry the point; any
invented term; any adjective doing a number's job. Three rules bind the
model. Backticked text, file paths, and `namespace:name` tokens are
identifiers, never invented terms. Wording the previous round suggested
or accepted is not re-flagged. Length and formatting are not quality;
temperature 0. The model never outputs a verdict.

**Calibration.** `tools/judge/calibrate.py` runs a labeled set of
drafts — each bad one violating exactly one check — through both
halves, three times per draft. Editing the pinned prompt or the
counting script means re-running it and committing the refreshed
`tools/judge/calibration/RESULTS.md`. Switching the judge model means
the same, because a prompt calibrated on one model does not transfer
(#129). The results file records the model choice and per-check flip
counts.

**The pre-check.** Run `tools/judge/precheck.sh <draft> [--pr-body]`
on every draft PR or issue body before it reaches GitHub. It runs the
script, plus the model checks when `ANTHROPIC_API_KEY` is set. It
prints a trace line — `Local judge: PASS (claude-haiku-4-5,
2026-08-04)` — to paste into the body's "Proof it works" slot. CI then
confirms instead of discovering.

The human is the final arbiter. The AI never overrules the judge: it
records its disagreement with evidence and leaves the verdict standing.
Any merge over a FAIL is logged as the AI's own call, awaiting the human.

**The rewrite budget: two patches, then redo from scratch.** After two
rewrites and a third FAIL, stop patching sentences. Rewrite the whole
text from scratch in plain words; that resets the budget once. Evidence:
PR #126 failed five rounds of patching and passed in one round after a
full rewrite. If the from-scratch version still fails, post it and note
the failing checks — do not loop.

## Decision questions

The interactive question tool invites the exact failure the working
agreement bans: option cards that feel like an analysis while holding none.

1. **Prose first, menu second.** Give the full explanation in prose — what
   was checked, what was found, what each option costs — with every
   technical term explained. The cards summarize; they never replace.
2. **A question in reply cancels the menu.** If the human answers a menu
   with a question or a complaint, answer it completely in prose and stop.
   Do not re-present the menu in the same turn. The human decides in their
   own words.
3. **The test:** could a tired reader who saw only the prose, never the
   menu, make the decision? If not, the menu is premature.
4. **The judge gates the menu.** Before presenting a decision menu, run the
   judge on the draft prose. Rewrite on FAIL, as for a PR body. On PASS,
   record it: `workflow-cmd.sh set_chat_judge_passed true`. The
   workflow-manager plugin refuses the menu until that flag is set, and
   clears it after each menu (#124).

## Chat replies

Chat has no template; the recipe and the decision-question rules still
apply. Decision menus are judge-gated since 1.5.0 (#124) — the first
enforcement extension, made after chat drifted twice on 2026-08-04. If
drift continues, the next step is a real judge model on the menu text
itself, not more prose rules.
