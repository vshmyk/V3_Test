param(
    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string[]]$Tables,

    [Parameter()]
    [int]$WindowMinutes = 15,

    [Parameter()]
    [string]$StartLsn,

    [Parameter()]
    [string]$OutputPath = ".\offline-log-transactions.json",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-SchemaTableIdentifier {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $text = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Invalid table name '$Value'. Use schema.table or [schema].[table] format."
    }

    $schemaName = $null
    $tableName = $null
    $dotIndex = $text.IndexOf(".")
    if ($dotIndex -ge 0) {
        if ($dotIndex -lt 1 -or $dotIndex -ge ($text.Length - 1)) {
            throw "Invalid table name '$Value'. Use table, schema.table, [table], or [schema].[table] format."
        }

        $schemaText = $text.Substring(0, $dotIndex).Trim()
        $tableText = $text.Substring($dotIndex + 1).Trim()
        if ($tableText.Contains(".")) {
            throw "Invalid table name '$Value'. Use exactly one schema.table pair."
        }

        if ($schemaText.StartsWith("[") -and $schemaText.EndsWith("]") -and $schemaText.Length -ge 2) {
            $schemaText = $schemaText.Substring(1, $schemaText.Length - 2)
        }
        if ($tableText.StartsWith("[") -and $tableText.EndsWith("]") -and $tableText.Length -ge 2) {
            $tableText = $tableText.Substring(1, $tableText.Length - 2)
        }

        $schemaName = $schemaText.Trim()
        $tableName = $tableText.Trim()
        if ([string]::IsNullOrWhiteSpace($schemaName) -or [string]::IsNullOrWhiteSpace($tableName)) {
            throw "Invalid table name '$Value'. Parsed schema/table is empty."
        }
    } else {
        if ($text.StartsWith("[") -and $text.EndsWith("]") -and $text.Length -ge 2) {
            $text = $text.Substring(1, $text.Length - 2)
        }
        $tableName = $text.Trim()
        if ([string]::IsNullOrWhiteSpace($tableName)) {
            throw "Invalid table name '$Value'. Parsed table is empty."
        }
    }

    return [pscustomobject]@{
        SchemaName = $schemaName
        TableName  = $tableName
    }
}

if ($WindowMinutes -lt 1) {
    throw "WindowMinutes must be greater than 0."
}

if ($StartLsn -and ($StartLsn -notmatch "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")) {
    throw "StartLsn format is invalid. Expected format: 00000025:0000f6c0:0006"
}

if (-not $Tables -or $Tables.Count -eq 0) {
    throw "Provide at least one table in table, schema.table, [table], or [schema].[table] format."
}

$validatedTables = @()
foreach ($table in $Tables) {
    $validatedTables += Parse-SchemaTableIdentifier -Value $table
}

$targetsSql = ($validatedTables | ForEach-Object {
    $schemaSql = "NULL"
    if (-not [string]::IsNullOrWhiteSpace($_.SchemaName)) {
        $schemaEscaped = $_.SchemaName.Replace("'", "''")
        $schemaSql = ("N'{0}'" -f $schemaEscaped)
    }
    $tableEscaped = $_.TableName.Replace("'", "''")
    ("SELECT {0} AS schema_name, N'{1}' AS table_name" -f $schemaSql, $tableEscaped)
}) -join "`nUNION ALL`n"

$startLsnLiteral = if ($StartLsn) { "N'" + $StartLsn.Replace("'", "''") + "'" } else { "NULL" }

$query = @"
DECLARE @WindowMinutes INT = $WindowMinutes;
DECLARE @StartLsn NVARCHAR(25) = $startLsnLiteral;

SELECT schema_name, table_name
INTO #target_tables
FROM (
$targetsSql
) tt;

SELECT
    [Current LSN] AS current_lsn,
    [Transaction ID] AS transaction_id,
    [Operation] AS operation_name,
    [Context] AS context_name,
    [AllocUnitName] AS alloc_unit_name,
    [Begin Time] AS begin_time,
    [End Time] AS end_time,
    [SPID] AS spid,
    [Page ID] AS page_id,
    [Slot ID] AS slot_id,
    [Transaction Name] AS transaction_name,
    [RowLog Contents 0] AS rowlog0,
    [RowLog Contents 1] AS rowlog1,
    [RowLog Contents 2] AS rowlog2,
    [RowLog Contents 3] AS rowlog3
