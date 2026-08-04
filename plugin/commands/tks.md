---
description: Token Saver — toggle RTK, Serena, mcp2cli for token reduction
allowed-tools: Bash
---

Manage the TkSaver package. Controls which token-saving tools are active.

## Usage

- `/tks` — show current status
- `/tks on` — enable master toggle (all members active)
- `/tks off` — disable master toggle
- `/tks rtk on` / `/tks rtk off` — toggle RTK member
- `/tks serena on` / `/tks serena off` — toggle Serena member
- `/tks mcp2cli on` / `/tks mcp2cli off` — toggle mcp2cli member
- `/tks status` — same as no-args

## Execution

Parse `$ARGUMENTS` and run the appropriate commands.

1. If no argument or `status`, gather state and report:

```bash
ENABLED=$("${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" get_tk_saver_enabled)
RTK=$("${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" get_tk_saver_member rtk)
SERENA=$("${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" get_tk_saver_member serena)
MCP2CLI=$("${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" get_tk_saver_member mcp2cli)
echo "master=$ENABLED rtk=$RTK serena=$SERENA mcp2cli=$MCP2CLI"
```

Then check binary availability:

```bash
command -v rtk && echo "rtk_bin=found" || echo "rtk_bin=missing"
command -v serena && echo "serena_bin=found" || echo "serena_bin=missing"
command -v mcp2cli && echo "mcp2cli_bin=found" || echo "mcp2cli_bin=missing"
```

Present a formatted status table:

```
[TkSaver] Token Saver: ON/OFF
  RTK        : ON/OFF  (binary: found/not found)
  Serena     : ON/OFF  (binary: found/not found)
  mcp2cli    : ON/OFF  (binary: found/not found)
```

When master is OFF, show member states as lowercase with "(inactive - master toggle off)".
When a binary is not found, append install link:
- RTK: https://github.com/rtk-ai/rtk
- Serena: https://github.com/oraios/serena
- mcp2cli: https://github.com/knowsuchagency/mcp2cli

2. If argument is `on`:

```bash
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_enabled true
```

If the tk_saver key didn't exist before, also initialize all members to true:

```bash
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_member rtk true
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_member serena true
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_member mcp2cli true
```

Report: "Token Saver **enabled**. All members active."

3. If argument is `off`:

```bash
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_enabled false
```

Report: "Token Saver **disabled**."

4. If argument is `rtk on`, `rtk off`, `serena on`, `serena off`, `mcp2cli on`, or `mcp2cli off`:

```bash
"${CLAUDE_SKILL_DIR}/../scripts/workflow-cmd.sh" set_tk_saver_member "<member>" "<true|false>"
```

Report: "`<Member>` set to **on/off**."

5. If argument is anything else, report: "Unknown argument. Use `on`, `off`, `status`, or `<member> on|off` (members: rtk, serena, mcp2cli)."
