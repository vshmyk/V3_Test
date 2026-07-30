param(
    [string]$InstallRoot = "$env:LOCALAPPDATA\AOtransact\FtpsUploader"
)

$ErrorActionPreference = "Stop"

$installRoot = [System.IO.Path]::GetFullPath($InstallRoot)
$sourceUploaderPath = Join-Path $PSScriptRoot "Send-FtpsFile.ps1"
$installedUploaderPath = Join-Path $installRoot "Send-FtpsFile.ps1"
$settingsPath = Join-Path $installRoot "ftps-settings.json"
$credentialPath = Join-Path $installRoot "ftps-credential.clixml"
$launcherPath = Join-Path $installRoot "Send-CompPassFile.cmd"

if (-not (Test-Path -LiteralPath $sourceUploaderPath)) {
    throw "Uploader script not found: $sourceUploaderPath"
}

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

$userName = Read-Host "FTP user name"
if ([string]::IsNullOrWhiteSpace($userName)) {
    throw "User name is required."
}

$password = Read-Host "FTP password" -AsSecureString
if ($password.Length -eq 0) {
    throw "Password is required."
}

$credential = [pscredential]::new($userName, $password)
$credential | Export-Clixml -LiteralPath $credentialPath

$settings = [ordered]@{
    Host = "comppass.westus.cloudapp.azure.com"
    Port = 21
    EnableSsl = $true
    UsePassive = $true
    CredentialPath = $credentialPath
}

$settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
Copy-Item -LiteralPath $sourceUploaderPath -Destination $installedUploaderPath -Force

$launcherLines = @(
    "@echo off",
    "setlocal",
    "powershell -NoProfile -ExecutionPolicy Bypass -File ""%~dp0Send-FtpsFile.ps1"" -Path ""%~1"" -RemotePath ""%~2""",
    "exit /b %errorlevel%"
)

Set-Content -LiteralPath $launcherPath -Value $launcherLines -Encoding ASCII

Write-Host "FTPS uploader installed to $installRoot"
Write-Host "Command:"
Write-Host "  $launcherPath C:\Path\To\File.ext [remote/path/on/server.ext]"
Write-Host "Credentials were saved with Windows DPAPI for the current user."
Write-Host "If you use another computer, copy this folder there and run the installer again on that computer."
