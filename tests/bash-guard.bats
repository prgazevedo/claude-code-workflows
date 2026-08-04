#!/usr/bin/env bats
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# Bash-guard hook: allowlist/denylist per phase, write-op detection,
# destructive git, chaining detection, and self-protection.

load helpers/common

setup() {
    setup_test_project
}

teardown() {
    teardown_test_project
}

@test "unparseable command fails closed" {
    write_state define guided
    run_bash_guard '{"tool_input": {}}'
    assert_deny
}

@test "define allows read-only commands" {
    write_state define guided
    run_bash_guard "$(bash_payload 'ls -la')"
    assert_allow
}

@test "define blocks rm" {
    write_state define guided
    run_bash_guard "$(bash_payload 'rm -rf src')"
    assert_deny
}

@test "define blocks redirect writes to source" {
    write_state define guided
    run_bash_guard "$(bash_payload 'echo hack > src/app.py')"
    assert_deny
}

@test "define allows redirect writes to docs/plans/" {
    write_state define guided
    run_bash_guard "$(bash_payload 'echo note > docs/plans/note.md')"
    assert_allow
}

@test "define blocks sed -i" {
    write_state define guided
    run_bash_guard "$(bash_payload 'sed -i s/a/b/ src/app.py')"
    assert_deny
}

@test "chained command escapes the workflow-cmd allowance and is denied in define" {
    write_state define guided
    run_bash_guard "$(bash_payload 'workflow-cmd.sh get_phase && rm -rf src')"
    assert_deny
}

@test "chained git commit is denied" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'git commit -m "x" && git push')"
    assert_deny
}

@test "destructive git is denied even in implement" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'git reset --hard HEAD~3')"
    assert_deny
}

@test "user-set-phase.sh execution via Bash is denied in every phase" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'bash plugin/scripts/user-set-phase.sh complete')"
    assert_deny
}

@test "direct write to the state file is denied even in implement" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'echo {} > .claude/state/workflow.json')"
    assert_deny
}

@test "sed against enforcement files is denied even in implement" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'sed -i s/deny/allow/ .claude/hooks/pre-tool-bash-guard.sh')"
    assert_deny
}

@test "implement allows ordinary writes" {
    write_state implement guided
    run_bash_guard "$(bash_payload 'echo data > src/output.txt')"
    assert_allow
}

@test "complete allows read-only commands" {
    write_state complete guided
    run_bash_guard "$(bash_payload 'ls -la')"
    assert_allow
}

@test "complete allows writes to docs/" {
    write_state complete guided
    run_bash_guard "$(bash_payload 'echo done > docs/handover.md')"
    assert_allow
}

@test "complete blocks writes to source" {
    write_state complete guided
    run_bash_guard "$(bash_payload 'echo hack > src/app.py')"
    assert_deny
}

@test "complete allows rm of .claude/tmp/ only" {
    write_state complete guided
    run_bash_guard "$(bash_payload 'rm .claude/tmp/scratch.txt')"
    assert_allow
    run_bash_guard "$(bash_payload 'rm src/app.py')"
    assert_deny
}

@test "no state file means no enforcement" {
    run_bash_guard "$(bash_payload 'rm -rf src')"
    assert_allow
}
