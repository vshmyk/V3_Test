param(
    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$Database = "OASIS_MH",

    [Parameter(Mandatory = $true)]
    [string[]]$Tables,

    [Parameter()]
    [string[]]$Operations = @("DMLALL"),

    [Parameter()]
    [int[]]$Spids,

    [Parameter()]
    [string[]]$Users,

    [Parameter()]
    [string[]]$ExcludeUsers,

    [Parameter()]
    [int]$WindowMinutes = 15,

    [Parameter()]
    [string]$StartLsn,

    [Parameter()]
    [ValidateSet("fn_dblog", "fn_full_dblog", "sys.fn_dblog", "sys.fn_full_dblog", "master.sys.fn_dblog", "master.sys.fn_full_dblog")]
    [string]$LogReaderFunction = "fn_dblog",

    [Parameter()]
    [string]$OutputPath = ".\output\live-dml-manifest.json",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($WindowMinutes -lt 1) {
    throw "WindowMinutes must be > 0."
}

if ($StartLsn -and ($StartLsn -notmatch "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")) {
    throw "StartLsn format is invalid. Expected 00000025:0000F6C0:0006"
}

if (-not $Tables -or $Tables.Count -eq 0) {
    throw "Provide at least one table in schema.table format."
}

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

function Resolve-LogReaderFunction {
    param([Parameter(Mandatory = $true)][string]$ConfiguredValue)

    switch ($ConfiguredValue.Trim().ToLowerInvariant()) {
        "fn_dblog" { return "fn_dblog" }
        "sys.fn_dblog" { return "fn_dblog" }
        "master.sys.fn_dblog" { return "fn_dblog" }
        "fn_full_dblog" { return "fn_full_dblog" }
        "sys.fn_full_dblog" { return "fn_full_dblog" }
        "master.sys.fn_full_dblog" { return "fn_full_dblog" }
        default { throw "Unsupported LogReaderFunction '$ConfiguredValue'. Allowed values: fn_dblog, fn_full_dblog" }
    }
}

$resolvedLogReaderFunction = Resolve-LogReaderFunction -ConfiguredValue $LogReaderFunction

$opMap = @{
    "INSERT" = @("LOP_INSERT_ROWS")
    "DELETE" = @("LOP_DELETE_ROWS")
    "UPDATE" = @("LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS")
    "DMLALL" = @("LOP_INSERT_ROWS", "LOP_DELETE_ROWS", "LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS")
}

if (-not $Operations -or $Operations.Count -eq 0) {
    $Operations = @("DMLALL")
}

$resolvedLogOps = New-Object System.Collections.Generic.List[string]
foreach ($opRaw in $Operations) {
    $op = ([string]$opRaw).Trim().ToUpperInvariant()
    if (-not $opMap.ContainsKey($op)) {
        throw "Unsupported operation '$opRaw'. Supported values: DMLALL, INSERT, UPDATE, DELETE"
    }
    foreach ($logOp in $opMap[$op]) {
        if (-not $resolvedLogOps.Contains($logOp)) {
            $resolvedLogOps.Add($logOp)
        }
    }
}
if ($resolvedLogOps.Count -eq 0) {
    throw "Resolved operation list is empty."
}
$opsSqlList = ($resolvedLogOps | ForEach-Object { "N'" + $_.Replace("'", "''") + "'" }) -join ", "

$hasSpidFilter = if ($Spids -and $Spids.Count -gt 0) { 1 } else { 0 }
$spidSqlList = if ($hasSpidFilter -eq 1) { ($Spids | ForEach-Object { [int]$_ } | Sort-Object -Unique) -join ", " } else { "-1" }

$normUsers = @()
if ($Users) {
    $normUsers = @($Users | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}
$hasUsersFilter = if ($normUsers.Count -gt 0) { 1 } else { 0 }
$usersSqlList = if ($hasUsersFilter -eq 1) { ($normUsers | ForEach-Object { "N'" + $_.Replace("'", "''") + "'" }) -join ", " } else { "N''" }

$normExcludeUsers = @()
if ($ExcludeUsers) {
    $normExcludeUsers = @($ExcludeUsers | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}
$hasExcludeUsersFilter = if ($normExcludeUsers.Count -gt 0) { 1 } else { 0 }
$excludeUsersSqlList = if ($hasExcludeUsersFilter -eq 1) { ($normExcludeUsers | ForEach-Object { "N'" + $_.Replace("'", "''") + "'" }) -join ", " } else { "N''" }

$validatedTables = @()
foreach ($table in $Tables) {
    if ($table -notmatch "^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$") {
        throw "Invalid table '$table'. Use schema.table format."
    }
    $parts = $table.Split(".")
    $validatedTables += [pscustomobject]@{
        SchemaName = $parts[0]
        TableName  = $parts[1]
    }
}

$targetsSql = ($validatedTables | ForEach-Object {
    "SELECT N'$($_.SchemaName)' AS schema_name, N'$($_.TableName)' AS table_name"
}) -join "`nUNION ALL`n"

$startLsnLiteral = if ($StartLsn) { "N'" + $StartLsn.Replace("'", "''") + "'" } else { "NULL" }

$query = @"
DECLARE @WindowMinutes INT = $WindowMinutes;
DECLARE @StartLsn NVARCHAR(25) = $startLsnLiteral;
DECLARE @HasSpidFilter BIT = $hasSpidFilter;
DECLARE @HasUsersFilter BIT = $hasUsersFilter;
DECLARE @HasExcludeUsersFilter BIT = $hasExcludeUsersFilter;

SELECT schema_name, table_name
INTO #target_tables
FROM (
$targetsSql
) tt;

SELECT TOP (0)
    [Current LSN] AS current_lsn,
    [Transaction ID] AS transaction_id,
    [Operation] AS operation_name,
    [Context] AS context_name,
    [AllocUnitName] AS alloc_unit_name,
    [AllocUnitId] AS alloc_unit_id,
    [End Time] AS end_time,
    [Page ID] AS page_id,
    [Slot ID] AS slot_id,
    [SPID] AS spid,
    [Transaction Name] AS transaction_name,
    [Transaction SID] AS transaction_sid,
    [RowLog Contents 0] AS rowlog0,
    [RowLog Contents 1] AS rowlog1,
    [RowLog Contents 2] AS rowlog2,
    [RowLog Contents 3] AS rowlog3,
    [RowLog Contents 4] AS rowlog4,
    [RowLog Contents 5] AS rowlog5
INTO #log_rows
FROM $resolvedLogReaderFunction(NULL, NULL);

IF (@StartLsn IS NULL)
BEGIN
    INSERT INTO #log_rows
    SELECT
        [Current LSN] AS current_lsn,
        [Transaction ID] AS transaction_id,
        [Operation] AS operation_name,
        [Context] AS context_name,
        [AllocUnitName] AS alloc_unit_name,
        [AllocUnitId] AS alloc_unit_id,
        [End Time] AS end_time,
        [Page ID] AS page_id,
        [Slot ID] AS slot_id,
        [SPID] AS spid,
        [Transaction Name] AS transaction_name,
        [Transaction SID] AS transaction_sid,
        [RowLog Contents 0] AS rowlog0,
        [RowLog Contents 1] AS rowlog1,
        [RowLog Contents 2] AS rowlog2,
        [RowLog Contents 3] AS rowlog3,
        [RowLog Contents 4] AS rowlog4,
        [RowLog Contents 5] AS rowlog5
    FROM $resolvedLogReaderFunction(NULL, NULL)
    WHERE [Transaction ID] IS NOT NULL
      AND [Operation] IN (
          'LOP_BEGIN_XACT',
          'LOP_COMMIT_XACT',
          'LOP_INSERT_ROWS',
          'LOP_DELETE_ROWS',
          'LOP_MODIFY_ROW',
          'LOP_MODIFY_COLUMNS'
      );
END
ELSE
BEGIN
    INSERT INTO #log_rows
    SELECT
        [Current LSN] AS current_lsn,
        [Transaction ID] AS transaction_id,
        [Operation] AS operation_name,
        [Context] AS context_name,
        [AllocUnitName] AS alloc_unit_name,
        [AllocUnitId] AS alloc_unit_id,
        [End Time] AS end_time,
        [Page ID] AS page_id,
        [Slot ID] AS slot_id,
        [SPID] AS spid,
        [Transaction Name] AS transaction_name,
        [Transaction SID] AS transaction_sid,
        [RowLog Contents 0] AS rowlog0,
        [RowLog Contents 1] AS rowlog1,
        [RowLog Contents 2] AS rowlog2,
        [RowLog Contents 3] AS rowlog3,
        [RowLog Contents 4] AS rowlog4,
        [RowLog Contents 5] AS rowlog5
    FROM $resolvedLogReaderFunction(@StartLsn, NULL)
    WHERE [Transaction ID] IS NOT NULL
      AND [Operation] IN (
          'LOP_BEGIN_XACT',
          'LOP_COMMIT_XACT',
          'LOP_INSERT_ROWS',
          'LOP_DELETE_ROWS',
          'LOP_MODIFY_ROW',
          'LOP_MODIFY_COLUMNS'
      )
      AND [Current LSN] > @StartLsn;
END;

WITH commits AS (
    SELECT
        transaction_id,
        end_time AS commit_time
    FROM #log_rows
    WHERE operation_name = 'LOP_COMMIT_XACT'
      AND (
            @StartLsn IS NOT NULL
            OR end_time >= DATEADD(MINUTE, -@WindowMinutes, SYSDATETIME())
      )
),
begins_raw AS (
    SELECT
        transaction_id,
        spid,
        transaction_name,
        transaction_sid,
        current_lsn,
        ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY current_lsn ASC) AS rn
    FROM #log_rows
    WHERE operation_name = 'LOP_BEGIN_XACT'
),
begins AS (
    SELECT
        transaction_id,
        spid AS tx_spid,
        transaction_name AS tx_transaction_name,
        SUSER_SNAME(transaction_sid) AS user_name
    FROM begins_raw
    WHERE rn = 1
),
changes AS (
    SELECT
        lr.current_lsn,
        lr.transaction_id,
        lr.operation_name,
        lr.context_name,
        lr.alloc_unit_name,
        lr.alloc_unit_id,
        lr.page_id,
        lr.slot_id,
        ISNULL(br.tx_spid, lr.spid) AS tx_spid,
        ISNULL(NULLIF(br.tx_transaction_name, N''), lr.transaction_name) AS tx_transaction_name,
        br.user_name,
        lr.rowlog0,
        lr.rowlog1,
        lr.rowlog2,
        lr.rowlog3,
        lr.rowlog4,
        lr.rowlog5,
        c.commit_time,
        CASE
            WHEN PARSENAME(lr.alloc_unit_name, 3) IS NOT NULL THEN PARSENAME(lr.alloc_unit_name, 3)
            ELSE PARSENAME(lr.alloc_unit_name, 2)
        END AS schema_name,
        CASE
            WHEN PARSENAME(lr.alloc_unit_name, 3) IS NOT NULL THEN PARSENAME(lr.alloc_unit_name, 2)
            ELSE PARSENAME(lr.alloc_unit_name, 1)
        END AS table_name
    FROM #log_rows lr
    INNER JOIN commits c
        ON c.transaction_id = lr.transaction_id
    LEFT JOIN begins br
        ON br.transaction_id = lr.transaction_id
    WHERE lr.operation_name IN ($opsSqlList)
      AND lr.alloc_unit_name IS NOT NULL
      AND (@HasSpidFilter = 0 OR ISNULL(br.tx_spid, lr.spid) IN ($spidSqlList))
      AND (@HasUsersFilter = 0 OR UPPER(ISNULL(br.user_name, N'')) IN ($usersSqlList))
      AND (@HasExcludeUsersFilter = 0 OR UPPER(ISNULL(br.user_name, N'')) NOT IN ($excludeUsersSqlList))
)
SELECT
    ch.current_lsn,
    ch.transaction_id,
    ch.operation_name,
    ch.context_name,
    ch.schema_name,
    ch.table_name,
    ch.alloc_unit_name,
    TRY_CONVERT(BIGINT, ch.alloc_unit_id) AS alloc_unit_id,
    TRY_CONVERT(BIGINT, TRY_CONVERT(BIGINT, ch.alloc_unit_id) / 65536) % 4294967296 AS hobt_token,
    ch.page_id,
    ch.slot_id,
    ch.tx_spid AS spid,
    ch.tx_transaction_name AS transaction_name,
    ch.user_name,
    master.dbo.fn_varbintohexstr(ch.rowlog0) AS rowlog0_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog1) AS rowlog1_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog2) AS rowlog2_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog3) AS rowlog3_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog4) AS rowlog4_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog5) AS rowlog5_hex,
    ch.commit_time
