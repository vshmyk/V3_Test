# INTEGRAMASTER_V3 UpdateAll Redesign

Last updated: 2026-06-19 UTC

## Scope

This redesign treats the real `INTEGRAMASTER_V2` integration engine as the workflow that starts at:

- `dbo.UpdateAll`

and then fans out into:

- `dbo.UpdateSourceTable`
- `dbo.UpdateAOTable`
- `dbo.UpdateDestination`
- `dbo.RunBatch`
- `dbo.UpdateDestObject`
- `dbo.GetAccessToken`

Additional helper capabilities around that workflow were also confirmed in live V2:

- `dbo.ExecuteAsync`
- `dbo.WriteToFile`
- `SF.RequestUpdate`
- `SF.UpdateObjectField`
- `utils.SourceToDestinationDiscrepancy`

This is intentionally not a transaction-loader redesign.

## Live V2 Findings

Reviewed directly against live `INTEGRAMASTER_V2` on `LOCALHOST\ERPLINK` on `2026-06-19`.

### `dbo.UpdateAll` is the real orchestrator

It loops through `dbo.AOobject` rows in `SortOrder` and, per object:

- optionally runs `PreUpdateProcessor`
- refreshes source state via `UpdateSourceTable`
- refreshes AO state via `UpdateAOTable`
- executes destination sync in phase order:
  - `delete`
  - `insert`
  - `update`
- stamps `AOobject.LastUpdate`

### `dbo.AOobject` is the engine contract

It carries far more than just object names:

- source definition
- source table
- AO table
- destination object
- transaction mask
- batch size
- sync delay
- source/destination constraints
- hook procedures
- post-init procedures
- retrieve-new-destination flag

That means V2 is already metadata-driven, but the metadata is too denormalized and too tightly coupled to procedural code.

### `dbo.SyncFieldMapping` is the object schema contract

It controls:

- source fields
- destination fields
- key mappings
- hash components
- update flags
- ordering
- computed expressions
- conditional sync behavior

This is one of the strongest V2 ideas and should survive into V3.

### `dbo.UpdateDestination` is where orchestration becomes brittle

The live procedure:

- creates a physical per-run work table with a generated name
- expands columns dynamically from `SyncFieldMapping`
- fills work rows from the AO table
- batches rows by `AOobject.BatchSize`
- optionally runs sync or async via SQL Agent helper calls
- writes CSV success/error logs to disk
- mutates AO/source tables based on text result messages

This works, but it means important runtime state is spread across:

- AO tables
- source tables
- dynamic per-run tables
- CSV files
- SQL Agent job activity

### V2 also has real support tooling around the core engine

The live system includes helper procedures for:

- asynchronous execution through SQL Agent jobs
- CSV log materialization
- ad hoc field updates against destination records
- discrepancy reporting between source and destination-shadow data

That is another signal that V3 should model runtime history and operator workflows directly instead of pushing those concerns into disconnected helper procedures.

### `dbo.RunBatch` builds outbound JSON directly from the temporary work table

It:

- builds Salesforce-style JSON payloads
- calls `UpdateDestObject`
- parses the response with `OPENJSON`
- writes result text back to the dynamic work table

### Authentication and outbound API logic are embedded in SQL

`GetAccessToken` and `UpdateDestObject` handle:

- destination URL resolution
- username/password-style token acquisition
- HTTP calls from SQL

This is a major architectural boundary problem in V2.

## Core Problems To Fix

### 1. State is not durable enough

V2 has metadata tables, but the runtime itself depends heavily on transient tables and side effects.

### 2. Configuration and secrets are mixed together

`ClientProperties` is effectively acting as:

- client config
- endpoint config
- secret store
- feature flag store
- checkpoint store

### 3. AO tables are both state store and work queue

That makes it hard to reason about:

- current canonical source state
- current destination-known state
- what changed this run
- what failed this run

### 4. Hook execution is implicit

Several behaviors are hidden in columns like:

- `PreUpdateProcessor`
- `UpdateSourceProcessor`
- `PreAOupdateProcessor`
- `SourcePostInit`
- `AOPostInit`
- `UpdateTrigger`

Those should be explicit step definitions in V3.

### 5. Transport is embedded in the database engine

The outbound API layer should be modeled explicitly and made replaceable.

## V3 Design Principles

1. Keep metadata-driven orchestration.
2. Normalize object definition, field mapping, and hooks into first-class tables.
3. Persist runtime state for every run, object, step, batch, and work item.
4. Replace dynamic per-run work tables with durable JSON-backed work items.
5. Treat source snapshots and destination work queues as separate concepts.
6. Separate connection settings from secrets.
7. Keep object hooks as first-class extension points.
8. Allow the SQL engine to orchestrate, but avoid forcing SQL to own every transport concern forever.

