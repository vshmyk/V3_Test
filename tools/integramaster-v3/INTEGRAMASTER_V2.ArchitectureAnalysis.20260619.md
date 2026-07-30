# INTEGRAMASTER_V2 Architecture Analysis

Captured from live `INTEGRAMASTER_V2` and `PLS` on `LOCALHOST\ERPLINK` on `2026-06-19`.

## Executive Summary

`INTEGRAMASTER_V2` is not a single stored procedure. It is a metadata-driven synchronization platform built around:

- client-level configuration in `dbo.ClientProperties`
- object-level metadata in `dbo.AOobject`
- field-level mapping in `dbo.SyncFieldMapping`
- source staging tables in client databases under `SRC`
- destination-shadow tables in client databases under `AO`
- an orchestration entrypoint in `dbo.UpdateAll`
- outbound API dispatch from SQL through `dbo.UpdateDestObject`

The architecture is stronger than it first appears because it already separates:

- orchestration
- object metadata
- field mapping
- source staging
- destination shadow state

But it is also brittle because runtime state is spread across mutable tables, generated work tables, SQL Agent jobs, CSV files, and string-based hooks.

## Runtime Flow

### 1. Entry point

The integration process starts from:

- `dbo.UpdateAll`

Inputs:

- `@ClientId`
- `@Objects`
- `@RefreshAO`
- `@RefreshSource`
- `@UpdateDestination`
- `@OutputResult`

Behavior:

- resolves the client database name from `ClientProperties`
- selects active objects from `AOobject`
- orders them by `SortOrder`
- runs object-level hook and sync phases

### 2. Metadata-driven object loop

For each object, `UpdateAll` reads from `AOobject`:

- source definition
- AO table
- destination object
- transaction mask
- pre-update hook

Then it can call:

- `dbo.UpdateSourceTable`
- `dbo.UpdateAOTable`
- `dbo.UpdateDestination`

### 3. Source refresh

`dbo.UpdateSourceTable` is the source extraction and normalization phase.

Core behavior:

- resolves client DB, linked server, and source DB settings
- uses `AOobject` and `SyncFieldMapping` to build source extraction SQL
- creates or reloads `SRC.<Object>` tables in the client DB
- computes `RowHash`
- applies source constraints
- optionally runs `UpdateSourceProcessor`
- updates source rows for insert/update/delete semantics

### 4. AO refresh

`dbo.UpdateAOTable` is the shadow-state reconciliation phase.

Core behavior:

- reads from `SRC.<Object>`
- writes into `AO.<Object>`
- computes:
  - `AORowHash`
  - `srcRowHash`
- uses key mappings from `SyncFieldMapping`
- supports:
  - destination ID preservation
  - secondary-key updates
  - delete marking
  - sync delay filtering
- optionally runs `PreAOupdateProcessor`

### 5. Destination planning and dispatch

`dbo.UpdateDestination` is the outbound planner and batch dispatcher.

Core behavior:

- reads object config from `AOobject`
- expands destination fields from `SyncFieldMapping`
- creates a generated physical work table
- fills work rows from `AO.<Object>`
- selects rows by transaction type:
  - `delete`
  - `insert`
  - `update`
- groups work into batches
- runs `dbo.RunBatch`
- optionally runs async via `dbo.ExecuteAsync`
- writes success/error CSV files via `dbo.WriteToFile`
- mutates AO and source state based on batch results

### 6. Batch execution

`dbo.RunBatch` builds the actual outbound payload.

Core behavior:

- resolves destination object name
- builds JSON from work rows
- calls `dbo.UpdateDestObject`
- parses response JSON with `OPENJSON`
- writes per-row result messages back to the work table

### 7. Transport layer

`dbo.UpdateDestObject` performs the outbound HTTP request.

Core behavior:

- builds destination composite API URL
- resolves token and URL settings
- uses `dbo.clr_httpRequest`
- returns raw response JSON

Authentication is handled by:

- `dbo.GetAccessToken`

which currently:

- reads username/password/client credentials from `ClientProperties`
- performs OAuth token acquisition from SQL using OLE automation

## Main Data Structures

### `dbo.ClientProperties`

Role:

- global client runtime settings

Observed usage:

- DB names
- linked server names
- destination URL
- credentials
- file paths
- integration feature flags
- checkpoints

Problem:

- configuration, routing, and secrets are mixed in one generic property table

### `dbo.AOobject`

Role:

- object-level integration contract

Important columns:

- `ClientId`
- `ObjectName`
- `SortOrder`
- `ActiveFlag`
- `DataSource`
- `DataSourceTable`
- `AOtable`
- `DestObject`
- `TransactionTypes`
- `BatchSize`
- `SyncDelay`
- `RetrieveNewDest`
- `SrcDataConstraint`
- `DestDataConstraint`
- `UpdateProcessor`
- `UpdateSourceProcessor`
- `PreUpdateProcessor`
- `PreAOupdateProcessor`
- `SourcePostInit`
- `AOPostInit`
- `UpdateTrigger`

What it means:

- V2 already has a strong metadata-driven object model

### `dbo.SyncFieldMapping`

Role:

- field-level mapping contract between source and destination-shadow state

Important columns:

- `SrcField`
- `DestField`
- `SrcKey`
- `DestKey`
- `SrcHashComponent`
- `ComputedValue`
- `FieldSortOrder`
- `UpdateFlag`
- `ConditionalSync`
- `SrcSecondaryKey`
- `ToOasis`

What it means:

- V2 is already using a declarative mapping model, which is worth preserving

### `SRC.<Object>` tables

Role:

