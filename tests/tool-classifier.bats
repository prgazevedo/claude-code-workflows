#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# Tool classifier: coaching dispatch categories (regression class of #43).

load helpers/common

setup() {
    source "$SCRIPTS_DIR/infrastructure/tool-classifier.sh"
}

classify_bash() {  # classify_bash <command>
    _classify_tool "Bash" "$(bash_payload "$1")"
}

@test "user-set-phase.sh commands classify as phase-transition" {
    [ "$(classify_bash '!bash plugin/scripts/user-set-phase.sh implement')" = "phase-transition" ]
}

@test "workflow-cmd.sh agent_set_phase classifies as phase-transition" {
    [ "$(classify_bash 'plugin/scripts/workflow-cmd.sh agent_set_phase review')" = "phase-transition" ]
}

@test "other workflow-cmd.sh calls classify as infrastructure-query" {
    [ "$(classify_bash 'plugin/scripts/workflow-cmd.sh get_phase')" = "infrastructure-query" ]
}

@test "ordinary bash commands classify as coaching-participant" {
    [ "$(classify_bash 'ls -la')" = "coaching-participant" ]
}

@test "Write and Edit tools classify as coaching-participant" {
    [ "$(_classify_tool Write '{}')" = "coaching-participant" ]
    [ "$(_classify_tool Edit '{}')" = "coaching-participant" ]
}

@test "Agent dispatch classifies as coaching-participant" {
    [ "$(_classify_tool Agent '{}')" = "coaching-participant" ]
}

@test "read-only tools classify as irrelevant" {
    [ "$(_classify_tool Read '{}')" = "irrelevant" ]
    [ "$(_classify_tool Grep '{}')" = "irrelevant" ]
}
