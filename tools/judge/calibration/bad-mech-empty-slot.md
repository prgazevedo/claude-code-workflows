## What changed

The health check endpoint now reports the database connection state. Monitors can see outages directly.

## Why

The 502 on 2026-07-28 took an hour to trace to the database. This check would have shown it in seconds.

## Proof it works

<!-- Test output, eval verdict, or the words "not tested". -->

## What I need from you

Nothing — merge if it looks right.

Closes #15
