param(
    [Parameter(Mandatory = $true)][string]$CaptureExecutable,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'aotransact-postgresql.config.json')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($config.postgres.host -notin @('localhost', '127.0.0.1', '::1')) {
    throw 'This fixture creates an isolated test table/slot and is restricted to local PostgreSQL.'
}
$id = [guid]::NewGuid().ToString('N')
$table = "aotransact_test_$id"
$slot = "aotransact_test_$id"
$temp = Join-Path $env:TEMP $table
New-Item -ItemType Directory -Path $temp | Out-Null
$lines = @(Get-Content -LiteralPath $config.postgres.credentials_path)
$protected = $lines | Where-Object { $_ -like 'DPAPI_LOCAL_MACHINE=*' } | Select-Object -First 1
$previousPassword = $env:PGPASSWORD
if ($protected) {
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect(
        [Convert]::FromBase64String($protected.Substring('DPAPI_LOCAL_MACHINE='.Length)),
        [Text.Encoding]::UTF8.GetBytes('AOtransactPostgreSQL|Credential|v1'),
        [Security.Cryptography.DataProtectionScope]::LocalMachine)
    $env:PGPASSWORD = [Text.Encoding]::UTF8.GetString($bytes)
    [Array]::Clear($bytes, 0, $bytes.Length)
} else {
    $legacy = $lines | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if (-not $legacy) { throw 'Local fixture credential not found.' }
    $env:PGPASSWORD = $legacy.Substring('Password='.Length)
}
$psql = [string]$config.postgres.psql_path
function Invoke-TestSql([string]$Sql) {
    $result = & $psql -X -w -h $config.postgres.host -p $config.postgres.port -U $config.postgres.user -d $config.postgres.database -t -A -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw 'Local catch-up fixture SQL failed.' }
    return ($result -join "`n").Trim()
}
function Save-TestConfig {
    [IO.File]::WriteAllText($testConfig, ($config | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
try {
    [void](Invoke-TestSql "CREATE TABLE public.$table (id integer PRIMARY KEY, value text);")
    [void](Invoke-TestSql "SELECT slot_name FROM pg_create_logical_replication_slot('$slot', 'test_decoding');")
    foreach ($n in 1..4) { [void](Invoke-TestSql "INSERT INTO public.$table VALUES ($n, 'fixture-$n');") }
    $config.tables = @("public.$table")
    $config.capture.slot_name = $slot
    foreach ($property in @('output_path', 'checkpoint_path', 'last_batch_path', 'error_path')) {
        $config.capture.$property = Join-Path $temp $property
    }
    $config.capture.archive_directory = Join-Path $temp 'archive'
    $config.capture.max_changes_per_run = 1
    $config.capture | Add-Member -Force NoteProperty max_batches_per_run 2
    $config.capture | Add-Member -Force NoteProperty max_run_seconds 600
    $config.capture.archive_batches = $true
    $config.package.enabled = $true
    $config.package.directory = Join-Path $temp 'outbox'
    $config.package | Add-Member -Force NoteProperty sent_directory (Join-Path $temp 'sent')
    $config.sftp.enabled = $false
    $testConfig = Join-Path $temp 'config.json'
    Save-TestConfig
    & $CaptureExecutable --config $testConfig
    if ($LASTEXITCODE -ne 0) { throw 'Catch-up first invocation failed.' }
    $summaryPath = Join-Path $temp 'last-run.json'
    $run = Get-Content $summaryPath -Raw | ConvertFrom-Json
    if ($run.completed_batches -ne 2 -or $run.total_statements -ne 2 -or $run.stop_reason -ne 'batch_limit') {
        throw 'Catch-up did not honor the two-batch cap.'
    }
    $config.capture.max_batches_per_run = 20
    Save-TestConfig
    & $CaptureExecutable --config $testConfig
    if ($LASTEXITCODE -ne 0) { throw 'Catch-up resumed invocation failed.' }
    $run = Get-Content $summaryPath -Raw | ConvertFrom-Json
    $archives = @(Get-ChildItem $config.capture.archive_directory -Filter '*.trn' -File)
    if ($run.completed_batches -ne 3 -or $run.total_statements -ne 2 -or $run.stop_reason -ne 'decoder_below_limit' -or $archives.Count -ne 4) {
        throw 'Catch-up resume/empty-stop/archive assertions failed.'
    }
    $capturedIds = @($archives | ForEach-Object {
        $text = Get-Content $_.FullName -Raw
        [regex]::Match($text, 'VALUES \((?<id>\d+),').Groups['id'].Value
    } | Sort-Object)
    if (($capturedIds -join ',') -cne '1,2,3,4') { throw 'Catch-up skipped or duplicated a fixture INSERT.' }
    $checkpoint = Get-Content $config.capture.checkpoint_path -Raw
    [void](Invoke-TestSql "INSERT INTO public.$table VALUES (5, 'failed-transfer');")
    $config.sftp.enabled = $true
    $config.sftp.credentials_path = Join-Path $temp 'missing-credentials.txt'
    Save-TestConfig
    & $CaptureExecutable --config $testConfig
    if ($LASTEXITCODE -eq 0) { throw 'Expected transfer failure did not occur.' }
    $run = Get-Content $summaryPath -Raw | ConvertFrom-Json
    if ($run.completed_batches -ne 0 -or $run.stop_reason -ne 'batch_failed' -or (Get-Content $config.capture.checkpoint_path -Raw) -cne $checkpoint) {
        throw 'A failed batch incorrectly advanced the checkpoint or continued.'
    }
    $remaining = Invoke-TestSql "SELECT count(*) FROM pg_logical_slot_peek_changes('$slot', NULL, 1) WHERE data LIKE 'table public.$table%';"
    if ($remaining -ne '1') { throw 'Failed transfer did not retain the pending change in the slot.' }
    foreach ($n in 6..10) { [void](Invoke-TestSql "INSERT INTO public.$table VALUES ($n, 'budget-$n');") }
    $config.sftp.enabled = $false
    $config.capture.max_run_seconds = 1
    Save-TestConfig
    & $CaptureExecutable --config $testConfig
    if ($LASTEXITCODE -ne 0) { throw 'Time-budget invocation failed.' }
    $run = Get-Content $summaryPath -Raw | ConvertFrom-Json
    if ($run.stop_reason -ne 'time_budget' -or $run.completed_batches -lt 1 -or $run.completed_batches -ge 6) {
        throw 'Soft time budget did not stop between completed batches with work remaining.'
    }
    Write-Host 'Catch-up cap, resume, empty-stop, unique INSERTs, time budget, and failure-without-advance tests passed.'
} finally {
    # Only this uniquely named local fixture is removed; application tables and slots are untouched.
    [void](Invoke-TestSql "SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE slot_name='$slot' AND NOT active;")
    [void](Invoke-TestSql "DROP TABLE IF EXISTS public.$table;")
    $env:PGPASSWORD = $previousPassword
}
