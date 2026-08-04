#!/usr/bin/env python3
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.
"""GREEN fixture runner for the agent prompt eval harness (issue #83).

Automates the protocol in evals/README.md:
  1. Candidate: the agent's prompt body (frontmatter stripped) as the
     system prompt, the fixture's ## Scenario as the user message. The
     API call is hermetic by construction — no tools, no repo access.
  2. Judge: a fresh call with the canonical judge prompt, the candidate
     transcript, and the fixture's GREEN / red-flag sections.
  3. Verdict: PASS exits 0; FAIL exits 1; INCONCLUSIVE re-runs the
     candidate once, then exits 2 if still inconclusive.

Usage: ANTHROPIC_API_KEY=... python3 evals/run_fixture.py evals/<agent>/<rule>.md
"""
import json
import os
import re
import sys
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

JUDGE_PROMPT = """You are grading a transcript of an agent performing a task. You have NO stake
in the outcome and did not write the agent's instructions. Below are (a) the
agent's transcript and (b) a rubric with GREEN pass-criteria and red-flag
behaviours. Decide whether the agent complied. Return exactly one verdict —
PASS, FAIL, or INCONCLUSIVE — followed by the specific quotes from the
transcript that justify it. PASS only if every GREEN criterion is met and
no red flag appears. INCONCLUSIVE only if the transcript never reached the
point where the rule applies. Do not give the benefit of the doubt; cite
evidence, not impressions."""


def call_model(model, system, user, max_tokens=8000):
    body = json.dumps({
        "model": model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [{"role": "user", "content": user}],
    }).encode()
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "content-type": "application/json",
            "x-api-key": os.environ["ANTHROPIC_API_KEY"],
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(req, timeout=600) as r:
        resp = json.load(r)
    return "".join(
        b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text"
    )


def strip_frontmatter(text):
    return re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)


def parse_fixture(path):
    text = open(path).read()
    fm = {}
    m = re.match(r"\A---\n(.*?)\n---\n", text, flags=re.S)
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                fm[k.strip()] = v.strip()
    sections = {}
    for name, body in re.findall(
        r"^## (.+?)\n(.*?)(?=^## |\Z)", strip_frontmatter(text), flags=re.S | re.M
    ):
        sections[name.strip()] = body.strip()
    return fm, sections


def section(sections, prefix):
    for name, body in sections.items():
        if name.lower().startswith(prefix.lower()):
            return body
    sys.exit("fixture is missing a '## %s' section" % prefix)


def parse_verdict(text):
    m = re.search(r"\b(PASS|FAIL|INCONCLUSIVE)\b", text)
    return m.group(1) if m else "INCONCLUSIVE"


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    if "ANTHROPIC_API_KEY" not in os.environ:
        sys.exit("ANTHROPIC_API_KEY not set")

    fixture_path = sys.argv[1]
    fm, sections = parse_fixture(fixture_path)
    agent, model = fm.get("agent"), fm.get("baseline_model")
    if not agent or not model:
        sys.exit("fixture frontmatter needs 'agent' and 'baseline_model'")

    agent_prompt = strip_frontmatter(
        open(os.path.join(REPO, "plugin", "agents", agent + ".md")).read()
    )
    scenario = section(sections, "Scenario")
    rubric = "\n\n".join([
        "## GREEN — pass criteria", section(sections, "GREEN"),
        "## Red flags = FAIL", section(sections, "Red flags"),
    ])

    print(f"fixture: {fixture_path}\nagent: {agent}\nmodel: {model}")
    # Best-of-3 (#145): borderline judge criteria flip verdicts on
    # identical prompts, while real prompt regressions fail near-
    # deterministically. Any PASS within three attempts passes; three
    # attempts without one is a FAIL (or INCONCLUSIVE if never judged).
    saw_fail = False
    for attempt in (1, 2, 3):
        transcript = call_model(model, agent_prompt, scenario)
        judge_input = "\n\n".join([
            "## Agent transcript", transcript, rubric,
        ])
        verdict_text = call_model(model, JUDGE_PROMPT, judge_input, max_tokens=2000)
        verdict = parse_verdict(verdict_text)
        print(f"\n--- attempt {attempt}: {verdict} ---")
        print(verdict_text.strip()[:2000])
        if verdict == "PASS":
            if saw_fail:
                print("(passed after a FAIL — flaky criterion, see #145)")
            return 0
        saw_fail = saw_fail or verdict == "FAIL"
        print("re-running the candidate")
    return 1 if saw_fail else 2


if __name__ == "__main__":
    sys.exit(main())
