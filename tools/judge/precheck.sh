#!/bin/sh
# Local pre-check for PR and issue bodies (issue #129).
#
# Runs the mechanical judge, and the model checks when ANTHROPIC_API_KEY
# is set. Prints the trace line to paste into the body's "Proof it works"
# slot, e.g.:  Local judge: PASS (claude-haiku-4-5, 2026-08-04)
#
# Usage: tools/judge/precheck.sh <file> [--pr-body|--prose|--feature]
# --feature grades a draft Feature issue body: prose mechanics plus the
# six content checks from feature-checks-prompt.txt (#128).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FILE=$1
MODE=${2:---pr-body}
[ -f "$FILE" ] || { echo "usage: precheck.sh <file> [--pr-body|--prose|--feature]" >&2; exit 2; }

MODEL=claude-haiku-4-5
PROMPT_FILE="$HERE/model-checks-prompt.txt"
MECH_MODE="$MODE"
if [ "$MODE" = "--feature" ]; then
  PROMPT_FILE="$HERE/feature-checks-prompt.txt"
  MECH_MODE="--prose"
fi
if python3 "$HERE/judge_checks.py" "$MECH_MODE" "$FILE"; then
  VERDICT=PASS
else
  VERDICT=FAIL
fi

if [ -n "$ANTHROPIC_API_KEY" ]; then
  python3 - "$FILE" "$PROMPT_FILE" "$MODEL" <<'PY'
import json, os, sys, urllib.request
file, prompt_file, model = sys.argv[1:4]
body = json.dumps({
    "model": model,
    "max_tokens": 1024,
    "temperature": 0,
    "system": open(prompt_file).read(),
    "messages": [{"role": "user", "content": open(file).read()}],
}).encode()
req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages", data=body,
    headers={"content-type": "application/json",
             "x-api-key": os.environ["ANTHROPIC_API_KEY"],
             "anthropic-version": "2023-06-01"})
with urllib.request.urlopen(req) as r:
    resp = json.load(r)
print("".join(b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text"))
PY
else
  echo "(model checks skipped — ANTHROPIC_API_KEY not set)"
fi

echo
echo "Local judge: $VERDICT ($MODEL, $(date +%F))"
[ "$VERDICT" = PASS ]
