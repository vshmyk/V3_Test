param(
    [string]$Database = "OASIS_FLUX",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$OutputPath = "C:\ERPLINK\FLUX\flux.trn",
    [string]$Window = "15 minutes"
)

$ErrorActionPreference = "Stop"

$passwordLine = Get-Content -LiteralPath $CredentialsPath | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
if (-not $passwordLine) {
    throw "Password entry not found in $CredentialsPath"
}

$env:PGPASSWORD = $passwordLine.Substring("Password=".Length)
$psql = "C:\Program Files\PostgreSQL\17\pgsql\bin\psql.exe"
$sql = "CALL aotransact_pg.write_recent_trn(interval '$Window', '$($OutputPath.Replace('\', '/'))');"

& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c $sql

Write-Host "Wrote $OutputPath for committed INSERT/UPDATE/DELETE rows in the last $Window"
