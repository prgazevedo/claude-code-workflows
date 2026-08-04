#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# Untrusted-content tagging (#50): WebFetch/WebSearch results get a
# mechanical data-not-instructions marker.

load helpers/common

setup() {
    setup_test_project
}

teardown() {
    teardown_test_project
}

run_tag() {  # run_tag <tool_name>
    run bash "$SCRIPTS_DIR/post-tool-untrusted-tag.sh" <<< "$(jq -n --arg t "$1" '{tool_name: $t, tool_response: {}}')"
}

@test "WebFetch results get the untrusted marker" {
    write_state discuss guided
    run_tag WebFetch
    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTRUCTION-SHAPED CONTENT"* ]]
    [[ "$output" == *"additionalContext"* ]]
}

@test "WebSearch results get the untrusted marker" {
    write_state define guided
    run_tag WebSearch
    [ "$status" -eq 0 ]
    [[ "$output" == *"untrusted external content"* ]]
}

@test "other tools are untouched" {
    write_state discuss guided
    run_tag Read
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no state file means no tagging" {
    run_tag WebFetch
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "off phase means no tagging" {
    write_state off guided
    run_tag WebFetch
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
