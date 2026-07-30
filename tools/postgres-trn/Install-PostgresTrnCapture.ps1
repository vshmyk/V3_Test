param(
    [string]$Database = "OASIS_FLUX",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$OutputDirectory = "C:\ERPLINK\FLUX"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $CredentialsPath)) {
    throw "Credentials file not found: $CredentialsPath"
}

$passwordLine = Get-Content -LiteralPath $CredentialsPath | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
if (-not $passwordLine) {
    throw "Password entry not found in $CredentialsPath"
}

$env:PGPASSWORD = $passwordLine.Substring("Password=".Length)
$psql = "C:\Program Files\PostgreSQL\17\pgsql\bin\psql.exe"
$sqlFile = Join-Path $PSScriptRoot "postgres-trn-capture.sql"

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

icacls $OutputDirectory /grant 'NT AUTHORITY\NetworkService:(OI)(CI)M' | Out-Null

& $psql -h $PgHost -p $Port -U $User -d postgres -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET track_commit_timestamp = on;"

$service = Get-Service -Name "postgresql-x64-17" -ErrorAction Stop
if ($service.Status -eq "Running") {
    Restart-Service -Name $service.Name -Force
} else {
    Start-Service -Name $service.Name
}

Start-Sleep -Seconds 3

& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $sqlFile
& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c "CALL aotransact_pg.install_capture_triggers(ARRAY['dbo','oasis']);"

Write-Host "Installed PostgreSQL TRN capture in $Database and prepared $OutputDirectory"
