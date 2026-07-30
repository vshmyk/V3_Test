# PostgreSQL Logical TRN Capture

This is the no-trigger capture path for `OASIS_FLUX`.

It uses:

- PostgreSQL logical decoding via `test_decoding`
- a persistent logical replication slot
- incremental extraction from the logical slot, so each run writes only the new committed DML since the previous run

Current assumption in this repo state:

- every tracked `dbo` / `oasis` table now has a primary key in PostgreSQL
- `oasis.CHSC_QUOTE_ATTACHMENTS` and `oasis.CHSC_PROJECT_ATTACHMENTS` are not expected to receive updates

That means the extractor can stay in a strict no-DDL / no-trigger mode and build replayable SQL Server-style DML from the logical stream using the primary keys already present on the tables.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-logical-trn\Install-PostgresLogicalTrn.ps1
```

This script:

- sets `wal_level=logical`
- ensures `track_commit_timestamp=on`
- restarts PostgreSQL
- removes the old `trg_aotransact_pg_capture_dml` triggers by default
- creates the logical slot `aotransact_flux_slot`

## Export `flux.trn`

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-logical-trn\Write-RecentFluxTrnLogical.ps1
```

Default output:

- TRN file: `C:\ERPLINK\FLUX\flux.trn`

## Important behavior

- This is forward-only from the point the logical slot exists.
- Each run consumes the next unread logical changes from the slot and writes only that batch to `flux.trn`.
- If nothing new has committed since the last run, `flux.trn` will be empty.
- If you delete the slot, unread logical changes are lost from this pipeline.

## Regression test

To generate a clean test batch with `INSERT` / `UPDATE` / `DELETE` on:

- `CHSC_PO`
- `CHSC_POLINE`
- `CHSC_QUOTE`
- `CHSC_QUOTELINE`

run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-logical-trn\Test-FluxTrnExtraction.ps1
```
