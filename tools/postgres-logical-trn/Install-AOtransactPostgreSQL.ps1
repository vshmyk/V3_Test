param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [string]$InstallDirectory = "C:\ProgramData\AOtransactPostgreSQL",
    [switch]$ForceConfig
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-PsqlExecutable {
    param([string]$ConfiguredPath)
    if ($ConfiguredPath -ne 'auto' -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }
    $candidates = @()
    $root = 'C:\Program Files\PostgreSQL'
    if (Test-Path -LiteralPath $root) {
        foreach ($directory in Get-ChildItem -LiteralPath $root -Directory) {
            foreach ($relativePath in @('bin\psql.exe', 'pgsql\bin\psql.exe')) {
                $candidate = Join-Path $directory.FullName $relativePath
                if (Test-Path -LiteralPath $candidate) { $candidates += Get-Item -LiteralPath $candidate }
            }
        }
    }
    $selected = $candidates | Sort-Object { if ($_.FullName -match '\\PostgreSQL\\(?<version>\d+)\\') { [int]$matches['version'] } else { 0 } } -Descending | Select-Object -First 1
    if (-not $selected) { throw 'PostgreSQL psql.exe was not found.' }
    return $selected.FullName
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this installer from an elevated PowerShell session."
}

$sourceConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
$sourceDirectory = Split-Path -Parent $sourceConfig
$config = Get-Content -LiteralPath $sourceConfig -Raw | ConvertFrom-Json
$clientId = [string]$config.client.id
if ($clientId -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Client ID must contain only letters, numbers, underscore, or hyphen: '$clientId'"
}

$resolvedPsql = Resolve-PsqlExecutable -ConfiguredPath ([string]$config.postgres.psql_path)
if (-not (Test-Path -LiteralPath $config.postgres.credentials_path)) {
    throw "PostgreSQL credentials file not found: $($config.postgres.credentials_path)"
}
if ([bool]$config.sftp.enabled) {
    if (-not (Test-Path -LiteralPath $config.sftp.credentials_path)) {
        throw "SFTP credentials file not found: $($config.sftp.credentials_path)"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'AOtransactPostgreSQL.exe'))) {
        throw 'Native SFTP requires installation from the executable package.'
    }
}

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
$sourceExecutable = Join-Path $PSScriptRoot "AOtransactPostgreSQL.exe"
$installedExecutable = Join-Path $InstallDirectory "AOtransactPostgreSQL.exe"
$installedScript = Join-Path $InstallDirectory "Capture-PostgreSQLLogicalBatch.ps1"
$installedPostgresSetup = Join-Path $InstallDirectory "Install-PostgresLogicalTrn.ps1"
$installedCredentialProtector = Join-Path $InstallDirectory "Protect-AOtransactCredentials.ps1"
$installedConfig = Join-Path $InstallDirectory "aotransact-postgresql.config.json"
if (Test-Path -LiteralPath $sourceExecutable) {
    Copy-Item -LiteralPath $sourceExecutable -Destination $installedExecutable -Force
    $notices = Join-Path $PSScriptRoot 'THIRD-PARTY-NOTICES.md'
    if (Test-Path -LiteralPath $notices) { Copy-Item -LiteralPath $notices -Destination $InstallDirectory -Force }
} else {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Capture-PostgreSQLLogicalBatch.ps1") -Destination $installedScript -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-PostgresLogicalTrn.ps1") -Destination $installedPostgresSetup -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Protect-AOtransactCredentials.ps1") -Destination $installedCredentialProtector -Force
if (-not (Test-Path -LiteralPath $installedConfig) -or $ForceConfig) {
    Copy-Item -LiteralPath $sourceConfig -Destination $installedConfig -Force
} else {
    Write-Warning "Existing installed config was preserved. Use -ForceConfig to replace it."
}

foreach ($path in @(
    [string]$config.capture.output_path,
    [string]$config.capture.checkpoint_path,
    [string]$config.capture.last_batch_path,
    [string]$config.capture.error_path
)) {
    $directory = Split-Path -Parent $path
    if ($directory) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}
New-Item -ItemType Directory -Path ([string]$config.capture.archive_directory) -Force | Out-Null
New-Item -ItemType Directory -Path ([string]$config.package.directory) -Force | Out-Null

if ([bool]$config.schedule.enabled) {
    $interval = [int]$config.schedule.interval_minutes
    if ($interval -lt 1) {
        throw "Schedule interval_minutes must be at least 1."
    }

    if (Test-Path -LiteralPath $installedExecutable) {
        $action = New-ScheduledTaskAction -Execute $installedExecutable -Argument "--config `"$installedConfig`""
    } else {
        $powerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$installedScript`" -ConfigPath `"$installedConfig`""
        $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $arguments
    }
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($interval) `
        -RepetitionInterval (New-TimeSpan -Minutes $interval) `
        -RepetitionDuration (New-TimeSpan -Days 3650)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes ([Math]::Max(10, $interval)))
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName ([string]$config.schedule.task_name) -Action $action -Trigger $trigger `
        -Settings $settings -Principal $taskPrincipal -Description "Capture PostgreSQL DML and transfer client $clientId batches." -Force | Out-Null
}

[pscustomobject]@{
    ClientId = $clientId
    InstallDirectory = $InstallDirectory
    ExecutablePath = if (Test-Path -LiteralPath $installedExecutable) { $installedExecutable } else { "" }
    ConfigPath = $installedConfig
    PostgresSetupPath = $installedPostgresSetup
    Scheduled = [bool]$config.schedule.enabled
    TaskName = if ([bool]$config.schedule.enabled) { [string]$config.schedule.task_name } else { "" }
    IntervalMinutes = if ([bool]$config.schedule.enabled) { [int]$config.schedule.interval_minutes } else { 0 }
}
