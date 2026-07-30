# CompTrans Extractor

This is a Windows command-line utility for Sybase/SQL Anywhere transaction extraction.

It started from the `CompTrans` flow, and it now follows the same overall pattern as `AOssc.bat` while moving client-specific behavior into config.

The executable:

- reads the source log from a fresh VSS shadow copy
- creates and deletes that shadow copy internally with built-in `vssadmin` calls
- runs `dbtran` against a configured table list
- updates the saved offset using a configured state-tracking table list
- builds a final `.trn` either from the current file alone or by concatenating `backup.trn + current.trn`
- zips the final `.trn` with built-in .NET zip support
- uploads the zip to one or more FTPS destinations

## Files

- `AOtransact.CompTransExtractor.csproj`: executable project
- `Build-CompTransExtractor.ps1`: publish script for a self-contained executable
- `Program.cs`: main entrypoint
- `CompTrans.config`: current config
- `CompTrans.config.sample`: generic starting template for a new client

## Build

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\comptrans-extractor\Build-CompTransExtractor.ps1
```

Published output lands in:

`tools\comptrans-extractor\publish\win-x64`

## Usage

Interactive first run on the target server:

```cmd
CompTransExtractor.exe --set-password
CompTransExtractor.exe
```

Regular scheduled-task run after password bootstrap:

```cmd
CompTransExtractor.exe
```

Optional custom config path:

```cmd
CompTransExtractor.exe --config C:\Deploy\CompTrans.config
```

## Config Notes

Everything client- or environment-specific should live in config, including:

- source paths
- current, backup, temp, and final transaction file paths
- target table list
- state-tracking table list
- archive retention
- final file mode: `CurrentOnly` or `BackupPlusCurrent`
- pre-run backup/shadow cleanup behavior
- one or more FTPS destinations, each with host, port, SSL mode, passive mode, remote directory, and credential scope
- one or more upload destinations using either `FTPS` or `SFTP`
- optional FTP debug logging with `FTP_DEBUG_LOG`

## FTP Debugging

To capture FTP diagnostics during a test run, set:

```ini
FTP_DEBUG_LOG=C:\Temp\CompTransExtractor.ftp.log
```

This writes basic upload diagnostics such as:

- target name
- local file path
- remote URI
- SSL/passive mode
- FTP/WebException status details

For temporary certificate troubleshooting only, you can also set:

```ini
FTP_SKIP_CERT_VALIDATION_FOR_DEBUG=true
```

Use that only for debugging and turn it back off afterward.

## Upload Targets

Use `UPLOAD_TARGETS` as a comma-separated list of destination names, then define each target with keys like:

```ini
UPLOAD_TARGETS=ERP_Link,CompPass
UPLOAD_TARGET.ERP_Link.PROTOCOL=SFTP
UPLOAD_TARGET.ERP_Link.HOST=sftp1.example.com
UPLOAD_TARGET.ERP_Link.PORT=22
UPLOAD_TARGET.ERP_Link.USER=user1
UPLOAD_TARGET.ERP_Link.PASSWORD_SCOPE=CurrentUser
UPLOAD_TARGET.ERP_Link.PASSWORD_ENCRYPTED=
UPLOAD_TARGET.CompPass.PROTOCOL=SFTP
UPLOAD_TARGET.CompPass.HOST=sftp2.example.com
UPLOAD_TARGET.CompPass.PORT=22
UPLOAD_TARGET.CompPass.USER=user2
UPLOAD_TARGET.CompPass.PASSWORD_SCOPE=CurrentUser
UPLOAD_TARGET.CompPass.PASSWORD_ENCRYPTED=
```

Running `CompTransExtractor.exe --set-password` will prompt once for each enabled upload target.

For OpenSSH-backed SFTP targets, use:

```ini
UPLOAD_TARGET.CompPass.PROTOCOL=SFTP
UPLOAD_TARGET.CompPass.PORT=22
```

For FTPS targets, add:

```ini
UPLOAD_TARGET.CompPass.PROTOCOL=FTPS
UPLOAD_TARGET.CompPass.PORT=21
UPLOAD_TARGET.CompPass.ENABLE_SSL=true
UPLOAD_TARGET.CompPass.USE_PASSIVE=true
```

## Deployment Notes

- Publish as a self-contained Windows executable.
- Run `--set-password` once on the target server under the same Windows account that will run the scheduled task if the upload targets use `PASSWORD_SCOPE=CurrentUser`.
- Set `PASSWORD_SCOPE=LocalMachine` for an upload target if any account on the same server must be able to decrypt that stored password.
- The program keeps local zip files from the last configured retention window and deletes older ones.
