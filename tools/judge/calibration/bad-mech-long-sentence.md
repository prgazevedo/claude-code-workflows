## What changed

The exporter writes one file per table, and because the old code opened every file at the start of the run and kept all of them open until the very end, runs with many tables could exhaust the file handle limit on smaller machines.

## Why

Two export runs died on the laptop last week. Each had over 200 tables.

## Proof it works

3 new unit tests pass.

## What I need from you

Nothing — merge if it looks right.

Closes #12
