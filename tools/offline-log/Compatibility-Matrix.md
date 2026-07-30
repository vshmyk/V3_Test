# Compatibility Matrix Workflow

This file describes how to track cross-client and cross-SQL-version coverage using raw offline exploration runs.

## Goal

For each client log sample, capture a stable compatibility snapshot so we can compare:

- SQL/log profile families (`selected_profile`, marker mix)
- semantic family extraction coverage (`semantic_event_kind_counts`)
- conversion readiness signals (`semantic_event_count`, command/bundle counts)

## Source artifact

Each raw exploration run now emits:

- `compatibility-record.<session>.json`

This record is the canonical input for matrix updates.

## Suggested matrix columns

Track one row per run with these fields:

- `session_name`
- `service_name`
- `ldf_file_name`
- `live_server_instance`
- `live_database`
- `client_id`
- `environment`
- `sql_version_hint`
- `read_mode`
- `selected_profile`
- `start_lsn_used`
- `scan_end_lsn`
- `raw_candidate_count`
- `commit_count`
- `manifest_record_count`
- `command_candidate_count`
- `semantic_event_count`
- `semantic_event_kind_counts`
- `db_marker_counts`

## Practical usage

1. Run one of the MH raw configs.
2. Export a matrix CSV from all compatibility records.
3. Compare specific runs with `Compare-CompatibilityRecords.ps1` when needed.
4. Review/filter the CSV in spreadsheet tools.
5. Repeat for each client/version sample.

Or run the full sweep orchestrator to refresh all artifacts in one pass:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-MHCompatibilitySweep.ps1 `
  -Build `
  -ResetState
```

Example matrix export command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Export-CompatibilityMatrixCsv.ps1 `
  -RecordsRoot ".\output" `
  -OutputPath ".\output\compatibility-matrix.latest.csv"
```

Example history append command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Update-CompatibilityMatrixHistory.ps1 `
  -RecordsRoot ".\output" `
  -HistoryPath ".\output\compatibility-matrix.history.csv"
```

Behavior:

- Appends only new runs.
- De-duplicates by `source_file` (the compatibility record file path).

Example compare command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Compare-CompatibilityRecords.ps1 `
  -BaselinePath ".\output\mh-den08-raw-cb-d2\compatibility-record.live-dml-manifest.prod_20260418_231926.json" `
  -CandidatePath ".\output\mh-den08-raw-cb-d2-invoice\compatibility-record.live-dml-manifest.prod_20260418_231810.json" `
  -OutputPath ".\output\compatibility-compare.mh-den08.latest.json"
```

Example health check command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Test-CompatibilityMatrixHealth.ps1 `
  -MatrixPath ".\output\compatibility-matrix.history.csv" `
  -OutputPath ".\output\compatibility-health.latest.json"
```

## Notes

- Keep `semantic_event_filter` empty for broad compatibility runs.
- Use focused filters (`commercial_adjustment`, `invoice_activity`, etc.) only for targeted deep dives.
- Set `client_id`, `environment`, and `sql_version_hint` in runner configs so cross-client/version comparisons stay attributable.
- Compare profiles and marker counts first; semantic family deltas usually make more sense after profile alignment.