## V3 Target Model

### Configuration

- `CFG.Client`
  - one row per integration tenant/client
- `CFG.ConnectionProfile`
  - source DB, linked server, destination API, file store, or future transport endpoints
- `CFG.RuntimeSetting`
  - non-secret runtime settings

### Metadata Definitions

- `DEF.ObjectDefinition`
  - replacement for the object-level role of `AOobject`
- `DEF.ObjectDependency`
  - allows dependency edges instead of only flat sort order
- `DEF.ObjectHook`
  - explicit hook phases and procedures
- `DEF.FieldMap`
  - replacement for `SyncFieldMapping`

### Runtime

- `RT.PipelineRun`
  - one `UpdateAll`-style run
- `RT.ObjectRun`
  - one object inside a run
- `RT.ObjectRunStep`
  - explicit lifecycle step rows
- `RT.SourceSnapshotRun`
  - one extraction/snapshot event
- `RT.SourceSnapshotRow`
  - normalized current source rows as JSON + hash
- `RT.ObjectState`
  - durable current canonical state per business key
- `RT.WorkSet`
  - a queueable unit of destination work by object + transaction type
- `RT.WorkItem`
  - one outbound row to insert/update/delete
- `RT.BatchRequest`
  - one destination batch request and response
- `RT.OperatorAction`
  - optional future table for ad hoc update/retry/correction actions now handled by helper procedures

## Recommended Step Phases

V3 should stop hiding phases inside one procedure and instead record them explicitly:

- `PreObject`
- `RefreshSource`
- `SourcePostInit`
- `RefreshState`
- `PreAoRefresh`
- `AoPostInit`
- `PlanDeletes`
- `PlanInserts`
- `PlanUpdates`
- `DispatchBatches`
- `ReconcileResults`
- `FinalizeObject`

## State Flow

### Source snapshot

For each object:

1. Run source extraction.
2. Store normalized rows in `RT.SourceSnapshotRow`.
3. Compute a canonical hash per business key.

### Canonical state update

1. Compare the latest snapshot to `RT.ObjectState`.
2. Mark each business key as:
   - new
   - changed
   - deleted
   - unchanged
3. Generate `RT.WorkItem` rows only for actual changes.

### Outbound batching

1. Group `RT.WorkItem` rows into `RT.WorkSet`.
2. Generate `RT.BatchRequest` payloads from `DEF.FieldMap`.
3. Persist request and response JSON.
4. Update `RT.ObjectState` only from confirmed successful outcomes.

This is a cleaner replacement for:

- AO row hash mutation
- per-run temp tables
- text-file success/error logs

## How V3 Improves On V2

### Durable work model

Instead of generated table names and CSV logs, V3 stores:

- work items
- batch requests
- result payloads
- step results

### Explicit hooks

Instead of packing hook procedure names into unrelated columns, V3 gives them:

- a phase
- an execution order
- an enable/disable flag

### Clear state separation

V3 separates:

- source snapshot state
- canonical current state
- outbound queued work
- run history

### Better migration path

Because `AOobject` and `SyncFieldMapping` are already metadata tables, V3 can import them instead of rebuilding everything by hand.

## Migration Strategy

### Phase 1

Deploy the V3 metadata and runtime tables.

### Phase 2

Import existing `AOobject` and `SyncFieldMapping` definitions from live V2 into V3.

### Phase 3

Run V3 in planning mode only:

- snapshot source
- build canonical state
- generate work items
- do not dispatch outbound changes yet

### Phase 4

Compare V3 planned inserts/updates/deletes with current V2 outcomes for selected clients.

### Phase 5

Enable outbound dispatch from V3 for one low-risk object or one low-risk client.

### Phase 6

Retire AO-table-driven runtime logic after parity is proven.

## What Should Not Survive Into V3

- dynamic generated physical work tables as the primary runtime model
- secret retrieval directly from generic client properties
- direct dependency on CSV log files for outcome reporting
- step status inferred only from mutable AO/source table fields
- outbound API logic that is invisible to runtime history

## Deliverables In This Repo

This redesign is paired with:

- `INTEGRAMASTER_V3.UpdateAll.Bootstrap.sql`

That bootstrap creates:

- client/config tables
- object definition tables
- field mapping tables
- runtime/run tables
- a legacy import procedure from `INTEGRAMASTER_V2`
- a V3 wrapper procedure with the same argument shape as `dbo.UpdateAll`

The wrapper is intentionally a V3 foundation, not a full cutover implementation yet.
