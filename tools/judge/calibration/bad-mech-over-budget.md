## What changed

The queue worker logs each job id. It also logs the outcome. A third log line records the timing. A fourth records the retry count.

## Why

Job failures were invisible last week. Logs now show each one.

## Proof it works

1 new unit test passes.

## What I need from you

Nothing — merge if it looks right.

Closes #14
