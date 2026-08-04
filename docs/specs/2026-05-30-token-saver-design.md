# Token Saver (TkSaver) — Design Spec

**Date:** 2026-05-30
**Phase:** Approach A (state, UI, detection — no enforcement)
**Follow-up:** Approach B saved as GitHub issue (bash guard enforcement, RTK hook management, coaching nudges)

## Problem

LLM token consumption is unnecessarily high due to verbose CLI output, heavy MCP tool schema injection, and lack of semantic code navigation. Three external tools address this — RTK, Serena, mcp2cli — but WFM has no way to manage, toggle, or surface their availability.

## Solution

A toggle-based package called **TkSaver** that:

- Tracks master and per-member enabled/disabled state in `workflow.json`
- Provides a `/tks` slash command for toggling and status
- Shows a compact statusline badge with per-member visibility
- Detects binary availability on session start and warns about missing tools
- Documents the tools in README.md

## Members

| Member | Purpose | Install |
|--------|---------|---------|
| RTK | CLI proxy that compresses command output by 60-90% | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) |
| Serena | LSP-powered code intelligence (symbol nav, semantic search) | [oraios/serena](https://github.com/oraios/serena) |
| mcp2cli | Converts MCP tool schemas to CLI commands, 96-99% discovery savings | [knowsuchagency/mcp2cli](https://github.com/knowsuchagency/mcp2cli) |

## State

Stored in `workflow.json` under a `tk_saver` key:

```json
{
  "tk_saver": {
    "enabled": true,
    "members": {
      "rtk": true,
      "serena": true,
      "mcp2cli": true
    }
  }
}
```

When the key doesn't exist (fresh project), TkSaver is considered inactive and hidden from the statusline.

## `/tks` Command

File: `plugin/commands/tks.md` (copied to `.claude/commands/` by setup.sh).
Uses `disable-model-invocation: true` to run as raw shell.

### Subcommands

| Command | Effect |
|---------|--------|
| `/tks` | Print status table |
| `/tks on` | Enable master toggle |
| `/tks off` | Disable master toggle |
| `/tks rtk on` | Enable RTK member |
| `/tks serena off` | Disable Serena member |
| `/tks mcp2cli on` | Enable mcp2cli member |
| `/tks status` | Same as no-args |

### Status output

When master ON:

```
[TkSaver] Token Saver: ON
  RTK        : ON  (binary: found)
  Serena     : ON  (binary: not found - install: https://github.com/oraios/serena)
  mcp2cli    : OFF (binary: found)
```

When master OFF:

```
[TkSaver] Token Saver: OFF
  RTK        : on  (inactive - master toggle off)
  Serena     : on  (inactive - master toggle off)
  mcp2cli    : off (inactive - master toggle off)
```

The command sources `settings.sh` for state read/write.

## Statusline Badge

Added as a new segment on line 2 after Claude-Mem, separated by the same dim `│` (Unicode box-drawing) divider used between existing segments.

### States

| Condition | Display |
|-----------|---------|
| Master ON, all members active+found | `TkSaver [R-S-M]` — all letters cyan |
| Master ON, partial | `TkSaver [R-S-M]` — active+found in cyan, disabled/missing in dim |
| Master OFF | `TkSaver x` — entire segment dim |
| Key absent from workflow.json | Segment hidden entirely |

### Colors

- Active+found members: **cyan** (same as branch/skill indicators)
- Disabled or binary-not-found members: **dim**
- Master on indicator: **cyan**
- Master off: **dim**

No green is used (red/green daltonism constraint).

## setup.sh Detection

When `tk_saver.enabled` is `true` in `workflow.json`, setup.sh prints a detection line during session start:

```
TkSaver: RTK found, Serena not installed, mcp2cli found
```

Binary detection via `command -v rtk`, `command -v serena`, `command -v mcp2cli`.

If tk_saver is off or the key doesn't exist, nothing is printed.

No auto-installation.

## settings.sh Extensions

New functions added to `plugin/scripts/infrastructure/settings.sh`:

- `get_tk_saver_enabled` — returns `true`/`false`, defaults to `false` if key absent
- `set_tk_saver_enabled <true|false>` — sets `tk_saver.enabled`
- `get_tk_saver_member <name>` — returns `true`/`false` for a specific member
- `set_tk_saver_member <name> <true|false>` — sets `tk_saver.members.<name>`

## README.md Updates

New section added under existing features:

**Token Saver (`/tks`)** — toggle-based package that reduces token consumption via external tools.

Table with member name, description, and install link.

Usage line: `/tks on|off`, `/tks <member> on|off`, `/tks status`.

Three tools added to the sources/tools list.

## Files Changed (Approach A)

| File | Change |
|------|--------|
| `plugin/commands/tks.md` | New — slash command |
| `plugin/scripts/infrastructure/settings.sh` | Extended — tk_saver getters/setters |
| `plugin/statusline/statusline.sh` | Extended — TkSaver badge segment |
| `plugin/scripts/setup.sh` | Extended — binary detection on session start |
| `README.md` | Extended — TkSaver section and sources |

## Approach B — Future Enforcement (GitHub Issue)

To be saved as a GitHub issue for later implementation:

- **RTK hook management**: setup.sh installs/removes RTK's PreToolUse hook based on tk_saver state
- **mcp2cli bash guard rules**: pre-tool-bash-guard.sh blocks write-like mcp2cli subcommands (create, update, delete, post, put, patch) unless explicitly enabled via `/tks mcp2cli writes on`
- **mcp2cli discovery-first coaching**: post-tool-coaching.sh nudges when mcp2cli tool is called without prior `mcp2cli --list` discovery in the session
- **mcp2cli local-code blocking**: bash guard blocks mcp2cli when server name matches code/filesystem patterns, nudges to use Serena or native tools
