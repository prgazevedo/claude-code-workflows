#!/bin/bash
# Copyright (C) 2026 Pedro Azevedo
# SPDX-License-Identifier: GPL-3.0-only
#
# This file is part of Claude Code Workflows.
# See LICENSE for details.

# Workflow Manager: decision-menu gate (#124)
# Matcher: AskUserQuestion
#
# A decision menu is allowed only after the plain-language judge passed the
# draft prose. The flag is consumed on use, so every menu needs a fresh
# judge pass. Rule: conventions/plain-language.md, Decision questions.

set -euo pipefail

# Exit silently when running as a project-deployed copy (missing infrastructure/).
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${CLAUDE_PLUGIN_ROOT:-}" ] && [ ! -d "$_self_dir/infrastructure" ] && exit 0

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/scripts/infrastructure/resolve-script-dir.sh" ]; then
    source "$CLAUDE_PLUGIN_ROOT/scripts/infrastructure/resolve-script-dir.sh"
else
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/infrastructure/resolve-script-dir.sh"
fi
# No state file or phase off: preamble returns 1 and the menu is allowed.
source "$SCRIPT_DIR/infrastructure/hook-preamble.sh" "menu-gate" || exit 0

source "$SCRIPT_DIR/infrastructure/deny-messages.sh"

# Consume stdin per the hook protocol; the payload itself is not inspected.
INPUT=$(cat)

if [ "$(get_chat_judge_passed)" = "true" ]; then
    set_chat_judge_passed false
    _log "[WFM menu-gate] menu allowed, judge flag consumed"
    exit 0
fi

emit_deny "BLOCKED: decision menu without a judged draft. Dispatch a fresh judge subagent on the prose you are about to show (rubric: conventions/plain-language.md). On PASS run: workflow-cmd.sh set_chat_judge_passed true — then present the menu."
