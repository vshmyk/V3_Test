# Offline Transaction Collector

This tool reads committed transaction log rows from an attached offline database copy and exports filtered results for specific tables.

## What it returns

- Committed changes within a time window (default: last 15 minutes)
- Only target tables you provide (`schema.table` or `[schema].[table]`)
- Transaction metadata (`Transaction ID`, begin/commit time, SPID, LSN)
- Log payload hex (`rowlog0_hex` to `rowlog3_hex`)
- `reconstructed_sql_template` (equivalent DML template, not guaranteed original submitted SQL text)

## Script

`Get-CommittedTableTransactions.ps1`

Manifest-free MH quote-only shortcut:

`Run-MHDen08-QuoteLogScan.ps1`

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-MHDen08-QuoteLogScan.ps1 `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -Database "OASIS_MH" `
  -WindowMinutes 60 `
  -OutputPath ".\output\mh-den08.quote-only.logscan.json"
```

## MH semantic event outputs (raw offline exploration)

When `read_mode` is `raw_offline_exploration`, the runner now emits semantic artifacts in addition to raw records:

- `semantic-events.<session>.json`: extracted semantic events per command
- `semantic-event-recovery.<session>.json`: normalized family summaries and table recommendations
- `business-event-feed.<session>.json`: compact event feed for quick review
- `business-event-feed.<session>.csv`: spreadsheet-friendly feed export
- `compatibility-record.<session>.json`: per-run compatibility coverage snapshot (profile, filters, marker mix, event-family counts, and compatibility tags)

Compatibility tags (optional but recommended):

- `pipeline.client_id`: client/log source identifier (example: `MH-DEN08`)
- `pipeline.environment`: environment label (example: `prod`)
- `pipeline.sql_version_hint`: SQL Server version hint for the source log (example: `16.0.1150.1`)

Optional semantic filter:

- `pipeline.semantic_event_kinds` lets you keep only selected event families in semantic outputs.
- Supported families currently include:
  - `commercial_adjustment`
  - `invoice_activity`
  - `attachment_activity`
  - `history_activity`

Example focused runs:

```powershell
dotnet run --project .\tools\offline-log\aotransact-runner\AOtransact.Runner.csproj -c Release -- `
  --config .\tools\offline-log\runner.config.mh-den08.raw-cb-d2.commercial-adjustment.json --once

dotnet run --project .\tools\offline-log\aotransact-runner\AOtransact.Runner.csproj -c Release -- `
  --config .\tools\offline-log\runner.config.mh-den08.raw-cb-d2.invoice.json --once

dotnet run --project .\tools\offline-log\aotransact-runner\AOtransact.Runner.csproj -c Release -- `
  --config .\tools\offline-log\runner.config.mh-den08.raw-cb-d2.attachment.json --once
```

Compatibility comparison helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Compare-CompatibilityRecords.ps1 `
  -BaselinePath ".\output\mh-den08-raw-cb-d2\compatibility-record.live-dml-manifest.prod_20260418_231926.json" `
  -CandidatePath ".\output\mh-den08-raw-cb-d2-invoice\compatibility-record.live-dml-manifest.prod_20260418_231810.json" `
  -OutputPath ".\output\compatibility-compare.mh-den08.latest.json"
```

Compatibility matrix export helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Export-CompatibilityMatrixCsv.ps1 `
  -RecordsRoot ".\output" `
  -OutputPath ".\output\compatibility-matrix.latest.csv"
```

Compatibility history append helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Update-CompatibilityMatrixHistory.ps1 `
  -RecordsRoot ".\output" `
  -HistoryPath ".\output\compatibility-matrix.history.csv"
```

Compatibility health check helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Test-CompatibilityMatrixHealth.ps1 `
  -MatrixPath ".\output\compatibility-matrix.history.csv" `
  -OutputPath ".\output\compatibility-health.latest.json"
```

One-command MH compatibility sweep:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-MHCompatibilitySweep.ps1 `
  -Build `
  -ResetState
```

Fast orchestration-only check (reuses existing run outputs):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-MHCompatibilitySweep.ps1 `
  -SkipRuns
