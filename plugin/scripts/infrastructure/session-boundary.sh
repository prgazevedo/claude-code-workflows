#!/bin/bash
# Copyright (C) 2026 azevedo-home-lab
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Session-boundary detection (#158 / #53 gaps 1+2).
# Workflow state is stamped with the session that wrote it. The first
# hook event of a DIFFERENT session downgrades autonomy=auto to ask —
# unattended autonomy must not outlive the session that armed it — and
# stamps the new id. Callers pass the raw hook input JSON.

[ -n "${_WFM_SESSION_BOUNDARY_LOADED:-}" ] && return 0
_WFM_SESSION_BOUNDARY_LOADED=1

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/infrastructure/state-io.sh"

# _check_session_boundary <hook-input-json>
# No-ops when: no state file, no session_id in the input (older Claude
# Code), or the id matches. Otherwise stamps the new id; if autonomy
# was auto, downgrades to ask and leaves a notice for the coach.
_check_session_boundary() {
    local input="$1"
    [ -f "$STATE_FILE" ] || return 0

    local incoming stored
    incoming=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null) || incoming=""
    [ -n "$incoming" ] || return 0

    stored=$(jq -r '.session_id // ""' "$STATE_FILE" 2>/dev/null) || stored=""

    if [ -z "$stored" ]; then
        _update_state '.session_id = $sid' --arg sid "$incoming"
        return 0
    fi
    [ "$stored" = "$incoming" ] && return 0

    local autonomy
    autonomy=$(jq -r '.autonomy_level // "off"' "$STATE_FILE" 2>/dev/null) || autonomy="off"
    if [ "$autonomy" = "auto" ]; then
        _update_state '.session_id = $sid
            | .autonomy_level = "ask"
            | .session_boundary_notice = "autonomy was auto in a previous session; downgraded to ask at the session boundary (#158). Re-arm deliberately with /autonomy auto."' \
            --arg sid "$incoming"
        _log "[WFM session] new session: auto downgraded to ask"
    else
        _update_state '.session_id = $sid' --arg sid "$incoming"
        _log "[WFM session] new session stamped"
    fi
    return 0
}
