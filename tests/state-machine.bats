#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# State machine: phase ordinals, get_phase edge cases, atomic writes,
# milestones, gate checks, and the agent_set_phase authorization matrix.

load helpers/common

setup() {
    setup_test_project
    source_state_machine
}

teardown() {
    teardown_test_project
}

# --- _phase_ordinal ---

@test "phase ordinals are strictly increasing along the pipeline" {
    [ "$(_phase_ordinal off)" -eq 0 ]
    [ "$(_phase_ordinal define)" -eq 1 ]
    [ "$(_phase_ordinal discuss)" -eq 2 ]
    [ "$(_phase_ordinal implement)" -eq 3 ]
    [ "$(_phase_ordinal review)" -eq 4 ]
    [ "$(_phase_ordinal complete)" -eq 5 ]
}

@test "unknown phase names map to ordinal 0" {
    [ "$(_phase_ordinal banana)" -eq 0 ]
    [ "$(_phase_ordinal '')" -eq 0 ]
}

# --- get_phase ---

@test "get_phase returns off when no state file exists" {
    [ "$(get_phase)" = "off" ]
}

@test "get_phase returns the stored phase" {
    write_state implement auto
    [ "$(get_phase)" = "implement" ]
}

@test "get_phase returns error on invalid JSON" {
    echo 'not json{' > "$TEST_PROJECT/.claude/state/workflow.json"
    [ "$(get_phase)" = "error" ]
}

@test "get_phase returns error on an unknown phase value" {
    write_state banana auto
    [ "$(get_phase)" = "error" ]
}

# --- _safe_write ---

@test "safe_write rejects zero-byte input and keeps the old state" {
    write_state define guided
    run _safe_write < /dev/null
    [ "$status" -ne 0 ]
    [ "$(get_phase)" = "define" ]
}

@test "safe_write rejects invalid JSON and keeps the old state" {
    write_state define guided
    run _safe_write <<< 'garbage{'
    [ "$status" -ne 0 ]
    [ "$(get_phase)" = "define" ]
}

@test "safe_write rejects payloads over 10KB" {
    write_state define guided
    run bash -c '
        source "'"$SCRIPTS_DIR"'/infrastructure/state-io.sh"
        jq -n --arg big "$(head -c 11000 /dev/zero | tr "\0" "x")" \
            "{phase: \"define\", pad: \$big}" | _safe_write
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"10KB"* ]]
}

@test "update_state stamps .updated" {
    write_state define guided
    _update_state '.phase = "discuss"'
    local updated
    updated=$(jq -r '.updated' "$STATE_FILE")
    [[ "$updated" == 20*T*Z ]]
}

# --- milestones ---

@test "reset_section initializes every field to false" {
    write_state discuss guided
    _reset_section "discuss" "problem_confirmed" "research_done" "approach_selected"
    [ "$(_get_section_field discuss problem_confirmed)" = "false" ]
    [ "$(_get_section_field discuss approach_selected)" = "false" ]
}

@test "set and get a boolean milestone field" {
    write_state discuss guided
    _reset_section "discuss" "approach_selected"
    _set_section_field "discuss" "approach_selected" "true"
    [ "$(_get_section_field discuss approach_selected)" = "true" ]
}

@test "check_milestones fails closed when the section is missing" {
    write_state implement auto
    local missing
    missing=$(_check_milestones "implement" "plan_written" "plan_read")
    [[ "$missing" == *plan_written* ]]
    [[ "$missing" == *plan_read* ]]
}

@test "check_milestones reports only the unset fields" {
    write_state implement auto
    _reset_section "implement" "plan_written" "plan_read"
    _set_section_field "implement" "plan_written" "true"
    local missing
    missing=$(_check_milestones "implement" "plan_written" "plan_read")
    [[ "$missing" != *plan_written* ]]
    [[ "$missing" == *plan_read* ]]
}

@test "check_milestones is empty when all fields are true" {
    write_state implement auto
    _reset_section "implement" "plan_written"
    _set_section_field "implement" "plan_written" "true"
    [ -z "$(_check_milestones implement plan_written | tr -d ' ')" ]
}

# --- agent_set_phase authorization matrix ---

@test "agent_set_phase rejects an invalid phase name" {
    write_state define auto
    run agent_set_phase banana
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid phase"* ]]
}

@test "agent_set_phase blocks setting phase to off" {
    write_state define auto
    run agent_set_phase off
    [ "$status" -ne 0 ]
    [[ "$output" == *"Only the user"* ]]
}

@test "agent_set_phase blocks when no state file exists" {
    run agent_set_phase implement
    [ "$status" -ne 0 ]
    [[ "$output" == *"No workflow state"* ]]
}

@test "agent_set_phase blocks outside auto autonomy" {
    write_state define guided
    run agent_set_phase discuss
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires user authorization"* ]]
}

@test "agent_set_phase blocks backward transitions" {
    write_state implement auto
    run agent_set_phase discuss
    [ "$status" -ne 0 ]
    [[ "$output" == *"forward-only"* ]]
}

