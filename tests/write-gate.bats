#!/usr/bin/env bats
# Copyright (C) 2026 azevedo-home-lab
# SPDX-License-Identifier: GPL-3.0-only
#
# Write-gate hook: phase/whitelist matrix for Write/Edit tools,
# guard-system self-protection, and path traversal handling.

load helpers/common

setup() {
    setup_test_project
}

teardown() {
    teardown_test_project
}

@test "no state file means no enforcement" {
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_allow
}

@test "off phase means no enforcement" {
    write_state off guided
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_allow
}

@test "define blocks source writes" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_deny
}

@test "define allows docs/plans/" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/docs/plans/plan.md")"
    assert_allow
}

@test "define allows docs/specs/" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/docs/specs/spec.md")"
    assert_allow
}

@test "define allows .claude/state/" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/.claude/state/scratch.json")"
    assert_allow
}

@test "discuss blocks source writes" {
    write_state discuss guided
    run_write_gate "$(write_payload "$TEST_PROJECT/lib/util.sh")"
    assert_deny
}

@test "discuss blocks root markdown" {
    write_state discuss guided
    run_write_gate "$(write_payload "$TEST_PROJECT/README.md")"
    assert_deny
}

@test "implement allows source writes" {
    write_state implement guided
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_allow
}

@test "review allows source writes" {
    write_state review guided
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_allow
}

@test "complete allows any docs/ path" {
    write_state complete guided
    run_write_gate "$(write_payload "$TEST_PROJECT/docs/handover/notes.md")"
    assert_allow
}

@test "complete allows root markdown" {
    write_state complete guided
    run_write_gate "$(write_payload "$TEST_PROJECT/README.md")"
    assert_allow
}

@test "complete blocks source writes" {
    write_state complete guided
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_deny
}

@test "guard-system files are blocked even in implement" {
    write_state implement guided
    run_write_gate "$(write_payload "$TEST_PROJECT/.claude/hooks/pre-tool-write-gate.sh")"
    assert_deny
}

@test "path outside the project root is denied in define" {
    write_state define guided
    outside=$(mktemp -d)
    run_write_gate "$(write_payload "$outside/evil.py")"
    rm -rf "$outside"
    assert_deny
}

@test "dotdot traversal into a restricted area is denied in define" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/docs/plans/../../src/app.py")"
    assert_deny
}

@test "workflow state file is denied in define despite the state whitelist" {
    write_state define guided
    run_write_gate "$(write_payload "$TEST_PROJECT/.claude/state/workflow.json")"
    assert_deny
}

@test "workflow state file is denied even in implement" {
    write_state implement guided
    run_write_gate "$(write_payload "$TEST_PROJECT/.claude/state/workflow.json")"
    assert_deny
}

@test "state older than 7 days is not enforced" {
    write_state define guided
    jq '.updated = "2026-05-31T12:00:00Z"' \
        "$TEST_PROJECT/.claude/state/workflow.json" > "$TEST_PROJECT/.claude/state/tmp.json"
    mv "$TEST_PROJECT/.claude/state/tmp.json" "$TEST_PROJECT/.claude/state/workflow.json"
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_allow
}

@test "state updated today is enforced" {
    write_state define guided
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.updated = $ts' \
        "$TEST_PROJECT/.claude/state/workflow.json" > "$TEST_PROJECT/.claude/state/tmp.json"
    mv "$TEST_PROJECT/.claude/state/tmp.json" "$TEST_PROJECT/.claude/state/workflow.json"
    run_write_gate "$(write_payload "$TEST_PROJECT/src/app.py")"
    assert_deny
}
