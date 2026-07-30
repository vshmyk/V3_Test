# CompTrans Extractor Production Runbook

This runbook covers how to deploy and activate `CompTransExtractor.exe` on a production server.

## Package

Deploy the published contents from:

`tools\comptrans-extractor\publish\win-x64`

Minimum files to keep on the server:

- `CompTransExtractor.exe`
- `CompTrans.config`
- `README.md` (optional)

## 1. Choose The Windows Account

Choose the Windows account that will run the scheduled task.

This matters because upload passwords are encrypted either for:

- the current Windows user, when `PASSWORD_SCOPE=CurrentUser`
- the whole machine, when `PASSWORD_SCOPE=LocalMachine`

Use `CurrentUser` when the task always runs under one dedicated service/user account.

## 2. Copy Files To The Server

Create a deployment folder such as:

```text
C:\ProgramData\AOtransact\CompTransExtractor
```

Copy the production files into that folder.

## 3. Configure `CompTrans.config`

Edit the config for the client environment.

Review these groups carefully:

- paths:
  `BACKUP_DIR`, `STATE_FILE`, `TRANSACTION_BACKUP_FILE`, `TRANSACTION_CURRENT_FILE`, `TRANSACTION_FINAL_FILE`, `TEMP_TRANSACTION_FILE`, `WORK_DIR`, `ARCHIVE_DIR`
- Sybase/log settings:
  `DBTRAN_PATH`, `SOURCE_DRIVE`, `SOURCE_LOG_RELATIVE_PATH`, `TABLE_LIST`, `STATE_TABLE_LIST`
- behavior:
  `FINAL_FILE_MODE`, `PREDELETE_BACKUP_DIR`, `PREDELETE_ALL_SHADOWS`, `DELETE_OLDEST_SHADOW_AFTER_RUN`, `ARCHIVE_RETENTION_DAYS`
- uploads:
  `UPLOAD_TARGETS` and `UPLOAD_TARGET.<name>.*`

For OpenSSH targets, configure:

```ini
UPLOAD_TARGET.<name>.PROTOCOL=SFTP
UPLOAD_TARGET.<name>.PORT=22
```

Current historical zip retention is controlled by:

```ini
ARCHIVE_RETENTION_DAYS=5
```

## 4. Verify Prerequisites

The server and task account need:

- access to `dbtran.exe`
- read access to the source log drive
- permission to run `vssadmin`
- permission to create/delete directory symbolic links
- write access to the configured data/log/archive folders
- network access to each FTPS destination
- network access to each FTPS or SFTP destination

## 5. Initialize Upload Passwords

Run this once interactively as the same Windows account that will run the scheduled task:

```cmd
CompTransExtractor.exe --set-password
```

The program will prompt once for each enabled upload target and store encrypted passwords in the config.

If the scheduled task will run under a different Windows account and `PASSWORD_SCOPE=CurrentUser`, uploads will fail until passwords are initialized under that task account.

## 6. Run A Manual Validation

Run the extractor manually:

```cmd
CompTransExtractor.exe
```

Confirm that it:

- creates a VSS shadow copy
- reads the Sybase log from the shadow path
- writes `TRANSACTION_CURRENT_FILE`
- updates `STATE_FILE`
- creates `TRANSACTION_FINAL_FILE`
- creates a zip in `ARCHIVE_DIR`
- uploads successfully to each enabled destination
- removes the shadow copy

## 7. Create The Scheduled Task

Recommended task settings:

- trigger: every 15 minutes
- run whether user is logged on or not
- run with highest privileges
- use the same Windows account used for `--set-password`
- do not allow overlapping runs

Program:

```text
C:\ProgramData\AOtransact\CompTransExtractor\CompTransExtractor.exe
```

Optional arguments if the config is stored elsewhere:

```text
--config C:\ProgramData\AOtransact\CompTransExtractor\CompTrans.config
```

## 8. Check First Production Runs

After enabling the task, verify:

- `STATE_FILE` is advancing
- new zip files appear in `ARCHIVE_DIR`
- uploaded files arrive at each destination
- old zip files age out according to `ARCHIVE_RETENTION_DAYS`
- local `.trn` files are cleaned up as expected

## FTP Troubleshooting

If extraction works but upload fails, enable FTP debug logging temporarily:

```ini
FTP_DEBUG_LOG=C:\Temp\CompTransExtractor.ftp.log
```

Then run:

```cmd
CompTransExtractor.exe
```

Review the log for:

- the remote URI being used
- SSL/passive mode
- FTP status codes
- WebException details

For SFTP targets, the log will instead show:

- remote SFTP path
- host and port
- SSH/SFTP exception type and message

If you suspect a certificate trust problem, you can temporarily set:

```ini
FTP_SKIP_CERT_VALIDATION_FOR_DEBUG=true
```

Use that only long enough to confirm whether certificate validation is the failure point, then switch it back to `false`.

## Common Failure Points

- wrong Windows account used for password initialization
- invalid `dbtran.exe` path
- incorrect source drive or log path
- insufficient rights for `vssadmin`
- insufficient rights for symlink creation/removal
- `FINAL_FILE_MODE=BackupPlusCurrent` without a valid `TRANSACTION_BACKUP_FILE`
- FTPS host/user/password mismatch for one of the upload targets
