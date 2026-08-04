#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# Coaching decline protocol (#53/#140): a declined check never fires
# again in the same phase; phase transitions clear declines.

load helpers/common

setup() {
    setup_test_project
    source_state_machine
}

teardown() {
    teardown_test_project
}

# Source the throttle engine after state exists (it reads state on load).
load_runner() {
    L3_MSG=""
    source "$SCRIPTS_DIR/l3/coaching-runner.sh"
}

@test "decline_check records the reason and timestamp" {
    write_state implement auto
    decline_check "stalled_auto_transition" "board work, not an implement cycle"
    [ "$(is_check_declined stalled_auto_transition)" = "true" ]
    run get_declined_checks
    [[ "$output" == *"board work"* ]]
}

@test "decline_check requires a reason" {
    write_state implement auto
    run decline_check "stalled_auto_transition"
    [ "$status" -ne 0 ]
}

@test "a non-declined check past its grace period fires" {
    write_state implement auto '{"coaching": {"tool_calls_since_agent": 10, "throttle": {"c1": {"first_true": 1, "fire_count": 0}}}}'
    load_runner
    run _should_fire "c1"
    [ "$status" -eq 0 ]
}

@test "a declined check never fires" {
    write_state implement auto '{"coaching": {"tool_calls_since_agent": 10, "throttle": {"c1": {"first_true": 1, "fire_count": 0}}}}'
    decline_check "c1" "adjudicated inapplicable"
    load_runner
    run _should_fire "c1"
    [ "$status" -ne 0 ]
}

@test "phase transition clears declines" {
    write_state implement auto
    _reset_section "implement" "plan_written" "plan_read" "all_tasks_complete"
    _set_section_field "implement" "plan_written" "true"
    _set_section_field "implement" "plan_read" "true"
    _set_section_field "implement" "all_tasks_complete" "true"
    decline_check "c1" "inapplicable"
    run agent_set_phase review
    [ "$status" -eq 0 ]
    [ "$(is_check_declined c1)" = "false" ]
}
