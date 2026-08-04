---
description: Show open GitHub issues with date and type labels
allowed-tools: Bash
---

List open GitHub issues for the current repository.

## Usage

- `/issues` — list open issues (default)
- `/issues closed` — list recently closed issues (last 20)
- `/issues <number>` — show details of a specific issue

## Execution

Parse `$ARGUMENTS` and run the appropriate subcommand.

1. If no argument or empty, list open issues:

```bash
gh issue list --state open --json number,title,labels,createdAt --limit 50
```

Format as a table:

```
[Issues] Open Issues (N)
#   | Type        | Title                                    | Opened
41  | bug         | slash commands break after plugin update  | 2026-05-31
40  | feature     | GH Issues as source of truth              | 2026-05-31
```

- **Type** column: extract from labels — use the first label whose name is one of: `bug`, `feature`, `enhancement`. If none match, leave blank.
- **Opened** column: format `createdAt` as `YYYY-MM-DD`.
- Sort by issue number descending (newest first, which is the default from `gh`).

2. If argument is `closed`, list recently closed issues:

```bash
gh issue list --state closed --json number,title,labels,createdAt,closedAt --limit 20
```

Format as:

```
[Issues] Recently Closed Issues (N)
#   | Type        | Title                                    | Opened     | Closed
38  | bug         | some fixed bug                           | 2026-05-28 | 2026-05-30
```

3. If argument is a number, show that issue's details:

```bash
gh issue view <number> --json number,title,state,labels,createdAt,body
```

Format as:

```
[Issue #<number>] <title>
State: <open/closed>  |  Type: <label>  |  Opened: <date>

<body content>
```

4. If argument is anything else, report: "Unknown argument. Use `/issues`, `/issues closed`, or `/issues <number>`."
