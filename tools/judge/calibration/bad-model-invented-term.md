## What changed

Uploads now go through a freshness gate before storage. The freshness gate drops files older than thirty days.

## Why

Old files clogged the review queue twice in July. Dropping them keeps the queue current.

## Proof it works

2 new unit tests pass.

## What I need from you

Nothing — merge if it looks right.

Closes #17
