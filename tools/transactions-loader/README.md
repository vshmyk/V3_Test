# Transactions Loader

Loader for zipped `pls.trn` batches received from another server.

## What it does

- accepts `ClientId` as a command-line parameter
- reads `DATASOURCE_LOCATION` from `INTEGRAMASTER_V2.dbo.ClientProperties`
- scans `[DATASOURCE_LOCATION]\Logs` for zip files
- sorts zip files from oldest to newest by file `Date Modified`
- reads `LAST_TRANSACTION_BATCH` from `INTEGRAMASTER_V2.dbo.ClientProperties`
- starts strictly after that checkpoint file
- does not backfill from the oldest file when `LAST_TRANSACTION_BATCH` is empty
- reads `OASIS_DB` from `INTEGRAMASTER_V2.dbo.ClientProperties`
- auto-detects the single `.trn` file inside each zip
- loads each individual DML statement into `OASIS_PLS.dbo.TransactionLog`
- preserves statement order exactly as encountered in `pls.trn`
- updates the checkpoint to the processed zip filename after each successful batch
- can optionally inject a PK-based `DELETE` before simple `INSERT ... VALUES (...)` statements for test replay scenarios

## Build

```powershell
dotnet build .\tools\transactions-loader\AOtransact.TransactionsLoader.csproj
```

## Run

```powershell
dotnet run --project .\tools\transactions-loader\AOtransact.TransactionsLoader.csproj -- `
  --client-id PLS `
  --config .\tools\transactions-loader\transactions-loader.config.sample.json
```

Example SQL Server Agent command step:

```powershell
dotnet C:\Users\vshmyk\AOprojects\AOtransact\tools\transactions-loader\bin\Debug\net8.0\AOtransact.TransactionsLoader.dll --client-id PLS --config C:\Users\vshmyk\AOprojects\AOtransact\tools\transactions-loader\transactions-loader.config.sample.json
```

Release publish:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\transactions-loader\Publish-TransactionsLoader.ps1
```

MSI build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\transactions-loader\Build-TransactionsLoaderMsi.ps1
```

This produces:

- `.\artifacts\msi\AOtransact.TransactionsLoader.Installer.msi`

Production install:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\transactions-loader\Install-TransactionsLoader.ps1
```

This installs the production executable and configs to:

- `C:\ProgramData\AOtransact\TransactionsLoader`

Production run example:

```powershell
C:\ProgramData\AOtransact\TransactionsLoader\AOtransact.TransactionsLoader.exe `
  --client-id PLS `
  --config C:\ProgramData\AOtransact\TransactionsLoader\transactions-loader.config.production.sample.json
```

SQL Agent example script:

- [sqlagent-job-step.example.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/sqlagent-job-step.example.sql)
- [sqlagent-job.pls.erplink.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/sqlagent-job.pls.erplink.sql)

## Inserted columns

- `TransactionId`
- `Id` = sequential statement number within each batch, starting at `1`
- `TransactionStatement`
- `BatchTime` = `GETDATE()`
- `BatchId` = zip file name without `.zip`

## Notes

- `OASIS_DB` is used dynamically, so inserts go to `[OASIS_DB].dbo.TransactionLog` for the supplied client.
- `DATASOURCE_LOCATION` is treated as the base path; the loader appends `\Logs` unless the property already ends with `Logs`.
- `LAST_TRANSACTION_BATCH` is the checkpoint property updated after each successfully committed zip batch.
- `LAST_TRANSACTION_BATCH` must be populated; the loader stops if it is blank or missing.
- `TransactionId` is taken from the header line immediately above each statement when present, for example `--UPDATE-1137-0344373967268`.
- The zip must contain exactly one `.trn` file; the loader errors if there are zero or multiple `.trn` entries.
- The sample config defaults to `dry_run=true`; switch it to `false` for real loads.
- `options.predelete_before_insert=true` is a test-only replay aid. When enabled, the loader tries to derive the target table primary key for simple `INSERT ... VALUES (...)` statements and injects a matching `DELETE` before the `INSERT`.
- The pre-delete rewrite is intentionally conservative. If the loader cannot parse the `INSERT`, cannot find the target table PK, or the `INSERT` does not include every PK column, it leaves the statement unchanged.
- The tuned `RunTransactions` script now defaults `@InitialBatchSize` to `1000`, which tested slightly faster than `500` after the proc and index changes.
- [transactions-loader.config.production.sample.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/transactions-loader.config.production.sample.json) is the production-oriented sample with `dry_run=false` and no file cap.
