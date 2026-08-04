#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Configuration getters/setters — autonomy, debug, active skill, plan/spec paths, tests

[ -n "${_WFM_SETTINGS_LOADED:-}" ] && return 0
_WFM_SETTINGS_LOADED=1

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/infrastructure/state-io.sh"

get_autonomy_level() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "ask"
        return
    fi
    local level
    level=$(jq -r '.autonomy_level // "ask"' "$STATE_FILE" 2>/dev/null) || level="ask"
    [ -z "$level" ] && level="ask"
    echo "$level"
}

set_autonomy_level() {
    local level="$1"
    # Backward-compat: map legacy numeric values
    case "$level" in
        1) level="off" ;;
        2) level="ask" ;;
        3) level="auto" ;;
    esac
    case "$level" in
        off|ask|auto) ;;
        *) echo "ERROR: Invalid autonomy level: $level (valid: off, ask, auto)" >&2; return 1 ;;
    esac
    # set_autonomy_level is always user-initiated — called from !backtick in autonomy.md.
    # No authorization check needed here; the user's slash command is the authorization.
    if [ ! -f "$STATE_FILE" ]; then
        echo "WARNING: No workflow state file. Start a workflow phase first (e.g., /define)." >&2
        return 1
    fi
    _show "[WFM state] SET autonomy_level = $level"
    _update_state '.autonomy_level = $v' --arg v "$level"
}

# ---------------------------------------------------------------------------
# Debug mode
# ---------------------------------------------------------------------------

get_debug() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "off"
        return
    fi
    local val
    val=$(jq -r '.debug // "off"' "$STATE_FILE" 2>/dev/null) || val="off"
    # Backwards compat
    case "$val" in
        true) val="log" ;;
        false|null|"") val="off" ;;
        off|log|show) ;;
        *) val="off" ;;
    esac
    echo "$val"
}

set_debug() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "WARNING: No workflow state file. Start a workflow phase first." >&2
        return 1
    fi
    local val="${1:-}"
    # Backwards compat: true->log, false->off
    case "$val" in
        true) val="log" ;;
        false) val="off" ;;
        off|log|show) ;;
        *) echo "ERROR: Invalid debug value: $val (valid: off, log, show)" >&2; return 1 ;;
    esac
    _show "[WFM state] SET debug = $val"
    _update_state '.debug = $v' --arg v "$val"
}

# ---------------------------------------------------------------------------
# Active skill management
# ---------------------------------------------------------------------------

set_active_skill() { if [ ! -f "$STATE_FILE" ]; then return; fi; _show "[WFM state] SET active_skill = $1"; _update_state '.active_skill = $v' --arg v "$1"; }

get_active_skill() {
    if [ ! -f "$STATE_FILE" ]; then
        echo ""
        return
    fi
    local val
    val=$(jq -r '.active_skill // ""' "$STATE_FILE" 2>/dev/null) || val=""
    echo "$val"
}

# ---------------------------------------------------------------------------
# Plan path management
# ---------------------------------------------------------------------------

set_plan_path() { if [ ! -f "$STATE_FILE" ]; then return; fi; _show "[WFM state] SET plan_path = $1"; _update_state '.plan_path = $v' --arg v "$1"; }

get_plan_path() {
    if [ ! -f "$STATE_FILE" ]; then
        echo ""
        return
    fi
    local val
    val=$(jq -r '.plan_path // ""' "$STATE_FILE" 2>/dev/null) || val=""
    echo "$val"
}

# ---------------------------------------------------------------------------
# Spec path management
# ---------------------------------------------------------------------------

set_spec_path() { if [ ! -f "$STATE_FILE" ]; then return; fi; _show "[WFM state] SET spec_path = $1"; _update_state '.spec_path = $v' --arg v "$1"; }

get_spec_path() {
    if [ ! -f "$STATE_FILE" ]; then
        echo ""
        return
    fi
    local val
    val=$(jq -r '.spec_path // ""' "$STATE_FILE" 2>/dev/null) || val=""
    echo "$val"
}

# ---------------------------------------------------------------------------
# Test results tracking (preserved across phase transitions)
# ---------------------------------------------------------------------------

set_tests_passed_at() { if [ ! -f "$STATE_FILE" ]; then return; fi; _show "[WFM state] SET tests_last_passed_at = $1"; _update_state '.tests_last_passed_at = $v' --arg v "$1"; }

get_tests_passed_at() {
    if [ ! -f "$STATE_FILE" ]; then
        echo ""
        return
    fi
    local val
    val=$(jq -r '.tests_last_passed_at // ""' "$STATE_FILE" 2>/dev/null) || val=""
    echo "$val"
}

