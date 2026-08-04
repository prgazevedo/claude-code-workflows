#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Attempt log — append-only ledger of fix attempts (#45).
# Lives at the TOP LEVEL of workflow state (.attempt_log), deliberately outside
# the phase sections: reset_review_status and friends replace their whole
# section, and the log must survive review loop-backs. Fresh subagents have no
# memory of earlier attempts; this log is that memory.

[ -n "${_WFM_ATTEMPT_LOG_LOADED:-}" ] && return 0
_WFM_ATTEMPT_LOG_LOADED=1

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/infrastructure/state-io.sh"

# Append one attempt row. Never rewrites earlier rows.
# Usage: log_attempt <verdict> <signature> [what-changed]
#   verdict:   PASS | FAIL | result of the verify/review pass
#   signature: failing test name(s) for test failures; file:rule for findings
#   what-changed: what this fix pass changed since the previous attempt
log_attempt() {
    local verdict="${1:-}" signature="${2:-}" changed="${3:-}"
    if [ ! -f "$STATE_FILE" ]; then return; fi
    if [ -z "$verdict" ] || [ -z "$signature" ]; then
        echo "ERROR: usage: log_attempt <verdict> <signature> [what-changed]" >&2
        return 1
    fi
    _show "[WFM state] APPEND attempt_log: $verdict · $signature"
    _update_state '.attempt_log = ((.attempt_log // []) + [{
            n: (((.attempt_log // []) | length) + 1),
            at: $ts, verdict: $v, signature: $s, changed: $c
        }])' \
        --arg v "$verdict" --arg s "$signature" --arg c "$changed" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# Print the log, one row per attempt: n · verdict · signature · what-changed
get_attempt_log() {
    if [ ! -f "$STATE_FILE" ]; then echo "no attempts logged"; return; fi
    local rows
    rows=$(jq -r '(.attempt_log // [])[]
        | "\(.n) · \(.verdict) · \(.signature) · \(.changed)"' \
        "$STATE_FILE" 2>/dev/null) || rows=""
    if [ -z "$rows" ]; then echo "no attempts logged"; else echo "$rows"; fi
}

# How many of the most recent attempts share the newest signature (consecutive).
# 3 means: stop — a fourth identical attempt carries no new information.
count_repeated_signature() {
    if [ ! -f "$STATE_FILE" ]; then echo 0; return; fi
    local count
    count=$(jq -r '(.attempt_log // []) | map(.signature) | reverse
        | if length == 0 then 0
          else .[0] as $last | ([.[] | . == $last] | index(false) // length)
          end' "$STATE_FILE" 2>/dev/null) || count=0
    echo "$count"
}
