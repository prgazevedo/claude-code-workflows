## Context

The export button saves notes as JSON only, and separately the login page still uses the old password rules.

## Goal

The export button offers CSV, and the login page enforces the new password policy with a strength meter.

## Acceptance Criteria

- A CSV choice appears next to the JSON one, with one row per note.
- Passwords under 12 characters are rejected at signup and change.
- The strength meter updates on every keystroke.

## Scope: out

- Other export formats. The existing JSON path and current sessions are unchanged.