# ---------------------------------------------------------------------------
# Token Saver (TkSaver) management
# ---------------------------------------------------------------------------

get_tk_saver_enabled() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "false"
        return
    fi
    local val
    val=$(jq -r '.tk_saver.enabled // false' "$STATE_FILE" 2>/dev/null) || val="false"
    echo "$val"
}

set_tk_saver_enabled() {
    local val="$1"
    case "$val" in
        true|false) ;;
        on) val="true" ;;
        off) val="false" ;;
        *) echo "ERROR: Invalid tk_saver value: $val (valid: true, false, on, off)" >&2; return 1 ;;
    esac
    if [ ! -f "$STATE_FILE" ]; then
        echo "WARNING: No workflow state file. Start a workflow phase first or run /tks to initialize." >&2
        return 1
    fi
    _show "[WFM state] SET tk_saver.enabled = $val"
    _update_state '.tk_saver.enabled = ($v | test("true"))' --arg v "$val"
}

get_tk_saver_member() {
    local name="$1"
    if [ ! -f "$STATE_FILE" ]; then
        echo "false"
        return
    fi
    local val
    val=$(jq -r --arg n "$name" '.tk_saver.members[$n] // false' "$STATE_FILE" 2>/dev/null) || val="false"
    echo "$val"
}

set_tk_saver_member() {
    local name="$1"
    local val="$2"
    case "$name" in
        rtk|serena|mcp2cli) ;;
        *) echo "ERROR: Unknown tk_saver member: $name (valid: rtk, serena, mcp2cli)" >&2; return 1 ;;
    esac
    case "$val" in
        true|false) ;;
        on) val="true" ;;
        off) val="false" ;;
        *) echo "ERROR: Invalid value: $val (valid: true, false, on, off)" >&2; return 1 ;;
    esac
    if [ ! -f "$STATE_FILE" ]; then
        echo "WARNING: No workflow state file." >&2
        return 1
    fi
    _show "[WFM state] SET tk_saver.members.$name = $val"
    _update_state '.tk_saver.members[$n] = ($v | test("true"))' --arg n "$name" --arg v "$val"
}

# ---------------------------------------------------------------------------
# Chat judge flag — decision-menu gate (#124)
# Set true after the plain-language judge passes the draft decision prose.
# pre-tool-menu-gate.sh consumes it: each menu needs a fresh judge pass.
# ---------------------------------------------------------------------------

get_chat_judge_passed() {
    if [ ! -f "$STATE_FILE" ]; then echo "false"; return; fi
    local val
    val=$(jq -r '.chat_judge_passed // false | tostring' "$STATE_FILE" 2>/dev/null) || val="false"
    echo "$val"
}

set_chat_judge_passed() {
    local val="${1:-}"
    case "$val" in
        true|false) ;;
        *) echo "ERROR: set_chat_judge_passed takes true or false" >&2; return 1 ;;
    esac
    if [ ! -f "$STATE_FILE" ]; then return; fi
    _show "[WFM state] SET chat_judge_passed = $val"
    _update_state '.chat_judge_passed = ($v == "true")' --arg v "$val"
}

# ---------------------------------------------------------------------------
# Coaching decline protocol (#53 / #140)
# Records that the agent adjudicated a coaching directive as inapplicable,
# with the reason — an audit trail instead of a silent standoff. A declined
# check never fires again in the same phase; phase transitions reset
# .coaching and clear declines with it.
# ---------------------------------------------------------------------------

decline_check() {
    local check_name="${1:-}" reason="${2:-}"
    if [ -z "$check_name" ] || [ -z "$reason" ]; then
        echo "ERROR: decline_check needs <check_name> and <reason>" >&2
        return 1
    fi
    if [ ! -f "$STATE_FILE" ]; then
        echo "WARNING: No workflow state file." >&2
        return 1
    fi
    _show "[WFM coach] DECLINED $check_name: $reason"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _update_state '.coaching.declined[$cn] = {reason: $r, at: $ts}' \
        --arg cn "$check_name" --arg r "$reason" --arg ts "$ts"
}

get_declined_checks() {
    if [ ! -f "$STATE_FILE" ]; then echo "{}"; return; fi
    jq -c '.coaching.declined // {}' "$STATE_FILE" 2>/dev/null || echo "{}"
}

is_check_declined() {
    local check_name="${1:-}"
    if [ ! -f "$STATE_FILE" ]; then echo "false"; return; fi
    jq -e --arg cn "$check_name" '.coaching.declined[$cn] // empty' \
        "$STATE_FILE" >/dev/null 2>&1 && echo "true" || echo "false"
}
