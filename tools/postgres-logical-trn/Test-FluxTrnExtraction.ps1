param(
    [string]$Database = "OASIS_FLUX",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$OutputPath = "C:\ERPLINK\FLUX\flux.trn"
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

# Drain any unread logical changes and clear the local rolling file so the test output is self-contained.
[System.IO.File]::WriteAllText($OutputPath, "")

$testSql = @"
-- CHSC_PO
WITH sample AS (
    SELECT to_jsonb(t) ||
           jsonb_build_object(
               'POID', 99124001,
               'PONUMBER', 'AO-PO-TEST-001',
               'CONDITIONEDPONUMBER', 'AO-PO-TEST-001',
               'RESELLPONUMBER', 'AO-PO-TEST-001',
               'INTERNALNOTES', 'AO logical test insert PO',
               'REMARKS', 'AO logical test insert PO'
           ) AS j
    FROM oasis."CHSC_PO" t
    LIMIT 1
)
INSERT INTO oasis."CHSC_PO"
SELECT *
FROM jsonb_populate_record(NULL::oasis."CHSC_PO", (SELECT j FROM sample));

UPDATE oasis."CHSC_PO"
SET "INTERNALNOTES" = 'AO logical test update PO',
    "REMARKS" = 'AO logical test update PO remark',
    "PONUMBER" = 'AO-PO-TEST-002'
WHERE "DBID" = 'FLONCA001'
  AND "POID" = 99124001;

DELETE FROM oasis."CHSC_PO"
WHERE "DBID" = 'FLONCA001'
  AND "POID" = 99124001;

-- CHSC_POLINE
WITH sample AS (
    SELECT to_jsonb(t) ||
           jsonb_build_object(
               'POID', 99124002,
               'LINENUMBER', 99124002,
               'LINEUID', 99124002,
               'PARTNUMBER', 'AO-POLINE-TEST-001',
               'DESCRIPTION', 'AO logical test insert POLINE',
               'CANCELREASON', 'AO logical test insert POLINE'
           ) AS j
    FROM oasis."CHSC_POLINE" t
    LIMIT 1
)
INSERT INTO oasis."CHSC_POLINE"
SELECT *
FROM jsonb_populate_record(NULL::oasis."CHSC_POLINE", (SELECT j FROM sample));

UPDATE oasis."CHSC_POLINE"
SET "PARTNUMBER" = 'AO-POLINE-TEST-002',
    "DESCRIPTION" = 'AO logical test update POLINE',
    "CANCELREASON" = 'AO logical test update POLINE'
WHERE "DBID" = 'FLONCA001'
  AND "POID" = 99124002
  AND "LINENUMBER" = 99124002;

DELETE FROM oasis."CHSC_POLINE"
WHERE "DBID" = 'FLONCA001'
  AND "POID" = 99124002
  AND "LINENUMBER" = 99124002;

-- CHSC_QUOTE
WITH sample AS (
    SELECT to_jsonb(t) ||
           jsonb_build_object(
               'QUOTEID', 99124003,
               'QUOTENUMBER', 'AO-QUOTE-TEST-001',
               'PROJECT', 'AO logical test insert QUOTE',
               'REMARKS', 'AO logical test insert QUOTE',
               'QUOTENOTES', 'AO logical test insert QUOTE'
           ) AS j
    FROM oasis."CHSC_QUOTE" t
    LIMIT 1
)
INSERT INTO oasis."CHSC_QUOTE"
SELECT *
FROM jsonb_populate_record(NULL::oasis."CHSC_QUOTE", (SELECT j FROM sample));

UPDATE oasis."CHSC_QUOTE"
SET "PROJECT" = 'AO logical test update QUOTE',
    "REMARKS" = 'AO logical test update QUOTE remark',
    "QUOTENOTES" = 'AO logical test update QUOTE note'
WHERE "DBID" = 'FLONCA001'
  AND "QUOTEID" = 99124003;

DELETE FROM oasis."CHSC_QUOTE"
WHERE "DBID" = 'FLONCA001'
  AND "QUOTEID" = 99124003;

-- CHSC_QUOTELINE
WITH sample AS (
    SELECT to_jsonb(t) ||
           jsonb_build_object(
               'QUOTEID', 99124004,
               'LINENUMBER', 99124004,
               'LINEUID', 99124004,
               'PARTNUMBER', 'AO-QLINE-TEST-001',
               'DESCRIPTION', 'AO logical test insert QUOTELINE',
               'SPECDNOTES', 'AO logical test insert QUOTELINE'
           ) AS j
    FROM oasis."CHSC_QUOTELINE" t
    LIMIT 1
)
INSERT INTO oasis."CHSC_QUOTELINE"
SELECT *
FROM jsonb_populate_record(NULL::oasis."CHSC_QUOTELINE", (SELECT j FROM sample));

UPDATE oasis."CHSC_QUOTELINE"
SET "PARTNUMBER" = 'AO-QLINE-TEST-002',
    "DESCRIPTION" = 'AO logical test update QUOTELINE',
    "SPECDNOTES" = 'AO logical test update QUOTELINE'
WHERE "DBID" = 'FLONCA001'
  AND "QUOTEID" = 99124004
  AND "LINENUMBER" = 99124004;

DELETE FROM oasis."CHSC_QUOTELINE"
WHERE "DBID" = 'FLONCA001'
  AND "QUOTEID" = 99124004
  AND "LINENUMBER" = 99124004;
"@

$testSqlPath = Join-Path $env:TEMP "aotransact-postgres-logical-trn-test.sql"
Set-Content -LiteralPath $testSqlPath -Value $testSql -Encoding ASCII
& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $testSqlPath
Remove-Item -LiteralPath $testSqlPath -Force

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Write-RecentFluxTrnLogical.ps1") -Database $Database -PgHost $PgHost -Port $Port -User $User -CredentialsPath $CredentialsPath -OutputPath $OutputPath

Write-Host "Test DML extracted to $OutputPath"
