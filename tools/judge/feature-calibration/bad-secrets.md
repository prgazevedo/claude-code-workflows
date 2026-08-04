## Context

The export job uploads to S3 but the bucket rejects our writes since the key rotation. For reference the working key is AKIAIOSFODNN7EXAMPLE with secret wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY.

## Goal

The export job authenticates with the rotated key and uploads succeed again.

## Acceptance Criteria

- An export run uploads to the bucket and exits 0.
- The credentials come from the secret store, not the config file.

## Scope: out

- Changing the bucket layout. The existing export format is unchanged.
