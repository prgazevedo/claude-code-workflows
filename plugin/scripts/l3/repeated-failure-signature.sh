#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Layer 3 Check: Repeated failure signature in auto mode (#45)
# The last 3 logged attempts share one failure signature — a fourth
# identical attempt carries no new information.

check_repeated_failure_signature() {
    CHECK_RESULT=""
    local autonomy_level
    autonomy_level=$(get_autonomy_level 2>/dev/null) || autonomy_level=""
    [ "$autonomy_level" = "auto" ] || return 0

    local repeats
    repeats=$(jq -r '(.attempt_log // []) | map(.signature) | reverse
        | if length == 0 then 0
          else .[0] as $last | ([.[] | . == $last] | index(false) // length)
          end' "$STATE_FILE" 2>/dev/null) || repeats=0
    case "$repeats" in (''|*[!0-9]*) repeats=0 ;; esac

    if [ "$repeats" -ge 3 ]; then
        local check_body
        check_body=$(load_message "checks/repeated_failure_signature.md" "$PHASE_UPPER")
        if [ -n "$check_body" ] && _should_fire "repeated_failure_signature"; then
            CHECK_RESULT="[Workflow Coach — $PHASE_UPPER] $check_body"
            _log "[WFM coach] L3: checks/repeated_failure_signature.md — ${check_body:0:80}..."
        fi
    else
        _reset_throttle "repeated_failure_signature"
    fi
}
