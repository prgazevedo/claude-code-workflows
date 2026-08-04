## Context

Note IDs are sequential integers, which leaks volume and makes URLs guessable.

## Goal

Notes use random 12-character IDs everywhere.

## Acceptance Criteria

- New notes get a random 12-character ID.
- A note URL with a random ID resolves to the note.
- Sequential IDs no longer appear in any new URL.
