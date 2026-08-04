#!/usr/bin/env python3
"""Mechanical checks for the language judge (issue #127).

This script is the only source of a FAIL verdict. The model half of the
judge produces recommendations and has no verdict power
(conventions/plain-language.md § The judge).

Used in two places with identical behavior:
  - CI: .github/workflows/language-judge.yml
  - locally, before posting a PR or issue body (the pre-check)

Modes:
  judge_checks.py --pr-body FILE   slot presence + budgets + sentence length
  judge_checks.py --prose FILE     sentence length only (issue bodies, docs)

Output: findings, then a final line "MECHANICAL: PASS" or "MECHANICAL: FAIL".
Exit code 0 on PASS, 1 on FAIL.
"""
import re
import sys

WORD_LIMIT = 25

# PR template slots: heading -> sentence budget (None = presence only)
SLOTS = [
    ("What changed", 2),
    ("Why", 2),
    ("Proof it works", None),
    ("What I need from you", None),
]

_MARKER = re.compile(r"^\s*([#>*-]|\d+\.)\s*")


def strip_non_prose(text):
    """Remove everything sentence rules do not apply to.

    Code fences, HTML comments, YAML frontmatter, table rows, block
    quotes. Backticked spans collapse to one token (identifiers are
    names, not prose); URLs collapse to one token.
    """
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"```.*\Z", "", text, flags=re.S)  # unclosed fence
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = text.replace("**", "")  # bold is formatting; ".**" must still end a sentence
    text = re.sub(r"`[^`\n]+`", "IDENT", text)
    text = re.sub(r"https?://\S+", "URL", text)
    kept = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(">"):
            continue  # block quote: verbatim material, not the author's prose
        if stripped.startswith("|") or re.match(r"^\|?[\s:|-]+\|", stripped):
            continue  # table row or separator
        kept.append(line)
    return "\n".join(kept)


def sentence_units(prose):
    """Split stripped prose into sentence units.

    Paragraphs of marker lines (bullets, numbered items, headings) count
    per line; ordinary paragraphs are joined then split on terminators.
    """
    units = []
    for para in re.split(r"\n\s*\n", prose):
        lines = [l for l in para.splitlines() if l.strip()]
        if not lines:
            continue
        if _MARKER.match(lines[0]):
            # List-like paragraph: a marker line starts a unit; an
            # indented continuation line extends the current bullet.
            pieces = []
            for l in lines:
                if _MARKER.match(l):
                    pieces.append(_MARKER.sub("", l).strip())
                elif pieces:
                    pieces[-1] += " " + l.strip()
                else:
                    pieces.append(l.strip())
        else:
            pieces = [" ".join(l.strip() for l in lines)]
        for piece in pieces:
            for sent in re.split(r"(?<=[.!?])\s+", piece):
                words = [w for w in sent.split() if re.search(r"[A-Za-z0-9]", w)]
                if words:
                    units.append(" ".join(w for w in sent.split()))
    return units


def _word_count(sentence):
    return len([w for w in sentence.split() if re.search(r"[A-Za-z0-9]", w)])


def long_sentences(text, limit=WORD_LIMIT):
    """Return (word_count, sentence) for every sentence over the limit."""
    out = []
    for unit in sentence_units(strip_non_prose(text)):
        # A heading is a label, not a sentence.
        n = _word_count(unit)
        if n > limit:
            out.append((n, unit[:200]))
    return out


def _split_slots(body):
    """Return {heading: content} for ## headings in a PR body."""
    slots = {}
    current = None
    for line in body.splitlines():
        m = re.match(r"^##\s+(.*)$", line)
        if m:
            current = m.group(1).strip()
            slots[current] = []
        elif current is not None:
            slots[current].append(line)
    return {k: "\n".join(v) for k, v in slots.items()}


def check_pr_body(body):
    """Slot presence, sentence budgets, and sentence length for a PR body.

    Returns (ok, findings).
    """
    findings = []
    slots = _split_slots(body)
    for heading, budget in SLOTS:
        if heading not in slots:
            findings.append('missing slot: "## %s"' % heading)
            continue
        content = re.sub(r"^Closes #\d+\s*$", "", slots[heading], flags=re.M)
        units = sentence_units(strip_non_prose(content))
        if not units:
            findings.append('empty slot: "## %s"' % heading)
        elif budget is not None and len(units) > budget:
            findings.append(
                'slot "## %s" over budget: %d sentence units, budget %d'
                % (heading, len(units), budget)
            )
    for n, sent in long_sentences(body):
        findings.append('sentence over %d words (%d): "%s"' % (WORD_LIMIT, n, sent))
    return (not findings, findings)


def grade_prose(text):
    """Sentence-length-only report ending in the verdict line."""
    lines = []
    found = long_sentences(text)
    for n, sent in found:
        lines.append('- sentence over %d words (%d): "%s"' % (WORD_LIMIT, n, sent))
    if not lines:
        lines.append("(no sentences over %d words)" % WORD_LIMIT)
    lines.append("MECHANICAL: FAIL" if found else "MECHANICAL: PASS")
    return "\n".join(lines)


def main(argv):
    if len(argv) != 3 or argv[1] not in ("--pr-body", "--prose"):
        print(__doc__)
        return 2
    text = open(argv[2]).read()
    if argv[1] == "--prose":
        report = grade_prose(text)
        print(report)
        return 1 if report.endswith("FAIL") else 0
    ok, findings = check_pr_body(text)
    for f in findings:
        print("- " + f)
    if ok:
        print("(all slots present and inside budget; no long sentences)")
    print("MECHANICAL: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
