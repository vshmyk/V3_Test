# INTEGRAMASTER_V3 Design

Last updated: 2026-06-19 UTC

## Goal

Build a new integration engine that keeps the strongest ideas from `INTEGRAMASTER_V2`, but stops treating integration as:

- one `ClientProperties` rowset
- one checkpoint value
- one `RunTransactions` procedure
- one target `TransactionLog` table pattern

`INTEGRAMASTER_V3` should become a reusable platform for future projects, not just a tuned version of the current PLS transaction replay flow.

## Live V2 Findings

The design below is informed by a direct review of the live `INTEGRAMASTER_V2` database on `LOCALHOST\ERPLINK` on `2026-06-19`.

Observed facts that matter for V3:

- The active SQL Agent job step for PLS still runs `EXEC dbo.RunTransactions @ClientId = N'PLS';`.
- `dbo.RunTransactions_NEW` exists in the live database, but the scheduler is not pointed at it yet.
- `dbo.RunTransactions` is still tightly coupled to:
  - `dbo.GetClientParameterValue`
  - `dbo.ClientProperties`
  - `[OASIS_DB].dbo.TransactionLog`
- `dbo.LoadTransactions_v2` still shells out to the filesystem and directly mutates `LAST_TRANSACTION_BATCH`.
- `dbo.ClientProperties` is serving as a mixed-purpose store for:
  - integration routing
  - source paths
  - checkpoints
  - destination settings
  - secrets and tokens
- `OASIS_PLS.dbo.TransactionLog` has no primary key or foreign keys and acts as both inbox and replay audit surface.

Those findings reinforce that V3 should separate:

- config from secrets
- ingestion from replay
- replay telemetry from target tables
- feed runtime state from generic client properties

## What V2 Gets Right

- It is simple to operate.
- It has a clear client checkpoint model.
- It protects execution with `sp_getapplock`.
- It can isolate bad statements by recursively shrinking failing ranges.
- It has already proven the basic "ingest then replay" pattern in production-like usage.

## What V2 Limits

### 1. Configuration is too implicit

Everything important is hidden in `ClientProperties` name/value rows. That makes ad hoc setup easy, but it becomes weak when we need:

- multiple feeds per client
- different execution modes
- per-feed runtime policy
- richer operational metadata

### 2. Ingestion and execution are loosely coordinated

The loader writes directly into the target system's `TransactionLog`. That couples:

- transport
- staging
- replay
- replay status

into one target-specific table.

### 3. There is no first-class runtime model

V2 has no durable concept of:

- feed definitions
- inbox batches
- statement lifecycle
- run history
- per-slice execution telemetry
- poison-batch handling

### 4. V2 is optimized for one style of integration

Today the logic is effectively:

- load zipped `.trn` files
- extract DML
- write to a log table
- replay SQL in order

Future integrations may instead need:

- file copy + transform + load
- validation-only runs
- staged merge execution
- non-SQL payload ingestion
- richer alerting and replay controls

## V3 Design Principles

1. Separate configuration, ingestion, runtime, and replay state.
2. Model feeds explicitly, not just clients.
3. Keep ordered statement replay as one supported execution mode, not the only mode.
4. Make batch and statement lifecycle durable and queryable.
5. Preserve the V2 strengths:
   - checkpointing
   - applocks
   - ordered replay
   - binary split failure isolation
6. Add compatibility where practical so migration can be staged.

## Core Model

### Configuration

- `CFG.IntegrationClient`
  - who the integration belongs to
  - default target database
  - default source root
- `CFG.IntegrationFeed`
  - one client can have multiple feeds
  - each feed has its own source, file pattern, checkpoint behavior, and execution mode
- `CFG.IntegrationProperty`
  - optional extensibility layer for future feed/client settings without schema churn
  - intended for non-secret settings

### Runtime

- `RT.IntegrationCheckpoint`
  - durable position for a feed
- `RT.IntegrationInboxBatch`
  - one discovered external batch per source artifact
- `RT.IntegrationInboxStatement`
  - ordered statements staged independently from the target database
- `RT.IntegrationRun`
  - one execution attempt
- `RT.IntegrationRunSlice`
  - one replay slice inside a run, including split-on-error telemetry

## Execution Modes

V3 introduces the idea of execution mode at the feed level.

Initial supported mode in this redesign:

- `StatementReplay`
  - replay ordered SQL statements into the target database
  - preserves the V2 mental model

Future modes the model is designed to allow:

- `StoredProcedure`
- `TransformAndMerge`
- `FileOnly`
- `WebhookDispatch`

## Statement Replay Flow

### Ingest

1. Loader resolves the feed.
2. Loader creates one `RT.IntegrationInboxBatch` row per source file.
3. Loader creates ordered `RT.IntegrationInboxStatement` rows.
4. Loader marks the batch `Ready`.

### Execute

1. `RT.RunIntegrationFeed_V3` resolves the feed runtime.
2. It acquires an applock scoped to client + feed.
3. It creates a durable `RT.IntegrationRun` row.
4. It selects pending statements ordered by:
   - batch timestamp
   - external batch key
   - ordinal
5. It executes slices of statements against the target database.
6. On error it recursively splits slices until it isolates a single bad statement.
7. It records slice telemetry in `RT.IntegrationRunSlice`.
8. It updates statement and batch status.
9. It advances the checkpoint only after fully successful batches.

## Why Inbox Staging Is Better

In V2, replay state lives in the same table that acts as the transport landing zone.

In V3, we can answer:

- which external batch was loaded?
- which statements came from it?
- which run attempted them?
- which slice failed?
- which statements are still pending?
- which batch became poison?

without relying on target-database side effects.

## Migration Strategy

### Phase 1

Deploy the V3 schemas and runtime objects.

### Phase 2

Keep the current loader if needed, but begin resolving source/checkpoint settings from V3 compatibility objects rather than `ClientProperties`.

### Phase 3

Replace direct writes to target `TransactionLog` with writes to:

- `RT.IntegrationInboxBatch`
- `RT.IntegrationInboxStatement`

### Phase 4

Cut replay over from `dbo.RunTransactions` in `INTEGRAMASTER_V2` to `RT.RunIntegrationFeed_V3` in `INTEGRAMASTER_V3`.

### Phase 5

Add feed-specific transforms or alternate execution modes as new projects require them.

## Compatibility Layer

This redesign includes a compatibility view:

- `dbo.vw_TransactionsLoaderCompatibility_V3`

It exposes:

- `DATASOURCE_LOCATION`
- `LAST_TRANSACTION_BATCH`
- `OASIS_DB`

in a shape similar to the current loader expectations, so migration does not have to be all-at-once.

## What This Redesign Intentionally Changes

- Checkpoints are feed-scoped, not just client-scoped.
- Batches are first-class records.
- Statements are staged in the integration database, not only in the target database.
- Run history and failure telemetry become part of the engine itself.
- Configuration becomes explicit and queryable.

## Recommended Next Implementation Steps

1. Deploy `INTEGRAMASTER_V3.Bootstrap.sql`.
2. Register the first client/feed pair for the current transaction replay use case.
3. Add a loader write path that targets the V3 inbox tables.
4. Run the same `.trn` batches through V2 and V3 in parallel.
5. Compare:
   - processed statement counts
   - isolated failures
   - checkpoint advancement
   - replay timing
6. Cut one client over only after batch-for-batch parity is confirmed.
