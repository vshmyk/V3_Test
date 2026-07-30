param(
    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter(Mandatory = $true)]
    [string[]]$Tables,

    [Parameter()]
    [string]$OfflineDatabaseName = "OASIS_MH_OFFLINE",

    [Parameter()]
    [string]$SourceDrive = "E:",

    [Parameter()]
    [string]$LinkPath = "C:\Users\vshmyk\AgencyOnline\TransLogs_Shadow",

    [Parameter()]
    [string]$SnapshotDataPath = "DATA\Oasis",

    [Parameter()]
    [string]$MdfName = "OASIS_MH.mdf",

    [Parameter()]
    [string]$LdfName = "OASIS_MH_log.ldf",

    [Parameter()]
    [int]$HoursBack = 4,

    [Parameter()]
    [string]$OutputPath = ".\output\offline-log-last-4h.json",

    [Parameter()]
    [string]$MhTrnPath = ".\output\mh.trn",

    [Parameter()]
    [string]$MhTrnTable = "oasis.CHSC_POLINE",

    [Parameter()]
    [int]$MhTrnHoursBack = 5,

    [Parameter()]
    [string]$StatePath = ".\output\LastOffset.json",

    [Parameter()]
    [string]$MetadataCacheDir = ".\output\metadata",

    [Parameter()]
    [string]$AttachStagingDir = "C:\ProgramData\AOtransact\AttachStaging",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword,

    [Parameter()]
    [switch]$UseAttachedDatabase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($HoursBack -lt 1) {
    throw "HoursBack must be greater than 0."
}

if ($MhTrnHoursBack -lt 1) {
    throw "MhTrnHoursBack must be greater than 0."
}

if (-not $Tables -or $Tables.Count -eq 0) {
    throw "Provide at least one table in schema.table format."
}

if ($MhTrnTable -notmatch "^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$") {
    throw "MhTrnTable must use schema.table format (letters, digits, underscore)."
}

if (-not $StatePath) {
    throw "StatePath cannot be empty."
}

if (-not $MetadataCacheDir) {
    throw "MetadataCacheDir cannot be empty."
}

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

function New-ConnectionString {
    param(
        [string]$Server,
        [string]$Database
    )

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $Server
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

function Invoke-SqlNonQuery {
    param(
        [string]$Database,
        [string]$Sql
    )

    $connection = New-Object System.Data.SqlClient.SqlConnection (New-ConnectionString -Server $ServerInstance -Database $Database)
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 0
    $command.CommandText = $Sql

    try {
        $connection.Open()
        [void]$command.ExecuteNonQuery()
    } finally {
        $connection.Dispose()
    }
}

function Invoke-SqlQuery {
    param(
        [string]$Database,
        [string]$Sql
    )

    $connection = New-Object System.Data.SqlClient.SqlConnection (New-ConnectionString -Server $ServerInstance -Database $Database)
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 0
    $command.CommandText = $Sql

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
    $table = New-Object System.Data.DataTable

    try {
        [void]$adapter.Fill($table)
    } finally {
        $adapter.Dispose()
        $connection.Dispose()
    }

    return ,$table
}

function Remove-LinkPath {
    if (-not (Test-Path -LiteralPath $LinkPath)) {
        return
    }

    $item = Get-Item -LiteralPath $LinkPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        cmd.exe /c "rmdir `"$LinkPath`"" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove symbolic link $LinkPath"
        }
        return
    }

    $children = Get-ChildItem -LiteralPath $LinkPath -Force
    if ($children.Count -gt 0) {
        throw "Path $LinkPath exists and is not an empty symbolic link. Refusing to delete."
    }

    Remove-Item -LiteralPath $LinkPath -Force
}

function Split-SchemaTable {
    param(
        [string]$SchemaTable
    )

    $parts = $SchemaTable.Split(".")
    if ($parts.Count -ne 2) {
        throw "Invalid schema.table value: $SchemaTable"
    }

    return [pscustomobject]@{
        SchemaName = $parts[0]
        TableName  = $parts[1]
    }
}

function Parse-LogDateTime {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime()
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $formats = @(
        "yyyy/MM/dd HH:mm:ss:fff",
        "yyyy-MM-dd HH:mm:ss.fff",
        "yyyy-MM-ddTHH:mm:ss.fffffffK",
        "o"
    )
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::AssumeLocal

    foreach ($format in $formats) {
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($text, $format, $culture, $styles, [ref]$parsed)) {
            return $parsed.ToUniversalTime()
        }
    }

    $fallback = [datetime]::MinValue
    if ([datetime]::TryParse($text, [ref]$fallback)) {
        return $fallback.ToUniversalTime()
    }

    return $null
}

function Normalize-TableName {
    param(
        [string]$SchemaName,
        [string]$TableName
    )

    return ("{0}.{1}" -f $SchemaName, $TableName).ToUpperInvariant()
}

function Ensure-ParentDirectory {
    param(
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Ensure-Directory {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-AttachSql {
    param(
        [string]$DatabaseName,
        [string]$MdfPath,
        [string]$LdfPath
    )

    $escapedDb = $DatabaseName.Replace("]", "]]")
    $escapedMdf = $MdfPath.Replace("'", "''")
    $escapedLdf = $LdfPath.Replace("'", "''")
    return @"
SET NOCOUNT ON;
IF DB_ID(N'$escapedDb') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    EXEC sp_detach_db @dbname=N'$escapedDb';
END;
CREATE DATABASE [$escapedDb]
ON (FILENAME = N'$escapedMdf'),
   (FILENAME = N'$escapedLdf')
FOR ATTACH;
ALTER DATABASE [$escapedDb] SET READ_ONLY;
"@
}

function Copy-OfflineFilesToStaging {
    param(
        [string]$SourceMdfPath,
        [string]$SourceLdfPath,
        [string]$StagingRootDir
    )

    Ensure-Directory -Path $StagingRootDir
    $runDir = Join-Path -Path $StagingRootDir -ChildPath ("run-" + [Guid]::NewGuid().ToString("N"))
    Ensure-Directory -Path $runDir

    $sourceDir = Split-Path -Parent $SourceMdfPath
    $mdfFileName = Split-Path -Leaf $SourceMdfPath
    $ldfFileName = Split-Path -Leaf $SourceLdfPath

    $copyOutput = & robocopy $sourceDir $runDir $mdfFileName $ldfFileName /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /J
    $rc = $LASTEXITCODE
    if ($rc -gt 7) {
        throw ("Failed to copy offline files into staging. robocopy exit code {0}. Output:`n{1}" -f $rc, ($copyOutput -join [Environment]::NewLine))
    }

    $stagedMdf = Join-Path -Path $runDir -ChildPath $mdfFileName
    $stagedLdf = Join-Path -Path $runDir -ChildPath $ldfFileName
    if (-not (Test-Path -LiteralPath $stagedMdf)) {
        throw "Staged MDF file missing: $stagedMdf"
    }
    if (-not (Test-Path -LiteralPath $stagedLdf)) {
        throw "Staged LDF file missing: $stagedLdf"
    }

    return [pscustomobject]@{
        staging_dir = $runDir
        mdf_path    = $stagedMdf
        ldf_path    = $stagedLdf
    }
}

