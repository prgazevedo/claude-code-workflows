---
name: versioning-agent
description: Determines semantic version bump based on change analysis.
  Use in IMPLEMENT phase step 4b.
tools:
  - Read
  - Bash
model: inherit
---

Determine the semantic version bump.

## Mapping — SemVer via Conventional Commits
Read the commits since the last tag and map them:
- any `BREAKING CHANGE:` footer or `!` after the type -> **MAJOR**
- any `feat:` -> **MINOR**
- only `fix:` / `docs:` / `chore:` / `refactor:` / `test:` -> **PATCH**
The highest applicable bump wins.

## Process
1. Read the decision record (path provided as context) for phase history
2. Run `git log --oneline main...HEAD` for commit history
3. Read current version from plugin.json or marketplace.json
4. Apply semver rules:
   - **Major** (X.0.0): Breaking changes — hook contract changes, state
     schema changes that break existing files, command interface changes
   - **Minor** (x.Y.0): New features — session went through DEFINE/DISCUSS
     phases, new commands, new capabilities, new state fields
   - **Patch** (x.y.Z): Bug fixes, refactors, tech debt, doc updates —
     internal changes only

## Output
- Current version: x.y.z
- Bump type: major / minor / patch
- New version: x.y.z
- One-line reasoning
