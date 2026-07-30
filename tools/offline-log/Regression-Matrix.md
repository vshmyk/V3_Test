# AOtransact Regression Matrix

This matrix defines the regression scenarios that should be maintained and rerun as the converter evolves.

Purpose:
- make correctness and performance claims repeatable
- define pass/fail expectations
- separate converter failures from generator/test scaffolding failures

Status values:
- `Proven`
- `Partially Proven`
- `Not Proven`

## Core Rules

- Prefer preserved manifests for converter-only regression when possible.
- Separate `generator regressions` from `converter regressions`.
- Record:
  - manifest path
  - output path
  - expected user DML counts
  - unresolved count
  - skipped internal count
  - live-read count
  - total converter time

## Regression Scenarios

| ID | Scenario | Scope | Expected Result | Thresholds | Current Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| R1 | Single-table updates | `oasis.CHSC_QUOTELINE`, `100 UPDATE` | `100/100`, `0 unresolved` | counts only, timing not locked | Proven | Prior tuned runs and manifest-based validation |
| R2 | Single-table blended | `oasis.CHSC_QUOTELINE`, `334 U / 333 D / 333 I` | `1000/1000`, `0 unresolved`, `0 skipped internal` | `live_calls <= 4`, `total_run_ms <= 1500` | Proven | [fast.ql_blended_1000_tuned_20260311_203524.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.ql_blended_1000_tuned_20260311_203524.trn) |
| R3 | 4-key PK updates | `oasis.CHSC_POLINE_HISTORY`, `1000 UPDATE` | `1000/1000`, `0 unresolved`, no physloc fallback | `live_calls <= 4`, `total_run_ms <= 1500`, `fetch_physloc=0` | Proven | [fast.chsc_poline_history.key4_test.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.chsc_poline_history.key4_test.trn) |
| R4 | Mixed-PK updates | `oasis.CHSC_QUOTEDISTRIBUTORCONTACT`, `20 UPDATE` | `20/20`, `0 unresolved` | `live_calls <= 4`, `total_run_ms <= 1000` | Proven | [fast.qdc_mixedpk_probe.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.qdc_mixedpk_probe.trn) |
| R5 | 6-table update-only | `CHSC_PO`, `CHSC_POLINE`, `CHSC_POLINE_HISTORY`, `CHSC_PROJECT`, `CHSC_QUOTELINE`, `CHSC_QUOTE`, `1000 UPDATE each` | all user updates converted, near-zero skipped internal | `ok >= 5999`, `unresolved = 0`, `skipped_internal <= 1`, `live_calls <= 25`, `total_run_ms <= 2500` | Proven | [fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn](/c:/Users/vshmyk/AOprojects/AOtransact/fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn) |
| R6 | 6-table generic blended | same 6 tables, generic mutation selection | expected to expose generator weakness, not silently pass | negative control only | Proven as negative control | [blend6x1000_fresh_20260311_200725.run.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/blend6x1000_fresh_20260311_200725.run.json) |
| R7 | 6-table tuned blended | same 6 tables, tuned mutation profiles | all intended user DML converted, `0 unresolved` | `ok = 6000`, `unresolved = 0`, `insert = 1998`, `update = 2004`, `delete = 1998`, `fetch_physloc = 0`; selected internal companion rows may remain | Proven | [fast.r7_tuned_blended_20260311_225435.final.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.r7_tuned_blended_20260311_225435.final.trn) |
| R8 | Insert-only | selected exercised tables, `500 INSERT each` | all user inserts converted | counts only, suite not yet canonical | Partially Proven | inserts work in blended runs, but no single canonical insert-only suite yet |
| R9 | Delete-only | selected exercised tables, `500 DELETE each` | all user deletes converted | counts only, suite not yet canonical | Partially Proven | deletes work in blended runs, but no single canonical delete-only suite yet |
| R10 | Incremental LSN bootstrap | first run against source with no state | capture head LSN, no historical replay | `bootstrap_only=true`, `no_op_short_circuit=false`, valid `state_last_lsn_saved` | Proven | [r10r12_flux_quoteline_artifacts_20260311.bootstrap.summary.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/r10r12_flux_quoteline_artifacts_20260311.bootstrap.summary.json) |
| R11 | Incremental LSN follow-up | second run starting from saved state after new source DML | only new transactions emitted | `manifest_record_count=1`, `trn_statements=1`, saved LSN advances, `row_lookup_live_reads <= 1`, `total_ms <= 2000` | Proven | [session.r11_flux_quoteline_incremental_20260311.summary.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/session.r11_flux_quoteline_incremental_20260311.summary.json) |
| R12 | No-op short-circuit | unchanged head LSN | no shadow/decode work, explicit no-op marker | `no_op_short_circuit=true`, `manifest_record_count=0`, latest LSN equals start LSN | Proven | [r10r12_flux_quoteline_artifacts_20260311.noop.summary.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/r10r12_flux_quoteline_artifacts_20260311.noop.summary.json) |
| R13 | Output contract stability | same manifest, same converter config | deterministic `.trn` output shape | requires canonical diff check | Partially Proven | observed in practice, not yet frozen/versioned |
| R14 | Low live-read mode | preserved manifest, converter-only replay | low and classified live-read count | thresholds vary by scenario; not yet standardized | Partially Proven | counters exist, budget not frozen |
| R15 | Performance target small | `~6000` user DML on fast path | low-seconds converter runtime | `total_run_ms <= 2500` on canonical 6-table update-only artifact | Proven | post-key4-fix 6-table rerun |
| R16 | Performance target production-like | `15000+` user DML mixed workload | target throughput consistently met | target not yet repeatedly demonstrated | Not Proven | no repeated production-like pass yet |

