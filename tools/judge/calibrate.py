#!/usr/bin/env python3
"""Calibration runner for the language judge (issue #129).

Runs every draft in calibration/manifest.json through both judge halves:
  - mechanical (judge_checks.py, deterministic) — expected verdict must match;
  - model (model-checks-prompt.txt, RUNS repeats at temperature 0) — expected
    flags must appear in every run; per-check flip rate is reported.

Editing model-checks-prompt.txt or judge_checks.py requires re-running
this and committing the refreshed calibration/RESULTS.md.

Usage: ANTHROPIC_API_KEY=... python3 tools/judge/calibrate.py \
    [--model claude-haiku-4-5] [--prompt model-checks-prompt.txt] \
    [--dir calibration]

The manifest may carry a "checks" list naming the CHECK-* tokens the
prompt emits; the default is the language judge's three.
"""
import datetime
import json
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from judge_checks import check_pr_body, grade_prose  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = 3
DEFAULT_CHECKS = ("OPENING", "TERMS", "ADJECTIVES")


def call_model(model, system, text):
    body = json.dumps({
        "model": model,
        "max_tokens": 1024,
        "temperature": 0,
        "system": system,
        "messages": [{"role": "user", "content": text}],
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
    with urllib.request.urlopen(req) as r:
        resp = json.load(r)
    return "".join(
        b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text"
    )


def parse_flags(output, checks):
    """Return the set of checks the model flagged."""
    flags = set()
    for check in checks:
        m = re.search(r"CHECK-%s:\s*(OK|FLAG)" % check, output)
        if m and m.group(1) == "FLAG":
            flags.add(check)
    return flags


def main():
    model = "claude-haiku-4-5"
    prompt_file = "model-checks-prompt.txt"
    cal_dir = "calibration"
    if "--model" in sys.argv:
        model = sys.argv[sys.argv.index("--model") + 1]
    if "--prompt" in sys.argv:
        prompt_file = sys.argv[sys.argv.index("--prompt") + 1]
    if "--dir" in sys.argv:
        cal_dir = sys.argv[sys.argv.index("--dir") + 1]
    if "ANTHROPIC_API_KEY" not in os.environ:
        sys.exit("ANTHROPIC_API_KEY not set")

    system = open(os.path.join(HERE, prompt_file)).read()
    manifest = json.load(open(os.path.join(HERE, cal_dir, "manifest.json")))
    checks = tuple(manifest.get("checks", DEFAULT_CHECKS))
    failures = []
    rows = []
    flips = {c: 0 for c in checks}

    for d in manifest["drafts"]:
        text = open(os.path.join(HERE, cal_dir, d["file"])).read()

        if d["mode"] == "pr-body":
            ok, _ = check_pr_body(text)
            verdict = "PASS" if ok else "FAIL"
        else:
            verdict = "FAIL" if grade_prose(text).endswith("FAIL") else "PASS"
        mech_ok = verdict == d["expect_mechanical"]
        if not mech_ok:
            failures.append(
                "%s: mechanical %s, expected %s" % (d["file"], verdict, d["expect_mechanical"])
            )

        if d["expect_flags"] is None:
            # Mechanical-half draft: the model's opinion is not asserted.
            flags_col, want_col, model_ok = "(not asserted)", "-", True
        else:
            run_flags = [
                parse_flags(call_model(model, system, text), checks)
                for _ in range(RUNS)
            ]
            expected = set(d["expect_flags"])
            if d.get("match") == "subset":
                # Correlated checks may co-flag (a vague goal is also
                # untestable); the target check must appear every run.
                model_ok = all(expected <= f for f in run_flags)
            else:
                model_ok = all(f == expected for f in run_flags)
            for c in checks:
                seen = [c in f for f in run_flags]
                if any(seen) and not all(seen):
                    flips[c] += 1
            if not model_ok:
                failures.append(
                    "%s: model flags %s across %d runs, expected %s"
                    % (d["file"], [sorted(f) for f in run_flags], RUNS, sorted(expected))
                )
            flags_col = " / ".join(",".join(sorted(f)) or "-" for f in run_flags)
            want_col = ",".join(sorted(expected)) or "-"
        rows.append(
            "| %s | %s (want %s) | %s (want %s) | %s |"
            % (
                d["file"],
                verdict,
                d["expect_mechanical"],
                flags_col,
                want_col,
                "ok" if (mech_ok and model_ok) else "MISMATCH",
            )
        )

    today = datetime.date.today().isoformat()
    status = "PASS" if not failures else "FAIL"
    report = [
        "# Calibration results",
        "",
        "Generated by `tools/judge/calibrate.py` — do not edit by hand.",
        "",
        "- Date: %s" % today,
        "- Model: %s (temperature 0, %d runs per draft)" % (model, RUNS),
        "- Prompt: %s" % prompt_file,
        "- Status: **%s**" % status,
        "- Per-check flip count (drafts where a check changed its answer between runs):",
        "  - " + ", ".join("%s: %d" % (c, flips[c]) for c in checks),
        "",
        "| Draft | Mechanical | Model flags per run | Result |",
        "|---|---|---|---|",
    ] + rows
    if failures:
        report += ["", "## Failures", ""] + ["- " + f for f in failures]
    out = os.path.join(HERE, cal_dir, "RESULTS.md")
    open(out, "w").write("\n".join(report) + "\n")
    print("\n".join(report))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
