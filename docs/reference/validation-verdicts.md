# Validation Verdict Registry

The single vocabulary for validator agents and gates. Adopted from the
agentic-sdlc comparative analysis (#46), with the registry it lacked.
The principle: **degrade honestly — never as a pass.** A check that
cannot run gets a labeled verdict, never a skip and never a PASS.

| Verdict | Meaning | Counts as pass? |
|---|---|---|
| `PASS` | Demonstrated working through the runtime surface this session, output recorded | yes |
| `FAIL` | Demonstrated not working, or missing | no |
| `BLOCKED-BY-ENV` | The surface exists but cannot be driven from here; the exact confirming command is stated | no |
| `NO-RUNTIME-SURFACE` | The change has no drivable surface (pure docs, type-only), one-line justification | no |
| `NO-TEST-SUITE` | The project has no detectable test suite, so the tests-passing gate could not run | no |
| `MANUAL` | Requires user action to verify; flagged, not blocking | no |
| `TO MONITOR` | Long-term metric, not verifiable now | no |

Consumers: `outcome-validator`, `plan-validator`, `boundary-tester`
prompts, and the IMPLEMENT exit gate (`gate-checks.sh`), which records
`NO-TEST-SUITE` in workflow state instead of silently skipping the
`tests_passing` milestone.

## The fresh-evidence rule

No `PASS` without having run the command **this session** and read its
output. Not sufficient: a previous run, CI on another commit, an
implementer's report, or "should be fine". Each claim pairs with what
proves it and what explicitly does not:

| Claim | Requires | Not sufficient |
|---|---|---|
| Lint clean | the lint command exits 0 this session | "should be fine" |
| Unit pass | this session's run reports 0 failures | a previous run |
| Bug fixed | the original symptom now passes | the code changed |

## The untested-behaviors ledger

Every "cannot be tested" claim names a concrete structural obstacle and
is recorded in the validation artifact: behavior · obstacle · what
would verify it. A claim living only in a code comment or the PR text
does not exist.