INTO #log_rows
FROM fn_dblog(NULL, NULL)
WHERE (@StartLsn IS NULL OR [Current LSN] > @StartLsn);

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
begins AS (
    SELECT
        transaction_id,
        begin_time,
        spid,
        transaction_name
    FROM #log_rows
    WHERE operation_name = 'LOP_BEGIN_XACT'
),
changes AS (
    SELECT
        lr.current_lsn,
        lr.transaction_id,
        lr.operation_name,
        lr.context_name,
        lr.alloc_unit_name,
        lr.page_id,
        lr.slot_id,
        lr.rowlog0,
        lr.rowlog1,
        lr.rowlog2,
        lr.rowlog3,
        c.commit_time,
        LTRIM(RTRIM(REPLACE(REPLACE(
            CASE
                WHEN p1.first_dot > 1 THEN LEFT(lr.alloc_unit_name, p1.first_dot - 1)
                ELSE NULL
            END
        , '[', ''), ']', ''))) AS schema_name,
        LTRIM(RTRIM(REPLACE(REPLACE(
            CASE
                WHEN p1.first_dot <= 0 THEN NULL
                WHEN p2.second_dot > p1.first_dot THEN
                    SUBSTRING(lr.alloc_unit_name, p1.first_dot + 1, p2.second_dot - p1.first_dot - 1)
                ELSE
                    SUBSTRING(lr.alloc_unit_name, p1.first_dot + 1, LEN(lr.alloc_unit_name) - p1.first_dot)
            END
        , '[', ''), ']', ''))) AS table_name
    FROM #log_rows lr
    INNER JOIN commits c
        ON c.transaction_id = lr.transaction_id
    CROSS APPLY (
        SELECT CHARINDEX('.', lr.alloc_unit_name) AS first_dot
    ) p1
    CROSS APPLY (
        SELECT
            CASE
                WHEN p1.first_dot > 0 THEN CHARINDEX('.', lr.alloc_unit_name, p1.first_dot + 1)
                ELSE 0
            END AS second_dot
    ) p2
    WHERE lr.operation_name IN ('LOP_INSERT_ROWS', 'LOP_DELETE_ROWS', 'LOP_MODIFY_ROW', 'LOP_MODIFY_COLUMNS')
      AND lr.alloc_unit_name IS NOT NULL
      AND p1.first_dot > 0
)
SELECT
    ch.current_lsn,
    ch.transaction_id,
    ch.operation_name,
    ch.context_name,
    ch.schema_name,
    ch.table_name,
    ch.alloc_unit_name,
    ch.page_id,
    ch.slot_id,
    b.spid AS begin_spid,
    b.transaction_name,
    b.begin_time AS tx_begin_time,
    ch.commit_time AS tx_commit_time,
    master.dbo.fn_varbintohexstr(ch.rowlog0) AS rowlog0_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog1) AS rowlog1_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog2) AS rowlog2_hex,
    master.dbo.fn_varbintohexstr(ch.rowlog3) AS rowlog3_hex,
    CASE ch.operation_name
        WHEN 'LOP_INSERT_ROWS' THEN
            CONCAT('INSERT INTO [', ch.schema_name, '].[', ch.table_name, '] (/* columns */) VALUES (/* decode rowlog */);')
        WHEN 'LOP_DELETE_ROWS' THEN
            CONCAT('DELETE FROM [', ch.schema_name, '].[', ch.table_name, '] WHERE /* decode key from rowlog */;')
        ELSE
            CONCAT('UPDATE [', ch.schema_name, '].[', ch.table_name, '] SET /* decode changed columns */ WHERE /* decode key */;')
    END AS reconstructed_sql_template
FROM changes ch
INNER JOIN #target_tables tt
    ON UPPER(tt.table_name) = UPPER(ch.table_name)
   AND (tt.schema_name IS NULL OR UPPER(tt.schema_name) = UPPER(ch.schema_name))
LEFT JOIN begins b
    ON b.transaction_id = ch.transaction_id
ORDER BY ch.commit_time ASC, ch.current_lsn ASC;

SELECT
    lt.current_lsn AS scan_end_lsn,
    lt.transaction_id AS scan_last_transaction_id,
    lt.operation_name AS scan_last_operation,
    lc.scan_last_commit_time
