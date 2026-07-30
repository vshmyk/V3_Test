# INTEGRAMASTER_V3 Runtime Notes

Last updated: 2026-06-20 UTC

## Current State

The V3 runtime control plane is now deployed in local SQL database:

- `INTEGRAMASTER_V3`

Runtime schema:

- `rt`

## Deployed Runtime Tables

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

## Deployed Runtime Procedures

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

## Deployed Runtime Views

- `rt.vw_SyncObjectOperationMask`
- `rt.vw_PipelinePlanSummary`
- `rt.vw_WorkPlanSummary`
- `rt.vw_BatchRequestSummary`
- `rt.vw_DispatchResultSummary`

## What Runtime Does Today

`rt.PlanPipelineRun` currently:

1. resolves the V3 client
2. creates one durable pipeline run row
3. expands the selected sync objects
4. records the planned operation mask per object
5. creates ordered step rows for:
   - standard engine phases
   - operation planning phases
   - imported object hooks

This gives us a durable, queryable execution plan without touching live source or destination systems.

`rt.CaptureSourceSnapshot` now:

1. resolves the configured V3 source database profile for the client
2. reads the object's stage table from `meta.SyncObject`
3. derives a stable business key from `meta.FieldMap`
4. prefers the metadata-defined hash surface from `meta.FieldMap.SourceHashOrder`
5. falls back to persisted stage `RowHash` only when metadata does not define a hash surface
6. updates bounded current source state in `rt.SourceCurrent`
7. writes row-level inserts, updates, and deletes into `rt.SourceDelta`
8. keeps `rt.SourceSnapshotRun` as the durable capture-run audit header
9. fails fast when duplicate business keys are detected

`rt.CreateSyntheticSourceSnapshot` now:

1. clones the current cached source state for an object by default
2. can still clone a legacy materialized snapshot run when one is explicitly supplied
3. lets us inject synthetic update/insert/delete-style row mutations
4. records only deltas plus the new current state, without materializing another full snapshot rowset
5. gives us a safe way to test source-change capture before real API dispatch

`rt.RefreshSourceStage` now:

1. resolves the V3 client and object metadata for one object run
2. chooses a refresh mode from `meta.SyncObjectSetting` or `cfg.ClientSetting`
3. uses legacy `INTEGRAMASTER_V2.dbo.UpdateSourceTable` by default
4. leaves room for future custom source refresh implementations without changing pipeline orchestration

`rt.ExecutePlannedSourceSnapshots` now:

1. takes a planned pipeline run
2. executes `rt.RefreshSourceStage` for selected objects in order
3. captures the refreshed stage into durable source snapshot runs, deltas, and current-state refreshes
4. updates step status

`rt.PlanObjectWork` now:

1. resolves the latest completed source capture run for an object run
2. compares current cached source state in `rt.SourceCurrent` to canonical state in `rt.ObjectState`
3. creates durable `rt.WorkSet` rows per enabled operation
4. creates durable `rt.WorkItem` rows only for real inserts, updates, or deletes
5. leaves `rt.ObjectState` untouched until a future successful dispatch/reconciliation phase

`rt.ExecutePlannedWorkPreparation` now:

1. runs work planning for selected pipeline objects in order
2. updates `RefreshState` and `Plan*` step results
3. leaves the pipeline in `ready` state for future batching/dispatch

`rt.BuildBatchRequests` now:

1. groups ready work items by object operation and batch size
2. shapes destination-facing JSON payloads from `meta.FieldMap`
3. persists durable batch headers in `rt.BatchRequest`
4. persists explicit batch-to-item membership in `rt.BatchRequestItem`

`rt.ExecutePlannedBatchPreparation` now:

1. executes batch generation for ready work sets in pipeline order
2. updates the `BuildBatches` step result per object
3. leaves the pipeline in `ready` state for future dispatch

`rt.DispatchBatchRequest` now:

1. dispatches a persisted batch request in a pluggable transport mode
2. supports safe `simulate` mode today
3. persists per-item response data in `rt.BatchRequestItem`
4. updates `rt.WorkItem` outcomes
5. reconciles successful results into `rt.ObjectState`