```

## Hybrid scripts (live manifest + offline raw LDF match)

- `Get-LiveCommittedDmlManifest.ps1`
- `Get-RawLdfHybridMatches.ps1`
- `Convert-HybridToTrn.ps1`
- `Run-HybridLdfCopyFromShadow.ps1`
- `Run-HybridLdfSingleSnapshotMultiTable.ps1`
- `Apply-TrnToTarget.ps1`
- `Export-ChscMetadataSnapshot.ps1`
- `Read-MdfRowByPhysLoc.ps1` (phase-1 offline MDF row reader by file/page/slot)
- `Read-MdfRowsFromManifest.ps1` (phase-1 bulk offline MDF row extractor from manifest page/slot pairs)
- `Decode-MdfRowHex.ps1` (phase-2 row-hex to column values decoder using metadata snapshot)

Hybrid example:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Get-LiveCommittedDmlManifest.ps1 `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -Database "OASIS_MH" `
  -Operations "DMLALL" `
  -Users "AGENCYONLINE\\vshmyk" `
  -WindowMinutes 360 `
  -Tables "oasis.CHSC_POLINE" `
  -OutputPath ".\output\live-dml-manifest.json"

powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Export-ChscMetadataSnapshot.ps1 `
  -ServerInstance "LOCALHOST\ERPLINK" `
  -Database "OASIS_MH" `
  -SchemaName "oasis" `
  -OutputPath ".\output\chsc_metadata.snapshot.json"

powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Get-RawLdfHybridMatches.ps1 `
  -LdfPath "E:\LDF_Shadow\OASIS_MH_log.ldf" `
  -ManifestPath ".\output\live-dml-manifest.json" `
  -OutputPath ".\output\raw-ldf-hybrid-matches.json"

powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Convert-HybridToTrn.ps1 `
  -ManifestPath ".\output\live-dml-manifest.json" `
  -HybridPath ".\output\raw-ldf-hybrid-matches.json" `
  -OutputPath ".\output\mh.trn" `
  -UndoOutputPath ".\output\mh.undo.trn" `
  -BeforeAfterJsonPath ".\output\mh.before_after.json" `
  -TargetTable "oasis.CHSC_POLINE" `
  -UpdateMode "adaptive" `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -Database "OASIS_MH" `
  -MetadataServerInstance "LOCALHOST\SQLEXPRESS" `
  -MetadataDatabase "OASIS_MH" `
  -MetadataSnapshotPath ".\output\chsc_metadata.snapshot.json" `
  -SqlUser "SaAdmin" `
  -SqlPassword "Admin"
```

Offline MDF row read (no attach, phase-1 utility):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Read-MdfRowByPhysLoc.ps1 `
  -MdfPath "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy160\DATA\Oasis\OASIS_FLUX.mdf" `
  -PageId "32728" `
  -SlotId 14 `
  -ExpectedFileId 1 `
  -OutputPath ".\output\mdf-row.sample.json"
```

Notes:
- This utility returns raw row bytes (`row_hex`) for a specific page/slot.
- It is designed as a building block for fully offline decode and does not perform column-level decoding yet.

Offline MDF bulk row extraction from manifest (no attach):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Read-MdfRowsFromManifest.ps1 `
  -ManifestPath ".\output\live-dml-manifest.sqlexpress_flux_100_capture_20260309_223807.json" `
  -MdfPath "\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy167\DATA\Oasis\OASIS_FLUX.mdf" `
  -TargetTable "oasis.CHSC_POLINE" `
  -OutputPath ".\output\offline-mdf-rows.chsc_poline.json"
```

Returns:
- resolved row bytes by `file/page/slot`
- unresolved row references with reason (`slot_oob`, `slot_norm`, etc.)
- page cache stats and elapsed time

Decode one offline row-hex into typed column values:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Decode-MdfRowHex.ps1 `
  -RowHex "0x3000..." `
  -MetadataSnapshotPath ".\output\chsc_metadata_flux.snapshot.json" `
  -TargetTable "oasis.CHSC_POLINE" `
  -OutputPath ".\output\decoded-row.sample.json"
```

