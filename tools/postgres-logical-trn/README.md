# AOtransactPostgreSQL

`AOtransactPostgreSQL` is a client-agnostic Windows utility that captures committed PostgreSQL changes without table triggers or table DDL, translates them to SQL Server-compatible DML, packages each non-empty batch as a ZIP containing one `.trn` file, and optionally transfers it by SFTP.

It uses PostgreSQL logical decoding through `test_decoding`, a persistent logical replication slot, primary keys already present on configured tables, and a saved local checkpoint.

## Client configuration

Start with `aotransact-postgresql.config.example.json` and save the customized file as `aotransact-postgresql.config.json`.

The recommended setup is the elevated graphical wizard:

```powershell
.\AOtransactPostgreSQL.exe --wizard
```

The wizard collects and validates all client, PostgreSQL, file, ZIP, SFTP, schedule, and tracked-table settings. It writes ACL-restricted credential files, optionally configures PostgreSQL logical decoding, performs an initial capture, installs the utility, and registers the scheduled task. PostgreSQL setup is clearly marked because it may restart the database service.

Set `postgres.psql_path` and `postgres.service_name` to `auto` to detect the newest installed PostgreSQL version. Both standard layouts are supported: `C:\Program Files\PostgreSQL\<version>\bin` and `C:\Program Files\PostgreSQL\<version>\pgsql\bin`. The wizard displays the detected values so they can be reviewed or overridden before installation.

Configured table names are the SQL Server destination names. If an exact PostgreSQL relation is absent, capture automatically uses a table with the same name (case-insensitive) from another PostgreSQL schema when there is exactly one match. For example, configured `oasis.CHSC_PO` can read from PostgreSQL `public.chsc_po` while emitting DML for SQL Server `[oasis].[CHSC_PO]`. Ambiguous matches are rejected instead of guessed.

`capture.max_changes_per_run` bounds each logical-decoding read (default `10000`). PostgreSQL completes the current transaction even when that limit is reached, so transaction boundaries remain intact while busy databases are processed in predictable batches. `last-batch.json` records `batch_limit_reached` to show whether more WAL is likely waiting.

Version 1.9.0 processes up to `capture.max_batches_per_run` batches per EXE invocation (default `20`), stopping sooner when a batch returns below its decoder limit or `capture.max_run_seconds` is reached (default `600`). The time budget is soft: it is checked between batches and never interrupts a transaction, transfer, or slot advancement. Each batch retains its own archive, ZIP, delivery, and checkpoint. The exclusive run lock covers the whole invocation. Set `max_batches_per_run` to `1`, or pass `--single-batch`, for the previous behavior. More batches increase catch-up load; tune the limits to the client's database capacity. Direct invocation of the PowerShell batch script still processes only one batch.

`last-batch.json` includes the first and last decoded commit timestamps in UTC. `last-run.json`, beside the last-batch file, records total batches/statements, stop reason, latest decoded commit, and a conservative `more_wal_hint`. A hint of `true` is not proof of pending changes; a transaction can exceed the row limit even when it is the last pending transaction. SFTP verification confirms file delivery, not successful SQL Server application.

A drained run can finish with an empty last batch, clearing the current `.trn` when configured. Use the run summary for totals and the archive/sent ZIPs for earlier batches. Keep the scheduled task's execution timeout longer than the soft budget plus the maximum expected duration of one batch.

Only one capture process may use a configuration at a time. The executable holds an exclusive `.run.lock` file for the full run, and capture also refuses to proceed when PostgreSQL reports that the logical slot is already active.

When SFTP is enabled, every ZIP in `package.directory` is treated as pending and uploaded oldest first. Successfully verified uploads are moved to `package.sent_directory` (or a sibling `sent` directory for older configs), so interrupted transfers are retried without repeatedly sending completed files.

Version 2.0.0 embeds native .NET SFTP using SSH.NET; neither WinSCP.exe nor WinSCPnet.dll is needed. OpenSSH-style SHA-256 fingerprints (`ssh-ed25519 255 SHA256:<hash>`), legacy WinSCP SHA-256 notation (`ssh-ed25519 255 <hash>`), and bare `SHA256:<hash>` are accepted with strict verification. Wildcards are rejected. Existing `winscp_dll_path` properties are ignored and can be removed.

Native uploads use unique unpublished temporary names, verify size and SHA-256 by reading back the remote content, then rename to the final filename. An already-present identical final file is accepted as a retry; a different final file is never deleted or overwritten. `sftp.timeout_seconds` defaults to `60`, and `sftp.retry_count` defaults to `2` additional attempts for transient connection/I/O failures. Authentication, fingerprint, and content-collision failures stop capture without advancing its slot. Full remote readback increases transfer traffic but detects corrupted or conflicting content.

