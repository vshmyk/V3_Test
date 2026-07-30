# IIS FTPS Single-File Uploader

This folder contains a small Windows command-line uploader for an IIS FTPS server using explicit TLS on port 21.

Server settings baked into the installer:

- Host: `comppass.westus.cloudapp.azure.com`
- Port: `21`
- Encryption: explicit TLS/SSL

## Install

### Option 1: executable build

Build the standalone executable:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\iis-ftps-client\Build-FtpsUploader.ps1
```

That publishes to:

`C:\Users\vshmyk\AOprojects\AOtransact\tools\iis-ftps-client\publish\win-x64`

Then run:

```cmd
.\tools\iis-ftps-client\publish\win-x64\AOtransact.FtpsUploader.exe install
```

### Option 2: PowerShell installer

Run once as the Windows user who will send files:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\iis-ftps-client\Install-FtpsUploader.ps1
```

Or from a copied folder on another machine:

```cmd
Install-CompPassFtpsUploader.cmd
```

The installer:

- prompts for FTP user name and password
- stores credentials with Windows DPAPI in a user-scoped encrypted file
- writes the installed launcher to `%LOCALAPPDATA%\AOtransact\FtpsUploader`
- creates a launcher: `%LOCALAPPDATA%\AOtransact\FtpsUploader\Send-CompPassFile.cmd`

## Upload a file

Send a file and keep the same file name on the server:

```cmd
%LOCALAPPDATA%\AOtransact\FtpsUploader\Send-CompPassFile.cmd C:\Temp\example.txt
```

Send a file with an explicit remote path:

```cmd
%LOCALAPPDATA%\AOtransact\FtpsUploader\Send-CompPassFile.cmd C:\Temp\example.txt incoming/example.txt
```

Or call the executable directly:

```cmd
AOtransact.FtpsUploader.exe send --path C:\Temp\example.txt --remote-path incoming/example.txt
```

If you need to bypass certificate validation temporarily for troubleshooting, call the PowerShell script directly:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\AOtransact\FtpsUploader\Send-FtpsFile.ps1" `
  -Path "C:\Temp\example.txt" `
  -RemotePath "incoming/example.txt" `
  -SkipCertificateCheck
```

## Notes

- Credentials saved by `Export-Clixml` are encrypted for the current Windows user on the current machine.
- The executable stores credentials with Windows DPAPI for the current Windows user on the current machine.
- To use the uploader from a different computer, copy this `iis-ftps-client` folder there and run the installer again on that computer.
- The uploader only sends one file per command.
- The remote folder must already exist on the FTP server.