One-shot safe runner (shadow -> copy LDF -> hybrid pipeline -> cleanup):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-HybridLdfCopyFromShadow.ps1 `
  -SourceDrive "E:" `
  -SnapshotDataPath "DATA\Oasis" `
  -LdfReadMode "direct" `
  -CopiedLdfPath "E:\AOexpress\Logs\OASIS_MH_log_shadow.ldf" `
  -LiveServerInstance "LOCALHOST\SQLEXPRESS" `
  -LiveDatabase "OASIS_MH" `
  -MetadataServerInstance "LOCALHOST\SQLEXPRESS" `
  -MetadataDatabase "OASIS_MH" `
  -MetadataSnapshotPath ".\output\chsc_metadata.snapshot.json" `
  -Tables "oasis.CHSC_POLINE","oasis.CHSC_PO" `
  -Operations "DMLALL" `
  -WindowMinutes 360 `
  -StatePath ".\output\HybridLastOffset.json" `
  -LockFilePath ".\output\HybridFlow.lock" `
  -MetricsPath ".\output\HybridRunMetrics.json" `
  -ManifestPath ".\output\live-dml-manifest.json" `
  -HybridMatchesPath ".\output\raw-ldf-hybrid-matches.json" `
  -HybridTrnPath ".\output\mh.trn" `
  -HybridUnresolvedTrnPath ".\output\mh.unresolved.trn" `
  -HybridQuarantineTrnPath ".\output\mh.quarantine.trn" `
  -UndoTrnPath ".\output\mh.undo.trn" `
  -BeforeAfterJsonPath ".\output\mh.before_after.json" `
  -OutputSuccessfulOnly $true `
  -GenerateUndo $true `
  -ExportBeforeAfter $true `
  -ApplyToTarget $true `
  -ApplyTargetServerInstance "LOCALHOST\SQLEXPRESS" `
  -ApplyTargetDatabase "OASIS_MH" `
  -ApplyResultPath ".\output\mh.apply.json" `
  -ApplyStopOnError $true `
  -ApplyWrapInTransaction $false `
  -TargetTable "oasis.CHSC_POLINE" `
  -UpdateMode "adaptive" `
  -ApplySafetyMode "strict"
```

`HybridTrnPath` now defaults to successful recoveries only, while:
- unresolved/template rows are written to `HybridUnresolvedTrnPath`
- strict-but-unsafe rows are written to `HybridQuarantineTrnPath`

Optional config-file mode (explicit CLI params still win):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-HybridLdfCopyFromShadow.ps1 `
  -ConfigPath ".\tools\offline-log\hybrid.config.sample.json"
```

Single-snapshot multi-table session (one shadow copy for all tables in same run):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-HybridLdfSingleSnapshotMultiTable.ps1 `
  -SourceDrive "E:" `
  -SnapshotDataPath "DATA\Oasis" `
  -LdfName "OASIS_FLUX_log.ldf" `
  -LiveServerInstance "LOCALHOST\ERPLINK" `
  -LiveDatabase "OASIS_FLUX" `
  -MetadataServerInstance "LOCALHOST\SQLEXPRESS" `
  -MetadataDatabase "OASIS_FLUX" `
  -MetadataSnapshotPath ".\output\chsc_metadata_flux.snapshot.json" `
  -Tables "oasis.CHSC_PO","oasis.CHSC_POLINE","oasis.CHSC_POLINE_HISTORY","oasis.CHSC_PROJECT","oasis.CHSC_QUOTELINE","oasis.CHSC_QUOTE" `
  -WindowMinutes 240 `
  -StatePath ".\output\LastOffset.json" `
  -BootstrapFirstRun $true `
  -ApplyToTarget $true `
  -ApplyTargetServerInstance "LOCALHOST\SQLEXPRESS" `
  -ApplyTargetDatabase "OASIS_FLUX" `
  -ApplySafetyMode "off" `
  -SqlUser "SaAdmin" `
  -SqlPassword "Admin"
```

Single-snapshot bootstrap/incremental behavior:

- If no `-StartLsn` is provided, script attempts to reuse `last_lsn` from `StatePath` for the same scope (`LiveServerInstance + LiveDatabase + table-set + filters + source signature`).
- If no reusable state exists and `-BootstrapFirstRun $true`, script captures current live head LSN, writes it to `StatePath`, writes a bootstrap summary, and exits without scanning historical transactions.
- On later runs with the same scope, script starts from the saved LSN and proceeds with normal flow.

High-throughput mode (extract/reconstruct only):

- Use `-PerformanceProfile "turbo_extract"` when you do not apply to target in the same run.
- This profile forces:
  - `ApplyToTarget = $false`
  - `GenerateUndo = $false`
  - `ExportBeforeAfter = $false`
  - `ApplySafetyMode = "off"`
  - `HeuristicsProfile = "fast"` and `MaxRowLogPairs = 8` (unless explicitly overridden)
  - `AdaptiveFastReplaceNonHighConfidence = $true` (skip expensive changed-column decode when adaptive mode will replace anyway)