@test "agent_set_phase blocks same-phase transitions" {
    write_state implement auto
    run agent_set_phase implement
    [ "$status" -ne 0 ]
    [[ "$output" == *"forward-only"* ]]
}

@test "agent_set_phase advances define to discuss in auto mode" {
    write_state define auto
    run agent_set_phase discuss
    [ "$status" -eq 0 ]
    [ "$(get_phase)" = "discuss" ]
}

@test "leaving discuss is gated on approach_selected" {
    write_state discuss auto
    _reset_section "discuss" "problem_confirmed" "research_done" "approach_selected"
    run agent_set_phase implement
    [ "$status" -ne 0 ]
    [[ "$output" == *"approach not selected"* ]]
}

@test "leaving discuss succeeds once approach_selected is true" {
    write_state discuss auto
    _reset_section "discuss" "approach_selected"
    _set_section_field "discuss" "approach_selected" "true"
    run agent_set_phase implement
    [ "$status" -eq 0 ]
    [ "$(get_phase)" = "implement" ]
}

@test "leaving implement is gated on implementation milestones" {
    write_state implement auto
    _reset_section "implement" "plan_written" "plan_read" "all_tasks_complete"
    run agent_set_phase review
    [ "$status" -ne 0 ]
    [[ "$output" == *"incomplete milestones"* ]]
}

@test "tests_passing is required when the project has a tests directory" {
    write_state implement auto
    mkdir -p "$TEST_PROJECT/tests"
    _reset_section "implement" "plan_written" "plan_read" "tests_passing" "all_tasks_complete"
    _set_section_field "implement" "plan_written" "true"
    _set_section_field "implement" "plan_read" "true"
    _set_section_field "implement" "all_tasks_complete" "true"
    run agent_set_phase review
    [ "$status" -ne 0 ]
    [[ "$output" == *tests_passing* ]]
}

@test "agent cannot jump from review to complete without findings_acknowledged" {
    write_state review auto
    _reset_section "review" "verification_complete" "agents_dispatched" "findings_presented" "findings_acknowledged"
    run agent_set_phase complete
    [ "$status" -ne 0 ]
    [[ "$output" == *"REVIEW phase was not completed"* ]]
}

@test "review to complete succeeds once findings_acknowledged is true" {
    write_state review auto
    _reset_section "review" "findings_acknowledged"
    _set_section_field "review" "findings_acknowledged" "true"
    run agent_set_phase complete
    [ "$status" -eq 0 ]
    [ "$(get_phase)" = "complete" ]
}

@test "phase transition resets coaching counters and message_shown" {
    write_state define auto '{"message_shown": true, "coaching": {"tool_calls_since_agent": 7, "layer2_fired": ["x"]}}'
    run agent_set_phase discuss
    [ "$status" -eq 0 ]
    [ "$(jq -r '.message_shown' "$STATE_FILE")" = "false" ]
    [ "$(jq -r '.coaching.tool_calls_since_agent' "$STATE_FILE")" = "0" ]
}

@test "phase transition preserves unrelated state keys" {
    write_state define auto '{"issue_mappings": {"45": "done"}, "autonomy_level": "auto"}'
    run agent_set_phase discuss
    [ "$status" -eq 0 ]
    [ "$(jq -r '.issue_mappings["45"]' "$STATE_FILE")" = "done" ]
    [ "$(jq -r '.autonomy_level' "$STATE_FILE")" = "auto" ]
}

@test "leaving implement with no test suite records NO-TEST-SUITE" {
    write_state implement auto
    _reset_section "implement" "plan_written" "plan_read" "all_tasks_complete"
    _set_section_field "implement" "plan_written" "true"
    _set_section_field "implement" "plan_read" "true"
    _set_section_field "implement" "all_tasks_complete" "true"
    run agent_set_phase review
    [ "$status" -eq 0 ]
    [ "$(jq -r '.implement.tests_passing' "$STATE_FILE")" = "NO-TEST-SUITE" ]
}

@test "leaving implement with a test suite keeps tests_passing true" {
    write_state implement auto
    mkdir -p "$TEST_PROJECT/tests"
    _reset_section "implement" "plan_written" "plan_read" "tests_passing" "all_tasks_complete"
    for f in plan_written plan_read tests_passing all_tasks_complete; do
        _set_section_field "implement" "$f" "true"
    done
    run agent_set_phase review
    [ "$status" -eq 0 ]
    [ "$(jq -r '.implement.tests_passing' "$STATE_FILE")" = "true" ]
}

@test "get_<phase>_field with no argument lists all fields instead of crashing" {
    write_state discuss guided
    _reset_section "discuss" "problem_confirmed" "research_done" "approach_selected"
    _set_section_field "discuss" "research_done" "true"
    run bash -c '
        set -euo pipefail
        SCRIPT_DIR="'"$SCRIPTS_DIR"'"
        source "$SCRIPT_DIR/infrastructure/state-io.sh"
        source "$SCRIPT_DIR/infrastructure/milestones.sh"
        get_discuss_field
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"research_done=true"* ]]
    [[ "$output" == *"problem_confirmed=false"* ]]
}
