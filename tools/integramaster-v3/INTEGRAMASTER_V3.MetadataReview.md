# INTEGRAMASTER_V3 Metadata Review

Last updated: 2026-06-19 UTC

## Goal

Replace the current V2 metadata tables with a cleaner, more normalized structure that:

- uses clearer names
- removes overloaded generic storage
- enforces integrity
- keeps the metadata-driven behavior that works well in V2

## V2 Tables Reviewed

- `dbo.ClientProperties`
- `dbo.AOobject`
- `dbo.SyncFieldMapping`

Reviewed against live `INTEGRAMASTER_V2` on `LOCALHOST\ERPLINK`.

## Main Findings

### `ClientProperties`

Problems:

- one generic property bag for everything
- mixes config and secrets
- no primary key
- no scope typing
- no validation for allowed property names

Observed uses include:

- database routing
- linked server names
- destination API URL
- usernames/passwords/secrets/tokens
- file paths
- feature toggles
- operational parameters

V3 direction:

- split into:
  - `cfg.IntegrationClient`
  - `cfg.ConnectionProfile`
  - `cfg.ClientSetting`
  - `cfg.ClientSecretReference`

### `AOobject`

Problems:

- name is unclear
- object definition, operation policy, hooks, and miscellaneous options are all mixed together
- weak integrity
- duplicate logical objects exist in live data

Observed live integrity issue:

- duplicate `(ClientId, ObjectName)` exists for `MACSII / QuoteItem`

V3 direction:

- replace with:
  - `meta.SyncObject`
  - `meta.SyncObjectOperation`
  - `meta.SyncObjectHook`
  - `meta.SyncObjectSetting`

### `SyncFieldMapping`

Problems:

- field mapping, hash behavior, keys, update policy, and optional flags are all mixed together
- no enforced uniqueness for display order inside an object
- some columns appear unused or legacy

Observed live integrity issue:

- duplicate `FieldSortOrder` values exist within the same object for multiple clients

Columns with especially weak evidence of current use:

- `DestHashComponent_DEL`
- `ConditionalSync`

V3 direction:

- replace with:
  - `meta.FieldMap`

## Better Naming

### Client metadata

- `ClientProperties` -> `cfg.IntegrationClient`, `cfg.ClientSetting`, `cfg.ClientSecretReference`

### Object metadata

- `AOobject` -> `meta.SyncObject`

Reason:

- the table is defining synchronized business objects, not “AO objects”

### Field metadata

- `SyncFieldMapping` -> `meta.FieldMap`

Reason:

- shorter and clearer

### Operations

Instead of one `TransactionTypes` string column:

- `meta.SyncObjectOperation`

Reason:

- one row per operation is easier to validate and query

### Hooks

Instead of several procedure-name columns:

- `meta.SyncObjectHook`

Reason:

- hook phase becomes explicit and extensible

## Recommended V3 Tables

### `cfg.IntegrationClient`

Core client record.

### `cfg.ConnectionProfile`

Structured endpoints such as:

- source SQL database
- linked server
- destination API

### `cfg.ClientSetting`

Non-secret client settings.

### `cfg.ClientSecretReference`

Reference names for secrets, without storing raw passwords in the new model.

### `meta.SyncObject`

Core object definition, including:

- execution order
- source stage table
- state table
- destination object name
- batch size
- sync delay
- retrieval policy

### `meta.SyncObjectOperation`

One row per supported operation:

- `I`
- `U`
- `D`
- `R`

### `meta.SyncObjectHook`

One row per hook phase and procedure.

### `meta.SyncObjectSetting`

For low-frequency or legacy per-object options that do not belong in the core object table.

### `meta.FieldMap`

Field-level mapping with:

- source field name
- state column name
- outbound field name
- key flags
- hash ordering
- computed expression
- data types

## Integrity Rules Added In V3

- primary keys on every table
- foreign keys between client, object, hook, operation, and field map tables
- unique client codes
- unique object codes per client
- unique operation codes per object
- unique hook rows per object/phase/procedure
- filtered unique display order per object
- check constraints for:
  - operation code
  - connection type
  - hook phase
  - non-negative sync delay
  - positive batch size

## Legacy Columns Not Carried Forward As Core Columns

These are intentionally not first-class columns in the new core tables:

- `O4Json`
- `ResultSet`
- `DataSourceParameter`
- `RestrictOnReload`

If needed, they are imported into:

- `meta.SyncObjectSetting`

That keeps the main schema clean while preserving recoverability.

## Development Starting Point

The first V3 development pass creates:

- the new `INTEGRAMASTER_V3` database
- normalized metadata tables
- lookup tables for hook phases and operation types
- import procedures from live V2 metadata

Initial pilot import target:

- `PLS`