- latest normalized source rows for an object

Observed pattern:

- include a `RowHash`
- include source-native business columns
- are regenerated and enriched during source refresh

### `AO.<Object>` tables

Role:

- destination shadow state plus sync control fields

Observed pattern:

- include destination `Id`
- include destination-shaped business columns
- include:
  - `AORowHash`
  - `srcRowHash`
- sometimes include:
  - `IsDeleted`
  - `LastModifiedDate`

What they represent:

- a hybrid of current known destination state, outbound queue candidate set, and sync checkpoint surface

## Extension Model

The extension model in V2 is real and important.

Observed hook categories:

- `PreUpdateProcessor`
- `UpdateSourceProcessor`
- `PreAOupdateProcessor`
- `SourcePostInit`
- `AOPostInit`
- `UpdateTrigger`

Examples seen in `PLS`:

- `SRC.QuoteItemPreUpdate`
  - source cleanup before refresh
- `SRC.PurchaseOrderItemPostInit`
  - performance indexes after source table build
- `AO.PurchaseOrderPostInit`
  - performance indexes after AO table build
- `AO.UpdateProjectAccounts`
  - business enrichment after refresh

What this means:

- hooks are first-class architecture, even though they are stored as string columns

## State Model In V2

V2 is fundamentally a hash-based state-diff engine.

Important mechanics:

- `dbo.GetRowHashDefinition`
  - builds hash expressions from `SyncFieldMapping`
- `dbo.UpdateAORowHash`
  - recomputes AO row hashes
- source rows hold `RowHash`
- AO rows hold:
  - `AORowHash`
  - `srcRowHash`

Practical meaning:

- inserts are rows present in source but not yet carrying destination `Id`
- updates are rows where source hash differs from AO hash
- deletes are rows marked missing from source and flagged in AO

This is a good underlying idea, but the implementation couples state mutation too tightly to the execution path.

## Operational Model

### Async execution

V2 supports asynchronous batch execution through:

- `dbo.ExecuteAsync`

It creates transient SQL Agent jobs dynamically.

This works, but runtime visibility becomes split across:

- integration tables
- msdb job metadata

### File logging

V2 writes:

- success CSV logs
- error CSV logs

through:

- `dbo.WriteToFile`

This is useful operationally, but it means the durable outcome model is outside the database runtime tables.

### Reconciliation helpers

Additional helper procedures exist for diagnostics and ad hoc correction, including:

- `utils.SourceToDestinationDiscrepancy`
- `SF.RequestUpdate`
- `SF.UpdateObjectField`

This suggests V2 evolved practical support tools around the core engine rather than modeling those capabilities in the runtime itself.

## Architecture Strengths

- Metadata-driven object orchestration already exists.
- Field mapping is explicit and configurable.
- Source and destination-shadow layers are conceptually separated.
- Hash-based change detection is a solid foundation.
- Hooks allow client/object-specific customization.
- Batching and async dispatch exist already.

## Architecture Weaknesses

- Secrets and settings are mixed in `ClientProperties`.
- AO tables are overloaded as both state store and queue surface.
- Runtime work is stored in generated physical tables.
- Batch results are primarily expressed as text messages.
- Async job control depends on transient SQL Agent jobs.
- Outbound API transport is embedded directly in SQL.
- Hook phases are implicit strings instead of executable metadata.
- There is no single durable run history model for:
  - object steps
  - work items
  - batch requests
  - responses

## V3 Design Direction

V3 should preserve the best ideas from V2:

- object metadata
- field mapping
- hash-based change detection
- hook extensibility
- ordered object execution

But it should redesign the runtime around:

- normalized object definitions
- explicit hook registry
- durable pipeline runs
- source snapshots
- canonical object state
- work items
- batch requests
- persisted request/response payloads
- transport abstraction

## Proposed V3 Architecture

### Config layer

- `CFG.Client`
- `CFG.ConnectionProfile`
- `CFG.RuntimeSetting`

Purpose:

- move away from a single generic property bag
- split settings from endpoint definitions
- support secret references cleanly

### Definition layer

- `DEF.ObjectDefinition`
- `DEF.ObjectDependency`
- `DEF.ObjectHook`
- `DEF.FieldMap`

Purpose:

- preserve metadata-driven behavior
- normalize hooks into executable phases
- replace flat sort ordering with optional dependency edges

### Runtime layer

- `RT.PipelineRun`
- `RT.ObjectRun`
- `RT.ObjectRunStep`
- `RT.SourceSnapshotRun`
- `RT.SourceSnapshotRow`
- `RT.ObjectState`
- `RT.WorkSet`
- `RT.WorkItem`
- `RT.BatchRequest`

Purpose:

- make every unit of work durable and queryable

### Transport boundary

Recommended direction:

- keep SQL orchestration if needed initially
- move HTTP transport behind a narrower interface
- treat API dispatch as a service boundary, not raw implementation detail

## Recommended Migration Strategy

1. Import `AOobject` and `SyncFieldMapping` into V3 definitions.
2. Run V3 in planning mode only.
3. Compare V3 planned changes to V2 live outcomes for a real client like `PLS`.
4. Add durable batch persistence before replacing outbound dispatch.
5. Move one low-risk object to V3 execution.
6. Retire generated work-table runtime only after parity is demonstrated.

## Bottom Line

V2 already contains the right conceptual building blocks for a serious integration platform. The redesign for V3 should not throw those away. It should keep the metadata-driven synchronization model, but rebuild the runtime around durable state, explicit hooks, cleaner boundaries, and a transport layer that is no longer tangled into the orchestration core.