function Get-TablesKey {
    param(
        [string[]]$TablesInput
    )

    return (($TablesInput | ForEach-Object { $_.ToUpperInvariant() } | Sort-Object -Unique) -join ";")
}

function Get-SourceSignature {
    param(
        [string]$Drive,
        [string]$SnapshotPath,
        [string]$MdfFile,
        [string]$LdfFile
    )

    $parts = @(
        ([string]$Drive).Trim().ToUpperInvariant(),
        ([string]$SnapshotPath).Trim().ToUpperInvariant(),
        ([string]$MdfFile).Trim().ToUpperInvariant(),
        ([string]$LdfFile).Trim().ToUpperInvariant()
    )
    return ($parts -join "|")
}

function Load-IncrementalState {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return ($text | ConvertFrom-Json)
}

function Save-IncrementalState {
    param(
        [string]$Path,
        [pscustomobject]$State
    )

    Ensure-ParentDirectory -Path $Path
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Migrate-LegacyStatePath {
    param(
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        return
    }

    $leaf = Split-Path -Leaf $Path
    if (-not $leaf.Equals("LastOffset.json", [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $parent = Split-Path -Parent $Path
    if (-not $parent) {
        $parent = "."
    }
    $legacyPath = Join-Path -Path $parent -ChildPath "LastOffet.json"
    if (-not (Test-Path -LiteralPath $legacyPath)) {
        return
    }

    Ensure-ParentDirectory -Path $Path
    Move-Item -LiteralPath $legacyPath -Destination $Path -Force
    Write-Host "Migrated legacy state file to $Path"
}

function Is-ValidLsn {
    param(
        [AllowNull()]
        [string]$Lsn
    )

    if ([string]::IsNullOrWhiteSpace($Lsn)) {
        return $false
    }

    return ($Lsn -match "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")
}

function Get-MetadataCachePath {
    param(
        [string]$SchemaName,
        [string]$TableName
    )

    $safe = ("{0}_{1}" -f $SchemaName, $TableName) -replace "[^A-Za-z0-9_.-]", "_"
    return Join-Path -Path $MetadataCacheDir -ChildPath ($safe + ".metadata.json")
}

function Supports-BinaryDecodeType {
    param(
        [string]$DataType
    )

    $supported = @(
        "bit", "tinyint", "smallint", "int", "bigint",
        "decimal", "numeric", "money", "smallmoney",
        "float", "real",
        "char", "varchar", "nchar", "nvarchar",
        "binary", "varbinary", "uniqueidentifier",
        "date", "time", "datetime", "smalldatetime", "datetime2", "datetimeoffset"
    )

    return $supported -contains $DataType.ToLowerInvariant()
}

function Get-SqlTypeSpec {
    param(
        [pscustomobject]$Column
    )

    $type = $Column.data_type.ToLowerInvariant()
    switch ($type) {
        "varchar" {
            if ($Column.max_length -eq -1) { return "varchar(max)" }
            return "varchar($($Column.max_length))"
        }
        "nvarchar" {
            if ($Column.max_length -eq -1) { return "nvarchar(max)" }
            return "nvarchar($([Math]::Floor($Column.max_length / 2)))"
        }
        "char" { return "char($($Column.max_length))" }
        "nchar" { return "nchar($([Math]::Floor($Column.max_length / 2)))" }
        "binary" { return "binary($($Column.max_length))" }
        "varbinary" {
            if ($Column.max_length -eq -1) { return "varbinary(max)" }
            return "varbinary($($Column.max_length))"
        }
        "decimal" { return "decimal($($Column.precision),$($Column.scale))" }
        "numeric" { return "numeric($($Column.precision),$($Column.scale))" }
        "time" { return "time($($Column.scale))" }
        "datetime2" { return "datetime2($($Column.scale))" }
        "datetimeoffset" { return "datetimeoffset($($Column.scale))" }
        default { return $type }
    }
}

function Get-TableMetadata {
    param(
        [string]$Database,
        [string]$SchemaName,
        [string]$TableName
    )

    $safeSchema = $SchemaName.Replace("'", "''")
    $safeTable = $TableName.Replace("'", "''")
    $sql = @"
SET NOCOUNT ON;
SELECT
    c.column_id,
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.[precision],
    c.scale,
    c.is_nullable,
    CASE WHEN pkc.column_id IS NULL THEN 0 ELSE 1 END AS is_pk,
    ISNULL(pkc.key_ordinal, 0) AS pk_ordinal
FROM sys.columns c
JOIN sys.types t
    ON c.user_type_id = t.user_type_id
LEFT JOIN (
    SELECT ic.column_id, ic.key_ordinal
    FROM sys.indexes i
    JOIN sys.index_columns ic
        ON i.object_id = ic.object_id
       AND i.index_id = ic.index_id
    WHERE i.object_id = OBJECT_ID(N'[$safeSchema].[$safeTable]')
      AND i.is_primary_key = 1
) pkc
    ON pkc.column_id = c.column_id
WHERE c.object_id = OBJECT_ID(N'[$safeSchema].[$safeTable]')
ORDER BY c.column_id;
"@

    $dt = Invoke-SqlQuery -Database $Database -Sql $sql
    $result = @()
    foreach ($r in $dt.Rows) {
        $result += [pscustomobject]@{
            column_id   = [int]$r.column_id
            column_name = [string]$r.column_name
            data_type   = [string]$r.data_type
            max_length  = [int]$r.max_length
            precision   = [int]$r.precision
            scale       = [int]$r.scale
            is_nullable = [bool]$r.is_nullable
            is_pk       = ([int]$r.is_pk -eq 1)
            pk_ordinal  = [int]$r.pk_ordinal
        }
    }
    return $result
}

function Get-TableIndexes {
    param(
        [string]$Database,
        [string]$SchemaName,
        [string]$TableName
    )

    $safeSchema = $SchemaName.Replace("'", "''")
    $safeTable = $TableName.Replace("'", "''")
    $sql = @"
SET NOCOUNT ON;
SELECT
    i.name AS index_name,
    i.type_desc,
    i.is_primary_key,
    ic.key_ordinal,
    ic.is_included_column,
    c.name AS column_name
FROM sys.indexes i
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
   AND i.index_id = ic.index_id
JOIN sys.columns c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'[$safeSchema].[$safeTable]')
ORDER BY i.index_id, ic.key_ordinal, ic.index_column_id;
"@

    $dt = Invoke-SqlQuery -Database $Database -Sql $sql
    $result = @()
    foreach ($r in $dt.Rows) {
        $result += [pscustomobject]@{
            index_name         = [string]$r.index_name
            type_desc          = [string]$r.type_desc
            is_primary_key     = [bool]$r.is_primary_key
            key_ordinal        = [int]$r.key_ordinal
            is_included_column = [bool]$r.is_included_column
            column_name        = [string]$r.column_name
        }
    }
    return $result
}

function Get-CachedTableMetadata {
    param(
        [string]$Database,
        [string]$SchemaName,
        [string]$TableName
    )

    Ensure-Directory -Path $MetadataCacheDir
    $cachePath = Get-MetadataCachePath -SchemaName $SchemaName -TableName $TableName

    $columnsFromDb = Get-TableMetadata -Database $Database -SchemaName $SchemaName -TableName $TableName
    $indexesFromDb = Get-TableIndexes -Database $Database -SchemaName $SchemaName -TableName $TableName

    $snapshot = [pscustomobject]@{
        version          = 1
        schema_name      = $SchemaName
        table_name       = $TableName
        source_database  = $Database
        captured_at_utc  = (Get-Date).ToUniversalTime().ToString("o")
        columns          = $columnsFromDb
        indexes          = $indexesFromDb
    }

    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cachePath -Encoding UTF8

    return [pscustomobject]@{
        cache_path = $cachePath
        from_cache = $false
        columns    = $columnsFromDb
        indexes    = $indexesFromDb
    }
}

function Convert-HexToBytes {
    param(
        [AllowNull()]
        [string]$Hex
    )

    if ([string]::IsNullOrWhiteSpace($Hex)) {
        return ,([byte[]]@())
    }

    $clean = $Hex.Trim()
    if ($clean.StartsWith("0x")) {
        $clean = $clean.Substring(2)
    }

    if ($clean.Length -eq 0) {
        return ,([byte[]]@())
    }

    if (($clean.Length % 2) -ne 0) {
        throw "Invalid hex length: $Hex"
    }

    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $clean.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($clean.Substring($i, 2), 16)
    }
    return ,$bytes
}

function Find-SubArrayIndex {
    param(
        [byte[]]$Haystack,
        [byte[]]$Needle,
        [int]$StartAt = 0
    )

    if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) {
        return -1
    }

    for ($i = $StartAt; $i -le ($Haystack.Length - $Needle.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            return $i
        }
    }
    return -1
}

function Bytes-ToHexLiteral {
    param(
        [byte[]]$Bytes
    )

    if (-not $Bytes -or $Bytes.Length -eq 0) {
        return "0x"
    }

    $hex = [System.BitConverter]::ToString($Bytes).Replace("-", "")
    return "0x$hex"
}

function Convert-TypedValueToSqlLiteral {
    param(
        [AllowNull()]
        [object]$Value,
        [pscustomobject]$Column
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return "NULL"
    }

    $type = $Column.data_type.ToLowerInvariant()
    switch ($type) {
        "char" { return "'" + ([string]$Value).Replace("'", "''") + "'" }
        "varchar" { return "'" + ([string]$Value).Replace("'", "''") + "'" }
        "nchar" { return "N'" + ([string]$Value).Replace("'", "''") + "'" }
        "nvarchar" { return "N'" + ([string]$Value).Replace("'", "''") + "'" }
        "date" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd") + "'" }
        "time" {
            $dt = [datetime]$Value
            return "'" + $dt.ToString("HH:mm:ss.fffffff") + "'"
        }
        "datetime" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss.fff") + "'" }
        "smalldatetime" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss") + "'" }
        "datetime2" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss.fffffff") + "'" }
        "datetimeoffset" { return "'" + ([datetimeoffset]$Value).ToString("yyyy-MM-dd HH:mm:ss.fffffff zzz") + "'" }
        "bit" { return (if ([bool]$Value) { "1" } else { "0" }) }
        "tinyint" { return [Convert]::ToByte($Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "smallint" { return [Convert]::ToInt16($Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "int" { return [Convert]::ToInt32($Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "bigint" { return [Convert]::ToInt64($Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "float" { return [Convert]::ToDouble($Value).ToString("R", [System.Globalization.CultureInfo]::InvariantCulture) }
        "real" { return [Convert]::ToSingle($Value).ToString("R", [System.Globalization.CultureInfo]::InvariantCulture) }
        "decimal" { return [decimal]$Value | ForEach-Object { $_.ToString([System.Globalization.CultureInfo]::InvariantCulture) } }
        "numeric" { return [decimal]$Value | ForEach-Object { $_.ToString([System.Globalization.CultureInfo]::InvariantCulture) } }
        "money" { return [decimal]$Value | ForEach-Object { $_.ToString([System.Globalization.CultureInfo]::InvariantCulture) } }
        "smallmoney" { return [decimal]$Value | ForEach-Object { $_.ToString([System.Globalization.CultureInfo]::InvariantCulture) } }
        "uniqueidentifier" { return "'" + [string]$Value + "'" }
        "binary" {
            if ($Value -is [byte[]]) { return Bytes-ToHexLiteral -Bytes $Value }
            return [string]$Value
        }
        "varbinary" {
            if ($Value -is [byte[]]) { return Bytes-ToHexLiteral -Bytes $Value }
            return [string]$Value
        }
        default {
            return "'" + ([string]$Value).Replace("'", "''") + "'"
        }
    }
}

function Convert-HexLiteralToTypedValue {
    param(
        [string]$Database,
        [string]$HexLiteral,
        [pscustomobject]$Column
    )

    if ([string]::IsNullOrWhiteSpace($HexLiteral) -or $HexLiteral -eq "0x") {
        return $null
    }

    $typeSpec = Get-SqlTypeSpec -Column $Column
    $sql = "SELECT CAST($HexLiteral AS $typeSpec) AS value;"
    $dt = Invoke-SqlQuery -Database $Database -Sql $sql
    if ($dt.Rows.Count -eq 0) {
        return $null
    }

    $v = $dt.Rows[0]["value"]
    if ($v -is [System.DBNull]) {
        return $null
    }
    return $v
}

function Get-RowByPhysicalLocation {
    param(
        [string]$Database,
        [string]$SchemaName,
        [string]$TableName,
        [int]$FileId,
        [int]$PageId,
        [int]$SlotId,
        [pscustomobject[]]$Metadata
    )

    $selectParts = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Metadata) {
        $colName = $col.column_name.Replace("]", "]]")
        $selectParts.Add("[$colName]")
        if (Supports-BinaryDecodeType -DataType $col.data_type) {
            $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), [$colName])) AS [bin_$colName]")
        }
    }

    $physLoc = "(${FileId}:${PageId}:${SlotId})"
    $safeSchema = $SchemaName.Replace("]", "]]")
    $safeTable = $TableName.Replace("]", "]]")
    $sql = @"
SET NOCOUNT ON;
SELECT TOP (1)
    $($selectParts -join ",`n    ")
FROM [$safeSchema].[$safeTable] WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%) = '$physLoc';
"@

    $dt = Invoke-SqlQuery -Database $Database -Sql $sql
    if ($dt.Rows.Count -eq 0) {
        return $null
    }
    return $dt.Rows[0]
}

function Get-UpdatedColumns {
    param(
        [string]$Database,
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) {
        return @()
    }

    $updates = @()
    foreach ($col in $Metadata) {
        if (-not (Supports-BinaryDecodeType -DataType $col.data_type)) {
            continue
        }

        $binField = "bin_{0}" -f $col.column_name
        if (-not $RowData.Table.Columns.Contains($binField)) {
            continue
        }

        $binHex = $RowData[$binField]
        if ($binHex -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$binHex)) {
            continue
        }

        $fullBytes = Convert-HexToBytes -Hex ([string]$binHex)
        if ($fullBytes.Length -eq 0) {
            continue
        }

        $searchAt = 0
        while ($true) {
            $pos = Find-SubArrayIndex -Haystack $fullBytes -Needle $newBytes -StartAt $searchAt
            if ($pos -lt 0) {
                break
            }

            $candidateOld = New-Object byte[] $fullBytes.Length
            [Array]::Copy($fullBytes, $candidateOld, $fullBytes.Length)
            [Array]::Copy($oldBytes, 0, $candidateOld, $pos, $oldBytes.Length)

            $oldHexLiteral = Bytes-ToHexLiteral -Bytes $candidateOld
            try {
                $oldTyped = Convert-HexLiteralToTypedValue -Database $Database -HexLiteral $oldHexLiteral -Column $col
            } catch {
                $searchAt = $pos + 1
                continue
            }

            $newTyped = $RowData[$col.column_name]
            if ($newTyped -is [System.DBNull]) {
                $newTyped = $null
            }

            $same = $false
            if ($null -eq $oldTyped -and $null -eq $newTyped) {
                $same = $true
            } elseif ($null -ne $oldTyped -and $null -ne $newTyped) {
                $same = ([string]$oldTyped -eq [string]$newTyped)
            }

            if (-not $same) {
                $updates += [pscustomobject]@{
                    column_name = $col.column_name
                    old_value   = $oldTyped
                    new_value   = $newTyped
                    old_sql     = Convert-TypedValueToSqlLiteral -Value $oldTyped -Column $col
                    new_sql     = Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col
                }
                break
            }

            $searchAt = $pos + 1
        }
    }

    $unique = @{}
    foreach ($u in $updates) {
        $key = $u.column_name.ToUpperInvariant()
        if (-not $unique.ContainsKey($key)) {
            $unique[$key] = $u
        }
    }
    return @($unique.Values)
}

$shadowId = $null
$shadowVolume = $null
$dbAttached = $false
$linkCreated = $false
$collectorTempPath = $null
$stagingRunDir = $null

try {
    Migrate-LegacyStatePath -Path $StatePath

    if ($UseAttachedDatabase) {
        Write-Host "Step 1/3: Using already attached database $OfflineDatabaseName on $ServerInstance"
        $checkAttached = Invoke-SqlQuery -Database "master" -Sql @"
SET NOCOUNT ON;
SELECT DB_ID(N'$($OfflineDatabaseName.Replace("'", "''"))') AS db_id;
"@
        if ($checkAttached.Rows.Count -eq 0 -or $checkAttached.Rows[0]["db_id"] -is [System.DBNull]) {
            throw "Database $OfflineDatabaseName is not attached on $ServerInstance."
        }
    } else {
        Write-Host "Step 1/8: Creating shadow copy for $SourceDrive"
        $createShadowOutput = & vssadmin create shadow "/for=$SourceDrive" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ("Failed to create shadow copy. Output:`n{0}" -f ($createShadowOutput -join [Environment]::NewLine))
        }

        $shadowIdMatch = ($createShadowOutput | Select-String -Pattern "Shadow Copy ID:\s*(\{[0-9a-fA-F-]+\})").Matches
        $shadowVolumeMatch = ($createShadowOutput | Select-String -Pattern "Shadow Copy Volume Name:\s*(\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy\d+)").Matches

        if ($shadowIdMatch.Count -eq 0 -or $shadowVolumeMatch.Count -eq 0) {
            throw ("Could not parse shadow copy details. Output:`n{0}" -f ($createShadowOutput -join [Environment]::NewLine))
        }

        $shadowId = $shadowIdMatch[0].Groups[1].Value
        $shadowVolume = $shadowVolumeMatch[0].Groups[1].Value + "\"

        Write-Host "Step 2/8: Creating symbolic link $LinkPath -> $shadowVolume"
        Ensure-ParentDirectory -Path $LinkPath
        Remove-LinkPath
        cmd.exe /c "mklink /D `"$LinkPath`" `"$shadowVolume`"" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create symbolic link $LinkPath -> $shadowVolume"
        }
        $linkCreated = $true

        $offlineRoot = Join-Path -Path $LinkPath -ChildPath $SnapshotDataPath
        $mdfPath = Join-Path -Path $offlineRoot -ChildPath $MdfName
        $ldfPath = Join-Path -Path $offlineRoot -ChildPath $LdfName

        if (-not (Test-Path -LiteralPath $mdfPath)) {
            throw "MDF file not found: $mdfPath"
        }

        if (-not (Test-Path -LiteralPath $ldfPath)) {
            throw "LDF file not found: $ldfPath"
        }

        Write-Host "Step 3/8: Attaching $OfflineDatabaseName from shadow copy"
        $attachFromMdf = $mdfPath
        $attachFromLdf = $ldfPath
        try {
            $attachSql = Get-AttachSql -DatabaseName $OfflineDatabaseName -MdfPath $attachFromMdf -LdfPath $attachFromLdf
            Invoke-SqlNonQuery -Database "master" -Sql $attachSql
            $dbAttached = $true
        } catch {
            $err = $_.Exception.Message
            Write-Warning ("Direct attach from shadow path failed: {0}" -f $err)
            Write-Host "Step 3/8 fallback: Copying MDF/LDF to staging path $AttachStagingDir"
            $staged = Copy-OfflineFilesToStaging -SourceMdfPath $mdfPath -SourceLdfPath $ldfPath -StagingRootDir $AttachStagingDir
            $stagingRunDir = $staged.staging_dir
            $attachFromMdf = $staged.mdf_path
            $attachFromLdf = $staged.ldf_path
            Write-Host ("Retrying attach from staging copy: {0}" -f $stagingRunDir)
            $attachSql = Get-AttachSql -DatabaseName $OfflineDatabaseName -MdfPath $attachFromMdf -LdfPath $attachFromLdf
            Invoke-SqlNonQuery -Database "master" -Sql $attachSql
            $dbAttached = $true
        }
        $escapedDb = $OfflineDatabaseName.Replace("]", "]]")
    }

    Write-Host "Step 4/8: Querying committed log rows for requested JSON output and mh.trn output"
    $collectorScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-CommittedTableTransactions.ps1"
    if (-not (Test-Path -LiteralPath $collectorScript)) {
        throw "Collector script not found: $collectorScript"
    }

    $primaryWindowMinutes = $HoursBack * 60
    $trnWindowMinutes = $MhTrnHoursBack * 60
    $collectorWindowMinutes = [Math]::Max($primaryWindowMinutes, $trnWindowMinutes)
    $collectorTables = @($Tables + $MhTrnTable | Sort-Object -Unique)
    $collectorTablesKey = Get-TablesKey -TablesInput $collectorTables
    if ($UseAttachedDatabase) {
        $escapedAttachedDb = $OfflineDatabaseName.Replace("'", "''")
        $fileRows = Invoke-SqlQuery -Database "master" -Sql @"
SET NOCOUNT ON;
SELECT physical_name
FROM sys.master_files
WHERE database_id = DB_ID(N'$escapedAttachedDb')
ORDER BY file_id;
"@
        $fileParts = @()
        foreach ($fr in $fileRows) {
            $p = [string]$fr["physical_name"]
            if (-not [string]::IsNullOrWhiteSpace($p)) {
                $fileParts += $p.ToUpperInvariant()
            }
        }
        $fileSig = if ($fileParts.Count -gt 0) { ($fileParts -join "|") } else { "NO_FILES" }
        $sourceSignature = "ATTACHED_DB::{0}::{1}::{2}" -f $ServerInstance.ToUpperInvariant(), $OfflineDatabaseName.ToUpperInvariant(), $fileSig
    } else {
        $sourceSignature = Get-SourceSignature -Drive $SourceDrive -SnapshotPath $SnapshotDataPath -MdfFile $MdfName -LdfFile $LdfName
    }

    $startLsnToUse = $null
    $state = Load-IncrementalState -Path $StatePath
    if ($state) {
        $stateServer = [string]$state.server_instance
        $stateDb = [string]$state.database
        $stateTablesKey = [string]$state.tables_key
        $stateLsn = [string]$state.last_lsn
        $stateSourceSignature = $null
        if ($state.PSObject.Properties.Name -contains "source_signature") {
            $stateSourceSignature = [string]$state.source_signature
        }
        if (
            $stateServer.Equals($ServerInstance, [System.StringComparison]::OrdinalIgnoreCase) -and
            $stateDb.Equals($OfflineDatabaseName, [System.StringComparison]::OrdinalIgnoreCase) -and
            $stateTablesKey.Equals($collectorTablesKey, [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals($stateSourceSignature, $sourceSignature, [System.StringComparison]::OrdinalIgnoreCase) -and
            (Is-ValidLsn -Lsn $stateLsn)
        ) {
            $startLsnToUse = $stateLsn
            Write-Host "Using incremental StartLSN from state: $startLsnToUse"
        } else {
            Write-Host "State file found but not reusable for current scan scope; running window-based scan."
        }
    } else {
        Write-Host "State file not found; running window-based scan."
    }

    $collectorTempPath = Join-Path -Path $env:TEMP -ChildPath ("offline-log-{0}.json" -f [Guid]::NewGuid())
    $collectorParams = @{
        ServerInstance = $ServerInstance
        Database = $OfflineDatabaseName
        Tables = $collectorTables
        WindowMinutes = $collectorWindowMinutes
        OutputPath = $collectorTempPath
    }
    if ($startLsnToUse) {
        $collectorParams["StartLsn"] = $startLsnToUse
    }

    if ($SqlUser) {
        $collectorParams["SqlUser"] = $SqlUser
        $collectorParams["SqlPassword"] = $SqlPassword
    }

    $lsnGapDetected = $false
    try {
        & $collectorScript @collectorParams
    } catch {
        $errorText = $_.Exception.Message
        if ($startLsnToUse -and $errorText -like "*Invalid parameter passed to OpenRowset(DBLog*") {
            $lsnGapDetected = $true
            Write-Warning "StartLSN $startLsnToUse was not found in current offline log copy. Falling back to window scan and refreshing state."
            $collectorParams.Remove("StartLsn") | Out-Null
            & $collectorScript @collectorParams
        } else {
            throw
        }
    }

    $collectorJson = Get-Content -LiteralPath $collectorTempPath -Raw
    $collectorData = $collectorJson | ConvertFrom-Json
    $allRecords = @($collectorData.records)
    $collectedAtUtc = Parse-LogDateTime -Value $collectorData.collected_at_utc
    if ($null -eq $collectedAtUtc) {
        $collectedAtUtc = (Get-Date).ToUniversalTime()
    }

    $scanEndLsn = [string]$collectorData.scan_end_lsn
    $scanLastTransactionId = [string]$collectorData.scan_last_transaction_id
    $scanLastOperation = [string]$collectorData.scan_last_operation
    if (-not (Is-ValidLsn -Lsn $scanEndLsn)) {
        $scanEndLsn = $null
    }
    $scanLastCommit = Parse-LogDateTime -Value $collectorData.scan_last_commit_time

    if (-not $scanEndLsn) {
        $scanFallback = Invoke-SqlQuery -Database $OfflineDatabaseName -Sql @"
SET NOCOUNT ON;
SELECT TOP (1)
    [Current LSN] AS current_lsn,
    [Transaction ID] AS transaction_id,
    [Operation] AS operation_name,
    [End Time] AS end_time,
    [Begin Time] AS begin_time
FROM fn_dblog(NULL, NULL)
WHERE [Transaction ID] IS NOT NULL
  AND [Transaction ID] <> '0000:00000000'
ORDER BY [Current LSN] DESC;
"@
        if ($scanFallback.Rows.Count -gt 0) {
            $candidateLsn = [string]$scanFallback.Rows[0]["current_lsn"]
            if (Is-ValidLsn -Lsn $candidateLsn) {
                $scanEndLsn = $candidateLsn
                $scanLastTransactionId = [string]$scanFallback.Rows[0]["transaction_id"]
                $scanLastOperation = [string]$scanFallback.Rows[0]["operation_name"]
                if (-not $scanLastCommit) {
                    $scanLastCommit = Parse-LogDateTime -Value $scanFallback.Rows[0]["end_time"]
                }
                Write-Host "Fallback scan end LSN resolved: $scanEndLsn"
            }
        }
    }

    $stateNextLsn = if ($scanEndLsn) { $scanEndLsn } elseif ($state -and (Is-ValidLsn -Lsn ([string]$state.last_lsn))) { [string]$state.last_lsn } else { $startLsnToUse }
    $stateNextCommitUtc = if ($scanLastCommit) { $scanLastCommit.ToString("o") } elseif ($state -and $state.last_commit_time) { [string]$state.last_commit_time } else { $null }

    $newState = [pscustomobject]@{
        version          = 1
        updated_at_utc   = $collectedAtUtc.ToString("o")
        server_instance  = $ServerInstance
        database         = $OfflineDatabaseName
        tables_key       = $collectorTablesKey
        source_signature = $sourceSignature
        last_lsn         = $stateNextLsn
        last_commit_time = $stateNextCommitUtc
        last_transaction_id = if ([string]::IsNullOrWhiteSpace($scanLastTransactionId)) { $null } else { $scanLastTransactionId }
        last_operation   = if ([string]::IsNullOrWhiteSpace($scanLastOperation)) { $null } else { $scanLastOperation }
    }
    Save-IncrementalState -Path $StatePath -State $newState
    if ($stateNextLsn) {
        Write-Host "Saved incremental state with last_lsn=$stateNextLsn"
    } else {
        Write-Host "Saved state file; no last_lsn available in this scan."
    }

    $primaryWindowStart = $collectedAtUtc.AddMinutes(-$primaryWindowMinutes)
    $primaryTableSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($table in $Tables) {
        [void]$primaryTableSet.Add($table)
    }

    $primaryRecords = @($allRecords | Where-Object {
        $recordTable = "{0}.{1}" -f $_.schema_name, $_.table_name
        if (-not $primaryTableSet.Contains($recordTable)) {
            return $false
        }

        $commitUtc = Parse-LogDateTime -Value $_.tx_commit_time
        if ($null -eq $commitUtc) {
            return $false
        }

        return $commitUtc -ge $primaryWindowStart
    })

    $primarySummary = [pscustomobject]@{
        collected_at_utc = $collectedAtUtc.ToString("o")
        server_instance  = $ServerInstance
        database         = $OfflineDatabaseName
        window_minutes   = $primaryWindowMinutes
        start_lsn_used   = $startLsnToUse
        scan_end_lsn     = $scanEndLsn
        state_path       = $StatePath
        lsn_gap_detected = $lsnGapDetected
        tables           = $Tables
        transaction_count = @($primaryRecords | Select-Object -ExpandProperty transaction_id -Unique).Count
        row_count        = $primaryRecords.Count
        note             = "Filtered from a single collector scan. SQL Server transaction log does not preserve original submitted SQL text for all DML."
        records          = $primaryRecords
    }

    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    $primarySummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host ("Wrote {0} rows across {1} transactions to {2}" -f $primarySummary.row_count, $primarySummary.transaction_count, (Resolve-Path -LiteralPath $OutputPath))

    Write-Host "Step 5/8: Creating mh.trn with reconstructed DML for $MhTrnTable (last $MhTrnHoursBack hour(s))"
    $trnWindowStart = $collectedAtUtc.AddMinutes(-$trnWindowMinutes)
    $mhTableKey = $MhTrnTable.ToUpperInvariant()
    $mhParts = Split-SchemaTable -SchemaTable $MhTrnTable
    $mhMetaSnapshot = Get-CachedTableMetadata -Database $OfflineDatabaseName -SchemaName $mhParts.SchemaName -TableName $mhParts.TableName
    $mhMetadata = @($mhMetaSnapshot.columns)
    if (-not $mhMetadata -or $mhMetadata.Count -eq 0) {
        throw "Could not load metadata for $MhTrnTable."
    }
    Write-Host "Loaded table metadata from database and wrote snapshot: $($mhMetaSnapshot.cache_path)"

    $pkColumns = @($mhMetadata | Where-Object { $_.is_pk } | Sort-Object pk_ordinal)
    $whereKeyColumns = @()
    $whereKeyLabel = "primary_key"
    if ($pkColumns.Count -gt 0) {
        $whereKeyColumns = $pkColumns
    } else {
        $candidateIndexes = @($mhMetaSnapshot.indexes | Where-Object {
            $_.key_ordinal -gt 0 -and -not $_.is_included_column
        })
        $candidateGroups = @($candidateIndexes | Group-Object index_name | ForEach-Object {
            $first = $_.Group[0]
            $keys = @($_.Group | Sort-Object key_ordinal)
            [pscustomobject]@{
                index_name = [string]$first.index_name
                key_count = $keys.Count
                keys = $keys
            }
        } | Sort-Object @{ Expression = { $_.key_count }; Descending = $true }, @{ Expression = { $_.index_name } })

        if ($candidateGroups.Count -gt 0) {
            $selected = $candidateGroups[0]
            $fallbackCols = @()
            foreach ($k in $selected.keys) {
                $col = $mhMetadata | Where-Object { $_.column_name -eq $k.column_name } | Select-Object -First 1
                if ($col) {
                    $fallbackCols += $col
                }
            }
            if ($fallbackCols.Count -gt 0) {
                $whereKeyColumns = $fallbackCols
                $whereKeyLabel = "index:$($selected.index_name)"
            }
        }
    }

    $trnRecords = @($allRecords | Where-Object {
        $recordTableKey = Normalize-TableName -SchemaName $_.schema_name -TableName $_.table_name
        if ($recordTableKey -ne $mhTableKey) {
            return $false
        }

        $op = [string]$_.operation_name
        if ($op -notin @("LOP_INSERT_ROWS", "LOP_DELETE_ROWS", "LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS")) {
            return $false
        }

        $commitUtc = Parse-LogDateTime -Value $_.tx_commit_time
        if ($null -eq $commitUtc) {
            return $false
        }

        return $commitUtc -ge $trnWindowStart
    } | Sort-Object @{ Expression = { Parse-LogDateTime -Value $_.tx_commit_time } }, @{ Expression = { $_.current_lsn } })

    $clusteredRecords = @($trnRecords | Where-Object {
        ([string]$_.context_name).ToUpperInvariant() -eq "LCX_CLUSTERED"
    })

    $trnLines = New-Object System.Collections.Generic.List[string]
    $trnLines.Add("-- Reconstructed DML for $MhTrnTable")
    $trnLines.Add("-- Window: last $MhTrnHoursBack hour(s)")
    $trnLines.Add("-- Generated UTC: $($collectedAtUtc.ToString("o"))")
    $trnLines.Add("-- WHERE key source: $whereKeyLabel")
    if ($whereKeyColumns.Count -eq 0) {
        $trnLines.Add("-- WARNING: no PK/index key columns resolved; UPDATE/DELETE may fall back to template statements.")
    }
    $trnLines.Add("")

    $statementCount = 0
    foreach ($record in $clusteredRecords) {
        $commitUtc = Parse-LogDateTime -Value $record.tx_commit_time
        $commitText = if ($commitUtc) { $commitUtc.ToString("yyyy-MM-dd HH:mm:ss.fff") } else { [string]$record.tx_commit_time }

        $pageIdText = [string]$record.page_id
        $slotText = [string]$record.slot_id
        if ([string]::IsNullOrWhiteSpace($pageIdText) -or [string]::IsNullOrWhiteSpace($slotText)) {
            continue
        }

        $pageParts = $pageIdText.Split(":")
        if ($pageParts.Count -ne 2) {
            continue
        }

        $fileId = [Convert]::ToInt32($pageParts[0], 16)
        $pageId = [Convert]::ToInt32($pageParts[1], 16)
        $slotId = [int]$slotText

        $rowData = Get-RowByPhysicalLocation `
            -Database $OfflineDatabaseName `
            -SchemaName $mhParts.SchemaName `
            -TableName $mhParts.TableName `
            -FileId $fileId `
            -PageId $pageId `
            -SlotId $slotId `
            -Metadata $mhMetadata

        $op = ([string]$record.operation_name).ToUpperInvariant()
        $dmlAction = switch ($op) {
            "LOP_INSERT_ROWS" { "INSERT" }
            "LOP_DELETE_ROWS" { "DELETE" }
            default { "UPDATE" }
        }
        $trnLines.Add("--$dmlAction ($($record.current_lsn))")
        $trnLines.Add("-- tx=$($record.transaction_id); commit_utc=$commitText; op=$($record.operation_name)")
        if ($op -in @("LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS")) {
            if ($null -eq $rowData) {
                $trnLines.Add("-- Could not resolve current row by page/slot; using template fallback.")
                $trnLines.Add([string]$record.reconstructed_sql_template)
                $trnLines.Add("GO")
                $trnLines.Add("")
                $statementCount++
                continue
            }

            $changedColumns = @(Get-UpdatedColumns `
                -Database $OfflineDatabaseName `
                -RowData $rowData `
                -Metadata $mhMetadata `
                -RowLogOldHex ([string]$record.rowlog0_hex) `
                -RowLogNewHex ([string]$record.rowlog1_hex))

            if (-not $changedColumns -or $changedColumns.Count -eq 0) {
                $trnLines.Add("-- Could not decode updated columns from rowlog payload; using template fallback.")
                $trnLines.Add([string]$record.reconstructed_sql_template)
                $trnLines.Add("GO")
                $trnLines.Add("")
                $statementCount++
                continue
            }

            $setClauses = @()
            foreach ($chg in ($changedColumns | Sort-Object column_name)) {
                $colName = $chg.column_name.Replace("]", "]]")
                $setClauses += "[$colName] = $($chg.new_sql)"
            }

            $whereClauses = @()
            foreach ($pk in $whereKeyColumns) {
                $pkCol = $pk.column_name
                if (-not $rowData.Table.Columns.Contains($pkCol)) {
                    continue
                }
                $pkName = $pkCol.Replace("]", "]]")
                $pkValue = $rowData[$pkCol]
                $whereClauses += "[$pkName] = $(Convert-TypedValueToSqlLiteral -Value $pkValue -Column $pk)"
            }

            if ($whereClauses.Count -eq 0) {
                $trnLines.Add("-- Could not construct PK WHERE clause; using template fallback.")
                $trnLines.Add([string]$record.reconstructed_sql_template)
                $trnLines.Add("GO")
                $trnLines.Add("")
                $statementCount++
                continue
            }

            foreach ($chg in ($changedColumns | Sort-Object column_name)) {
                $trnLines.Add("-- changed: [$($chg.column_name)] $($chg.old_sql) -> $($chg.new_sql)")
            }
            $trnLines.Add("UPDATE [$($mhParts.SchemaName)].[$($mhParts.TableName)] SET $($setClauses -join ', ') WHERE $($whereClauses -join ' AND ');")
            $trnLines.Add("GO")
            $trnLines.Add("")
            $statementCount++
            continue
        }

        if ($op -eq "LOP_INSERT_ROWS" -and $null -ne $rowData) {
            $insertCols = @()
            $insertVals = @()
            foreach ($col in $mhMetadata) {
                $colName = $col.column_name
                if (-not $rowData.Table.Columns.Contains($colName)) {
                    continue
                }
                $value = $rowData[$colName]
                if ($value -is [System.DBNull]) {
                    continue
                }
                $insertCols += "[" + $colName.Replace("]", "]]") + "]"
                $insertVals += (Convert-TypedValueToSqlLiteral -Value $value -Column $col)
            }

            if ($insertCols.Count -gt 0) {
                $trnLines.Add("INSERT INTO [$($mhParts.SchemaName)].[$($mhParts.TableName)] ($($insertCols -join ', ')) VALUES ($($insertVals -join ', '));")
            } else {
                $trnLines.Add([string]$record.reconstructed_sql_template)
            }
            $trnLines.Add("GO")
            $trnLines.Add("")
            $statementCount++
            continue
        }

        if ($op -eq "LOP_DELETE_ROWS" -and $null -ne $rowData) {
            $whereClauses = @()
            foreach ($pk in $whereKeyColumns) {
                $pkCol = $pk.column_name
                if (-not $rowData.Table.Columns.Contains($pkCol)) {
                    continue
                }
                $pkName = $pkCol.Replace("]", "]]")
                $pkValue = $rowData[$pkCol]
                $whereClauses += "[$pkName] = $(Convert-TypedValueToSqlLiteral -Value $pkValue -Column $pk)"
            }

            if ($whereClauses.Count -gt 0) {
                $trnLines.Add("DELETE FROM [$($mhParts.SchemaName)].[$($mhParts.TableName)] WHERE $($whereClauses -join ' AND ');")
            } else {
                $trnLines.Add([string]$record.reconstructed_sql_template)
            }
            $trnLines.Add("GO")
            $trnLines.Add("")
            $statementCount++
            continue
        }

        $trnLines.Add([string]$record.reconstructed_sql_template)
        $trnLines.Add("GO")
        $trnLines.Add("")
        $statementCount++
    }

    if ($clusteredRecords.Count -eq 0) {
        $trnLines.Add("-- No matching committed INSERT/UPDATE/DELETE records in requested window.")
    }

    $mhTrnDir = Split-Path -Parent $MhTrnPath
    if ($mhTrnDir -and -not (Test-Path -LiteralPath $mhTrnDir)) {
        New-Item -ItemType Directory -Path $mhTrnDir | Out-Null
    }
    $trnLines | Set-Content -LiteralPath $MhTrnPath -Encoding ASCII
    Write-Host ("Wrote {0} reconstructed statements to {1}" -f $statementCount, (Resolve-Path -LiteralPath $MhTrnPath))

    if (-not $UseAttachedDatabase) {
        Write-Host "Step 6/8: Detaching $OfflineDatabaseName"
        $detachSql = @"
SET NOCOUNT ON;
IF DB_ID(N'$escapedDb') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    EXEC sp_detach_db @dbname=N'$escapedDb';
END;
"@
        Invoke-SqlNonQuery -Database "master" -Sql $detachSql
        $dbAttached = $false

        Write-Host "Step 7/8: Deleting symbolic link $LinkPath"
        Remove-LinkPath
        $linkCreated = $false

        Write-Host "Step 8/8: Deleting shadow copy $shadowId"
        & vssadmin delete shadows "/Shadow=$shadowId" /Quiet | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete shadow copy $shadowId"
        }

        $shadowId = $null
    }

    if ($stagingRunDir -and (Test-Path -LiteralPath $stagingRunDir)) {
        Remove-Item -LiteralPath $stagingRunDir -Recurse -Force
        $stagingRunDir = $null
    }
    Write-Host "Completed successfully."
}
finally {
    if ($dbAttached) {
        try {
            $escapedDb = $OfflineDatabaseName.Replace("]", "]]")
            Invoke-SqlNonQuery -Database "master" -Sql @"
SET NOCOUNT ON;
IF DB_ID(N'$escapedDb') IS NOT NULL
BEGIN
    ALTER DATABASE [$escapedDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    EXEC sp_detach_db @dbname=N'$escapedDb';
END;
"@
        } catch {
            Write-Warning ("Cleanup detach failed: {0}" -f $_.Exception.Message)
        }
    }

    if ($linkCreated) {
        try {
            Remove-LinkPath
        } catch {
            Write-Warning ("Cleanup link removal failed: {0}" -f $_.Exception.Message)
        }
    }

    if ($shadowId) {
        try {
            & vssadmin delete shadows "/Shadow=$shadowId" /Quiet | Out-Null
        } catch {
            Write-Warning ("Cleanup shadow deletion failed: {0}" -f $_.Exception.Message)
        }
    }

    if ($collectorTempPath -and (Test-Path -LiteralPath $collectorTempPath)) {
        try {
            Remove-Item -LiteralPath $collectorTempPath -Force
        } catch {
            Write-Warning ("Cleanup temporary collector file failed: {0}" -f $_.Exception.Message)
        }
    }

    if ($stagingRunDir -and (Test-Path -LiteralPath $stagingRunDir)) {
        try {
            Remove-Item -LiteralPath $stagingRunDir -Recurse -Force
        } catch {
            Write-Warning ("Cleanup staging directory failed: {0}" -f $_.Exception.Message)
        }
    }
}
