# LiteSpeed-Informed Refactor Plan

## Why This Exists

Our current offline pipeline is strongest at:

- scanning raw log bytes
- finding active windows and marker families
- building exploratory manifests

It is weakest at:

- promoting record fragments directly into trusted row DML
- staying stable across marker families
- separating "record evidence" from "command reconstruction"

The LiteSpeed LogReader surface suggests a better model:

1. `Reader`
2. `Records`
3. `Transactions`
4. `Commands`

That layered shape fits what we have been learning from the MH `.ldf` work:

- `CB` often looks like status / workflow / attachment-side signal
- `D2` often looks like structured fragment bundles
- neither is safe to treat as an immediate row image

## Current Code Shape

### Runner

Primary file:

- [Program.cs](/c:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/aotransact-runner/Program.cs)

Current main stages:

- `BuildOfflineManifestAsync(...)`
- `BuildRawOfflineExplorationAsync(...)`
- `RunOfflineScan(...)`
- `RunConvertAsync(...)`

Current behavior:

- raw bytes are scanned
- candidate records are decoded into a flat `OfflineScanResult`
- some candidates are written directly to manifest rows
- converter tries to materialize final DML from those rows

### Converter

Primary file:

- [Program.cs](/c:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/fast-quote-convert/Program.cs)

Current behavior:

- reads flat manifest rows
- uses table-specific heuristics
- resolves keys
- optionally uses live DB validation
- emits DML or unresolved placeholders

This is where most brittleness currently lives.

## LiteSpeed Hints We Should Copy

From LiteSpeed wrapper metadata:

- `RecordWrapper`
  - `Lsn`
  - `PreviousLsn`
  - `Operation`
  - `Context`
  - `ObjectID`
  - `ObjectName`
  - `PageID`
  - `SlotID`
  - `IndexID`
  - `TransactionID`
  - `Date`
  - `NTUser`
  - `Commited`
- `TransactionWrapper`
  - `TransactionID`
  - `BeginLsn`
  - `EndLsn`
  - `BeginTime`
  - `EndTime`
  - `RecordCount`
  - `CommandCount`
  - `NTUser`
  - `DbUser`
  - `Commited`
- `CommandWrapper`
  - `TransactionID`
  - `Lsn`
  - `Type`
  - `Name`
  - `ObjectID`
  - `ObjectName`
  - `ParentID`
  - `ParentName`
  - `RedoScript`
  - `UndoScript`
  - `Columns`

The main lesson is not "copy LiteSpeed internals". The lesson is:

- preserve richer record identity early
- group transactionally before inferring commands
- only materialize row-level DML after command reconstruction

## Proposed New Pipeline

### Stage 1: Record Extraction

Keep `RunOfflineScan(...)`, but change its output role.

Instead of acting as a near-final manifest builder, it should produce a richer intermediate record stream.

### New model: `ExtractedRecord`

Suggested fields:

- `Offset`
- `Length`
- `DbMarker`
- `MajorOp`
- `Action`
- `CurrentLsn`
- `PreviousLsn` if derivable
- `TxId`
- `PrimaryToken`
- `MatchedTable`
- `MatchedSchema`
- `StrictPrimaryTokenMatch`
- `RecordType`
- `ContextHint`
- `PageIdHint`
- `SlotIdHint`
- `IndexIdHint`
- `CaptureHex`
- `CaptureAscii`
- `RecordFlags`
- `EvidenceTags`

Notes:

- `MatchedTable` should be nullable.
- `EvidenceTags` should hold things like:
  - `base_row_token`
  - `nearby_token_match`
  - `printable_payload`
  - `control_like`
  - `dense_fragment`
  - `commit_like`

### Stage 2: Transaction Assembly

New stage in the runner:

- `BuildTransactionBundles(...)`

This should group records by:

- `TxId`
- LSN proximity
- offset proximity
- commit presence

### New model: `TransactionBundle`

Suggested fields:

- `TransactionId`
- `BeginLsn`
- `EndLsn`
- `RecordCount`
- `CommitSeen`
- `PrimaryMarkerFamilies`
- `TablesSeen`
- `TokensSeen`
- `Records`
- `BundleTags`

Important behavior:

