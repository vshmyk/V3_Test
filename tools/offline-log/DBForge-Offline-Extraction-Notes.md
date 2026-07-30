# DBForge Transaction Log Reverse-Engineering Notes (Black-Box)

Date: 2026-03-13
Scope: metadata and runtime-shape inspection only (no binary modification).

## What Was Confirmed

1. Product and engine:
- Executable: `transactionlog.exe` (`dbForge Transaction Log 2025.3.107.0`)
- Core assembly: `Devart.DbForge.TransactionLog.dll`

2. Offline parser model exists (direct file parsing, not SQL-first):
- `Devart.DbForge.TransactionLog.Ldf.LdfFileRecordDescriptor`
- `Devart.DbForge.TransactionLog.Ldf.LSN`
- `Devart.DbForge.TransactionLog.Ldf.Operations`
- `Devart.DbForge.TransactionLog.Ldf.Contexts`
- `Devart.DbForge.TransactionLog.Mdf.PageSlotLink`
- `Devart.DbForge.TransactionLog.Mdf.AllocUnit`

3. File access modes:
- `Devart.DbForge.TransactionLog.Common.FileAccessType = Direct | VSS | Ntfs`

4. Explicit task pipeline (enum `TaskType`) indicates staged processing:
- Core load: `MdfFileLoading`, `LdfFileLoading`
- MDF system object hydration:
  - `SystemTableRowsetsLoading`
  - `SystemTableAllocUnitsLoading`
  - `SystemTableColParsLoading`
  - `SystemTableIdxStatsLoading`
  - plus related object reference tables
- LDF enrichment passes:
  - `LdfFileLsnValueLoading`
  - `LdfFileBeginTimeValueLoading`
  - `LdfFileDmlOperationValueLoading`
  - `LdfFileContextValueLoading`
  - `LdfFileTransactionIdValueLoading`
  - `LdfFileTransactionSidValueLoading`
  - `LdfFileObjectNameValueLoading`
  - `LdfFileModifyValueLoading`
  - `LdfFileByTransactionLoading`

5. Operation/context vocabulary aligns with raw log semantics:
- Operations include `LOP_INSERT_ROWS`, `LOP_DELETE_ROWS`, `LOP_MODIFY_ROW`, `LOP_MODIFY_COLUMNS`, `LOP_BEGIN_XACT`, `LOP_COMMIT_XACT`.
- Contexts include `LCX_HEAP`, `LCX_INDEX_LEAF`, `LCX_MARK_AS_GHOST`, `LCX_PFS`, `LCX_GAM`, `LCX_SGAM`, etc.

6. No static evidence of SQL-driven extraction in binaries:
- No hits for `fn_dblog`, `sys.fn_dblog`, `fn_dump_dblog`, `DBCC PAGE`, `OpenRowset(DBLog,...)`.
- There is a `ViewerFnDbLog` type, likely a separate viewer/projection path, not the primary offline extraction path.

## Inferred Internal Strategy

DBForge appears to do:
1. Acquire stable files (VSS/Direct/Ntfs).
2. Parse LDF records into compact descriptors (`LSN`, op, context, tx id, page/slot, alloc unit id).
3. Hydrate MDF system metadata once (object/rowset/allocunit/index/column map).
4. Enrich parsed records in focused passes (time, object, DML op classification, by-transaction grouping).
5. Project output views/scripts from pre-indexed record descriptors.

This is consistent with high throughput because data is parsed once and reused.

## Decompiled Clues We Can Reuse Directly

1. Multi-layer in-memory caches are explicit:
- `Dictionary<LSN, DmlOperationValue>` with bounded eviction semantics.
- `Dictionary<ulong, List<LSN>>` for object/alloc-unit to LSN lists.
- `SortedDictionary<PageSlotLink, SortedList<LSN,...>>` for page-slot timelines.

2. Row/page access is page-slot first, then decode:
- Repeated `GetRawDataPageSlot(...)` calls followed by decode.
- `PageNo * 8192` offset logic confirms fixed page addressing path.
- `ReadDataPage(...)` variants used heavily for both single/paired row images.

3. Aggressive operation/context pre-filtering before expensive decode:
- Fast allow-list checks around:
  - `LOP_INSERT_ROWS`
  - `LOP_DELETE_ROWS`
  - `LOP_MODIFY_ROW`
  - `LOP_MODIFY_COLUMNS`
- Additional context filters (`LCX_HEAP`, `LCX_CLUSTERED`, etc.) gate deeper parsing.

4. Delete path has special handling:
- Code branches where `LOP_DELETE_ROWS` with no useful payload is skipped early.
- Separate comparison/extraction path for delete "before image" style value materialization.

5. Insert/delete/update are decoded with different expected payload shapes:
- Insert/delete branches compute different `result.Length` expectations.
- Modify-row branch requires at least two payload parts and has dedicated parsing.

6. System metadata is treated as first-class cached state:
- frequent lookups of cached column metadata maps and alloc-unit bindings.
- decode functions assume metadata dictionaries are already hydrated and reused.

## AOtransact Blueprint (Actionable)

1. Introduce a single-pass LDF descriptor index (mandatory):
- Persist compact records:
  - `lsn`, `txid`, `op`, `context`, `alloc_unit_id/name`, `page_id`, `slot_id`,
  - `prev_lsn`, `rowlog_offsets`, `record_offset`.
- Store as binary or JSONL shard files keyed by LSN range.

2. Build MDF metadata cache once per session:
- Table/object/rowset/alloc-unit/index/PK mapping.
- Avoid per-table repeated metadata SQL during conversion.

3. Split conversion into deterministic stages:
- Stage A: transaction graph build (`BEGIN/COMMIT`, tx->records map).
- Stage B: table/object binding from alloc-unit map.
- Stage C: action-specific decode/render:
  - `DELETE`: key-first decode path (no row image fetch unless requested).
  - `UPDATE`: pair rows by tx+key+proximity.
  - `INSERT`: defer expensive row-image reconstruction; use targeted decode first.

4. Make heavy steps cacheable across reruns:
- Reuse shadow device for debug loops.
- Reuse parsed descriptor index when LDF unchanged.
- Reuse per-table key-shape decode cache.

5. Keep live DB fallback as last resort:
- Strict unresolved-only fallback with hard counters and cutoffs.
- Report fallback ratio and unresolved reasons by action.

6. Add explicit action-specific fast paths:
- `DELETE`: key-only render path from minimal payload + metadata map, avoid full value decode.
- `UPDATE`: prefer pair-by-(tx,key,lsn-nearby) before row-image diff.
- `INSERT`: prefilter candidates by alloc-unit/object and only decode typed values on final candidate.

7. Add first-class LSN/object/page-slot indexes:
- `tx -> lsn[]`
- `alloc_unit -> lsn[]`
- `page_slot -> (lsn, action)[]`
- Keep all three indexes in memory for the conversion run and persist optional compact snapshot for reruns.

## Immediate Priority for Current Performance Regression

Given current AOtransact behavior (Step 4 stalls on `500 U + 500 D`):
- Instrument `Convert-HybridToTrn` around:
  - tx grouping,
  - candidate selection,
  - key decode loops,
  - row lookup loops.
- Add per-loop counters and elapsed metrics in phase timing output.
- Enforce fail-fast guardrails:
  - max candidate rows per tx/action,
  - max decode attempts per manifest row,
  - bounded fallback loops.

This should expose the exact hot loop causing the current timeout.