FROM (SELECT 1 AS dummy) d
OUTER APPLY (
    SELECT TOP (1)
        x.current_lsn,
        x.transaction_id,
        x.operation_name
    FROM #log_rows x
    WHERE x.transaction_id IS NOT NULL
      AND x.transaction_id <> '0000:00000000'
    ORDER BY x.current_lsn DESC
) lt
OUTER APPLY (
    SELECT MAX(CASE WHEN operation_name = 'LOP_COMMIT_XACT' THEN end_time END) AS scan_last_commit_time
    FROM #log_rows
) lc;

DROP TABLE #log_rows;
DROP TABLE #target_tables;
"@

$connStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$connStringBuilder["Data Source"] = $ServerInstance
$connStringBuilder["Initial Catalog"] = $Database
$connStringBuilder["TrustServerCertificate"] = $true

if ($SqlUser) {
    if (-not $SqlPassword) {
        throw "SqlPassword is required when SqlUser is provided."
    }
    $connStringBuilder["User ID"] = $SqlUser
    $connStringBuilder["Password"] = $SqlPassword
    $connStringBuilder["Integrated Security"] = $false
} else {
    $connStringBuilder["Integrated Security"] = $true
}

$connection = New-Object System.Data.SqlClient.SqlConnection($connStringBuilder.ConnectionString)
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

$rows = @($dataTable.Rows | ForEach-Object {
    [pscustomobject]@{
        current_lsn                 = $_.current_lsn
        transaction_id              = $_.transaction_id
        operation_name              = $_.operation_name
        context_name                = $_.context_name
        schema_name                 = $_.schema_name
        table_name                  = $_.table_name
        alloc_unit_name             = $_.alloc_unit_name
        page_id                     = $_.page_id
        slot_id                     = $_.slot_id
        begin_spid                  = $_.begin_spid
        transaction_name            = $_.transaction_name
        tx_begin_time               = $_.tx_begin_time
        tx_commit_time              = $_.tx_commit_time
        rowlog0_hex                 = $_.rowlog0_hex
        rowlog1_hex                 = $_.rowlog1_hex
        rowlog2_hex                 = $_.rowlog2_hex
        rowlog3_hex                 = $_.rowlog3_hex
        reconstructed_sql_template  = $_.reconstructed_sql_template
        is_exact_original_sql_text  = $false
    }
})

$scanEndLsn = $null
$scanLastTransactionId = $null
$scanLastOperation = $null
$scanLastCommitTime = $null
if ($metaTable.Rows.Count -gt 0) {
    $metaRow = $metaTable.Rows[0]
    if ($metaRow.scan_end_lsn -and $metaRow.scan_end_lsn -isnot [System.DBNull]) {
        $scanEndLsn = [string]$metaRow.scan_end_lsn
    }
    if ($metaRow.scan_last_commit_time -and $metaRow.scan_last_commit_time -isnot [System.DBNull]) {
        $scanLastCommitTime = [string]$metaRow.scan_last_commit_time
    }
    if ($metaRow.scan_last_transaction_id -and $metaRow.scan_last_transaction_id -isnot [System.DBNull]) {
        $scanLastTransactionId = [string]$metaRow.scan_last_transaction_id
    }
    if ($metaRow.scan_last_operation -and $metaRow.scan_last_operation -isnot [System.DBNull]) {
        $scanLastOperation = [string]$metaRow.scan_last_operation
    }
}

$summary = [pscustomobject]@{
    collected_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    server_instance  = $ServerInstance
    database         = $Database
    window_minutes   = $WindowMinutes
    start_lsn_used   = $StartLsn
    incremental_mode = [bool]$StartLsn
    scan_end_lsn     = $scanEndLsn
    scan_last_transaction_id = $scanLastTransactionId
    scan_last_operation = $scanLastOperation
    scan_last_commit_time = $scanLastCommitTime
    tables           = $Tables
    transaction_count = @($rows | Select-Object -ExpandProperty transaction_id -Unique).Count
    row_count        = $rows.Count
    note             = "SQL Server transaction log does not preserve original submitted SQL text for all DML. reconstructed_sql_template is an equivalent template plus row-log payload hex."
    records          = $rows
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host ("Wrote {0} rows across {1} transactions to {2}" -f $summary.row_count, $summary.transaction_count, (Resolve-Path -LiteralPath $OutputPath))