FROM changes ch
INNER JOIN #target_tables tt
    ON tt.schema_name = ch.schema_name
   AND tt.table_name = ch.table_name
ORDER BY ch.commit_time ASC, ch.current_lsn ASC;

SELECT TOP (1)
    current_lsn AS scan_end_lsn
FROM #log_rows
ORDER BY current_lsn DESC;

DROP TABLE #log_rows;
DROP TABLE #target_tables;
"@

$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder["Data Source"] = $ServerInstance
$builder["Initial Catalog"] = $Database
$builder["TrustServerCertificate"] = $true

if ($SqlUser) {
    $builder["User ID"] = $SqlUser
    $builder["Password"] = $SqlPassword
    $builder["Integrated Security"] = $false
} else {
    $builder["Integrated Security"] = $true
}

$connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
$command = $connection.CreateCommand()
$command.CommandTimeout = 0
$command.CommandText = $query

$dataTable = New-Object System.Data.DataTable
$metaTable = New-Object System.Data.DataTable

try {
    $connection.Open()
    $reader = $command.ExecuteReader()
    try {
        $dataTable.Load($reader)
        if ($reader.NextResult()) {
            $metaTable.Load($reader)
        }
    } finally {
        $reader.Dispose()
    }
} finally {
    $connection.Dispose()
}

