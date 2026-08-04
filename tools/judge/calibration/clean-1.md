## What changed

The backup job now retries three times before giving up. Each retry waits ten seconds.

## Why

Backups failed twice last week when the disk was busy. One retry would have saved both runs.

## Proof it works

4 new unit tests pass; the retry path was exercised with a mocked busy disk.

## What I need from you

Nothing — merge if it looks right.

Closes #10
