## What changed

The `parse_config` function now rejects unknown keys with a named error. Callers see which key failed in the message.

## Why

A typo in one config key cost an hour of debugging on 2026-07-30. A named error would have shown it at once.

## Proof it works

not tested

## What I need from you

A decision: should unknown keys warn instead of erroring in dev mode?

Closes #11
