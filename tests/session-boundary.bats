#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# Session-boundary detection (#158): auto autonomy never outlives the
# session that armed it.

load helpers/common

setup() {
    setup_test_project
}

teardown() {
    teardown_test_project
}

# Run the write-gate with a session_id in the hook payload.
gate_with_session() {  # gate_with_session <session_id> <file_path>
    run bash "$SCRIPTS_DIR/pre-tool-write-gate.sh" <<< "$(jq -n --arg s "$1" --arg f "$2" '{session_id: $s, tool_input: {file_path: $f}}')"
}

@test "first event stamps the session id" {
    write_state implement auto
    gate_with_session "sess-A" "$TEST_PROJECT/src/app.py"
    [ "$(jq -r '.session_id' "$TEST_PROJECT/.claude/state/workflow.json")" = "sess-A" ]
    [ "$(jq -r '.autonomy_level' "$TEST_PROJECT/.claude/state/workflow.json")" = "auto" ]
}

@test "same session changes nothing" {
    write_state implement auto '{"session_id": "sess-A"}'
    gate_with_session "sess-A" "$TEST_PROJECT/src/app.py"
    [ "$(jq -r '.autonomy_level' "$TEST_PROJECT/.claude/state/workflow.json")" = "auto" ]
    [ "$(jq -r '.session_boundary_notice // ""' "$TEST_PROJECT/.claude/state/workflow.json")" = "" ]
}

@test "new session downgrades auto to ask with a notice" {
    write_state implement auto '{"session_id": "sess-A"}'
    gate_with_session "sess-B" "$TEST_PROJECT/src/app.py"
    [ "$(jq -r '.autonomy_level' "$TEST_PROJECT/.claude/state/workflow.json")" = "ask" ]
    [ "$(jq -r '.session_id' "$TEST_PROJECT/.claude/state/workflow.json")" = "sess-B" ]
    [[ "$(jq -r '.session_boundary_notice' "$TEST_PROJECT/.claude/state/workflow.json")" == *"downgraded to ask"* ]]
}

@test "new session with non-auto autonomy only restamps" {
    write_state implement guided '{"session_id": "sess-A"}'
    gate_with_session "sess-B" "$TEST_PROJECT/src/app.py"
    [ "$(jq -r '.autonomy_level' "$TEST_PROJECT/.claude/state/workflow.json")" = "guided" ]
    [ "$(jq -r '.session_id' "$TEST_PROJECT/.claude/state/workflow.json")" = "sess-B" ]
    [ "$(jq -r '.session_boundary_notice // ""' "$TEST_PROJECT/.claude/state/workflow.json")" = "" ]
}

@test "payload without session_id is a no-op" {
    write_state implement auto '{"session_id": "sess-A"}'
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    [ "$(jq -r '.autonomy_level' "$TEST_PROJECT/.claude/state/workflow.json")" = "auto" ]
    [ "$(jq -r '.session_id' "$TEST_PROJECT/.claude/state/workflow.json")" = "sess-A" ]
}
