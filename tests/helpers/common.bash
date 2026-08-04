# Copyright (C) 2026 azevedo-home-lab
# SPDX-License-Identifier: GPL-3.0-only
#
# Shared bats helpers: temp project fixture, state file builders, hook
# runners, and allow/deny assertions. Tests never touch the real
# ~/.claude or the repo's own .claude/state — every test gets a fresh
# temp CLAUDE_PROJECT_DIR.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/plugin/scripts"

setup_test_project() {
    TEST_PROJECT=$(mktemp -d)
    export CLAUDE_PROJECT_DIR="$TEST_PROJECT"
    mkdir -p "$TEST_PROJECT/.claude/state"
}

teardown_test_project() {
    [ -n "${TEST_PROJECT:-}" ] && rm -rf "$TEST_PROJECT"
    unset CLAUDE_PROJECT_DIR
}

# write_state <phase> <autonomy> [extra-jq-object]
# Builds a minimal valid workflow.json in the temp project.
write_state() {
    local phase="$1" autonomy="${2:-guided}" extra="${3:-}"
    [ -z "$extra" ] && extra='{}'
    jq -n --arg p "$phase" --arg a "$autonomy" --argjson x "$extra" \
        '{phase: $p, autonomy_level: $a, message_shown: false} + $x' \
        > "$TEST_PROJECT/.claude/state/workflow.json"
}

# Source the infrastructure layer into the current shell (for unit tests
# of functions). SCRIPT_DIR must point at plugin/scripts before sourcing.
source_infra() {
    SCRIPT_DIR="$SCRIPTS_DIR"
    source "$SCRIPTS_DIR/infrastructure/state-io.sh"
    source "$SCRIPTS_DIR/infrastructure/phase.sh"
    source "$SCRIPTS_DIR/infrastructure/settings.sh"
    source "$SCRIPTS_DIR/infrastructure/milestones.sh"
}

source_state_machine() {
    source_infra
    source "$SCRIPTS_DIR/agent-set-phase.sh"
}

# Run a PreToolUse hook end-to-end with a JSON payload on stdin.
run_write_gate() {
    run bash "$SCRIPTS_DIR/pre-tool-write-gate.sh" <<< "$1"
}

run_bash_guard() {
    run bash "$SCRIPTS_DIR/pre-tool-bash-guard.sh" <<< "$1"
}

# Payload builders
write_payload() {  # write_payload <file_path>
    jq -n --arg f "$1" '{tool_input: {file_path: $f}}'
}

bash_payload() {  # bash_payload <command>
    jq -n --arg c "$1" '{tool_input: {command: $c}}'
}

# Assertions on hook output (bats `run` merges stdout+stderr into $output)
assert_deny() {
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]] || {
        echo "expected deny, got: $output" >&2
        return 1
    }
}

assert_allow() {
    [ "$status" -eq 0 ]
    [[ "$output" != *'"permissionDecision"'* ]] || {
        echo "expected allow, got: $output" >&2
        return 1
    }
}
