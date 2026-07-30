# AOtransact Production Readiness Checklist

This checklist defines the minimum pass/fail bar for calling the AOtransact converter production-ready.

Current working status:
- `Prototype`: surpassed
- `Validated Prototype`: largely true
- `Pre-Production`: partial
- `Production-Ready`: not yet

## 1. Correctness

Pass only if all are true:

- `100%` of intended user DML is present in output for regression scenarios
- `0` user transactions are misclassified as internal/system
- `0` internal/system transactions are emitted as user DML in accepted runs
- emitted PK predicates uniquely identify the target row
- statement order matches commit/LSN order requirements
- `INSERT`, `UPDATE`, and `DELETE` all pass independently
- blended multi-table runs pass independently of single-table runs

## 2. Update Safety

Pass only if all are true:

- true `UPDATE` is emitted only when confidence policy is satisfied
- fallback to `DELETE+INSERT` is deterministic and documented
- `NULL`, empty string, defaulted values, and unchanged columns are handled correctly
- wide/text-like columns do not silently degrade correctness
- confidence mode chosen for each update is recorded in output or metrics

## 3. Key Resolution

Pass only if all are true:

- 2-key tables validated
- 3-key tables validated
- 4-key tables validated
- mixed-type PK tables validated
- tables with nullable/non-leading business fields do not break key extraction
- no supported table requires ad hoc hard-coded field names beyond metadata-driven key handling

## 4. Live Read Budget

Pass only if all are true:

- every live DB query type is enumerated
- per-run counters exist for each live query category
- normal supported path has a defined max live-read budget
- fallback live reads are separately counted and classified
- a run can be labeled clearly as:
  - `offline`
  - `hybrid`
  - `live-assisted`

## 5. Incremental LSN Handling

Pass only if all are true:

- first-run bootstrap captures current head LSN correctly
- next run starts from saved LSN correctly
- no-op run short-circuit works when head LSN is unchanged
- state scope mismatch is detected and rejected
- corrupted/missing state can be recovered safely
- duplicate replay is either prevented or explicitly detectable

## 6. Output Contract

Pass only if all are true:

- `.trn` format is documented
- comments/metadata format is documented
- unresolved output handling is documented
- quarantine output handling is documented
- downstream replication process can consume output without ambiguity
- contract is versioned once frozen

## 7. Regression Harness

Pass only if all are true:

- repeatable single-table regression tests exist
- repeatable multi-table regression tests exist
- tests cover:
  - inserts
  - updates
  - deletes
  - blended runs
  - internal/system noise
  - incremental LSN runs
- each regression has expected:
  - DML counts
  - unresolved count
  - skipped internal count
  - live-read count range
  - timing envelope

## 8. Test Data Generation

Pass only if all are true:

- generator uses table-aware mutation profiles
- generated updates are guaranteed to produce real logged row changes
- generator avoids no-op updates
- generator safely preserves reinsertion data where needed
- generator output is reproducible enough for regression use

## 9. Performance

Pass only if all are true:

- benchmark scope is defined clearly:
  - source DB
  - table set
  - transaction mix
  - start/end LSN window
- measured end-to-end timings are repeatable
- measured converter-only timings are repeatable
- target throughput is met under production-like mixed workloads
- fallback-heavy runs are measured separately from normal runs

## 10. Observability

Pass only if all are true:

- every run emits machine-readable summary metrics
- unresolved rows are classified by reason
- fallback counts are broken down by reason
- per-table timing exists
- total rows / ok / unresolved / skipped internal are always emitted
- run artifacts are easy to tie back to source manifest/session

## 11. Failure Handling

Pass only if all are true:

- malformed manifest handling is explicit
- missing metadata handling is explicit
- unsupported table shape handling is explicit
- live DB unavailable fallback mode is explicit
- shadow copy / offline file read failures are explicit
- partial-success behavior is intentional, not accidental

## 12. Supported Scope

Pass only if all are true:

- supported table classes are listed
- unsupported/partial-support cases are listed
- required SQL Server versions are listed
- offline/hybrid/live-assisted operating modes are listed
- assumptions around metadata stability are listed

## Release Gate

Do not call AOtransact production-ready until these are satisfied:

1. `Correctness`
2. `Update Safety`
3. `Key Resolution`
4. `Incremental LSN Handling`
5. `Regression Harness`
6. `Output Contract`

These are the hard gate. Performance and observability matter, but correctness and repeatability come first.

## Recommended Internal Status Labels

Use these labels consistently in notes and run summaries:

- `Prototype`
- `Validated Prototype`
- `Pre-Production`
- `Production-Ready`

Current assessment:
- AOtransact is between `Validated Prototype` and `Pre-Production`

