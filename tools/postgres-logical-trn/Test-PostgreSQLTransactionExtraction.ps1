param(
    [string]$Database = "OASIS_FLUX",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$OutputPath = "C:\ERPLINK\AOtransactPostgreSQL\transactions.trn",
    [string]$ConfigPath = (Join-Path $PSScriptRoot "aotransact-postgresql.config.json"),
    [string]$CaptureExecutable = ""
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

function Invoke-Capture {
    if ([string]::IsNullOrWhiteSpace($CaptureExecutable)) {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Capture-PostgreSQLLogicalBatch.ps1") -ConfigPath $ConfigPath
    } else {
        & $CaptureExecutable --config $ConfigPath --single-batch
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Logical capture failed with exit code $LASTEXITCODE."
    }
}

# Drain any unread logical changes so the test output is self-contained.
Invoke-Capture | Out-Null

$testSql = @"
BEGIN;

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
SET "INTERNALNOTES" = 'AO logical test update PO
O''Brien multiline note',
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
               'QUOTENOTES', (SELECT string_agg(md5(i::text), '') FROM generate_series(1, 500) i)
           ) AS j
    FROM oasis."CHSC_QUOTE" t
    LIMIT 1
)
INSERT INTO oasis."CHSC_QUOTE"
SELECT *
FROM jsonb_populate_record(NULL::oasis."CHSC_QUOTE", (SELECT j FROM sample));

UPDATE oasis."CHSC_QUOTE"
SET "PROJECT" = 'AO logical test update QUOTE',
    "REMARKS" = 'AO logical test update QUOTE remark'
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

COMMIT;
"@

$testSqlPath = Join-Path $env:TEMP "aotransact-postgres-logical-trn-test.sql"
Set-Content -LiteralPath $testSqlPath -Value $testSql -Encoding ASCII
& $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $testSqlPath
if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL test transaction script failed with exit code $LASTEXITCODE."
}
Remove-Item -LiteralPath $testSqlPath -Force

Invoke-Capture

$capturedSql = Get-Content -LiteralPath $OutputPath -Raw
$dmlCount = ([regex]::Matches($capturedSql, '(?m)^(INSERT INTO|UPDATE|DELETE FROM) ')).Count
if ($dmlCount -ne 12) {
    throw "Expected 12 captured DML statements, but found $dmlCount."
}
$operationSequence = @([regex]::Matches($capturedSql, '(?m)^(INSERT INTO|UPDATE|DELETE FROM) ') |
    ForEach-Object { $_.Groups[1].Value })
$expectedSequence = @('INSERT INTO', 'UPDATE', 'DELETE FROM') * 4
if (($operationSequence -join '|') -cne ($expectedSequence -join '|')) {
    throw "Captured DML does not preserve source transaction order: $($operationSequence -join ', ')"
}
if ($capturedSql -match '(?i)WHERE[^;]*\bOR\b') {
    throw "Captured primary-key WHERE clause contains an unexpected OR operator."
}
if ($capturedSql -match '(?m)^-- commit_time=') {
    throw "Captured DML contains an unexpected commit_time metadata line."
}
if ($capturedSql -match '(?i)unchanged-toast-datum') {
    throw "Captured DML contains PostgreSQL's unchanged TOAST sentinel."
}
if ($capturedSql -notmatch '(?i)WHERE \[DBID\] = ''FLONCA001'' AND \[POID\] = 99124002 AND \[LINENUMBER\] = 99124002') {
    throw "Captured composite primary-key WHERE clause does not use equality joined by AND."
}
if ($capturedSql -notmatch "(?s)\[INTERNALNOTES\] = 'AO logical test update PO\r?\nO''Brien multiline note'") {
    throw "Captured SQL did not preserve and safely quote a multiline string value."
}

$testConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ([bool]$testConfig.package.enabled) {
    $lastBatch = Get-Content -LiteralPath $testConfig.capture.last_batch_path -Raw | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $lastBatch.zip_path)) {
        throw "Expected ZIP package was not created: $($lastBatch.zip_path)"
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($lastBatch.zip_path)
    try {
        if ($zip.Entries.Count -ne 1 -or -not $zip.Entries[0].FullName.EndsWith('.trn')) {
            throw "ZIP package must contain exactly one .trn file."
        }
        $reader = [System.IO.StreamReader]::new($zip.Entries[0].Open())
        try {
            $zippedSql = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
        if ($zippedSql -ne $capturedSql) {
            throw "Zipped .trn content does not match the generated output file."
        }
    }
    finally {
        $zip.Dispose()
    }
}

Write-Host "Test DML extracted to $OutputPath"
