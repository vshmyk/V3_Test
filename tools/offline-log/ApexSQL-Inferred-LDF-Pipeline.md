# ApexSQL LDF Processing (Inferred, Black-Box)

## Scope
- Goal: infer architecture/flow only.
- Method: binary metadata/reflection and artifact inspection.
- Constraint: no ApexSQL source code reuse.

Input artifacts:
- `output/apex_reflection_signals.json`
- `output/apex_reflection_summary.json`
- `output/apex_key_hits.txt`

## High-signal components found
- `ApexSql.Engine.LogSource`
- `ApexSql.Engine.LogSequentialReader`
- `ApexSql.Engine.LogRandomReader`
- `ApexSql.Engine.LogOperation`
- `ApexSql.Engine.DmlLogOperation`
- `ApexSql.Engine.CoreRecoveryWizard`
- `ApexSql.Common.DdlAuditing.Internal.TransactionInfo`
- `ApexSql.Common.DdlAuditing.DmlOperationProcessor`

Strong LSN/page signals:
- `get_FirstLsn`, `get_LastLsn`, `get_CheckPointLsn`
- `LogOperation.get_Lsn`, `get_PreviousOperationLsn`
- `DmlLogOperation.get_PageId`, slot/page fields
- `AllocationUnitId` types

Recovery/script signals:
- `CreateRecoverer`, `CreateRecovererForOfflineDatabase`
- `ReadBackupData`
- `RecoverDeletedRowsWithLogData`, `RecoverDeletedRowsWithNoLogData`
- `RecoverDroppedObjectsAndDataWithLogData`, `...NoLogData`
- `DmlOperationProcessor.get_CreateRedoScript`
- `DmlOperationProcessor.get_CreateUndoScript`
- `TransactionInfo.IsCommittedOperation`

## Inferred processing pipeline
1. Build a unified `LogSource` abstraction for log/backup inputs.
2. Create two readers:
   - Sequential reader for ordered scan by LSN/time window.
   - Random reader for targeted fetch by page/slot/LSN during decode/linking.
3. Parse physical records into `LogOperation` / `DmlLogOperation`.
4. Group operations into transactions and keep only committed ones.
5. Resolve row identity and table/object mapping (allocation/page/slot + metadata).
6. Reconstruct row change semantics (old/new image, changed columns, PK predicate).
7. Generate redo/undo scripts through a dedicated scripting stage.
8. Run recovery-specific paths for partial metadata/log scenarios.
9. Emit confidence/safety partitions (safe vs unresolved/quarantine style outputs).

## Mapping to our current flow
- Already aligned:
  - LSN incremental state (`LastOffset.json` / `HybridLastOffset.json`)
  - committed-only filtering
  - confidence/safe vs unresolved/quarantine outputs
  - redo/undo generation (`mh.trn` / `mh.undo.trn`)
  - static metadata snapshot support
- Missing/partial vs inferred model:
  - no true random-access page/slot resolver stage
  - limited multi-record transaction graphing beyond manifest join
  - partial handling of complex row images (`NULL`/blank transitions, multi-field updates)
  - no backup-chain-aware source abstraction (LDF + backup set continuity)

## Practical design upgrades (no code borrowing)
1. Add an explicit `operation graph` stage keyed by:
   - `tx_id`, `lsn`, `prev_lsn`, `allocation_unit_id`, `page_id`, `slot_id`.
2. Add a `random resolver` pass:
   - revisit uncertain updates and pull nearby records by linkage keys.
3. Strengthen update reconstruction:
   - column bitmap + variable-length segment decoder.
   - first-class `NULL -> ''` and `value -> NULL` handling.
4. Add `source continuity` checks:
   - guardrails for truncation/reset and gaps between runs.
5. Keep strict output contract:
   - main TRN = safe only.
   - unresolved/quarantine files for low-confidence replay.

## Conclusion
Your architecture direction is correct. The main gap to close is deeper row/record linking and stronger byte-level update decoding, not broad workflow changes.
