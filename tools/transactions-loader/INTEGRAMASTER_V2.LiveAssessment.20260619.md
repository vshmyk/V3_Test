# INTEGRAMASTER_V2 Live Assessment

Captured from `LOCALHOST\ERPLINK` on `2026-06-19`.

## Confirmed Runtime Facts

- Database `INTEGRAMASTER_V2` exists on `LOCALHOST\ERPLINK`.
- Database `OASIS_PLS` exists on `LOCALHOST\ERPLINK`.
- SQL Agent job `AOtransact - Transactions Pipeline - PLS` has a step named `Apply Loaded Transactions`.
- That step currently executes:
  - `EXEC dbo.RunTransactions @ClientId = N'PLS';`

## Key Objects Present

- `dbo.ClientProperties`
- `dbo.GetClientParameterValue`
- `dbo.LoadTransactionPackage`
- `dbo.LoadTransactionPackage_v2`
- `dbo.LoadTransactions`
- `dbo.LoadTransactions_v2`
- `dbo.RunTransactions`
- `dbo.RunTransactions_NEW`
- `dbo.sp_LoadTransactions_v2`
- `dbo.sp_RunTransactions_v2`
- `dbo.sp_UpdateTransactionStatus`
- `dbo.ValidateTransactionFile`

## Architectural Observations

### 1. `ClientProperties` is doing too much

The table is not just transaction-pipeline config. It is acting as a general integration property store across many clients.

It currently mixes:

- source paths
- destination database names
- checkpoints
- linked-server names
- feature toggles
- external integration settings
- credentials and secrets

That is a strong reason for V3 to stop using one name/value table as the primary engine contract.

### 2. The active replay path is still the older proc

`dbo.RunTransactions_NEW` exists, but the live SQL Agent job still points at `dbo.RunTransactions`.

That means the actual production-like behavior still depends on the older implementation characteristics, including:

- direct lookup of `OASIS_DB` from `GetClientParameterValue`
- replay against `[OASIS_DB].dbo.TransactionLog`
- status updates written back into the same target table

### 3. `LoadTransactions_v2` is still filesystem-coupled

The live definition shows the load path still depends on shell/file enumeration behavior and updates `LAST_TRANSACTION_BATCH` directly in `ClientProperties`.

That means:

- source discovery is not first-class runtime state
- batch ingestion is not durably modeled
- checkpoint advancement is tied to the load operation itself

### 4. Target replay state lives in `OASIS_PLS.dbo.TransactionLog`

`TransactionLog` currently acts as:

- the landing zone
- the replay queue
- the replay status table

This is one of the main things V3 should split apart.

### 5. The target log table is operational, but not a strong domain model

On `2026-06-19`, `OASIS_PLS.dbo.TransactionLog` had:

- no primary key
- no foreign keys
- several supporting indexes
- `0` pending rows where `ExecutionTime IS NULL`

This is workable for V2, but not ideal as the core runtime model for future integrations.

## Design Consequences For V3

V3 should introduce:

- explicit client records
- explicit feed records
- feed-scoped checkpoints
- inbox batches
- inbox statements
- durable run history
- slice-level failure telemetry
- compatibility views only as a bridge, not as the core model

## Safe Summary

The live V2 system is not just "one transaction runner." It is a broader, organically grown integration hub with transaction replay embedded inside it. The V3 redesign should treat transaction replay as one supported feed type inside a clearer platform model.
