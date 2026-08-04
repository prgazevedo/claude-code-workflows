# Contributing to Claude Code Workflows

Thank you for your interest in contributing.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/prgazevedo/claude-code-workflows.git
   cd claude-code-workflows
   ```

2. Prerequisites:
   - Bash 4+
   - jq (for JSON manipulation in hooks)
   - Git
   - [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) (for testing the full workflow)

3. Install the plugin and verify hooks are active:
   ```bash
   claude  # start Claude Code in the project directory
   /define  # verify phase transitions work
   /off
   ```

## Making Changes

1. Fork the repository and create a feature branch
2. Make your changes
3. Verify the workflow pipeline works end-to-end
4. Add tests for new functionality
5. Add GPL v3 license headers to new source files
6. Submit a pull request

## Code Style

- **Shell scripts**: Use `set -euo pipefail`, quote variables, use `[ ]` for conditionals (POSIX style, consistent with existing codebase)
- **Markdown**: ATX-style headers (`##`), fenced code blocks with language tags
- **JSON**: 2-space indentation, trailing newline
- **Commits**: Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)

## Testing

The mechanical layer has a bats suite in [`tests/`](tests/), run by CI on
every push and PR (`.github/workflows/shell-tests.yml`). Run it locally
with `bats tests/` (install: `brew install bats-core`).

**A change to a guard, gate, or state-machine script requires a test.**
This is the shell-layer mirror of the agent-prompt Iron Law below: the
enforcement scripts are the product, and an untested edit to them is how
the bug history (#41, #43) happened. `shellcheck -S error` also runs in
CI over `plugin/scripts/`.

Manual end-to-end verification still covers what the suite cannot:
- Phase transitions (`/define` -> `/discuss` -> `/implement` -> `/review` -> `/complete`)
- Coaching delivery in a live session
- Agent auto-transition in `auto` autonomy mode

### Editing an agent prompt

Agent prompts in `plugin/agents/` are the plugin's behaviour, so some of them
have pressure-test fixtures in [`evals/`](evals/README.md).

**Before committing an edit to a covered agent, re-run its GREEN fixtures.**
Covered agents are the directories under `evals/`. CI does this
automatically: a PR touching a covered `plugin/agents/*.md` re-runs that
agent's fixtures (`.github/workflows/agent-evals.yml`), and a FAIL fails
the job. Run locally with
`python3 evals/run_fixture.py evals/<agent>/<rule>.md`. The full
protocol — the candidate/judge split and what a FAIL means — is in
[`evals/README.md`](evals/README.md). The human is the final arbiter
and may merge over a FAIL; the override is recorded on the PR.

Runs are manual and cost model calls; there is no CI job for them yet
(tracked in #83, which is blocked on this repo having CI at all).

## Pull Request Process

1. Verify manually: run the workflow through at least one full IMPLEMENT → REVIEW → COMPLETE cycle and confirm no regressions
2. Update documentation if behavior changes
3. One feature per PR — keep changes focused
4. Describe what and why in the PR description

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## License

By contributing, you agree that your contributions will be licensed under the GPL v3 license.
