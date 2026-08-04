"""Tests for judge_checks.py — the mechanical half of the language judge.

Run: python3 tools/judge/test_judge_checks.py
Every case here traces to a misgrade documented in issue #127.
"""
import unittest

from judge_checks import (
    strip_non_prose,
    sentence_units,
    long_sentences,
    check_pr_body,
    grade_prose,
)

LONG = (
    "This sentence keeps going and going with word after word after word "
    "piled on so that the total count of words lands well past the limit "
    "of twenty five words in one sentence."
)
SHORT = "This one is short."


class StripNonProse(unittest.TestCase):
    def test_code_fence_removed(self):
        text = "Before.\n\n```python\n" + LONG + "\n```\n\nAfter."
        self.assertNotIn("going", strip_non_prose(text))

    def test_table_rows_removed(self):
        # Issue #127: round 1 on PR #123 counted fixture table rows as prose.
        text = "Intro.\n\n| a | b |\n|---|---|\n| " + LONG + " | x |\n"
        self.assertNotIn("going", strip_non_prose(text))

    def test_block_quotes_removed(self):
        # Issue #127: a verbatim 59-word quote was graded as a sentence.
        text = "Intro.\n\n> " + LONG + "\n"
        self.assertNotIn("going", strip_non_prose(text))

    def test_html_comments_removed(self):
        text = "Keep.\n<!-- 2 sentences max. -->\n"
        self.assertNotIn("sentences max", strip_non_prose(text))

    def test_frontmatter_removed(self):
        text = "---\ntitle: x\n---\nBody text."
        out = strip_non_prose(text)
        self.assertNotIn("title:", out)
        self.assertIn("Body text.", out)

    def test_backticked_span_is_one_token(self):
        # Identifier immunity: a long backticked name is one word, not many.
        text = "The `superpowers:subagent-driven-development` skill runs."
        units = sentence_units(strip_non_prose(text))
        self.assertEqual(len(units), 1)
        words = units[0].split()
        self.assertEqual(len(words), 4)

    def test_urls_do_not_inflate_counts(self):
        text = (
            "See https://example.com/a/very/long/path/that/would/count/"
            "as/many/words/if/split for details."
        )
        n = len(long_sentences(text, limit=5))
        self.assertEqual(n, 0)


class LongSentenceCheck(unittest.TestCase):
    def test_long_sentence_flagged(self):
        found = long_sentences("Intro. " + LONG)
        self.assertEqual(len(found), 1)
        self.assertGreater(found[0][0], 25)

    def test_short_sentences_pass(self):
        self.assertEqual(long_sentences("One. Two three. Four?"), [])

    def test_bullet_items_are_separate_units(self):
        text = "- first item.\n- second item.\n"
        self.assertEqual(long_sentences(text), [])

    def test_heading_marker_not_counted(self):
        self.assertEqual(long_sentences("## A heading line here"), [])

    def test_bold_terminated_sentence_still_splits(self):
        # "label.** Next sentence" must be two units, not one merged one.
        units = sentence_units(strip_non_prose("**A label.** Then a sentence."))
        self.assertEqual(len(units), 2)

    def test_wrapped_bullets_are_separate_units(self):
        # A hanging-indent continuation extends its bullet; the bullets
        # must not be joined into one giant unit.
        text = (
            "1. Classify:\n"
            "   - one short bullet that wraps to a\n"
            "     second line here.\n"
            "   - another short bullet.\n"
        )
        self.assertEqual(long_sentences(text, limit=15), [])


PR_BODY_GOOD = """## What changed

The judge verdict is now computed by a script. The model only recommends.

## Why

Five grading rounds on PR #126 flipped findings. A script cannot flip.

## Proof it works

12 unit tests pass; sample bodies below.

## What I need from you

Nothing — merge if it looks right.

Closes #127
"""

PR_BODY_OVER_BUDGET = PR_BODY_GOOD.replace(
    "The model only recommends.",
    "The model only recommends. Here is a third sentence. And a fourth one.",
)

PR_BODY_MISSING_SLOT = PR_BODY_GOOD.replace("## Why", "## Whatever")

PR_BODY_EMPTY_PROOF = PR_BODY_GOOD.replace(
    "12 unit tests pass; sample bodies below.",
    "<!-- Test output, eval verdict, or the words \"not tested\". -->",
)


class PrBodyChecks(unittest.TestCase):
    def test_good_body_passes(self):
        ok, findings = check_pr_body(PR_BODY_GOOD)
        self.assertTrue(ok, findings)

    def test_over_budget_slot_fails(self):
        ok, findings = check_pr_body(PR_BODY_OVER_BUDGET)
        self.assertFalse(ok)
        self.assertTrue(any("What changed" in f for f in findings))

    def test_missing_slot_fails(self):
        ok, findings = check_pr_body(PR_BODY_MISSING_SLOT)
        self.assertFalse(ok)
        self.assertTrue(any("Why" in f for f in findings))

    def test_empty_slot_fails(self):
        ok, findings = check_pr_body(PR_BODY_EMPTY_PROOF)
        self.assertFalse(ok)
        self.assertTrue(any("Proof it works" in f for f in findings))

    def test_not_tested_is_valid_proof(self):
        body = PR_BODY_GOOD.replace(
            "12 unit tests pass; sample bodies below.", "not tested"
        )
        ok, findings = check_pr_body(body)
        self.assertTrue(ok, findings)

    def test_long_sentence_in_body_fails(self):
        body = PR_BODY_GOOD.replace("A script cannot flip.", LONG)
        ok, findings = check_pr_body(body)
        self.assertFalse(ok)

    def test_two_sentences_not_counted_as_three(self):
        # Issue #127: the model twice counted 2 sentences as 3.
        ok, findings = check_pr_body(PR_BODY_GOOD)
        self.assertTrue(ok, findings)


class GradeProse(unittest.TestCase):
    def test_verdict_line_pass(self):
        report = grade_prose("All short sentences. Nothing to flag.")
        self.assertTrue(report.endswith("MECHANICAL: PASS"))

    def test_verdict_line_fail(self):
        report = grade_prose(LONG)
        self.assertTrue(report.endswith("MECHANICAL: FAIL"))


if __name__ == "__main__":
    unittest.main()