function Convert-OperationToAction {
    param([string]$Operation)
    switch ($Operation) {
        "LOP_INSERT_ROWS" { return "INSERT" }
        "LOP_DELETE_ROWS" { return "DELETE" }
        "LOP_MODIFY_ROW" { return "UPDATE" }
        "LOP_MODIFY_COLUMNS" { return "UPDATE" }
        default { return "UNKNOWN" }
    }
}

$rows = New-Object System.Collections.Generic.List[object]
$txSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($r in $dataTable.Rows) {
    $action = Convert-OperationToAction -Operation ([string]$r.operation_name)
    if ($action -eq "UNKNOWN") {
        continue
    }

    $lsn = [string]$r.current_lsn
    $tx = [string]$r.transaction_id
    $manifestKey = ("{0}|{1}|{2}" -f $action, $tx, $lsn).ToUpperInvariant()

    [void]$txSet.Add($tx)

    $rows.Add([pscustomobject]@{
        manifest_key    = $manifestKey
        action          = $action
        current_lsn     = $lsn
        tx_id           = $tx
        operation_name  = [string]$r.operation_name
        context_name    = [string]$r.context_name
        schema_name     = [string]$r.schema_name
        table_name      = [string]$r.table_name
        alloc_unit_name = [string]$r.alloc_unit_name
        alloc_unit_id   = if ($r.alloc_unit_id -is [System.DBNull]) { $null } else { [int64]$r.alloc_unit_id }
        hobt_token      = if ($r.hobt_token -is [System.DBNull]) { $null } else { [int64]$r.hobt_token }
        page_id         = [string]$r.page_id
        slot_id         = if ($r.slot_id -is [System.DBNull]) { $null } else { [int]$r.slot_id }
        spid            = if ($r.spid -is [System.DBNull]) { $null } else { [int]$r.spid }
        transaction_name = [string]$r.transaction_name
        user_name       = if ($r.user_name -is [System.DBNull]) { $null } else { [string]$r.user_name }
        rowlog0_hex     = [string]$r.rowlog0_hex
        rowlog1_hex     = [string]$r.rowlog1_hex
        rowlog2_hex     = [string]$r.rowlog2_hex
        rowlog3_hex     = [string]$r.rowlog3_hex
        rowlog4_hex     = [string]$r.rowlog4_hex
        rowlog5_hex     = [string]$r.rowlog5_hex
        commit_time     = if ($r.commit_time -is [System.DBNull]) { $null } else { [string]$r.commit_time }
    }) | Out-Null
}

