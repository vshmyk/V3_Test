param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "aotransact-postgresql.config.json")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security

$credentialEntropy = [Text.Encoding]::UTF8.GetBytes('AOtransactPostgreSQL|Credential|v1')

function Get-CredentialPassword {
    param([string]$Path)

    $lines = @(Get-Content -LiteralPath $Path)
    $protectedLine = $lines | Where-Object { $_ -like 'DPAPI_LOCAL_MACHINE=*' } | Select-Object -First 1
    if ($protectedLine) {
        $protectedBytes = $null
        $plainBytes = $null
        try {
            $protectedBytes = [Convert]::FromBase64String($protectedLine.Substring('DPAPI_LOCAL_MACHINE='.Length))
            $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
                $protectedBytes,
                $script:credentialEntropy,
                [Security.Cryptography.DataProtectionScope]::LocalMachine)
            return [Text.Encoding]::UTF8.GetString($plainBytes)
        }
        catch {
            throw "Credential file could not be decrypted on this computer: $Path. $($_.Exception.Message)"
        }
        finally {
            if ($null -ne $plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
            if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
        }
    }

    $passwordLine = $lines | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if ($passwordLine) {
        return $passwordLine.Substring('Password='.Length)
    }

    throw "Encrypted or legacy password entry not found in $Path"
}

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

function Resolve-PostgresServiceName {
    param([string]$ConfiguredName, [string]$PsqlPath)

    if ($ConfiguredName -ne 'auto' -and (Get-Service -Name $ConfiguredName -ErrorAction SilentlyContinue)) {
        return $ConfiguredName
    }
    if ($PsqlPath -match '\\PostgreSQL\\(?<version>\d+)\\') {
        $versionService = "postgresql-x64-$($matches['version'])"
        if (Get-Service -Name $versionService -ErrorAction SilentlyContinue) { return $versionService }
    }
    $selected = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue |
        Sort-Object @{ Expression = { $_.Status -eq 'Running' }; Descending = $true }, Name -Descending |
        Select-Object -First 1
    if (-not $selected) { throw 'PostgreSQL Windows service was not found.' }
    return $selected.Name
}

function Invoke-Psql {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$Port,
        [string]$User,
        [string]$Database,
        [string]$Sql
    )

    $result = & $Psql -h $HostName -p $Port -U $User -d $Database -t -A -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed with exit code $LASTEXITCODE."
    }
    return (($result | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n").Trim()
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$postgres = $config.postgres
$capture = $config.capture
$psql = Resolve-PsqlExecutable -ConfiguredPath ([string]$postgres.psql_path)
$serviceName = Resolve-PostgresServiceName -ConfiguredName ([string]$postgres.service_name) -PsqlPath $psql
$slotName = [string]$capture.slot_name
if ($slotName -notmatch '^[a-z0-9_]+$') {
    throw "Logical slot name must contain only lowercase letters, numbers, and underscores: '$slotName'"
}

$env:PGPASSWORD = Get-CredentialPassword -Path ([string]$postgres.credentials_path)
$connection = @{
    Psql = $psql
    HostName = [string]$postgres.host
    Port = [int]$postgres.port
    User = [string]$postgres.user
}

$walLevel = Invoke-Psql @connection -Database "postgres" -Sql "SHOW wal_level;"
$commitTracking = Invoke-Psql @connection -Database "postgres" -Sql "SHOW track_commit_timestamp;"
$restartRequired = $false
if ($walLevel -ne "logical") {
    [void](Invoke-Psql @connection -Database "postgres" -Sql "ALTER SYSTEM SET wal_level = logical;")
    $restartRequired = $true
}
if ($commitTracking -ne "on") {
    [void](Invoke-Psql @connection -Database "postgres" -Sql "ALTER SYSTEM SET track_commit_timestamp = on;")
    $restartRequired = $true
}

if ($restartRequired) {
    Restart-Service -Name $serviceName -Force
    (Get-Service -Name $serviceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(60))
}

$database = [string]$postgres.database
$existingPlugin = Invoke-Psql @connection -Database $database -Sql "SELECT plugin FROM pg_replication_slots WHERE slot_name = '$slotName';"
if ([string]::IsNullOrWhiteSpace($existingPlugin)) {
    [void](Invoke-Psql @connection -Database $database -Sql "SELECT slot_name FROM pg_create_logical_replication_slot('$slotName', 'test_decoding');")
} elseif ($existingPlugin -ne "test_decoding") {
    throw "Existing slot '$slotName' uses plugin '$existingPlugin', not test_decoding."
}

$slotState = Invoke-Psql @connection -Database $database -Sql "SELECT slot_name || '|' || plugin || '|' || active::text FROM pg_replication_slots WHERE slot_name = '$slotName';"
Write-Host "Configured logical capture for $database without altering any tables. Slot: $slotState"
