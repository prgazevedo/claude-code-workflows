#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Workflow Manager: guards the user's "!" bang-input against dangerous
# commands (#155). UserPromptSubmit hook — exit 2 blocks the prompt and
# shows the stderr reason; exit 0 lets it through.
#
# Ordering caveat (recorded on #155): the docs say UserPromptSubmit
# fires before the prompt is processed and can block it. Whether that
# is before the bang line's SHELL EXECUTION is unverified — the one
# observed transcript showed output arriving already-executed. This
# hook is correct either way: if the hook fires first it prevents
# execution; if not, it still keeps the dangerous line and its output
# out of the conversation, and the zsh preexec fallback in
# docs/reference/bang-input-guard.md covers the execution side.
#
# Deliberately state-free: protection must not depend on a phase being
# active, so this sources only the pattern libraries.

set -euo pipefail

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${CLAUDE_PLUGIN_ROOT:-}" ] && [ ! -d "$_self_dir/infrastructure" ] && exit 0

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/scripts/infrastructure" ]; then
    SCRIPT_DIR="$CLAUDE_PLUGIN_ROOT/scripts"
else
    SCRIPT_DIR="$_self_dir"
fi

source "$SCRIPT_DIR/infrastructure/patterns.sh"
source "$SCRIPT_DIR/infrastructure/git-safety.sh"

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null) || PROMPT=""

# Only bang-input is in scope. Normal prompts pass untouched.
case "$PROMPT" in
    \!*) ;;
    *) exit 0 ;;
esac
CMD="${PROMPT#\!}"

_deny() {
    echo "BLOCKED bang-input (#155): $1" >&2
    echo "  Line: ${CMD:0:120}" >&2
    echo "  If intended, run it in your own terminal instead." >&2
    exit 2
}

# Destructive git — same test the agent-side bash guard uses.
if _is_destructive_git "$CMD"; then
    _deny "destructive git command"
fi

# Writes targeting the enforcement layer or workflow state.
if echo "$CMD" | grep -qE "$GUARD_SYSTEM_PATTERN"; then
    if echo "$CMD" | grep -qE '(>|>>|\brm\b|\bmv\b|\bcp\b|sed[[:space:]]+-i|tee[[:space:]]|chmod[[:space:]]|truncate[[:space:]])'; then
        _deny "write touching enforcement files"
    fi
fi
if echo "$CMD" | grep -qE "$STATE_FILE_PATTERN"; then
    if echo "$CMD" | grep -qE '(>|>>|\brm\b|\bmv\b|sed[[:space:]]+-i|tee[[:space:]])'; then
        _deny "write touching workflow state files"
    fi
fi

# Recursive/forced rm outside throwaway areas.
if echo "$CMD" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rfRF][a-zA-Z]*[[:space:]]+)+'; then
    if ! echo "$CMD" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[[:space:]]+)*("?\$?[A-Za-z_{}]*"?)?(/private)?(/tmp/|[^[:space:]]*\.claude/tmp/)'; then
        _deny "recursive rm outside /tmp or .claude/tmp"
    fi
fi

# Pipe-to-shell: fetched content executed sight-unseen.
if echo "$CMD" | grep -qE '(curl|wget)[[:space:]][^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|k)?sh(\b|$)'; then
    _deny "piping downloaded content into a shell"
fi

# Force-push protection beyond _is_destructive_git's coverage.
if echo "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]][^|;&]*(--force([^-]|$)|-f([[:space:]]|$))'; then
    _deny "force push"
fi

exit 0
