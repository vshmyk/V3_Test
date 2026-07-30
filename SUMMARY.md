# AOtransact Project Summary

Last updated: 2026-06-29 UTC

## Purpose

`AOtransact` is a SQL- and log-driven integration/tooling repo with three important active areas:

- `tools/transactions-loader`
- `tools/integramaster-v3`
- `tools/offline-log`

The current strategic project is the redesign of `INTEGRAMASTER_V2` into `INTEGRAMASTER_V3`, while keeping the existing transaction loader intact and continuing maintenance on the active Purchase Order History V2 SQL logic.

This file is intended as the top-level handoff for a future Codex session.

## Repo Identity

- Repo root: `C:\Users\vshmyk\AOprojects\AOtransact`
- Git branch during the latest V3 work: `main`
- Primary live SQL instance used for validation: `LOCALHOST\ERPLINK`
- Resolved SQL Server name from validation runs: `CENTERA-DEV\ERPLINK`

## Main Workstreams

### 1. INTEGRAMASTER_V3

Primary area:

- [tools/integramaster-v3](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3)

Goal:

- redesign `INTEGRAMASTER_V2` into a reusable metadata-driven integration engine for future projects
- do not redesign the transaction log loader as part of this work

Current live V3 database:

- `INTEGRAMASTER_V3`

Current runtime schema:

- `rt`

Meaning of `rt`:

- `runtime`

### 2. Purchase Order History V2

Primary area:

- [tools/transactions-loader](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader)

This is still active production-style SQL work, especially around Purchase Order History snapshots, diffing, notifications, and retention.

### 3. Offline Log / Hybrid Recovery

Primary area:

- [tools/offline-log](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log)

This remains a separate log/mining toolchain and is not the current center of the V3 integration-engine redesign.

## Top-Level Layout

Important directories:

- [tools](C:/Users/vshmyk/AOprojects/AOtransact/tools)
- [AOtransact.Database](C:/Users/vshmyk/AOprojects/AOtransact/AOtransact.Database)
- [AOtransact.Sae](C:/Users/vshmyk/AOprojects/AOtransact/AOtransact.Sae)
- [installer](C:/Users/vshmyk/AOprojects/AOtransact/installer)
- [_thirdparty](C:/Users/vshmyk/AOprojects/AOtransact/_thirdparty)
- [output](C:/Users/vshmyk/AOprojects/AOtransact/output)

Important note:

- `tools` contains the actual working source files
- `output` contains generated or deployment-oriented artifacts

## INTEGRAMASTER_V3 Overview

### Design intent

V3 is intended to replace the V2 object-sync engine with a more explicit, metadata-driven runtime that separates:

- client/configuration metadata
- source capture
- current source state
- delta tracking
- work planning
- batching
- dispatch
- canonical object state

It should become reusable for future projects, not just a refactor of the current PLS integration.

### Current source of truth files

- [INTEGRAMASTER_V3.Database.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Database.sql)
- [INTEGRAMASTER_V3.Metadata.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Metadata.Bootstrap.sql)
- [INTEGRAMASTER_V3.Runtime.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Runtime.Bootstrap.sql)
- [INTEGRAMASTER_V3.RuntimeNotes.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RuntimeNotes.md)
- [INTEGRAMASTER_V3.MetadataReview.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.MetadataReview.md)
- [INTEGRAMASTER_V3.UpdateAll.Design.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.UpdateAll.Design.md)

### Metadata model

V3 replaced the V2 generic metadata model with these normalized tables:

- `cfg.IntegrationClient`
- `cfg.ConnectionProfile`
- `cfg.ClientSetting`
- `cfg.ClientSecretReference`
- `meta.SyncObject`
- `meta.SyncObjectOperation`
- `meta.SyncObjectHook`
- `meta.SyncObjectSetting`
- `meta.FieldMap`

Design rationale is documented in:

- [INTEGRAMASTER_V3.MetadataReview.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.MetadataReview.md)

### Runtime tables

Current deployed V3 runtime tables:

- `rt.PipelineRun`
- `rt.ObjectRun`
- `rt.ObjectRunStep`
- `rt.SourceSnapshotRun`
- `rt.SourceSnapshotRow`
- `rt.SourceCurrent`
- `rt.SourceDelta`
- `rt.ObjectState`
- `rt.WorkSet`
- `rt.WorkItem`
- `rt.BatchRequest`
- `rt.BatchRequestItem`

### Runtime procedures

Current deployed V3 runtime procedures:

- `rt.PlanPipelineRun`
- `rt.RefreshSourceStage`
- `rt.CaptureSourceSnapshot`
- `rt.CreateSyntheticSourceSnapshot`
- `rt.ExecutePlannedSourceSnapshots`
- `rt.PlanObjectWork`
- `rt.ExecutePlannedWorkPreparation`
- `rt.BuildBatchRequests`
- `rt.ExecutePlannedBatchPreparation`
- `rt.DispatchBatchRequest`
- `rt.ExecutePlannedBatchDispatch`
- `rt.RebaselineObjectStateFromSourceCurrent`

### Runtime views

Current deployed V3 runtime views:

- `rt.vw_SyncObjectOperationMask`
- `rt.vw_PipelinePlanSummary`
- `rt.vw_WorkPlanSummary`
- `rt.vw_BatchRequestSummary`
- `rt.vw_DispatchResultSummary`

## Current V3 Runtime Behavior

### Planning

`rt.PlanPipelineRun` creates durable pipeline/object/step rows and produces a queryable execution plan.

### Source refresh

`rt.RefreshSourceStage` is the V3 wrapper for source refresh.

Current behavior:

- resolves client and object metadata from `ObjectRun`
- chooses refresh mode from `meta.SyncObjectSetting` or `cfg.ClientSetting`
- defaults to `legacy_v2_updatesourcetable`
- currently calls `INTEGRAMASTER_V2.dbo.UpdateSourceTable` under the hood

Important implication:

- V3 now orchestrates source refresh itself
- but the underlying source stage build still temporarily uses V2 loader logic

### Source capture

`rt.CaptureSourceSnapshot` reads from the configured `src` stage table and:

- derives business keys from `meta.FieldMap`
- prefers metadata-defined hash fields from `SourceHashOrder`
- falls back to stage `RowHash` only if metadata does not define a hash surface
- updates bounded current source state in `rt.SourceCurrent`
- writes inserts/updates/deletes to `rt.SourceDelta`
- keeps a durable audit header in `rt.SourceSnapshotRun`

Important design change:

- normal live captures do not materialize full row history in `rt.SourceSnapshotRow`
- `rt.SourceCurrent` is bounded current state
- `rt.SourceDelta` is the change history

### Work planning

`rt.PlanObjectWork` compares `rt.SourceCurrent` to `rt.ObjectState` and produces only real inserts/updates/deletes in `rt.WorkItem`.

### Batching and dispatch

`rt.BuildBatchRequests` creates durable outbound batches from planned work.

`rt.DispatchBatchRequest` currently supports only:

- `simulate`

It still reconciles successful simulated outcomes into `rt.ObjectState`.

### Rebaseline

`rt.RebaselineObjectStateFromSourceCurrent` exists to realign canonical object state after hash-policy changes.

Important rule:

- only use it after a fresh live source capture for the same object

## Validated V3 Results

### PurchaseOrder

`PurchaseOrder` is the main fully validated pilot.

Validated behavior:

- live source capture works
- work planning works
- batch preparation works
- simulated dispatch works
- object-state reconciliation works
- idempotent reruns work
- synthetic change tests work
- live raw-source change tests work
- source refresh is now orchestrated through `rt.RefreshSourceStage`

Observed production-scale baseline:

- `PLS.src.PurchaseOrder` row count captured: about `92,973`

Important validated milestones:

- pipeline run `7`: simulated dispatch completed and materialized `92,973` `rt.ObjectState` rows
- pipeline run `9`: idempotent rerun planned `0` inserts and `0` updates
- pipeline run `10`: synthetic test planned `1` update and `1` insert
- `2026-06-21`: rebaseline realigned `92,973` active `PurchaseOrder` state rows
- after rebaseline, a no-change live capture planned `0` updates
- after rebaseline, a single-row live `CHSC_PO.PONUMBER` change produced `1` `rt.SourceDelta` row and `1` planned update work item
- `2026-06-23`: `rt.RefreshSourceStage` was deployed and validated through pipeline run `24`

Measured steady-state one-row live test after rebaseline:

- V2-backed source refresh through V3 wrapper: about `15.8s`
- V3 pipeline planning: about `33 ms`
- V3 source capture: about `2.4s`
- V3 work preparation: about `0.5s`

Conclusion:

- the main bottleneck is still source-stage refresh
- not V3 change capture
- not V3 work planning

### PurchaseOrderItem

`PurchaseOrderItem` is not yet fully baselined in V3.

Status discovered on `2026-06-29`:

- no prior `rt.SourceCurrent` rows
- no prior `rt.ObjectState` rows
- capture currently fails on duplicate business keys before any `rt.SourceDelta` rows are written

Current blocker:

- the configured `IsSourceMatchKey` set for `PurchaseOrderItem` is not unique

Observed duplicate-key findings:

- `63` duplicate business keys
- `130` rows participating in duplicate groups
- max duplicate group size: `3`

Strong candidate fix:

- include `ShipmentLineUID` in the `PurchaseOrderItem` source match key

Observed effect of that candidate:

- duplicate business keys dropped to `0` in testing

Current implication:

- if a user says they updated `src.PurchaseOrderItem`, that update has not yet been captured in V3 unless this key issue is fixed first

### QuoteItem

`QuoteItem` has been included in example planning work but is not yet validated end-to-end like `PurchaseOrder`.

## Important V3 Limitations

Still not implemented:

- real destination transport beyond `simulate`
- expression-driven outbound values where future clients need richer computed outbound fields
- actual hook execution phases like `PreObject`, `SourcePostLoad`, `StatePostLoad`, `FinalizeObject`
- retention/purge policy for `rt.SourceDelta`

Important operational caveats:

- synthetic source tests mutate `rt.SourceCurrent` for the selected object
- a later live capture restores the real current-state cache
- if canonical state was seeded under an older hash surface, broad false updates can appear until rebaseline is run

## Important V3 Test Assets

- [INTEGRAMASTER_V3.ChangeCaptureTest.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.ChangeCaptureTest.PurchaseOrder.sql)
- [INTEGRAMASTER_V3.RebaselineObjectState.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RebaselineObjectState.PurchaseOrder.sql)
- [INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql)

## Purchase Order History V2 Overview

Primary editable source:

- [PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql)

Primary V2 summary:

- [tools/transactions-loader/SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/SUMMARY.md)

Recent important maintenance/deployment artifact:

- [PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/output/PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql)

That 2026-06-26 script is a broad maintenance script for V2 PO snapshot retention and latest-run deletion behavior.

Important note:

- the V2 PO-history subsystem is still active and separate from the V3 integration-engine redesign
- V3 work should not casually rewrite or replace this subsystem

## Offline Log Overview

Primary documentation:

- [tools/offline-log/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/README.md)

High-level purpose:

- collect committed DML from SQL Server logs
- build live manifests from `fn_dblog` or `fn_full_dblog`
- match offline LDF bytes
- convert activity into `.trn` outputs

This remains part of the repo but was not the main area of change in the latest V3 sessions.

## Important Environment-Specific Facts

These matter a lot in future sessions:

- live V2 and V3 validation used `LOCALHOST\ERPLINK`
- `INTEGRAMASTER_V3` exists on `CENTERA-DEV\ERPLINK`
- `OASIS_PLS` exists on that same instance
- `PLS.src.*` stage tables are live source-stage inputs for V3 capture
- `rt.RefreshSourceStage` still routes to `INTEGRAMASTER_V2.dbo.UpdateSourceTable` by default

Do not assume:

- another machine has the same SQL instance name
- another machine has the same DB names
- another machine has the same filesystem paths

## Recommended Next Steps

Highest-value next steps for the next Codex session:

1. Fix `PurchaseOrderItem` business-key metadata by adding `ShipmentLineUID` to the source match key and validate capture.
2. Baseline `PurchaseOrderItem` into `rt.SourceCurrent` and `rt.ObjectState` once key uniqueness is fixed.
3. Add retention/purge for `rt.SourceDelta`.
4. Decide whether to keep using V2 `UpdateSourceTable` under the V3 refresh wrapper or start introducing object-specific/custom refresh procedures.
5. Implement real destination transport when ready to leave `simulate`.

## First Files To Open In A New Session

1. [SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/SUMMARY.md)
2. [INTEGRAMASTER_V3.RuntimeNotes.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RuntimeNotes.md)
3. [INTEGRAMASTER_V3.Runtime.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Runtime.Bootstrap.sql)
4. [INTEGRAMASTER_V3.Metadata.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Metadata.Bootstrap.sql)
5. [INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql)
6. [tools/transactions-loader/SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/SUMMARY.md)
7. [PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql)
8. [PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/output/PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql)
9. [tools/offline-log/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/README.md)

## Resume Guidance

If a future session needs to continue V3 work quickly:

1. Read this file.
2. Read `INTEGRAMASTER_V3.RuntimeNotes.md`.
3. Check the latest `rt.SourceSnapshotRun`, `rt.SourceDelta`, `rt.ObjectRun`, and `rt.WorkSet` rows in `INTEGRAMASTER_V3`.
4. Verify whether the target object already has `rt.SourceCurrent` and `rt.ObjectState` baseline rows.
5. If not, treat the object as not yet baselined before interpreting any “one changed row” claim.
6. For `PurchaseOrderItem`, fix match-key uniqueness before attempting live capture again.