## Canonical Table Set

Primary exercised table set:
- `oasis.CHSC_PO`
- `oasis.CHSC_POLINE`
- `oasis.CHSC_POLINE_HISTORY`
- `oasis.CHSC_PROJECT`
- `oasis.CHSC_QUOTELINE`
- `oasis.CHSC_QUOTE`

Extended table set:
- `oasis.CHSC_QUOTEDISTRIBUTORCONTACT`
- `oasis.CHSC_INVOICELINE`

## Current Known-Good Evidence

### A. 6-table update-focused fast path

- output: [fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn](/c:/Users/vshmyk/AOprojects/AOtransact/fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn)
- result:
  - `5999/6000`
  - `0 unresolved`
  - `1 skipped internal`
  - `live_calls = 25`
  - `total_run_ms = 2244`
- value:
  - strong evidence for converter correctness on the main exercised set

### B. `CHSC_QUOTELINE` tuned blended run

- result:
  - `1000/1000`
  - `334 UPDATE`
  - `333 DELETE`
  - `333 INSERT`
  - `0 unresolved`
  - `live_calls = 4`
  - `total_run_ms = 1212`
- value:
  - proves that generator tuning can eliminate false negatives for this table

### C. `CHSC_POLINE_HISTORY` 4-key fix

- result:
  - `1000/1000`
  - `0 unresolved`
  - no physloc fallback needed in validated run
  - `live_calls = 4`
  - `total_run_ms = 1219`
- value:
  - proves the key4 structural fix

### D. Mixed-PK probe

- table:
  - `oasis.CHSC_QUOTEDISTRIBUTORCONTACT`
- result:
  - `20/20`
  - `0 unresolved`
  - `live_calls = 4`
  - `total_run_ms = 728`
- value:
  - proves at least one mixed-PK strategy works

## Canonical Artifacts

These should be treated as the current reference artifacts for converter regression.