- New converter tuning flags:
  - `HeuristicsProfile = "full" | "fast"`
  - `MaxRowLogPairs` (0 = unlimited)
  - `DisableDecode` (`$true` disables row/value decode; fastest but mostly template/unresolved output)
  - `AdaptiveFastReplaceNonHighConfidence` (`$true` uses delete+insert fast-path for non-high confidence adaptive updates)

Benchmark isolation mode:

- `-BenchmarkMode $true` is now available on both runners:
  - `Run-HybridLdfSingleSnapshotMultiTable.ps1`
  - `Run-HybridLdfCopyFromShadow.ps1`
- It hard-forces:
  - `ApplyToTarget = $false`
  - `GenerateUndo = $false`
  - `ExportBeforeAfter = $false`
  - `ApplySafetyMode = "off"`
- This prevents any target writes during performance tests.

Idle-run short-circuit:

- Both runners now skip shadow copy/offline processing when a valid saved `last_lsn` equals current live head LSN.
- This targets frequent no-change intervals and reduces fixed overhead substantially.
- Output markers:
  - multi-table summary: `no_op_short_circuit=true`
  - copy-from-shadow metrics: `no_op_short_circuit=true`

Converter phase timings:

- `Convert-HybridToTrn.ps1` accepts `-PhaseTimingOutputPath`.
- Timings include:
  - `row_resolve_ms`
  - `pair_build_ms`
  - `heuristic_decode_ms`
  - `sql_render_ms`
  - `file_write_ms`
  - `total_ms`
- Runners now emit per-table/flow phase timing JSON sidecars automatically:
  - multi-table runner: `hybrid.<session>.<table>.phase_timings.json`
  - copy-from-shadow runner: `<HybridTrnPath base>.phase_timings.json`

Apply-only example (use generated `mh.trn` as replication payload into target DB):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Apply-TrnToTarget.ps1 `
  -TrnPath ".\output\mh.trn" `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -Database "OASIS_MH" `
  -OutputPath ".\output\mh.apply.json" `
  -StopOnError $true `
  -WrapInTransaction $false
```

Update reconstruction mode:

- `UpdateMode=adaptive` (default): emit `UPDATE` only for high-confidence decodes; otherwise fallback to `DELETE by PK + full-row INSERT`.
- `UpdateMode=update`: always emit `UPDATE ... SET ...` with decoded changed fields.
- `UpdateMode=replace`: always emit `DELETE by PK + full-row INSERT` for each update (best when you need reliable `... -> NULL` replay).
- Optional accelerator: `AdaptiveFastReplaceNonHighConfidence=$true` to skip update-column decode for non-high confidence adaptive updates and emit `DELETE+INSERT` directly.

Apply safety mode:

- `ApplySafetyMode=strict` (default): only safe recovered rows go to main `.trn`.
- Strict rules: `INSERT`/`DELETE` require `confidence=high` + `hobt_match=true` + key predicate; `UPDATE` requires key predicate and no adaptive replace fallback.
- `ApplySafetyMode=off`: previous behavior (all recovered rows go to main `.trn`).

LDF read mode:

- `LdfReadMode=direct` (default): parse LDF directly from shadow path (`\\?\GLOBALROOT...`), no copy step.
- `LdfReadMode=copy`: first copy to `CopiedLdfPath`, then parse copied file.

Hybrid incremental behavior:

- Script persists `last_lsn` in `StatePath` (default: `.\output\HybridLastOffset.json`).
- Next run automatically uses saved `last_lsn` as `StartLsn` when scope matches (`LiveServerInstance + LiveDatabase + Tables + SourceDrive/SnapshotDataPath/LdfName`).
- You can still override with explicit `-StartLsn`.
- If saved `StartLsn` is ahead of current live log head, script marks `lsn_reset_detected=true` and falls back to window-based scan.
- Script enforces single-run lock via `LockFilePath` (default: `.\output\HybridFlow.lock`).
- Script writes run metrics JSON to `MetricsPath` (default: `.\output\HybridRunMetrics.json`).

SQL 2022 parser compatibility note:

- Raw hybrid matcher now accepts additional SQL Server 2022 DML signatures observed in LDF (`record_type2=0x04` and major op `0x05` as `UPDATE`) in addition to legacy shapes.

Chunk-index acceleration (optional):

- `Get-RawLdfHybridMatches.ps1` now supports optional chunk index sidecar to reduce scan scope:
  - `EnableChunkIndex` (`$true/$false`)
  - `ChunkIndexPath` (default: `<OutputDir>\<LdfFileName>.chunk-index.json`)
  - `ChunkSizeMB` (default `64`)
  - `ChunkOverlapBytes` (default `96`)
  - `RebuildChunkIndex` (force rebuild)
  - `ChunkSelectMaxPercent` (default `85`; if too many chunks are selected, script falls back to full scan)