Use `AOtransactPostgreSQL.exe --test-sftp --config <path>` to verify authentication, host key, and remote directory. `--test-sftp-transfer` additionally uploads an 8 KB non-DML probe, validates readback/rename/identical-file retry, then removes the probe. Neither command accesses PostgreSQL or changes a checkpoint. A directly invoked capture script needs `-SftpExecutable <path>` when the EXE is not beside its config. SFTP dispatch uses the same embedded EXE; no password is passed on the command line.

`capture.archive_retention_days` controls retention of `.trn` files in `capture.archive_directory` and defaults to `5`. Cleanup runs after a successful capture and never removes pending ZIP packages from `outbox` or uploaded packages from `sent`.

`capture.trim_fixed_character_trailing_spaces` defaults to `true`. It removes only trailing ASCII-space padding from PostgreSQL fixed-width `character(n)`/`bpchar` values while preserving leading spaces and all `varchar`/`text` values unchanged.

Database and SFTP passwords are stored using Windows DPAPI `LocalMachine` encryption plus SYSTEM/Administrators-only file ACLs. Encrypted files are bound to the client computer so the `SYSTEM` scheduled task can decrypt them, but copies cannot be decrypted elsewhere. Legacy plaintext `Password=` files remain readable; run `Protect-AOtransactCredentials.ps1 -ConfigPath <path>` once to migrate an existing installation.

Generated DML preserves PostgreSQL logical-decoding order, including the original INSERT/UPDATE/DELETE sequence within each committed transaction.

Logical-decoding payloads are transported from `psql` as Base64 and decoded as UTF-8. This preserves embedded line breaks, commas, quotes, and Unicode text without CSV/native-process truncation.

Before writing or uploading a batch, every generated statement is checked for a terminating semicolon and balanced SQL string literals. Validation failure leaves the logical slot unchanged.

The client-specific settings are:

- `client.id` and `client.name`
- `postgres.*` connection, executable, Windows service, and credentials
- `capture.*` output, archive, checkpoint, metadata, and error paths
- `package.*` ZIP directory and filename templates
- `sftp.*` production endpoint, credentials, host key, and destination
- `schedule.*` task name and interval, which defaults to 15 minutes
- `tables` containing the exact `schema.table` names to capture

Filename templates support `{client_id}`, `{last_lsn}`, and `{batch_utc}`. The default `{client_id}_{last_lsn}.zip` is stable across retries and unique across clients.

Credential files created by the wizard use this format:

```text
DPAPI_LOCAL_MACHINE=<encrypted payload>
```

Passwords are not stored in the JSON config. The utility can still read legacy `Password=` files so existing installations can be migrated with `Protect-AOtransactCredentials.ps1`.

## PostgreSQL setup

Run once from elevated PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-PostgresLogicalTrn.ps1 `
  -ConfigPath .\aotransact-postgresql.config.json
```

The setup enables `wal_level=logical` and commit timestamp tracking when needed, restarts the configured PostgreSQL service if required, and creates the configured logical slot. It does not alter application tables.

Every configured table must already have a primary key. Attachments or other tables that never need synchronization can be omitted from `tables`.

## Run

Run the packaged executable directly:

```powershell
.\AOtransactPostgreSQL.exe --config .\aotransact-postgresql.config.json
```

If no config argument is supplied, the executable reads `aotransact-postgresql.config.json` beside itself.

Each successful non-empty run writes the current `.trn`, archives a copy, creates a ZIP, optionally uploads the ZIP, and only then advances the PostgreSQL logical slot. A packaging or SFTP failure leaves the slot unchanged for retry. Empty runs create no archive or ZIP by default.

## Install schedule

Run from elevated PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-AOtransactPostgreSQL.ps1 `
  -ConfigPath .\aotransact-postgresql.config.json
```

The installer copies the executable, config, PostgreSQL setup, credential migration script, and third-party notices to `C:\ProgramData\AOtransactPostgreSQL`. It registers the configured scheduled task as `SYSTEM`, starts missed runs when possible, and prevents overlapping instances. An existing installed config is preserved unless `-ForceConfig` is supplied.

## Build

Build the self-contained Windows x64 package with:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-AOtransactPostgreSQL.ps1
```

The package under `dist` contains `AOtransactPostgreSQL.exe`, editable config files, setup scripts, third-party notices, and this guide. SSH.NET is bundled inside the EXE; no WinSCP installation or separate .NET runtime is required. Windows PowerShell remains a Windows component dependency because the executable runs the embedded capture engine. Existing installations can upgrade by replacing only the EXE after stopping the task; credentials, checkpoints, and config remain unchanged. Old WinSCP files are unused and may be removed when no other software uses them.

## Regression test

The test performs real `INSERT`, `UPDATE`, and `DELETE` transactions on the configured PostgreSQL test database and verifies the generated SQL and ZIP:

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-PostgreSQLTransactionExtraction.ps1 `
  -CaptureExecutable .\dist\AOtransactPostgreSQL-win-x64\AOtransactPostgreSQL.exe
```