$scanEndLsn = $null
if ($metaTable.Rows.Count -gt 0 -and $metaTable.Rows[0].scan_end_lsn -isnot [System.DBNull]) {
    $scanEndLsn = [string]$metaTable.Rows[0].scan_end_lsn
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$summary = [pscustomobject]@{
    collected_at_utc   = (Get-Date).ToUniversalTime().ToString("o")
    server_instance    = $ServerInstance
    database           = $Database
    log_reader_function = $resolvedLogReaderFunction
    window_minutes     = $WindowMinutes
    start_lsn_used     = $StartLsn
    scan_end_lsn       = $scanEndLsn
    tables             = $Tables
    operations         = if ($Operations) { ,@($Operations) } else { ,@() }
    resolved_log_operations = if ($resolvedLogOps) { ,@($resolvedLogOps) } else { ,@() }
    spids              = if ($Spids) { ,@($Spids) } else { ,@() }
    users              = if ($Users) { ,@($Users) } else { ,@() }
    exclude_users      = if ($ExcludeUsers) { ,@($ExcludeUsers) } else { ,@() }
    record_count       = $rows.Count
    transaction_count  = $txSet.Count
    note               = "Committed DML manifest from live $resolvedLogReaderFunction, intended for offline LDF hybrid matching."
    records            = @($rows.ToArray())
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host ("Wrote {0} manifest rows ({1} transactions) to {2}" -f $summary.record_count, $summary.transaction_count, (Resolve-Path -LiteralPath $OutputPath))