- Optional descriptor index sidecar (single-pass DML descriptors):
  - `EnableDescriptorIndex` (`$true/$false`)
  - `DescriptorIndexPath` (default: `<OutputDir>\<LdfFileName>.descriptor-index.json`)
  - `RebuildDescriptorIndex` (force rebuild)
  - `Prepare-RawLdfDescriptorIndex.ps1` can prebuild this file for reuse.
- Diagnostics are emitted in `parser_diagnostics`:
  - `chunk_index_loaded`, `chunk_index_saved`, `chunk_scan_mode`, `chunk_selected_count`, `scan_window_count`, etc.
  - `descriptor_index_loaded`, `descriptor_index_used`, `descriptor_index_record_count`, etc.

## Full cycle script (shadow + attach/query/detach + cleanup)

`Run-ShadowAttachLogQuery.ps1`

This script executes:

1. Create shadow copy for a drive
2. Create symbolic link to shadow volume
3. Attach offline DB from the linked snapshot path (fallback: copy `MDF/LDF` to local staging and attach from staging if direct shadow attach fails)
4. Run one collector scan and write JSON output for requested window/tables
5. Create `mh.trn` with reconstructed DML for `oasis.CHSC_POLINE` (default last 5 hours)
6. Detach offline DB
7. Delete symbolic link
8. Delete shadow copy

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Run-ShadowAttachLogQuery.ps1 `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -SqlUser "SaAdmin" `
  -SqlPassword "Admin" `
  -LinkPath "C:\Users\vshmyk\AgencyOnline\TransLogs_Shadow" `
  -AttachStagingDir "C:\ProgramData\AOtransact\AttachStaging" `
  -SnapshotDataPath "DATA\Oasis" `
  -Tables "oasis.CHSC_POLINE","oasis.CHSC_POLINE_HISTORY" `
  -HoursBack 4 `
  -OutputPath ".\output\oasis-last-4h.json" `
  -MhTrnPath "C:\Users\vshmyk\AOprojects\AOtransact\output\mh.trn" `
  -MhTrnTable "oasis.CHSC_POLINE" `
  -MhTrnHoursBack 5 `
  -StatePath ".\output\LastOffset.json" `
  -MetadataCacheDir ".\output\metadata"
```

`mh.trn` behavior:

- For `UPDATE` rows, script reconstructs concrete `SET [Column] = value` clauses (decoded from row-log old/new bytes).
- It uses clustered log rows to produce one statement per affected base row.
- It now runs a linked-operation resolver pass (`tx_id + alloc/page/slot + LSN adjacency`) before decode, so split row-log fragments can be combined more reliably.
- Each reconstructed statement starts with a DML+LSN line, for example `--UPDATE (000FED3D:00043A4C:0089)`.
- If byte-level decode is not possible for a row, script falls back to a template statement with metadata comments.

Incremental behavior:

- Script persists `last_lsn` and `last_commit_time` in `StatePath`.
- Next run starts scanning from saved `last_lsn` (LSN incremental mode).
- State reuse is scoped by server/database/table-set plus source file signature (`SourceDrive + SnapshotDataPath + MDF/LDF`) to avoid cross-source LSN mismatches.
- If state is missing or incompatible (server/db/table-set mismatch), script falls back to window-based scan.

Metadata behavior:

- Script reads table metadata from database each run (columns/types + index layout).
- Script also writes a metadata snapshot to `MetadataCacheDir` for audit/reference.

## Example

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\offline-log\Get-CommittedTableTransactions.ps1 `
  -ServerInstance "LOCALHOST\SQLEXPRESS" `
  -Database "OASIS_MH_OFFLINE" `
  -SqlUser "SaAdmin" `
  -SqlPassword "Admin" `
  -WindowMinutes 15 `
  -Tables "oasis.CHSC_POLINE","oasis.CHSC_POLINE_HISTORY" `
  -OutputPath ".\output\oasis-last-15m.json"
```

## Notes

- Run this on the utility/offline SQL Server instance, not on Production.
- Keep `MDF` + `LDF` from the same shadow copy point-in-time.
- For exact original SQL text, SQL Server log internals are not always sufficient. This script outputs equivalent templates plus raw payloads for deeper decode.
