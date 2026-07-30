param(
    [string]$Database = "OASIS_FLUX",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$SlotName = "aotransact_flux_slot",
    [string[]]$SchemaNames = @("dbo", "oasis"),
    [switch]$RemoveExistingTriggers = $true
)

$ErrorActionPreference = "Stop"

function Get-PostgresPassword {
    param([string]$Path)

    $passwordLine = Get-Content -LiteralPath $Path | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if (-not $passwordLine) {
        throw "Password entry not found in $Path"
    }

    return $passwordLine.Substring("Password=".Length)
}

$env:PGPASSWORD = Get-PostgresPassword -Path $CredentialsPath
$psql = "C:\Program Files\PostgreSQL\17\pgsql\bin\psql.exe"

& $psql -h $PgHost -p $Port -U $User -d postgres -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET wal_level = logical;"
& $psql -h $PgHost -p $Port -U $User -d postgres -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET track_commit_timestamp = on;"
Restart-Service -Name "postgresql-x64-17" -Force
Start-Sleep -Seconds 3

$schemaFilter = ($SchemaNames | ForEach-Object { "'$_'" }) -join ", "
$tablesSql = @"
COPY (
    SELECT n.nspname AS table_schema, c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND n.nspname IN ($schemaFilter)
    ORDER BY n.nspname, c.relname
) TO STDOUT WITH CSV HEADER;
"@

$tables = & $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c $tablesSql | ConvertFrom-Csv

$sqlLines = New-Object System.Collections.Generic.List[string]
foreach ($table in $tables) {
    $sqlLines.Add(("ALTER TABLE ""{0}"".""{1}"" REPLICA IDENTITY FULL;" -f $table.table_schema, $table.table_name))
    if ($RemoveExistingTriggers) {
        $sqlLines.Add(("DROP TRIGGER IF EXISTS trg_aotransact_pg_capture_dml ON ""{0}"".""{1}"";" -f $table.table_schema, $table.table_name))
    }
}

$sqlFile = Join-Path $env:TEMP "aotransact-install-logical-trn-actions.sql"
[System.IO.File]::WriteAllLines($sqlFile, $sqlLines)
& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $sqlFile | Out-Null
Remove-Item -LiteralPath $sqlFile -Force

$slotCheckSql = "SELECT 1 FROM pg_replication_slots WHERE slot_name = '$SlotName';"
$slotExistsResult = & $psql -h $PgHost -p $Port -U $User -d $Database -t -A -v ON_ERROR_STOP=1 -c $slotCheckSql
$slotExists = if ($null -eq $slotExistsResult) { "" } else { $slotExistsResult.Trim() }
if (-not $slotExists) {
    & $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c "SELECT * FROM pg_create_logical_replication_slot('$SlotName', 'test_decoding');" | Out-Null
}

& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c "SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots WHERE slot_name = '$SlotName';"

Write-Host "Installed logical TRN capture on $Database with slot $SlotName"