- if a tx contains multiple marker families, we preserve that
- do not flatten away the relationship between `CB`, `D2`, `C8`, etc.

This is the stage that should absorb our MH bundle work.

### Stage 3: Command Reconstruction

New stage:

- `BuildCommandCandidates(...)`

This is the key architectural change.

Instead of asking "can I emit a row now?", we first ask:

- what logical command seems to exist inside this transaction bundle?

### New model: `CommandCandidate`

Suggested fields:

- `TransactionId`
- `CommandType`
  - `Insert`
  - `Update`
  - `Delete`
  - `Ddl`
  - `Unknown`
- `SchemaName`
- `TableName`
- `ObjectIdentityConfidence`
- `Records`
- `Fragments`
- `KeyEvidence`
- `ColumnEvidence`
- `Confidence`
- `Warnings`

For now, a `CommandCandidate` can still be incomplete. That is fine.

The important shift is:

- a command is reconstructed from multiple records
- not from one manifest row pretending to be the whole change

### Stage 4: Table-Specific Materializers

Only after we have `CommandCandidate`s should we try table-specific row materialization.

This is where the current converter logic belongs.

Instead of:

- `ManifestRec -> heuristic key decode -> emit`

the flow should become:

- `CommandCandidate -> table materializer -> resolved row or unresolved command`

## Concrete Code Refactor

### Runner Changes

In [Program.cs](/c:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/aotransact-runner/Program.cs):

1. Keep `RunOfflineScan(...)`, but rename its conceptual output from "manifest-first" to "record-first".
2. Add internal models:
   - `ExtractedRecord`
   - `TransactionBundle`
   - `CommandCandidate`
3. Split `BuildOfflineManifestAsync(...)` into:
   - `ExtractRecordsAsync(...)`
   - `BuildTransactionBundles(...)`
   - `BuildCommandCandidates(...)`
   - `WriteManifestFromCommands(...)`
4. For `raw_offline_exploration`, write:
   - `records.json`
   - `transactions.json`
   - `commands.json`
   instead of only one flattened pseudo-manifest

### Converter Changes

In [Program.cs](/c:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/fast-quote-convert/Program.cs):

1. Stop assuming one manifest row is close to one business row.
2. Accept richer per-command input.
3. Move current heuristics into table-specific materializers:
   - `QuoteLineMaterializer`
   - later `PoLineMaterializer`, etc.
4. Keep trust diagnostics, but attach them to:
   - command reconstruction
   - row materialization
   separately

## Minimal First Slice

We do not need to refactor everything at once.

### Slice 1

Add these models in the runner:

- `ExtractedRecord`
- `TransactionBundle`

And output them as JSON diagnostics for MH raw exploration.

This gives us:

- immediate visibility
- no converter rewrite yet
- lower-risk adoption

### Slice 2

Add `CommandCandidate` grouping only for:

- `CHSC_QUOTELINE`

That lets us test the new architecture against the area we already know best.

### Slice 3

Change converter input from flat manifest rows to command candidates for:

- `CHSC_QUOTELINE` only

If that works, expand table by table.

## How This Helps MH Specifically

For MH, we only have the `.ldf`.

That means:

- we should stop leaning on a non-matching test DB as authoritative truth
- we should lean harder on:
  - transaction grouping
  - fragment bundles
  - command-level inference

This proposal supports that directly.

For the current MH findings:

- `D2` dense/control subtypes become transaction fragments, not fake rows
- `CB` status/message records become companion evidence, not candidate DML rows
- command reconstruction can decide whether those families belong to:
  - one logical update
  - side-channel status activity
  - or unrelated noise

## What Success Looks Like

We should consider this refactor successful when:

1. repeated runs over the same `.ldf` produce stable `TransactionBundle` and `CommandCandidate` output
2. stale false-positive rows drop without relying on ad hoc table heuristics
3. unresolved output becomes "unresolved command" instead of "fake row with weak key"
4. row materializers operate on command evidence, not isolated fragments

## Recommended Next Implementation Step

Build **Slice 1** first:

- add `ExtractedRecord`
- add `TransactionBundle`
- write them to JSON in raw exploration mode

That gives us a safer base for the next MH deep-dive and does not force a converter rewrite yet.
