# PostgreSQL TRN Capture

This folder adds a PostgreSQL-native path for emitting AOtransact-style `.trn` output from `OASIS_FLUX`.

What it does:

- installs row-level audit triggers on the `dbo` and `oasis` schemas
- captures committed `INSERT`, `UPDATE`, and `DELETE` row changes into `aotransact_pg.dml_audit`
- uses `track_commit_timestamp` so export windows are based on commit time rather than trigger fire time
- writes a replay-friendly `flux.trn` file to `C:\ERPLINK\FLUX\flux.trn`

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-trn\Install-PostgresTrnCapture.ps1
```

This script:

- enables `track_commit_timestamp`
- restarts the PostgreSQL Windows service
- creates the audit objects in `OASIS_FLUX`
- installs capture triggers on all current `dbo` and `oasis` tables
- grants the PostgreSQL service account write access to `C:\ERPLINK\FLUX`

## Export last 15 minutes

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-trn\Write-RecentFluxTrn.ps1
```

Optional custom window/output:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\postgres-trn\Write-RecentFluxTrn.ps1 `
  -Window "30 minutes" `
  -OutputPath "C:\ERPLINK\FLUX\flux.trn"
```

## TRN format

Each captured row change is exported as:

```text
--UPDATE-754321-0000000123
-- commit_time=2026-06-03 19:15:02.123 UTC table=oasis.CHSC_QUOTELINE
UPDATE oasis.CHSC_QUOTELINE SET qty = '2' WHERE quoteid IS NOT DISTINCT FROM '10';
GO
```

Notes:

- `UPDATE` statements use changed non-PK columns in the `SET` clause and primary keys in the `WHERE` clause when a PK exists.
- `DELETE` statements use the primary key in the `WHERE` clause when available, otherwise they fall back to all columns from the old row.
- `INSERT` statements include every table column in ordinal order.
- Binary values are emitted with `decode(..., 'hex')`.

## Maintenance

Purge old audit rows when needed:

```sql
CALL aotransact_pg.purge_audit_rows(interval '7 days');
```
