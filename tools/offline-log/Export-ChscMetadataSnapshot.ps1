param(
    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\\ERPLINK",

    [Parameter()]
    [string]$Database = "OASIS_MH",

    [Parameter()]
    [string]$SchemaName = "oasis",

    [Parameter()]
    [string[]]$Tables,

    [Parameter()]
    [string]$OutputPath = ".\\output\\chsc_metadata.snapshot.json",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

function New-ConnectionString {
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
    return $builder.ConnectionString
}

$tableFilterSql = ""
if ($Tables -and $Tables.Count -gt 0) {
    $valid = @($Tables | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($valid.Count -eq 0) {
        throw "Tables list is empty after normalization."
    }
    $quoted = ($valid | ForEach-Object { "N'" + $_.Replace("'", "''") + "'" }) -join ", "
    $tableFilterSql = "AND t.name IN ($quoted)"
}

$safeSchema = $SchemaName.Replace("'", "''")
$query = @"
SET NOCOUNT ON;

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    CASE WHEN pkc.column_id IS NULL THEN 0 ELSE 1 END AS is_pk,
    ISNULL(pkc.key_ordinal, 0) AS pk_ordinal,
    c.is_identity,
    c.is_computed
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id, ic.key_ordinal
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    WHERE i.is_primary_key = 1
) pkc ON pkc.object_id = c.object_id AND pkc.column_id = c.column_id
WHERE s.name = N'$safeSchema'
  AND t.name LIKE N'CHSC[_]%'
  $tableFilterSql
ORDER BY t.name, c.column_id;

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    i.is_primary_key,
    i.is_unique,
    ic.key_ordinal,
    c.name AS column_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.indexes i ON i.object_id = t.object_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE s.name = N'$safeSchema'
  AND t.name LIKE N'CHSC[_]%'
  $tableFilterSql
  AND ic.key_ordinal > 0
ORDER BY t.name, i.index_id, ic.key_ordinal;
"@

$conn = New-Object System.Data.SqlClient.SqlConnection (New-ConnectionString)
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 0
$cmd.CommandText = $query

$columnsTable = New-Object System.Data.DataTable
$indexesTable = New-Object System.Data.DataTable
try {
    $conn.Open()
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dataSet = New-Object System.Data.DataSet
    [void]$adapter.Fill($dataSet)

    if ($dataSet.Tables.Count -gt 0) {
        $columnsTable = $dataSet.Tables[0]
    }
    if ($dataSet.Tables.Count -gt 1) {
        $indexesTable = $dataSet.Tables[1]
    }
} finally {
    $conn.Dispose()
}

$tableKeys = New-Object System.Collections.Generic.HashSet[string]
foreach ($r in $columnsTable.Rows) {
    $k = ("{0}.{1}" -f [string]$r.schema_name, [string]$r.table_name).ToUpperInvariant()
    [void]$tableKeys.Add($k)
}

$tablesOut = @()
foreach ($k in ($tableKeys | Sort-Object)) {
    $parts = $k.Split(".")
    $schemaNameOut = $parts[0]
    $tableNameOut = $parts[1]

    $cols = @()
    foreach ($r in @($columnsTable.Rows | Where-Object {
        ([string]$_.schema_name).ToUpperInvariant() -eq $schemaNameOut -and
        ([string]$_.table_name).ToUpperInvariant() -eq $tableNameOut
    } | Sort-Object column_id)) {
        $cols += [pscustomobject]@{
            column_id   = [int]$r.column_id
            column_name = [string]$r.column_name
            data_type   = [string]$r.data_type
            max_length  = [int]$r.max_length
            precision   = [int]$r.precision
            scale       = [int]$r.scale
            is_nullable = [bool]$r.is_nullable
            is_pk       = ([int]$r.is_pk -eq 1)
            pk_ordinal  = [int]$r.pk_ordinal
            is_identity = [bool]$r.is_identity
            is_computed = [bool]$r.is_computed
        }
    }

    $idx = @()
    foreach ($r in @($indexesTable.Rows | Where-Object {
        ([string]$_.schema_name).ToUpperInvariant() -eq $schemaNameOut -and
        ([string]$_.table_name).ToUpperInvariant() -eq $tableNameOut
    } | Sort-Object index_name, key_ordinal)) {
        $idx += [pscustomobject]@{
            index_name     = [string]$r.index_name
            is_primary_key = [bool]$r.is_primary_key
            is_unique      = [bool]$r.is_unique
            key_ordinal    = [int]$r.key_ordinal
            column_name    = [string]$r.column_name
        }
    }

    $tablesOut += [pscustomobject]@{
        schema_name = $schemaNameOut.ToLowerInvariant()
        table_name  = $tableNameOut
        columns     = $cols
        indexes     = $idx
    }
}

$tablesOutArray = if ($null -eq $tablesOut) { @() } elseif ($tablesOut -is [array]) { $tablesOut } else { @($tablesOut) }
$out = [pscustomobject]@{
    generated_utc   = (Get-Date).ToUniversalTime().ToString("o")
    source_server   = $ServerInstance
    source_database = $Database
    schema_name     = $SchemaName
    table_count     = $tablesOutArray.Count
    tables          = $tablesOutArray
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$out | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Wrote metadata snapshot for {0} table(s) to {1}" -f $tablesOutArray.Count, (Resolve-Path -LiteralPath $OutputPath))
