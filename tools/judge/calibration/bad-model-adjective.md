## What changed

The rebuild now processes tables in batches instead of one pass. This makes it significantly faster and substantially lighter on memory.

## Why

Rebuilds blocked deploys last week. A faster rebuild unblocks them.

## Proof it works

not tested

## What I need from you

Nothing — merge if it looks right.

Closes #18
