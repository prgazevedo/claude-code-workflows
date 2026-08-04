Do not fix, modify, or delete anything unless explicitly asked. Default behavior is to investigate and report findings. Always ask before making changes.

## Writing rules

AI-authored text in this repo — PR bodies, issue bodies, doc prose —
follows [`conventions/plain-language.md`](conventions/plain-language.md).
Run `tools/judge/precheck.sh <draft> --pr-body` on PR bodies before
pushing; CI runs the same judge.

## Agent-prompt edits — the Iron Law

The prompts in `plugin/agents/*.md` are the plugin's behaviour. **No
agent-prompt edit without a failing test first**, edits included — RED →
GREEN → REFACTOR (ported from the agentic-sdlc bundle, #82):

1. **RED** — run the fixture's scenario *without* the change; capture verbatim
   what the bare agent does. If the bare agent does not fail, record the rule
   as GREEN-only with its ceiling (see `evals/README.md`).
2. **GREEN** — write only the prompt text that fixes those failures, and
   nothing more.
3. **REFACTOR** — re-run, close new loopholes, repeat until it passes.

Concretely:

- **Editing an agent covered in `evals/` re-runs its GREEN fixtures before
  commit.** A FAIL means the edit weakened the agent — fix it first.
- **A new rule in an agent prompt gets its RED baseline captured first**, with
  a fixture added under `evals/<agent>/`.
- The human is the final arbiter and may overrule a judge verdict; the
  overrule is recorded in the fixture.

### Match the prompt form to the observed failure

Classify the RED failure before choosing wording:

| Baseline failure | Right form |
|---|---|
| Knows the rule, skips it under pressure | Prohibition + rationalization table + red-flags list |
| Complies but output is wrong-shaped | Positive recipe: state what the output IS, in order |
| Omits a required element | Structural: a REQUIRED slot in the template they fill |
| Behaviour should depend on a condition | Conditional keyed to an observable predicate |

Prohibitions backfire on shaping and omission failures — don't default to
"don't X". Avoid exemption clauses ("unless it matters"); they reopen the
negotiation.

## Guard-System Integrity

Never use Bash to bypass Edit/Write tool blocks. If the guard-system blocks an edit, stop and tell the user. Do not use interpreters (python, node, ruby, perl), heredocs, or any indirect method to write files that the guard-system would block via the Edit/Write tools. The guard-system exists to keep the user in control — circumventing it defeats its purpose.

## Version Bumping

When bumping the plugin version, you MUST update ALL THREE files:
- `.claude-plugin/plugin.json` — repo-level manifest (development, setup.sh dev mode)
- `.claude-plugin/marketplace.json` — marketplace catalog (`claude plugin install` uses this version to name the cache directory)
- `plugin/.claude-plugin/plugin.json` — cache-level manifest (gets copied into the cache; Claude Code needs this to discover commands and agents)

If these are out of sync, `claude plugin install` creates the cache under the wrong version, or Claude Code fails to discover plugin commands. This was the root cause of a major bug where slash commands (/discuss, /define, etc.) failed in all projects.