| Scenario | Manifest | Output |
| --- | --- | --- |
| 6-table update-only | [live-dml-manifest.flux6_1k_decode_20260311_160031.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.flux6_1k_decode_20260311_160031.json) | [fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn](/c:/Users/vshmyk/AOprojects/AOtransact/fast.flux6_1k_decode_20260311_160031.hybrid_update.key4fix.trn) |
| `CHSC_QUOTELINE` tuned blended | [live-dml-manifest.ql_blended_1000_tuned_20260311_203524.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.ql_blended_1000_tuned_20260311_203524.json) | [fast.ql_blended_1000_tuned_20260311_203524.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.ql_blended_1000_tuned_20260311_203524.trn) |
| `CHSC_POLINE_HISTORY` key4 | [live-dml-manifest.flux6_1k_decode_20260311_160031.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.flux6_1k_decode_20260311_160031.json) | [fast.chsc_poline_history.key4_test.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.chsc_poline_history.key4_test.trn) |
| mixed-PK probe | [live-dml-manifest.qdc_mixedpk_probe.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.qdc_mixedpk_probe.json) | [fast.qdc_mixedpk_probe.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.qdc_mixedpk_probe.trn) |
| negative control, generic blended | [live-dml-manifest.blend6x1000_fresh_20260311_200725.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.blend6x1000_fresh_20260311_200725.json) | [fast.blend6x1000_fresh_20260311_200725.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.blend6x1000_fresh_20260311_200725.trn) |
| tuned blended canonical proof | [live-dml-manifest.r7_tuned_blended_20260311_225435.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.r7_tuned_blended_20260311_225435.json) | [fast.r7_tuned_blended_20260311_225435.final.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.r7_tuned_blended_20260311_225435.final.trn) |
| bootstrap baseline | n/a | [r10r12_flux_quoteline_artifacts_20260311.bootstrap.summary.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/r10r12_flux_quoteline_artifacts_20260311.bootstrap.summary.json) |
| no-op short-circuit | n/a | [r10r12_flux_quoteline_artifacts_20260311.noop.summary.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/r10r12_flux_quoteline_artifacts_20260311.noop.summary.json) |
| incremental follow-up | [live-dml-manifest.r11_flux_quoteline_incremental_20260311.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.r11_flux_quoteline_incremental_20260311.json) | [hybrid.r11_flux_quoteline_incremental_20260311.chsc_quoteline.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/hybrid.r11_flux_quoteline_incremental_20260311.chsc_quoteline.trn) |

## Known Negative Controls

These are valuable because they expose weaknesses:

### N1. 6-table generic blended run

- [blend6x1000_fast_20260311_200022.run.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/blend6x1000_fast_20260311_200022.run.json)
- [blend6x1000_fresh_20260311_200725.run.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/blend6x1000_fresh_20260311_200725.run.json)

Observed issue:
- converter had `0 unresolved`
- but generated logged mix was weak on some tables because mutation choice was poor

Use:
- keep these runs as proof that generic mutation generation is not yet sufficient

## Latest R7 Evidence

- manifest: [live-dml-manifest.r7_tuned_blended_20260311_225435.json](/c:/Users/vshmyk/AOprojects/AOtransact/output/live-dml-manifest.r7_tuned_blended_20260311_225435.json)
- output: [fast.r7_tuned_blended_20260311_225435.final.trn](/c:/Users/vshmyk/AOprojects/AOtransact/output/fast.r7_tuned_blended_20260311_225435.final.trn)
- compiled converter result:
  - `total=6033`
  - `ok=6000`
  - `unresolved=0`
  - `skipped_internal=17`
  - `insert=1998`
  - `update=2004`
  - `delete=1998`
  - `live_calls=43`
  - `fetch_physloc=0`
  - `total_run_ms=7687`

Per-table:
- `CHSC_PO`: `1000/1000`
- `CHSC_POLINE`: `1000/1025`, `17 skipped internal companion rows`
- `CHSC_POLINE_HISTORY`: `1000/1000`
- `CHSC_PROJECT`: `1000/1000`
- `CHSC_QUOTELINE`: `1000/1000`
- `CHSC_QUOTE`: `1000/1000`

Current R7 blocker:
- no remaining user-DML blocker on the exercised 6-table tuned blended suite
- remaining selected extras are `CHSC_POLINE` companion rows, not user-DML misses

## Pass/Fail Threshold Guidance

### Converter correctness regressions

Fail if:
- `unresolved > 0` for a scenario previously proven clean
- user DML count falls below expected threshold without an approved explanation
- skipped internal rises materially in a previously stable scenario
- live-read count exceeds locked threshold for a proven scenario
- total runtime materially exceeds locked threshold for a proven scenario

### Generator regressions

Fail if:
- intended updates do not produce actual logged updates for a tuned table profile
- mutation profile becomes no-op or unstable

### Performance regressions

Fail if:
- converter-only runtime regresses by more than an agreed threshold on preserved-manifest runs
- live-read count materially increases on a previously stable scenario

## Next Matrix Expansions

1. Add canonical manifest paths for each proven scenario.
2. Add explicit expected live-read count ranges.
3. Add target timing envelope per scenario.
4. Promote `R8` and `R9` to proven status.
5. Add SQL Server version coverage rows once version support is formalized.
