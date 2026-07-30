# AOtransact Production Readiness Scorecard

This file tracks the current assessed status of the AOtransact converter against the production-readiness checklist.

Status values:
- `Done`
- `Partial`
- `Not Started`
- `Blocked`

Overall current status:
- `Validated Prototype` moving toward `Pre-Production`

## Summary

| Area | Status | Notes |
| --- | --- | --- |
| Correctness | Partial | Strong results on exercised tables, but not yet proven across a broad supported scope. |
| Update Safety | Partial | Hybrid `UPDATE` vs `DELETE+INSERT` exists, but policy is not yet frozen as a release contract. |
| Key Resolution | Partial | 2-key, 3-key, 4-key, and some mixed-PK paths work; generic coverage is not yet proven. |
| Live Read Budget | Partial | Counters and reduction work exist, but formal run-mode guarantees and budgets are not frozen. |
| Incremental LSN Handling | Partial | Bootstrap, saved LSN reuse, and no-op short-circuit exist; needs harder validation and recovery rules. |
| Output Contract | Partial | `.trn` output is usable, but the contract is not yet formally versioned/frozen. |
| Regression Harness | Partial | We have repeatable artifacts and scenarios, but not a formal automated pass/fail suite. |
| Test Data Generation | Partial | Table-aware tuning exists for some tables; generic mutation selection is still weak. |
| Performance | Partial | Converter can be very fast; production-like scale and repeatability still need proof. |
| Observability | Partial | Timings and counters exist; unresolved/fallback taxonomy and reporting need hardening. |
| Failure Handling | Partial | Many failure paths are explicit, but production-grade error handling is incomplete. |
| Supported Scope | Not Started | Supported/unsupported table classes and SQL Server version policy are not yet documented. |

## Evidence

### 1. Correctness

Status: `Partial`

Evidence in favor:
- 6-table rerun after 4-key fix: `5999/6000`, `0 unresolved`, `1 skipped internal`
  - [fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn](/c:/Users/vshmyk/AOprojects/AOtransact/fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn)
- `CHSC_QUOTELINE` tuned blended run achieved `1000/1000`
- Mixed-PK probe on `CHSC_QUOTEDISTRIBUTORCONTACT` resolved cleanly

Why not `Done`:
- broader table coverage is not yet proven
- synthetic blended failures have still occurred due to weak mutation selection

### 2. Update Safety

Status: `Partial`

Evidence in favor:
- hybrid update mode exists in compiled converter
- high-confidence cases emit true `UPDATE`
- fallback path to `DELETE+INSERT` exists

Why not `Done`:
- confidence policy is not yet frozen as a release rule
- output policy is not yet documented as a stable contract

### 3. Key Resolution

Status: `Partial`

Evidence in favor:
- 4-key fix eliminated the `CHSC_POLINE_HISTORY` bottleneck
- mixed-PK resolver was validated for `CHSC_QUOTEDISTRIBUTORCONTACT`
- compiled converter supports 2/3/4 key and selected mixed-PK patterns

Why not `Done`:
- generic coverage across more table shapes is still unproven
- we still rely on special-case strategy by table shape, not yet a fully generalized model

### 4. Live Read Budget

Status: `Partial`

Evidence in favor:
- live-read counters exist in compiled converter
- normal runs have shown low call counts in good scenarios
- live DB usage has been reduced heavily from earlier versions

Why not `Done`:
- no frozen run-mode guarantees yet (`offline`, `hybrid`, `live-assisted`)
- no formal max budget by transaction volume and scenario

### 5. Incremental LSN Handling

Status: `Partial`

Evidence in favor:
- `BootstrapFirstRun` logic exists
- last-LSN reuse exists
- no-op short-circuit exists when head LSN is unchanged
- documented in [README.md](/c:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/README.md)

Why not `Done`:
- corruption recovery and duplicate replay handling are not yet fully validated
- scope mismatch behavior is present in design but not yet fully proven as a hardened release behavior

### 6. Output Contract

Status: `Partial`

Evidence in favor:
- `.trn` output structure is stable enough for current testing
- unresolved and quarantine concepts exist in the PowerShell pipeline
- compiled converter emits reproducible transaction output

Why not `Done`:
- no formal versioned contract document yet
- no consumer-facing stability promise yet

### 7. Regression Harness

Status: `Partial`

Evidence in favor:
- repeatable manifest-based test runs exist
- per-run artifacts exist in `output`
- we have known benchmark scenarios and comparison points

Why not `Done`:
- no automated pass/fail harness
- no canonical regression suite with locked expected counts and thresholds

### 8. Test Data Generation

Status: `Partial`

Evidence in favor:
- tuned mutation profiles fixed `CHSC_QUOTELINE`
- table-aware mutation strategy clearly improves results

Why not `Done`:
- generic mutation logic still produces weak/no-op updates on some tables
- not all exercised tables have a stable mutation profile

### 9. Performance

Status: `Partial`

Evidence in favor:
- compiled converter has demonstrated very fast runs
- `CHSC_POLINE_HISTORY` bottleneck was fixed by 4-key handling
- converter-only timings can be in low seconds for thousands of transactions

Why not `Done`:
- target throughput is not yet proven repeatedly under broader production-like mixes
- performance under fallback-heavy scenarios is not fully characterized

### 10. Observability

Status: `Partial`

Evidence in favor:
- phase timings exist
- counters exist
- machine-readable run summaries exist in JSON

Why not `Done`:
- unresolved/fallback reason taxonomy is not yet complete
- reporting format for production support is not yet finalized

### 11. Failure Handling

Status: `Partial`

Evidence in favor:
- missing manifest and metadata handling is explicit
- unsupported PK situations generally fail clearly rather than silently
- pipeline scripts emit summary artifacts and status markers

Why not `Done`:
- partial success and retry/recovery behavior are not yet codified as production policy
- not all failure classes are normalized into machine-readable error categories

### 12. Supported Scope

Status: `Not Started`

What is missing:
- supported table classes list
- unsupported/partial-support list
- SQL Server version support statement
- run-mode support statement
- assumptions around schema stability and metadata usage

## Hard Gate Status

| Release Gate Item | Status |
| --- | --- |
| Correctness | Partial |
| Update Safety | Partial |
| Key Resolution | Partial |
| Incremental LSN Handling | Partial |
| Regression Harness | Partial |
| Output Contract | Partial |

Production-ready assessment:
- `No`

## Recommended Next Actions

1. Build an automated regression suite around the current exercised tables and known-good manifests.
2. Freeze and document the hybrid `UPDATE` vs `DELETE+INSERT` policy.
3. Define explicit operating modes: `offline`, `hybrid`, `live-assisted`.
4. Publish a versioned `.trn` output contract.
5. Replace generic mutation generation with stable table-aware regression mutation profiles.
6. Document supported table classes and SQL Server scope.