`rt.ExecutePlannedBatchDispatch` now:

1. executes ready batch requests in order for a pipeline planned with `AllowDispatch = 1`
2. updates `DispatchBatches` and `ReconcileResults` step results
3. leaves the pipeline in `ready` state after the dispatch phase completes

## Verified Pilots

Client imported and validated:

- `PLS`

Example planning run created successfully for:

- `PurchaseOrder`
- `PurchaseOrderItem`
- `QuoteItem`

Live source snapshot execution validated for:

- `PurchaseOrder`

Observed result:

- `92,973` rows captured from `PLS.src.PurchaseOrder` into bounded `rt.SourceCurrent`
- `rt.SourceDelta` only records rows that changed during a capture run

Live work preparation validated for:

- `PurchaseOrder`

Observed result:

- `92,973` insert work items planned
- `0` update work items planned
- pipeline run moved to `ready`

Live batch preparation validated for:

- `PurchaseOrder`

Observed result:

- `92,973` insert work items grouped into `465` batch requests
- batch size respected at `200`, with the last batch containing `173` items
- `BuildBatches` step completed successfully on pipeline run `6`

Live dispatch and reconciliation validated for:

- `PurchaseOrder`

Observed result on pipeline run `7`:

- `465` simulated batch requests completed successfully
- `92,973` work items marked `completed`
- `92,973` canonical `rt.ObjectState` rows materialized
- `DispatchBatches` and `ReconcileResults` both completed

Idempotence validated on later reruns:

- pipeline run `9` planned `0` inserts and `0` updates against the same source snapshot
- downstream transport steps were explicitly marked `skipped`

Synthetic source-change capture validated:

- `PurchaseOrder`

Observed result on pipeline run `10`:

- a cloned snapshot was mutated with `1` synthetic update and `1` synthetic insert
- V3 planned `1` update work item and `1` insert work item
- no live source table changes and no API calls were required

Operational rebaseline validated:

- `PurchaseOrder`

Observed result on `2026-06-21`:

- `rt.RebaselineObjectStateFromSourceCurrent` re-aligned `92,973` active state rows to the current V3 source-hash policy
- a fresh no-change live capture then planned `0` inserts and `0` updates
- a later single-row live `CHSC_PO.PONUMBER` change produced `1` row in `rt.SourceDelta` and `1` planned update work item

## Important Current Limitation

The runtime still does not yet execute:

- real destination transport execution beyond safe `simulate` mode
- expression-driven outbound fields if future clients start using `DefaultValueExpression` or `ComputedValueExpression`
- hook execution phases such as `PreObject`, `SourcePostLoad`, `StatePostLoad`, and `FinalizeObject`

Synthetic source tests currently update `rt.SourceCurrent` for the selected object. A later live capture restores the real current-state cache.

For objects whose canonical state was previously seeded using a different source-hash surface, the first capture after a hash-policy change can plan broad updates until state is rebaselined to the new hash surface.

`rt.RebaselineObjectStateFromSourceCurrent` is now available as the operational repair for that case. It updates active `rt.ObjectState` rows from `rt.SourceCurrent` without touching live source tables or dispatching to the destination. It should be run only after a fresh live source capture for the same object.

It is intentionally being built one executable phase at a time.

## Recommended Next Development Step

Implement the next operational guardrail:

- configurable retention and purge for `rt.SourceDelta` history, while keeping `rt.SourceCurrent` bounded

Suggested first pilot objects:

- `QuoteItem`
- `PurchaseOrder`
- `PurchaseOrderItem`

Those are still the best candidates because they already have clear V2 hooks and are central to the current `PLS` workflow.

## Test Assets

- `tools/integramaster-v3/INTEGRAMASTER_V3.ChangeCaptureTest.PurchaseOrder.sql`
- `tools/integramaster-v3/INTEGRAMASTER_V3.RebaselineObjectState.PurchaseOrder.sql`

That script creates a synthetic `PurchaseOrder` source-state mutation and demonstrates how V3 records row deltas that should propagate downstream.
