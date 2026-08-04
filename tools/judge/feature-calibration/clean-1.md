## Context

The backup job logs to stdout only, so failures are found days late. The notifier service already sends alerts for disk events.

## Goal

Backup failures reach the existing notifier within a minute of the job exiting non-zero.

## Acceptance Criteria

- A failed backup run produces one alert containing the job name and exit code.
- A successful run produces no alert.
- Three failures in a row produce one escalation alert, not three duplicates.

## Scope: out

- Changing the notifier service itself; this only adds a new event source to it.
