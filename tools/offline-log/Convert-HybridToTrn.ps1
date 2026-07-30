param(
    [Parameter()]
    [string]$ManifestPath = ".\output\live-dml-manifest.json",

    [Parameter()]
    [string]$HybridPath = ".\output\raw-ldf-hybrid-matches.json",

    [Parameter()]
    [string]$OutputPath = ".\output\mh.trn",

    [Parameter()]
    [string]$TargetTable = "oasis.CHSC_POLINE",

    [Parameter()]
    [string]$ServerInstance,

    [Parameter()]
    [string]$Database,

    [Parameter()]
    [string]$MetadataServerInstance,

    [Parameter()]
    [string]$MetadataDatabase,

    [Parameter()]
    [string]$MetadataSnapshotPath,

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
[string]$SqlPassword
,
    [Parameter()]
    [bool]$OutputSuccessfulOnly = $false,

    [Parameter()]
    [string]$UnresolvedOutputPath
,
    [Parameter()]
    [string]$QuarantineOutputPath
,
    [Parameter()]
    [ValidateSet("update", "replace", "adaptive")]
    [string]$UpdateMode = "adaptive",

    [Parameter()]
    [ValidateSet("off", "strict")]
    [string]$ApplySafetyMode = "strict",

    [Parameter()]
    [bool]$GenerateUndo = $true,

    [Parameter()]
    [string]$UndoOutputPath = ".\output\mh.undo.trn",

    [Parameter()]
    [bool]$ExportBeforeAfter = $true,

    [Parameter()]
    [string]$BeforeAfterJsonPath = ".\output\mh.before_after.json"
,
    [Parameter()]
    [bool]$ExportRowHistory = $true,

    [Parameter()]
    [string]$RowHistoryJsonPath = ".\output\mh.row_history.json"
,
    [Parameter()]
    [ValidateSet("full", "fast")]
    [string]$HeuristicsProfile = "full",

    [Parameter()]
    [int]$MaxRowLogPairs = 0,

    [Parameter()]
    [bool]$DisableDecode = $false,

    [Parameter()]
    [bool]$UseLegacyByteOps = $false,

    [Parameter()]
    [bool]$AdaptiveFastReplaceNonHighConfidence = $false,

    [Parameter()]
    [string]$PhaseTimingOutputPath,

    [Parameter()]
    [string]$OfflineRowObjectCachePath,

    [Parameter()]
    [bool]$DisableLiveRowLookup = $false,

    [Parameter()]
    [bool]$OfflineAllowKeyPatch = $false
,
    [Parameter()]
    [bool]$EnableOfflineKeyMatchFallback = $true,

    [Parameter()]
    [bool]$LiveLookupIncludeBinaryPayload = $true,

    [Parameter()]
    [bool]$EnableLiveKeyPrefetch = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptStartWatch = [System.Diagnostics.Stopwatch]::StartNew()

$phaseTiming = [ordered]@{
    total_ms = 0
    row_resolve_ms = 0
    row_lookup_live_reads = 0
    row_lookup_cache_hits = 0
    pair_build_ms = 0
    heuristic_decode_ms = 0
    sql_render_ms = 0
    file_write_ms = 0
    events_total = 0
    events_update = 0
    events_insert = 0
    events_delete = 0
}

$phaseTimingByAction = @{
    "INSERT" = [ordered]@{
        events = 0
        resolved = 0
        unresolved = 0
        total_ms = 0
        row_resolve_ms = 0
        heuristic_decode_ms = 0
        sql_render_ms = 0
    }
    "UPDATE" = [ordered]@{
        events = 0
        resolved = 0
        unresolved = 0
        total_ms = 0
        row_resolve_ms = 0
        heuristic_decode_ms = 0
        sql_render_ms = 0
    }
    "DELETE" = [ordered]@{
        events = 0
        resolved = 0
        unresolved = 0
        total_ms = 0
        row_resolve_ms = 0
        heuristic_decode_ms = 0
        sql_render_ms = 0
    }
}

if (-not ("HybridPerfHelpers" -as [type])) {
Add-Type -TypeDefinition @"
using System;

public static class HybridPerfHelpers
{
    public static byte[] HexToBytes(string hex)
    {
        if (hex == null) throw new ArgumentNullException("hex");
        string s = hex.Trim();
        if (s.StartsWith("0x", StringComparison.OrdinalIgnoreCase)) s = s.Substring(2);
        if ((s.Length % 2) != 0) throw new ArgumentException("Hex string must have even length.", "hex");
        var bytes = new byte[s.Length / 2];
        for (int i = 0; i < s.Length; i += 2)
        {
            int hi = ParseNibble(s[i]);
            int lo = ParseNibble(s[i + 1]);
            bytes[i / 2] = (byte)((hi << 4) | lo);
        }
        return bytes;
    }

    public static int IndexOfSubArray(byte[] haystack, byte[] needle, int startAt)
    {
        if (haystack == null) throw new ArgumentNullException("haystack");
        if (needle == null) throw new ArgumentNullException("needle");
        if (needle.Length == 0) return -1;
        if (startAt < 0) startAt = 0;
        if (haystack.Length < needle.Length || startAt > haystack.Length - needle.Length) return -1;

        int max = haystack.Length - needle.Length;
        byte first = needle[0];
        for (int i = startAt; i <= max; i++)
        {
            if (haystack[i] != first) continue;
            int j = 1;
            for (; j < needle.Length; j++)
            {
                if (haystack[i + j] != needle[j]) break;
            }
            if (j == needle.Length) return i;
        }
        return -1;
    }

    private static int ParseNibble(char c)
    {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        throw new FormatException("Invalid hex character: " + c);
    }
}
"@
}

# Performance caches used to reduce repeated decode round-trips.
$script:TypedCastCache = @{}
$script:RowByPhysCache = @{}
$script:RowByKeyCache = @{}
$script:HexBytesCache = @{}
$script:RowByPhysLiveReadCount = 0
$script:RowByPhysCacheHitCount = 0
$script:TypedCastCacheMaxEntries = 200000
$script:RowByPhysCacheMaxEntries = 200000
$script:RowByKeyCacheMaxEntries = 200000
$script:HexBytesCacheMaxEntries = 50000
$script:OfflineRowsByManifestKey = @{}
$script:OfflineRowsByPhysKey = @{}
$script:OfflineRowsAll = @()
$script:OfflineKeyIndexCache = @{}
$script:DecodedWhereKeyCache = @{}
$script:QuoteDbidByQuoteIdCache = @{}
$script:PoDbidByPoidCache = @{}
$script:PoLineDbidByPoidCache = @{}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest file not found: $ManifestPath"
}

if (-not (Test-Path -LiteralPath $HybridPath)) {
    throw "Hybrid match file not found: $HybridPath"
}

if ($TargetTable -notmatch "^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$") {
    throw "TargetTable must be schema.table."
}

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

$tt = $TargetTable.Split(".")
$targetSchema = $tt[0]
$targetName = $tt[1]

$manifest = (Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
$hybrid = (Get-Content -LiteralPath $HybridPath -Raw | ConvertFrom-Json)

if (-not $ServerInstance) {
    if ($manifest.PSObject.Properties.Name -contains "server_instance") {
        $ServerInstance = [string]$manifest.server_instance
    }
}
if (-not $Database) {
    if ($manifest.PSObject.Properties.Name -contains "database") {
        $Database = [string]$manifest.database
    }
}
if (-not $MetadataServerInstance) {
    $MetadataServerInstance = $ServerInstance
}
if (-not $MetadataDatabase) {
    $MetadataDatabase = $Database
}

$snapshotColumnsByTable = @{}
$snapshotIndexesByTable = @{}
if (-not [string]::IsNullOrWhiteSpace($MetadataSnapshotPath)) {
    if (-not (Test-Path -LiteralPath $MetadataSnapshotPath)) {
        throw "MetadataSnapshotPath not found: $MetadataSnapshotPath"
    }
    $snapshotObj = Get-Content -LiteralPath $MetadataSnapshotPath -Raw | ConvertFrom-Json
    foreach ($t in @($snapshotObj.tables)) {
        $schemaName = [string]$t.schema_name
        $tableName = [string]$t.table_name
        if ([string]::IsNullOrWhiteSpace($schemaName) -or [string]::IsNullOrWhiteSpace($tableName)) { continue }
        $k = ("{0}.{1}" -f $schemaName, $tableName).ToUpperInvariant()
        $snapshotColumnsByTable[$k] = @($t.columns)
        $snapshotIndexesByTable[$k] = @($t.indexes)
    }
}

if (-not [string]::IsNullOrWhiteSpace($OfflineRowObjectCachePath)) {
    if (-not (Test-Path -LiteralPath $OfflineRowObjectCachePath)) {
        throw "OfflineRowObjectCachePath not found: $OfflineRowObjectCachePath"
    }

    $offlineObj = Get-Content -LiteralPath $OfflineRowObjectCachePath -Raw | ConvertFrom-Json
    foreach ($r in @($offlineObj.rows)) {
        $script:OfflineRowsAll += $r
        $mk = ""
        if ($r.PSObject.Properties.Name -contains "manifest_key" -and $null -ne $r.manifest_key) {
            $mk = ([string]$r.manifest_key).ToUpperInvariant()
        }
        if (-not [string]::IsNullOrWhiteSpace($mk)) {
            $script:OfflineRowsByManifestKey[$mk] = $r
        }

        $fileId = if ($r.PSObject.Properties.Name -contains "file_id") { $r.file_id } else { $null }
        $pageIdDec = if ($r.PSObject.Properties.Name -contains "page_id_dec") { $r.page_id_dec } else { $null }
        $slotId = if ($r.PSObject.Properties.Name -contains "slot_id") { $r.slot_id } else { $null }
        if ($null -ne $fileId -and $null -ne $pageIdDec -and $null -ne $slotId) {
            $pk = ("{0}:{1}:{2}" -f [int]$fileId, [int]$pageIdDec, [int]$slotId)
            $script:OfflineRowsByPhysKey[$pk] = $r
        }
    }
}

function Parse-CommitTime {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
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
    foreach ($f in $formats) {
        $d = [datetime]::MinValue
        if ([datetime]::TryParseExact($Text, $f, $culture, $styles, [ref]$d)) {
            return $d
        }
    }
    $x = [datetime]::MinValue
    if ([datetime]::TryParse($Text, [ref]$x)) {
        return $x
    }
    return $null
}

function Get-PropertyValue {
    param(
        [psobject]$Object,
        [string]$Name
    )
    if ($null -eq $Object) { return $null }
    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $null
}

function New-ConnectionString {
    param(
        [string]$DataSource,
        [string]$InitialCatalog
    )
    if (-not $DataSource -or -not $InitialCatalog) {
        return $null
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $DataSource
    $builder["Initial Catalog"] = $InitialCatalog
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

function Invoke-SqlQuery {
    param([string]$Sql)
    $connStr = New-ConnectionString -DataSource $ServerInstance -InitialCatalog $Database
    if (-not $connStr) {
        throw "ServerInstance/Database are required for decode mode."
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection($connStr)
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

function Invoke-MetadataSqlQuery {
    param([string]$Sql)
    $connStr = New-ConnectionString -DataSource $MetadataServerInstance -InitialCatalog $MetadataDatabase
    if (-not $connStr) {
        throw "MetadataServerInstance/MetadataDatabase are required for metadata mode."
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection($connStr)
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

function Supports-BinaryDecodeType {
    param([string]$DataType)
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
    param([pscustomobject]$Column)
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
        [string]$SchemaName,
        [string]$TableName
    )

    $k = ("{0}.{1}" -f $SchemaName, $TableName).ToUpperInvariant()
    if ($snapshotColumnsByTable.ContainsKey($k)) {
        return @($snapshotColumnsByTable[$k] | ForEach-Object {
            [pscustomobject]@{
                column_id   = [int]$_.column_id
                column_name = [string]$_.column_name
                data_type   = [string]$_.data_type
                max_length  = [int]$_.max_length
                precision   = [int]$_.precision
                scale       = [int]$_.scale
                is_nullable = [bool]$_.is_nullable
                is_pk       = if ($_.PSObject.Properties.Name -contains "is_pk") { [bool]$_.is_pk } else { $false }
                pk_ordinal  = if ($_.PSObject.Properties.Name -contains "pk_ordinal") { [int]$_.pk_ordinal } else { 0 }
            }
        })
    }

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
    $dt = Invoke-MetadataSqlQuery -Sql $sql
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
        [string]$SchemaName,
        [string]$TableName
    )
    $k = ("{0}.{1}" -f $SchemaName, $TableName).ToUpperInvariant()
    if ($snapshotIndexesByTable.ContainsKey($k)) {
        return @($snapshotIndexesByTable[$k] | ForEach-Object {
            [pscustomobject]@{
                index_name     = [string]$_.index_name
                is_primary_key = [bool]$_.is_primary_key
                is_unique      = [bool]$_.is_unique
                key_ordinal    = [int]$_.key_ordinal
                is_included_column = if ($_.PSObject.Properties.Name -contains "is_included_column") { [bool]$_.is_included_column } else { $false }
                column_name    = [string]$_.column_name
            }
        })
    }

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
    $dt = Invoke-MetadataSqlQuery -Sql $sql
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

function Resolve-WhereKeyColumns {
    param(
        [pscustomobject[]]$Metadata,
        [pscustomobject[]]$Indexes
    )

    $pkColumns = @($Metadata | Where-Object { $_.is_pk } | Sort-Object pk_ordinal)
    if ($pkColumns.Count -gt 0) {
        return [pscustomobject]@{
            label = "primary_key"
            columns = $pkColumns
        }
    }

    $candidateIndexes = @($Indexes | Where-Object { $_.key_ordinal -gt 0 -and -not $_.is_included_column })
    $groups = @($candidateIndexes | Group-Object index_name | ForEach-Object {
        $keys = @($_.Group | Sort-Object key_ordinal)
        $keyNames = @($keys | ForEach-Object { ([string]$_.column_name).ToUpperInvariant() })
        $isPk = @($keys | Where-Object { $_.is_primary_key }).Count -gt 0
        $isUnique = @($keys | Where-Object { $_.is_unique }).Count -gt 0

        $score = 0
        if ($isPk) { $score += 1200 }
        if ($isUnique) { $score += 300 }

        function _SeqEq([string[]]$a, [string[]]$b) {
            if ($a.Count -ne $b.Count) { return $false }
            for ($i = 0; $i -lt $a.Count; $i++) {
                if ($a[$i] -ne $b[$i]) { return $false }
            }
            return $true
        }
        function _ContainsAll([string[]]$a, [string[]]$b) {
            foreach ($x in $b) {
                if (-not ($a -contains $x)) { return $false }
            }
            return $true
        }

        $patterns = @(
            @{ exact = @("DBID", "POID", "LINENUMBER", "REVISION"); exact_score = 900; contain_score = 700 },
            @{ exact = @("DBID", "POID", "LINENUMBER"); exact_score = 880; contain_score = 680 },
            @{ exact = @("DBID", "QUOTEID", "LINENUMBER"); exact_score = 860; contain_score = 660 },
            @{ exact = @("DBID", "PROJECTID"); exact_score = 840; contain_score = 640 },
            @{ exact = @("DBID", "QUOTEID"); exact_score = 820; contain_score = 620 },
            @{ exact = @("DBID", "POID"); exact_score = 800; contain_score = 600 }
        )
        foreach ($p in $patterns) {
            if (_SeqEq $keyNames $p.exact) {
                $score += [int]$p.exact_score
                break
            }
            if (_ContainsAll $keyNames $p.exact) {
                $score += [int]$p.contain_score
                break
            }
        }

        if ($keyNames -contains "DBID") { $score += 100 }
        if ($keyNames.Count -gt 0) { $score += [Math]::Max(0, 20 - $keyNames.Count) }

        [pscustomobject]@{
            index_name = [string]$_.Name
            key_count = $keys.Count
            keys = $keys
            score = $score
        }
    } | Sort-Object @{ Expression = { $_.score }; Descending = $true }, @{ Expression = { $_.key_count } }, @{ Expression = { $_.index_name } })

    if ($groups.Count -eq 0) {
        $byName = @{}
        foreach ($c in @($Metadata)) {
            $n = ([string]$c.column_name).ToUpperInvariant()
            if (-not [string]::IsNullOrWhiteSpace($n)) {
                $byName[$n] = $c
            }
        }

        $preferredSets = @(
            @("DBID", "POID", "LINENUMBER", "REVISION"),
            @("DBID", "POID", "LINENUMBER"),
            @("DBID", "QUOTEID", "LINENUMBER"),
            @("DBID", "QUOTEID"),
            @("DBID", "PROJECTID"),
            @("DBID", "POID"),
            @("DBID", "ID")
        )

        foreach ($set in $preferredSets) {
            $allFound = $true
            $resolved = @()
            foreach ($name in $set) {
                if (-not $byName.ContainsKey($name)) {
                    $allFound = $false
                    break
                }
                $resolved += $byName[$name]
            }
            if ($allFound -and $resolved.Count -gt 0) {
                return [pscustomobject]@{
                    label = "heuristic:" + ($set -join "+")
                    columns = $resolved
                }
            }
        }

        $idLike = @($Metadata | Where-Object {
            ($_.is_nullable -eq $false) -and (
                ([string]$_.column_name).ToUpperInvariant().EndsWith("ID") -or
                ([string]$_.column_name).ToUpperInvariant() -eq "LINENUMBER" -or
                ([string]$_.column_name).ToUpperInvariant() -eq "REVISION"
            )
        })
        if ($idLike.Count -gt 0 -and $idLike.Count -le 4) {
            return [pscustomobject]@{
                label = "heuristic:id_like"
                columns = @($idLike | Sort-Object column_id)
            }
        }

        return [pscustomobject]@{
            label = "none"
            columns = @()
        }
    }

    $selected = $groups[0]
    $resolved = @()
    foreach ($k in $selected.keys) {
        $col = $Metadata | Where-Object { $_.column_name -eq $k.column_name } | Select-Object -First 1
        if ($col) { $resolved += $col }
    }

    return [pscustomobject]@{
        label = "index:$($selected.index_name)"
        columns = $resolved
    }
}

function Convert-HexToBytes {
    param([AllowNull()][string]$Hex)
    if ([string]::IsNullOrWhiteSpace($Hex)) { return ,([byte[]]@()) }
    $clean = $Hex.Trim()
    if ($clean.StartsWith("0x")) { $clean = $clean.Substring(2) }
    if ($clean.Length -eq 0) { return ,([byte[]]@()) }
    if (($clean.Length % 2) -ne 0) { throw "Invalid hex length: $Hex" }
    if ($UseLegacyByteOps) {
        $bytes = New-Object byte[] ($clean.Length / 2)
        for ($i = 0; $i -lt $clean.Length; $i += 2) {
            $bytes[$i / 2] = [Convert]::ToByte($clean.Substring($i, 2), 16)
        }
        return ,$bytes
    }
    $key = $clean.ToUpperInvariant()
    if ($script:HexBytesCache.ContainsKey($key)) {
        return ,([byte[]]$script:HexBytesCache[$key])
    }
    $bytes = [HybridPerfHelpers]::HexToBytes($clean)
    if ($script:HexBytesCache.Count -ge $script:HexBytesCacheMaxEntries) { $script:HexBytesCache.Clear() }
    $script:HexBytesCache[$key] = $bytes
    return ,$bytes
}

function Convert-HexPrefixToBytes {
    param(
        [AllowNull()][string]$Hex,
        [int]$MaxBytes = 256
    )
    if ([string]::IsNullOrWhiteSpace($Hex)) { return @() }
    if ($MaxBytes -le 0) { return @() }
    $h = $Hex.Trim()
    if ($h.StartsWith("0x", [System.StringComparison]::OrdinalIgnoreCase)) {
        $h = $h.Substring(2)
    }
    if ([string]::IsNullOrWhiteSpace($h)) { return @() }
    $maxHexChars = [Math]::Min($h.Length, $MaxBytes * 2)
    if ($maxHexChars -lt 2) { return @() }
    if (($maxHexChars % 2) -ne 0) { $maxHexChars-- }
    if ($maxHexChars -lt 2) { return @() }
    $prefix = $h.Substring(0, $maxHexChars)
    try {
        return [HybridPerfHelpers]::HexToBytes($prefix)
    } catch {
        return @()
    }
}

function Find-SubArrayIndex {
    param(
        [byte[]]$Haystack,
        [byte[]]$Needle,
        [int]$StartAt = 0
    )
    if ($null -eq $Needle -or $null -eq $Haystack) { return -1 }
    if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) { return -1 }
    if (-not $UseLegacyByteOps) {
        return [HybridPerfHelpers]::IndexOfSubArray($Haystack, $Needle, $StartAt)
    }
    for ($i = $StartAt; $i -le ($Haystack.Length - $Needle.Length); $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) {
                $match = $false
                break
            }
        }
        if ($match) { return $i }
    }
    return -1
}

function Bytes-ToHexLiteral {
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return "0x" }
    return "0x" + [System.BitConverter]::ToString($Bytes).Replace("-", "")
}

function Convert-TypedValueToSqlLiteral {
    param(
        [AllowNull()][object]$Value,
        [pscustomobject]$Column
    )
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return "NULL" }
    $type = $Column.data_type.ToLowerInvariant()
    switch ($type) {
        "char" { return "'" + ([string]$Value).Replace("'", "''") + "'" }
        "varchar" { return "'" + ([string]$Value).Replace("'", "''") + "'" }
        "nchar" { return "N'" + ([string]$Value).Replace("'", "''") + "'" }
        "nvarchar" { return "N'" + ([string]$Value).Replace("'", "''") + "'" }
        "date" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd") + "'" }
        "time" { return "'" + ([datetime]$Value).ToString("HH:mm:ss.fffffff") + "'" }
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
        "decimal" {
            try {
                return ([decimal]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                $s = [string]$Value
                if ($s -match '^-?[0-9]+(\.[0-9]+)?$') { return $s }
                return "'" + $s.Replace("'","''") + "'"
            }
        }
        "numeric" {
            try {
                return ([decimal]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                $s = [string]$Value
                if ($s -match '^-?[0-9]+(\.[0-9]+)?$') { return $s }
                return "'" + $s.Replace("'","''") + "'"
            }
        }
        "money" { return ([decimal]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "smallmoney" { return ([decimal]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        "uniqueidentifier" { return "'" + [string]$Value + "'" }
        "binary" {
            if ($Value -is [byte[]]) { return Bytes-ToHexLiteral -Bytes $Value }
            return [string]$Value
        }
        "varbinary" {
            if ($Value -is [byte[]]) { return Bytes-ToHexLiteral -Bytes $Value }
            return [string]$Value
        }
        default { return "'" + ([string]$Value).Replace("'", "''") + "'" }
    }
}

function Convert-HexLiteralToTypedValue {
    param(
        [string]$HexLiteral,
        [pscustomobject]$Column
    )
    if ([string]::IsNullOrWhiteSpace($HexLiteral) -or $HexLiteral -eq "0x") { return $null }
    $typeSpec = Get-SqlTypeSpec -Column $Column
    $cacheKey = ("{0}|{1}" -f $typeSpec, $HexLiteral.ToUpperInvariant())
    if ($script:TypedCastCache.ContainsKey($cacheKey)) {
        return $script:TypedCastCache[$cacheKey]
    }
    $sql = "SELECT CAST($HexLiteral AS $typeSpec) AS value;"
    $dt = Invoke-SqlQuery -Sql $sql
    if ($dt.Rows.Count -eq 0) {
        if ($script:TypedCastCache.Count -ge $script:TypedCastCacheMaxEntries) { $script:TypedCastCache.Clear() }
        $script:TypedCastCache[$cacheKey] = $null
        return $null
    }
    $v = $dt.Rows[0]["value"]
    if ($v -is [System.DBNull]) {
        if ($script:TypedCastCache.Count -ge $script:TypedCastCacheMaxEntries) { $script:TypedCastCache.Clear() }
        $script:TypedCastCache[$cacheKey] = $null
        return $null
    }
    if ($script:TypedCastCache.Count -ge $script:TypedCastCacheMaxEntries) { $script:TypedCastCache.Clear() }
    $script:TypedCastCache[$cacheKey] = $v
    return $v
}

function Resolve-PhysicalLocation {
    param([psobject]$ManifestRow)
    $pageText = [string](Get-PropertyValue -Object $ManifestRow -Name "page_id")
    if ([string]::IsNullOrWhiteSpace($pageText)) { return $null }
    $parts = $pageText.Split(":")
    if ($parts.Count -ne 2) { return $null }
    $slotRaw = Get-PropertyValue -Object $ManifestRow -Name "slot_id"
    if ($null -eq $slotRaw -or $slotRaw -is [System.DBNull]) { return $null }

    try {
        $fileId = [Convert]::ToInt32($parts[0], 16)
        $pageId = [Convert]::ToInt32($parts[1], 16)
        $slotId = [int]$slotRaw
        return [pscustomobject]@{
            file_id = $fileId
            page_id = $pageId
            slot_id = $slotId
        }
    } catch {
        return $null
    }
}

function Convert-ObjectToDataRow {
    param(
        [psobject]$ValuesObject,
        [pscustomobject[]]$Metadata
    )

    if ($null -eq $ValuesObject -or $null -eq $Metadata -or $Metadata.Count -eq 0) {
        return $null
    }

    $dt = New-Object System.Data.DataTable
    foreach ($col in $Metadata) {
        [void]$dt.Columns.Add([string]$col.column_name, [object])
    }

    $row = $dt.NewRow()
    foreach ($col in $Metadata) {
        $cn = [string]$col.column_name
        if ($ValuesObject.PSObject.Properties.Name -contains $cn) {
            $v = $ValuesObject.$cn
            if ($null -eq $v) {
                $row[$cn] = [System.DBNull]::Value
            } else {
                $row[$cn] = $v
            }
        } else {
            $row[$cn] = [System.DBNull]::Value
        }
    }
    [void]$dt.Rows.Add($row)
    return $dt.Rows[0]
}

function Get-OfflineRowDataForManifestRow {
    param(
        [psobject]$ManifestRow,
        [pscustomobject[]]$Metadata
    )

    if ($script:OfflineRowsByManifestKey.Count -eq 0 -and $script:OfflineRowsByPhysKey.Count -eq 0) {
        return $null
    }
    if ($null -eq $ManifestRow) { return $null }

    $mk = ([string](Get-PropertyValue -Object $ManifestRow -Name "manifest_key")).ToUpperInvariant()
    if (-not [string]::IsNullOrWhiteSpace($mk) -and $script:OfflineRowsByManifestKey.ContainsKey($mk)) {
        $rec = $script:OfflineRowsByManifestKey[$mk]
        if ($rec.PSObject.Properties.Name -contains "values") {
            $row = Convert-ObjectToDataRow -ValuesObject $rec.values -Metadata $Metadata
            if ($row -ne $null) { return $row }
        }
    }

    $phys = Resolve-PhysicalLocation -ManifestRow $ManifestRow
    if ($null -eq $phys) { return $null }
    $pk = ("{0}:{1}:{2}" -f [int]$phys.file_id, [int]$phys.page_id, [int]$phys.slot_id)
    if ($script:OfflineRowsByPhysKey.ContainsKey($pk)) {
        $rec = $script:OfflineRowsByPhysKey[$pk]
        if ($rec.PSObject.Properties.Name -contains "values") {
            return (Convert-ObjectToDataRow -ValuesObject $rec.values -Metadata $Metadata)
        }
    }
    return $null
}

function Get-OfflineRowDataByDecodedKey {
    param(
        [psobject]$DecodedKey,
        [pscustomobject[]]$Metadata
    )

    if ($null -eq $DecodedKey) { return $null }
    if ($null -eq $Metadata -or $Metadata.Count -eq 0) { return $null }
    if ($null -eq $script:OfflineRowsAll -or $script:OfflineRowsAll.Count -eq 0) { return $null }

    $keyNames = @($DecodedKey.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object)
    if ($keyNames.Count -eq 0) { return $null }
    $indexKey = ($keyNames -join "|").ToUpperInvariant()

    if (-not $script:OfflineKeyIndexCache.ContainsKey($indexKey)) {
        $metaByName = @{}
        foreach ($m in $Metadata) {
            $metaByName[[string]$m.column_name.ToUpperInvariant()] = $m
        }
        $idx = @{}
        foreach ($rec in @($script:OfflineRowsAll)) {
            if ($null -eq $rec) { continue }
            if (-not ($rec.PSObject.Properties.Name -contains "values")) { continue }
            $vals = $rec.values
            if ($null -eq $vals) { continue }

            $parts = New-Object System.Collections.Generic.List[string]
            $ok = $true
            foreach ($kn in $keyNames) {
                $p = $vals.PSObject.Properties | Where-Object { ([string]$_.Name).Equals($kn, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
                if ($null -eq $p) { $ok = $false; break }
                $metaCol = $null
                $mk = $kn.ToUpperInvariant()
                if ($metaByName.ContainsKey($mk)) { $metaCol = $metaByName[$mk] }
                $v = $p.Value
                $lit = if ($null -eq $v) { "NULL" } elseif ($null -ne $metaCol) { Convert-TypedValueToSqlLiteral -Value $v -Column $metaCol } else { [string]$v }
                $parts.Add(("{0}={1}" -f $mk, $lit)) | Out-Null
            }
            if (-not $ok) { continue }
            $sig = ($parts -join ";")
            if (-not $idx.ContainsKey($sig)) {
                $idx[$sig] = $rec
            }
        }
        $script:OfflineKeyIndexCache[$indexKey] = $idx
    }

    $lookupParts = New-Object System.Collections.Generic.List[string]
    $metaByName2 = @{}
    foreach ($m in $Metadata) {
        $metaByName2[[string]$m.column_name.ToUpperInvariant()] = $m
    }
    foreach ($kn in $keyNames) {
        $kp = $DecodedKey.PSObject.Properties | Where-Object { ([string]$_.Name).Equals($kn, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($null -eq $kp) { return $null }
        $mk = $kn.ToUpperInvariant()
        $metaCol = $null
        if ($metaByName2.ContainsKey($mk)) { $metaCol = $metaByName2[$mk] }
        $v = $kp.Value
        $lit = if ($null -eq $v) { "NULL" } elseif ($null -ne $metaCol) { Convert-TypedValueToSqlLiteral -Value $v -Column $metaCol } else { [string]$v }
        $lookupParts.Add(("{0}={1}" -f $mk, $lit)) | Out-Null
    }
    $lookupSig = ($lookupParts -join ";")
    $index = $script:OfflineKeyIndexCache[$indexKey]
    if ($index.ContainsKey($lookupSig)) {
        $rec = $index[$lookupSig]
        if ($rec -and $rec.PSObject.Properties.Name -contains "values") {
            return (Convert-ObjectToDataRow -ValuesObject $rec.values -Metadata $Metadata)
        }
    }
    return $null
}

function Get-RowByPhysicalLocation {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [int]$FileId,
        [int]$PageId,
        [int]$SlotId,
        [pscustomobject[]]$Metadata
)
    $rowCacheKey = ("{0}.{1}|{2}:{3}:{4}" -f $SchemaName.ToUpperInvariant(), $TableName.ToUpperInvariant(), $FileId, $PageId, $SlotId)
    if ($script:RowByPhysCache.ContainsKey($rowCacheKey)) {
        $script:RowByPhysCacheHitCount++
        return $script:RowByPhysCache[$rowCacheKey]
    }

    $selectParts = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Metadata) {
        $safeCol = $col.column_name.Replace("]", "]]")
        $selectParts.Add("[$safeCol]")
        if ($LiveLookupIncludeBinaryPayload -and (Supports-BinaryDecodeType -DataType $col.data_type)) {
            $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), [$safeCol])) AS [bin_$safeCol]")
        }
    }
    $safeSchema = $SchemaName.Replace("]", "]]")
    $safeTable = $TableName.Replace("]", "]]")
    $physLoc = "(${FileId}:${PageId}:${SlotId})"
    $sql = @"
SET NOCOUNT ON;
SELECT TOP (1)
    $($selectParts -join ",`n    ")
FROM [$safeSchema].[$safeTable] WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%) = '$physLoc';
"@
    $script:RowByPhysLiveReadCount++
    $dt = Invoke-SqlQuery -Sql $sql
    if ($dt.Rows.Count -eq 0) {
        if ($script:RowByPhysCache.Count -ge $script:RowByPhysCacheMaxEntries) { $script:RowByPhysCache.Clear() }
        $script:RowByPhysCache[$rowCacheKey] = $null
        return $null
    }
    $row = $dt.Rows[0]
    if ($script:RowByPhysCache.Count -ge $script:RowByPhysCacheMaxEntries) { $script:RowByPhysCache.Clear() }
    $script:RowByPhysCache[$rowCacheKey] = $row
    return $row
}

function Get-RowByDecodedKey {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [psobject]$DecodedKey,
        [pscustomobject[]]$Metadata
    )

    if ($null -eq $DecodedKey) { return $null }
    if ($null -eq $Metadata -or $Metadata.Count -eq 0) { return $null }

    # Hot-path specialization for CHSC_QUOTELINE.
    if (
        $SchemaName.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and
        $TableName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase) -and
        ($DecodedKey.PSObject.Properties.Name -contains "DBID") -and
        ($DecodedKey.PSObject.Properties.Name -contains "QUOTEID") -and
        ($DecodedKey.PSObject.Properties.Name -contains "LINENUMBER")
    ) {
        $dbid = [string]$DecodedKey.DBID
        $qid = [int64]$DecodedKey.QUOTEID
        $ln = [int64]$DecodedKey.LINENUMBER
        $keySig = ("DBID='{0}';LINENUMBER={1};QUOTEID={2}" -f $dbid.Replace("'", "''"), $ln, $qid).ToUpperInvariant()
        $rowCacheKey = ("{0}.{1}|{2}" -f $SchemaName.ToUpperInvariant(), $TableName.ToUpperInvariant(), $keySig)
        if ($script:RowByKeyCache.ContainsKey($rowCacheKey)) {
            $script:RowByPhysCacheHitCount++
            return $script:RowByKeyCache[$rowCacheKey]
        }

        $selectParts = New-Object System.Collections.Generic.List[string]
        foreach ($col in $Metadata) {
            $safeCol = $col.column_name.Replace("]", "]]")
            $selectParts.Add("[$safeCol]")
            if ($LiveLookupIncludeBinaryPayload -and (Supports-BinaryDecodeType -DataType $col.data_type)) {
                $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), [$safeCol])) AS [bin_$safeCol]")
            }
        }
        if ($selectParts.Count -eq 0) { return $null }
        $safeDbid = $dbid.Replace("'", "''")
        $safeSchema = $SchemaName.Replace("]", "]]")
        $safeTable = $TableName.Replace("]", "]]")
        $sql = @"
SET NOCOUNT ON;
SELECT TOP (1)
    $($selectParts -join ",`n    ")
FROM [$safeSchema].[$safeTable] WITH (READUNCOMMITTED)
WHERE [DBID] = '$safeDbid' AND [QUOTEID] = $qid AND [LINENUMBER] = $ln;
"@
        $script:RowByPhysLiveReadCount++
        $dt = Invoke-SqlQuery -Sql $sql
        if ($dt.Rows.Count -eq 0) {
            if ($script:RowByKeyCache.Count -ge $script:RowByKeyCacheMaxEntries) { $script:RowByKeyCache.Clear() }
            $script:RowByKeyCache[$rowCacheKey] = $null
            return $null
        }
        $row = $dt.Rows[0]
        if ($script:RowByKeyCache.Count -ge $script:RowByKeyCacheMaxEntries) { $script:RowByKeyCache.Clear() }
        $script:RowByKeyCache[$rowCacheKey] = $row
        return $row
    }

    $metaByName = @{}
    foreach ($col in $Metadata) {
        $metaByName[[string]$col.column_name.ToUpperInvariant()] = $col
    }

    $where = New-Object System.Collections.Generic.List[string]
    $keySigParts = New-Object System.Collections.Generic.List[string]
    foreach ($p in $DecodedKey.PSObject.Properties) {
        $name = [string]$p.Name
        $lookup = $name.ToUpperInvariant()
        if (-not $metaByName.ContainsKey($lookup)) { continue }
        $col = $metaByName[$lookup]
        $lit = Convert-TypedValueToSqlLiteral -Value $p.Value -Column $col
        $safeCol = $name.Replace("]", "]]")
        $where.Add("[$safeCol] = $lit") | Out-Null
        $keySigParts.Add(("{0}={1}" -f $lookup, $lit)) | Out-Null
    }

    if ($where.Count -eq 0) { return $null }
    $keySig = (($keySigParts.ToArray() | Sort-Object) -join ";")
    $rowCacheKey = ("{0}.{1}|{2}" -f $SchemaName.ToUpperInvariant(), $TableName.ToUpperInvariant(), $keySig)
    if ($script:RowByKeyCache.ContainsKey($rowCacheKey)) {
        $script:RowByPhysCacheHitCount++
        return $script:RowByKeyCache[$rowCacheKey]
    }

    $selectParts = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Metadata) {
        $safeCol = $col.column_name.Replace("]", "]]")
        $selectParts.Add("[$safeCol]")
        if ($LiveLookupIncludeBinaryPayload -and (Supports-BinaryDecodeType -DataType $col.data_type)) {
            $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), [$safeCol])) AS [bin_$safeCol]")
        }
    }

    $safeSchema = $SchemaName.Replace("]", "]]")
    $safeTable = $TableName.Replace("]", "]]")
    $sql = @"
SET NOCOUNT ON;
SELECT TOP (1)
    $($selectParts -join ",`n    ")
FROM [$safeSchema].[$safeTable] WITH (READUNCOMMITTED)
WHERE $($where -join " AND ");
"@
    $script:RowByPhysLiveReadCount++
    $dt = Invoke-SqlQuery -Sql $sql
    if ($dt.Rows.Count -eq 0) {
        if ($script:RowByKeyCache.Count -ge $script:RowByKeyCacheMaxEntries) { $script:RowByKeyCache.Clear() }
        $script:RowByKeyCache[$rowCacheKey] = $null
        return $null
    }
    $row = $dt.Rows[0]
    if ($script:RowByKeyCache.Count -ge $script:RowByKeyCacheMaxEntries) { $script:RowByKeyCache.Clear() }
    $script:RowByKeyCache[$rowCacheKey] = $row
    return $row
}

function Prefetch-ChscQuoteLineRowsByDecodedKeys {
    param(
        [object[]]$Rows,
        [pscustomobject[]]$Metadata
    )

    if (-not $EnableLiveKeyPrefetch) { return 0 }
    if ($DisableLiveRowLookup) { return 0 }
    if ($null -eq $Rows -or $Rows.Count -eq 0) { return 0 }

    $decoded = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($r in @($Rows)) {
        $k = Try-DecodeChscQuoteLineKeyFromRowLog -ManifestRow $r
        if ($null -eq $k) { continue }
        $sig = ("DBID={0};LINENUMBER={1};QUOTEID={2}" -f [string]$k.DBID, [int64]$k.LINENUMBER, [int64]$k.QUOTEID).ToUpperInvariant()
        if ($seen.Add($sig)) {
            $decoded.Add($k) | Out-Null
        }
    }
    if ($decoded.Count -eq 0) { return 0 }

    $selectParts = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Metadata) {
        $safeCol = $col.column_name.Replace("]", "]]")
        $selectParts.Add("t.[$safeCol]")
        if ($LiveLookupIncludeBinaryPayload -and (Supports-BinaryDecodeType -DataType $col.data_type)) {
            $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), t.[$safeCol])) AS [bin_$safeCol]")
        }
    }
    if ($selectParts.Count -eq 0) { return 0 }

    $prefetched = 0
    $chunkSize = 500
    for ($i = 0; $i -lt $decoded.Count; $i += $chunkSize) {
        $take = [Math]::Min($chunkSize, $decoded.Count - $i)
        $vals = New-Object System.Collections.Generic.List[string]
        for ($j = 0; $j -lt $take; $j++) {
            $k = $decoded[$i + $j]
            $dbid = ([string]$k.DBID).Replace("'", "''")
            $qid = [int64]$k.QUOTEID
            $ln = [int64]$k.LINENUMBER
            $vals.Add(("('{0}', {1}, {2})" -f $dbid, $qid, $ln)) | Out-Null
        }

        $sql = @"
SET NOCOUNT ON;
SELECT
    $($selectParts -join ",`n    ")
FROM [oasis].[CHSC_QUOTELINE] t WITH (READUNCOMMITTED)
JOIN (VALUES
    $($vals -join ",`n    ")
) v([DBID],[QUOTEID],[LINENUMBER])
    ON t.[DBID] = v.[DBID]
   AND t.[QUOTEID] = v.[QUOTEID]
   AND t.[LINENUMBER] = v.[LINENUMBER];
"@
        $script:RowByPhysLiveReadCount++
        $dt = Invoke-SqlQuery -Sql $sql
        foreach ($row in $dt.Rows) {
            $dbidVal = [string]$row["DBID"]
            $qidVal = [int64]$row["QUOTEID"]
            $lnVal = [int64]$row["LINENUMBER"]
            $cacheKey = ("OASIS.CHSC_QUOTELINE|DBID='{0}';LINENUMBER={1};QUOTEID={2}" -f $dbidVal.Replace("'", "''"), $lnVal, $qidVal).ToUpperInvariant()
            if ($script:RowByKeyCache.Count -ge $script:RowByKeyCacheMaxEntries) { $script:RowByKeyCache.Clear() }
            $script:RowByKeyCache[$cacheKey] = $row
            $prefetched++
        }
    }
    return $prefetched
}

function Prefetch-RowsByPhysicalLocation {
    param(
        [object[]]$Rows,
        [string]$SchemaName,
        [string]$TableName,
        [pscustomobject[]]$Metadata,
        [int]$BatchSize = 200
    )

    if ($DisableLiveRowLookup) { return 0 }
    if ($null -eq $Rows -or $Rows.Count -eq 0) { return 0 }
    if ($null -eq $Metadata -or $Metadata.Count -eq 0) { return 0 }

    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { continue }
        $phys = Resolve-PhysicalLocation -ManifestRow $r
        if ($null -eq $phys) { continue }
        $key = ("{0}:{1}:{2}" -f $phys.file_id, $phys.page_id, $phys.slot_id)
        $rowCacheKey = ("{0}.{1}|{2}" -f $SchemaName.ToUpperInvariant(), $TableName.ToUpperInvariant(), $key)
        if ($script:RowByPhysCache.ContainsKey($rowCacheKey)) { continue }
        $keys.Add($key) | Out-Null
    }

    if ($keys.Count -eq 0) { return 0 }
    $distinctKeys = @($keys | Sort-Object -Unique)
    if ($distinctKeys.Count -eq 0) { return 0 }

    $safeSchema = $SchemaName.Replace("]", "]]")
    $safeTable = $TableName.Replace("]", "]]")
    $selectParts = New-Object System.Collections.Generic.List[string]
    foreach ($col in $Metadata) {
        $safeCol = $col.column_name.Replace("]", "]]")
        $selectParts.Add("[$safeCol]")
        if ($LiveLookupIncludeBinaryPayload -and (Supports-BinaryDecodeType -DataType $col.data_type)) {
            $selectParts.Add("master.dbo.fn_varbintohexstr(CONVERT(varbinary(max), [$safeCol])) AS [bin_$safeCol]")
        }
    }
    $selectParts.Add("sys.fn_PhysLocFormatter(%%physloc%%) AS [__physloc]")

    $loaded = 0
    $offset = 0
    while ($offset -lt $distinctKeys.Count) {
        $batch = @($distinctKeys | Select-Object -Skip $offset -First $BatchSize)
        if ($batch.Count -eq 0) { break }
        $vals = @($batch | ForEach-Object { "'($($_))'" }) -join ", "
        $sql = @"
SET NOCOUNT ON;
SELECT
    $($selectParts -join ",`n    ")
FROM [$safeSchema].[$safeTable] WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%) IN ($vals);
"@
        $script:RowByPhysLiveReadCount++
        $dt = Invoke-SqlQuery -Sql $sql
        foreach ($row in $dt.Rows) {
            $pl = [string]$row["__physloc"]
            if ([string]::IsNullOrWhiteSpace($pl)) { continue }
            $clean = $pl.Trim()
            if ($clean.StartsWith("(") -and $clean.EndsWith(")")) {
                $clean = $clean.Substring(1, $clean.Length - 2)
            }
            $rowCacheKey = ("{0}.{1}|{2}" -f $SchemaName.ToUpperInvariant(), $TableName.ToUpperInvariant(), $clean)
            if ($script:RowByPhysCache.Count -ge $script:RowByPhysCacheMaxEntries) { $script:RowByPhysCache.Clear() }
            $script:RowByPhysCache[$rowCacheKey] = $row
            $loaded++
        }
        $offset += $BatchSize
    }
    return $loaded
}

function Get-UpdatedColumns {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )
    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $updates = @()
    foreach ($col in $Metadata) {
        if (-not (Supports-BinaryDecodeType -DataType $col.data_type)) { continue }
        $binField = "bin_{0}" -f $col.column_name
        if (-not $RowData.Table.Columns.Contains($binField)) { continue }
        $binHex = $RowData[$binField]
        if ($binHex -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$binHex)) { continue }

        $fullBytes = Convert-HexToBytes -Hex ([string]$binHex)
        if ($fullBytes.Length -eq 0) { continue }

        $searchAt = 0
        while ($true) {
            $pos = Find-SubArrayIndex -Haystack $fullBytes -Needle $newBytes -StartAt $searchAt
            if ($pos -lt 0) { break }

            $candidateOld = New-Object byte[] $fullBytes.Length
            [Array]::Copy($fullBytes, $candidateOld, $fullBytes.Length)
            [Array]::Copy($oldBytes, 0, $candidateOld, $pos, $oldBytes.Length)

            $oldHexLiteral = Bytes-ToHexLiteral -Bytes $candidateOld
            try {
                $oldTyped = Convert-HexLiteralToTypedValue -HexLiteral $oldHexLiteral -Column $col
            } catch {
                $searchAt = $pos + 1
                continue
            }

            $newTyped = $RowData[$col.column_name]
            if ($newTyped -is [System.DBNull]) { $newTyped = $null }

            $same = $false
            if ($null -eq $oldTyped -and $null -eq $newTyped) {
                $same = $true
            } elseif ($null -ne $oldTyped -and $null -ne $newTyped) {
                $same = ([string]$oldTyped -eq [string]$newTyped)
            }

            if (-not $same) {
                $updates += [pscustomobject]@{
                    column_name = $col.column_name
                    old_sql = Convert-TypedValueToSqlLiteral -Value $oldTyped -Column $col
                    new_sql = Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col
                }
                break
            }

            $searchAt = $pos + 1
        }
    }

    $unique = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $unique.ContainsKey($k)) { $unique[$k] = $u }
    }
    return @($unique.Values)
}

function Is-PrintableAsciiByte {
    param([byte]$Value)
    return ($Value -ge 32 -and $Value -le 126)
}

function Get-RowLogTextTokens {
    param([byte[]]$Bytes)

    $tokens = New-Object System.Collections.Generic.List[string]
    if (-not $Bytes -or $Bytes.Length -eq 0) { return @() }

    # ASCII tokens (len >= 3)
    $i = 0
    while ($i -lt $Bytes.Length) {
        if (-not (Is-PrintableAsciiByte -Value $Bytes[$i])) {
            $i++
            continue
        }
        $start = $i
        while ($i -lt $Bytes.Length -and (Is-PrintableAsciiByte -Value $Bytes[$i])) {
            $i++
        }
        $len = $i - $start
        if ($len -ge 3) {
            $tokens.Add([System.Text.Encoding]::ASCII.GetString($Bytes, $start, $len))
        }
    }

    # UTF-16LE ASCII-range tokens (len >= 3 chars)
    $i = 0
    while ($i -lt ($Bytes.Length - 1)) {
        if (-not ((Is-PrintableAsciiByte -Value $Bytes[$i]) -and $Bytes[$i + 1] -eq 0x00)) {
            $i++
            continue
        }
        $chars = New-Object System.Collections.Generic.List[char]
        while ($i -lt ($Bytes.Length - 1) -and (Is-PrintableAsciiByte -Value $Bytes[$i]) -and $Bytes[$i + 1] -eq 0x00) {
            $chars.Add([char]$Bytes[$i])
            $i += 2
        }
        if ($chars.Count -ge 3) {
            $tokens.Add((-join $chars))
        }
    }

    $seen = @{}
    $out = @()
    foreach ($t in $tokens) {
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        $key = $t.ToUpperInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $out += $t
        }
    }
    return $out
}

function Infer-OldTokenSegment {
    param(
        [string[]]$OldTokens,
        [string[]]$NewTokens,
        [string]$NewValue
    )
    if ([string]::IsNullOrWhiteSpace($NewValue)) { return $null }
    foreach ($nt in $NewTokens) {
        $pos = $nt.IndexOf($NewValue, [System.StringComparison]::Ordinal)
        if ($pos -lt 0) { continue }

        $prefix = $nt.Substring(0, $pos)
        $suffix = $nt.Substring($pos + $NewValue.Length)

        foreach ($ot in $OldTokens) {
            if ($ot.Length -lt ($prefix.Length + $suffix.Length)) { continue }
            if (-not $ot.StartsWith($prefix, [System.StringComparison]::Ordinal)) { continue }
            if (-not $ot.EndsWith($suffix, [System.StringComparison]::Ordinal)) { continue }

            $oldValue = $ot.Substring($prefix.Length, $ot.Length - $prefix.Length - $suffix.Length)
            if (-not [string]::IsNullOrWhiteSpace($oldValue) -and ($oldValue -ne $NewValue)) {
                return $oldValue
            }
        }
    }
    return $null
}

function Get-UpdatedColumnsTextHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex,
        [bool]$AllowMultiple = $false
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $oldTokens = @(Get-RowLogTextTokens -Bytes $oldBytes)
    $newTokens = @(Get-RowLogTextTokens -Bytes $newBytes)
    if ($oldTokens.Count -eq 0 -or $newTokens.Count -eq 0) { return @() }

    $updates = @()
    foreach ($col in $Metadata) {
        $dtype = $col.data_type.ToLowerInvariant()
        if ($dtype -notin @("char", "varchar", "nchar", "nvarchar", "text", "ntext")) { continue }
        if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }

        $newTyped = $RowData[$col.column_name]
        if ($newTyped -is [System.DBNull]) { continue }
        $newValue = [string]$newTyped
        if ([string]::IsNullOrWhiteSpace($newValue) -or $newValue.Length -lt 2) { continue }

        $oldValue = Infer-OldTokenSegment -OldTokens $oldTokens -NewTokens $newTokens -NewValue $newValue
        if (-not $oldValue) { continue }

        $updates += [pscustomobject]@{
            column_name = $col.column_name
            old_sql = Convert-TypedValueToSqlLiteral -Value $oldValue -Column $col
            new_sql = Convert-TypedValueToSqlLiteral -Value $newValue -Column $col
        }
    }

    if ($updates.Count -le 0) { return @() }
    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
            continue
        }

        $existing = $byCol[$k]
        if (($existing.old_sql -ne $u.old_sql) -or ($existing.new_sql -ne $u.new_sql)) {
            # Conflicting inference for same column, abandon heuristic for safety.
            return @()
        }
    }

    $resolved = @($byCol.Values)
    if ($AllowMultiple) {
        return $resolved
    }

    # Conservative guard for single-column mode.
    if ($resolved.Count -eq 1) {
        return @($resolved[0])
    }
    return @()
}

function Get-UpdatedColumnsTextPresenceHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $oldTokens = @(Get-RowLogTextTokens -Bytes $oldBytes)
    $newTokens = @(Get-RowLogTextTokens -Bytes $newBytes)
    if ($oldTokens.Count -eq 0 -or $newTokens.Count -eq 0) { return @() }

    $updates = @()
    foreach ($col in $Metadata) {
        $dtype = $col.data_type.ToLowerInvariant()
        if ($dtype -notin @("char", "varchar", "nchar", "nvarchar", "text", "ntext")) { continue }
        if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }

        $newTyped = $RowData[$col.column_name]
        if ($newTyped -is [System.DBNull]) { continue }
        $newValue = [string]$newTyped
        if ([string]::IsNullOrWhiteSpace($newValue) -or $newValue.Length -lt 3) { continue }

        $appearsNew = $false
        foreach ($nt in $newTokens) {
            if ($nt.IndexOf($newValue, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $appearsNew = $true
                break
            }
        }
        if (-not $appearsNew) { continue }

        $appearsOld = $false
        foreach ($ot in $oldTokens) {
            if ($ot.IndexOf($newValue, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $appearsOld = $true
                break
            }
        }
        if ($appearsOld) { continue }

        $oldGuess = Infer-OldTokenSegment -OldTokens $oldTokens -NewTokens $newTokens -NewValue $newValue
        $oldSql = if ($oldGuess) { Convert-TypedValueToSqlLiteral -Value $oldGuess -Column $col } else { "[unknown]" }

        $updates += [pscustomobject]@{
            column_name = $col.column_name
            old_sql = $oldSql
            new_sql = Convert-TypedValueToSqlLiteral -Value $newValue -Column $col
        }
    }

    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
        }
    }
    return @($byCol.Values)
}

function Merge-ChangedCandidateSet {
    param(
        [hashtable]$Target,
        [object[]]$Candidates
    )

    foreach ($c in @($Candidates)) {
        if ($null -eq $c) { continue }
        $colName = [string]$c.column_name
        if ([string]::IsNullOrWhiteSpace($colName)) { continue }
        $key = $colName.ToUpperInvariant()

        if (-not $Target.ContainsKey($key)) {
            $Target[$key] = $c
            continue
        }

        $existing = $Target[$key]
        $existingNew = [string]$existing.new_sql
        $candidateNew = [string]$c.new_sql
        if ($existingNew -ne $candidateNew) {
            # Ambiguous decode for same column -> keep existing deterministic result.
            continue
        }

        $existingKnown = ([string]$existing.old_sql -ne "[unknown]")
        $candidateKnown = ([string]$c.old_sql -ne "[unknown]")
        if (-not $existingKnown -and $candidateKnown) {
            $Target[$key] = $c
        }
    }
}

function Get-NumericRawFactor {
    param([pscustomobject]$Column)
    $dtype = $Column.data_type.ToLowerInvariant()
    switch ($dtype) {
        "tinyint" { return 1 }
        "smallint" { return 1 }
        "int" { return 1 }
        "bigint" { return 1 }
        "bit" { return 1 }
        "decimal" { return [decimal][Math]::Pow(10, [int]$Column.scale) }
        "numeric" { return [decimal][Math]::Pow(10, [int]$Column.scale) }
        "money" { return [decimal]10000 }
        "smallmoney" { return [decimal]10000 }
        default { return $null }
    }
}

function Convert-RawToTypedNumeric {
    param(
        [pscustomobject]$Column,
        [decimal]$RawValue
    )
    $factor = Get-NumericRawFactor -Column $Column
    if ($null -eq $factor -or $factor -eq 0) { return $null }
    $dtype = $Column.data_type.ToLowerInvariant()
    $scaled = $RawValue / $factor

    switch ($dtype) {
        "tinyint" { return [byte]$scaled }
        "smallint" { return [int16]$scaled }
        "int" { return [int32]$scaled }
        "bigint" { return [int64]$scaled }
        "bit" { return [bool]([int]$scaled -ne 0) }
        "decimal" { return [decimal]::Round([decimal]$scaled, [int]$Column.scale) }
        "numeric" { return [decimal]::Round([decimal]$scaled, [int]$Column.scale) }
        "money" { return [decimal]::Round([decimal]$scaled, 4) }
        "smallmoney" { return [decimal]::Round([decimal]$scaled, 4) }
        default { return $null }
    }
}

function Get-RowLogNumericRawPairs {
    param(
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )
    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $limit = [Math]::Min($oldBytes.Length, $newBytes.Length)
    if ($limit -lt 5) { return @() }

    $pairs = @()
    $seen = @{}
    for ($i = 0; $i -le ($limit - 5); $i++) {
        # Heuristic: many numeric payloads are encoded as 0x01 + 4-byte LE integer.
        if ($oldBytes[$i] -ne 0x01 -or $newBytes[$i] -ne 0x01) { continue }

        $oldRaw = [BitConverter]::ToUInt32($oldBytes, $i + 1)
        $newRaw = [BitConverter]::ToUInt32($newBytes, $i + 1)
        if ($oldRaw -eq $newRaw) { continue }
        if ($oldRaw -eq 0 -or $newRaw -eq 0) { continue }
        if ($oldRaw -gt 1000000000 -or $newRaw -gt 1000000000) { continue }

        $k = "$oldRaw|$newRaw"
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        $pairs += [pscustomobject]@{
            old_raw = [decimal]$oldRaw
            new_raw = [decimal]$newRaw
            offset  = $i
        }
    }
    return $pairs
}

function Get-UpdatedColumnsNumericHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $rawPairs = @(Get-RowLogNumericRawPairs -RowLogOldHex $RowLogOldHex -RowLogNewHex $RowLogNewHex)
    if ($rawPairs.Count -eq 0) { return @() }

    $numericColumns = @($Metadata | Where-Object {
        ($_.data_type.ToLowerInvariant()) -in @("tinyint", "smallint", "int", "bigint", "bit", "decimal", "numeric", "money", "smallmoney")
    })

    $updates = @()
    foreach ($pair in $rawPairs) {
        $matches = @()
        foreach ($col in $numericColumns) {
            if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }
            $cur = $RowData[$col.column_name]
            if ($cur -is [System.DBNull] -or $null -eq $cur) { continue }

            $factor = Get-NumericRawFactor -Column $col
            if ($null -eq $factor -or $factor -eq 0) { continue }

            try {
                $curDec = [decimal]$cur
            } catch {
                continue
            }

            try {
                $expectedRawDec = [decimal]::Round(($curDec * $factor), 0)
            } catch {
                continue
            }
            if ($expectedRawDec -ne $pair.new_raw) { continue }

            $newTyped = Convert-RawToTypedNumeric -Column $col -RawValue $pair.new_raw
            $oldTyped = Convert-RawToTypedNumeric -Column $col -RawValue $pair.old_raw
            if ($null -eq $newTyped -or $null -eq $oldTyped) { continue }

            $matches += [pscustomobject]@{
                column_name = $col.column_name
                old_sql = Convert-TypedValueToSqlLiteral -Value $oldTyped -Column $col
                new_sql = Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col
            }
        }

        if ($matches.Count -eq 1) {
            $updates += $matches[0]
        }
    }

    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
        }
    }
    return @($byCol.Values)
}

function Get-UpdatedColumnsNumericPresenceHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    # Restrict to money/decimal families to avoid false positives on common int/id payload fragments.
    $numericTypes = @("decimal", "numeric", "money", "smallmoney")
    $updates = @()

    foreach ($col in $Metadata) {
        $dtype = $col.data_type.ToLowerInvariant()
        if ($dtype -notin $numericTypes) { continue }
        if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }

        $newTyped = $RowData[$col.column_name]
        if ($newTyped -is [System.DBNull] -or $null -eq $newTyped) { continue }

        $binField = "bin_{0}" -f $col.column_name
        if (-not $RowData.Table.Columns.Contains($binField)) { continue }
        $binHex = $RowData[$binField]
        if ($binHex -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$binHex)) { continue }

        $fullNeedle = Convert-HexToBytes -Hex ([string]$binHex)
        if ($fullNeedle.Length -eq 0) { continue }

        $needleCandidates = New-Object System.Collections.Generic.List[object]
        $needleCandidates.Add([pscustomobject]@{ bytes = $fullNeedle; prefix = @() })
        if ($fullNeedle.Length -gt 2 -and $fullNeedle[0] -le 0x20) {
            $trimmed = New-Object byte[] ($fullNeedle.Length - 1)
            [Array]::Copy($fullNeedle, 1, $trimmed, 0, $trimmed.Length)
            $needleCandidates.Add([pscustomobject]@{ bytes = $trimmed; prefix = @($fullNeedle[0]) })
        }
        # Monetary numerics are often represented by a short raw-value tail in row-log fragments.
        if ($fullNeedle.Length -ge 6 -and $dtype -in @("decimal", "numeric", "money", "smallmoney")) {
            $prefixLen = $fullNeedle.Length - 4
            $tail4 = New-Object byte[] 4
            [Array]::Copy($fullNeedle, $prefixLen, $tail4, 0, 4)
            $prefixBytes = New-Object byte[] $prefixLen
            [Array]::Copy($fullNeedle, 0, $prefixBytes, 0, $prefixLen)
            $needleCandidates.Add([pscustomobject]@{ bytes = $tail4; prefix = $prefixBytes })
        }

        $emitted = $false
        foreach ($cand in $needleCandidates) {
            if ($cand.bytes.Length -eq 0) { continue }
            $oldAnyPos = Find-SubArrayIndex -Haystack $oldBytes -Needle $cand.bytes -StartAt 0
            $hasSamePosition = $false
            $probeAt = 0
            while ($true) {
                $probePos = Find-SubArrayIndex -Haystack $newBytes -Needle $cand.bytes -StartAt $probeAt
                if ($probePos -lt 0) { break }
                $probeAt = $probePos + 1
                if ($probePos -le ($oldBytes.Length - $cand.bytes.Length)) {
                    $sameAtPos = $true
                    for ($i = 0; $i -lt $cand.bytes.Length; $i++) {
                        if ($oldBytes[$probePos + $i] -ne $cand.bytes[$i]) {
                            $sameAtPos = $false
                            break
                        }
                    }
                    if ($sameAtPos) {
                        $hasSamePosition = $true
                        break
                    }
                }
            }
            if ($hasSamePosition) {
                continue
            }

            $searchAt = 0
            while (-not $emitted) {
                $posNew = Find-SubArrayIndex -Haystack $newBytes -Needle $cand.bytes -StartAt $searchAt
                if ($posNew -lt 0) { break }
                $searchAt = $posNew + 1

                if ($posNew -le ($oldBytes.Length - $cand.bytes.Length)) {
                    $sameAtPos = $true
                    for ($i = 0; $i -lt $cand.bytes.Length; $i++) {
                        if ($oldBytes[$posNew + $i] -ne $cand.bytes[$i]) {
                            $sameAtPos = $false
                            break
                        }
                    }
                    if ($sameAtPos) { continue }
                }

                $newSql = Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col
                $oldSql = "[unknown]"

                if ($posNew -le ($oldBytes.Length - $cand.bytes.Length)) {
                    $slice = New-Object byte[] $cand.bytes.Length
                    [Array]::Copy($oldBytes, $posNew, $slice, 0, $slice.Length)
                    $castBytes = $slice
                    if ($cand.prefix.Count -gt 0) {
                        $pref = New-Object byte[] ($slice.Length + $cand.prefix.Count)
                        for ($i = 0; $i -lt $cand.prefix.Count; $i++) { $pref[$i] = [byte]$cand.prefix[$i] }
                        [Array]::Copy($slice, 0, $pref, $cand.prefix.Count, $slice.Length)
                        $castBytes = $pref
                    }
                    try {
                        $oldTyped = Convert-HexLiteralToTypedValue -HexLiteral (Bytes-ToHexLiteral -Bytes $castBytes) -Column $col
                        if ($oldTyped -ne $null) {
                            $oldSql = Convert-TypedValueToSqlLiteral -Value $oldTyped -Column $col
                        }
                    } catch {
                        $oldSql = "[unknown]"
                    }
                }

                # Avoid adding likely false positives when value is present in old payload and old value cannot be distinguished.
                if ($oldSql -eq "[unknown]" -and $oldAnyPos -ge 0) {
                    continue
                }
                if ($oldSql -ne "[unknown]" -and $oldSql -eq $newSql) {
                    continue
                }

                $updates += [pscustomobject]@{
                    column_name = $col.column_name
                    old_sql = $oldSql
                    new_sql = $newSql
                }
                $emitted = $true
            }

            if ($emitted) { break }
        }
    }

    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
        }
    }
    return @($byCol.Values)
}

function Get-UpdatedColumnsTemporalHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $temporalTypes = @("date", "time", "datetime", "smalldatetime", "datetime2", "datetimeoffset")
    $updates = @()

    foreach ($col in $Metadata) {
        $dtype = $col.data_type.ToLowerInvariant()
        if ($dtype -notin $temporalTypes) { continue }
        if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }

        $newTyped = $RowData[$col.column_name]
        if ($newTyped -is [System.DBNull] -or $null -eq $newTyped) { continue }

        $binField = "bin_{0}" -f $col.column_name
        if (-not $RowData.Table.Columns.Contains($binField)) { continue }
        $binHex = $RowData[$binField]
        if ($binHex -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$binHex)) { continue }
        $fullNeedle = Convert-HexToBytes -Hex ([string]$binHex)
        if ($fullNeedle.Length -eq 0) { continue }

        $needleCandidates = New-Object System.Collections.Generic.List[object]
        $needleCandidates.Add([pscustomobject]@{ bytes = $fullNeedle; prefix = @() })
        if ($fullNeedle.Length -gt 2 -and $fullNeedle[0] -le 0x10) {
            $trimmed = New-Object byte[] ($fullNeedle.Length - 1)
            [Array]::Copy($fullNeedle, 1, $trimmed, 0, $trimmed.Length)
            $needleCandidates.Add([pscustomobject]@{ bytes = $trimmed; prefix = @($fullNeedle[0]) })
        }

        $posNew = -1
        $selected = $null
        foreach ($cand in $needleCandidates) {
            $pNew = Find-SubArrayIndex -Haystack $newBytes -Needle $cand.bytes -StartAt 0
            if ($pNew -lt 0) { continue }
            $pOldSame = Find-SubArrayIndex -Haystack $oldBytes -Needle $cand.bytes -StartAt 0
            if ($pOldSame -ge 0) { continue }
            $posNew = $pNew
            $selected = $cand
            break
        }
        if ($posNew -lt 0 -or $null -eq $selected) { continue }

        $oldSql = "[unknown]"
        if ($posNew -le ($oldBytes.Length - $selected.bytes.Length)) {
            $slice = New-Object byte[] $selected.bytes.Length
            [Array]::Copy($oldBytes, $posNew, $slice, 0, $selected.bytes.Length)
            $castBytes = $slice
            if ($selected.prefix.Count -gt 0) {
                $pref = New-Object byte[] ($slice.Length + $selected.prefix.Count)
                for ($i = 0; $i -lt $selected.prefix.Count; $i++) { $pref[$i] = [byte]$selected.prefix[$i] }
                [Array]::Copy($slice, 0, $pref, $selected.prefix.Count, $slice.Length)
                $castBytes = $pref
            }
            try {
                $oldTyped = Convert-HexLiteralToTypedValue -HexLiteral (Bytes-ToHexLiteral -Bytes $castBytes) -Column $col
                if ($oldTyped -ne $null) {
                    $oldSql = Convert-TypedValueToSqlLiteral -Value $oldTyped -Column $col
                    if ([string]$oldSql -eq [string](Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col)) {
                        continue
                    }
                }
            } catch {
                # leave as unknown
            }
        }

        $updates += [pscustomobject]@{
            column_name = $col.column_name
            old_sql = $oldSql
            new_sql = Convert-TypedValueToSqlLiteral -Value $newTyped -Column $col
        }
    }

    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
        }
    }
    return @($byCol.Values)
}

function Get-UpdatedColumnsShortTextHeuristic {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [string]$RowLogOldHex,
        [string]$RowLogNewHex
    )

    $oldBytes = Convert-HexToBytes -Hex $RowLogOldHex
    $newBytes = Convert-HexToBytes -Hex $RowLogNewHex
    if ($oldBytes.Length -eq 0 -or $newBytes.Length -eq 0) { return @() }

    $updates = @()
    foreach ($col in $Metadata) {
        $dtype = $col.data_type.ToLowerInvariant()
        if ($dtype -notin @("char", "varchar", "nchar", "nvarchar")) { continue }
        if ([int]$col.max_length -gt 2) { continue }
        if (-not $RowData.Table.Columns.Contains($col.column_name)) { continue }

        $newTyped = $RowData[$col.column_name]
        if ($newTyped -is [System.DBNull] -or $null -eq $newTyped) { continue }
        $newValue = [string]$newTyped
        if ([string]::IsNullOrWhiteSpace($newValue)) { continue }

        $asciiBytes = [System.Text.Encoding]::ASCII.GetBytes($newValue)
        $unicodeBytes = [System.Text.Encoding]::Unicode.GetBytes($newValue)
        $posNewAscii = Find-SubArrayIndex -Haystack $newBytes -Needle $asciiBytes -StartAt 0
        $posNewUni = Find-SubArrayIndex -Haystack $newBytes -Needle $unicodeBytes -StartAt 0
        if ($posNewAscii -lt 0 -and $posNewUni -lt 0) { continue }

        $posOldAscii = Find-SubArrayIndex -Haystack $oldBytes -Needle $asciiBytes -StartAt 0
        $posOldUni = Find-SubArrayIndex -Haystack $oldBytes -Needle $unicodeBytes -StartAt 0
        if ($posOldAscii -ge 0 -or $posOldUni -ge 0) { continue }

        $updates += [pscustomobject]@{
            column_name = $col.column_name
            old_sql = "[unknown]"
            new_sql = Convert-TypedValueToSqlLiteral -Value $newValue -Column $col
        }
    }

    $byCol = @{}
    foreach ($u in $updates) {
        $k = $u.column_name.ToUpperInvariant()
        if (-not $byCol.ContainsKey($k)) {
            $byCol[$k] = $u
        }
    }
    return @($byCol.Values)
}

function Is-UsableHexPayload {
    param([AllowNull()][string]$Hex)
    if ([string]::IsNullOrWhiteSpace($Hex)) { return $false }
    $h = $Hex.Trim()
    if ($h.Length -lt 3) { return $false }
    if ($h -eq "0x") { return $false }
    return $true
}

function Add-RowLogPair {
    param(
        [System.Collections.Generic.List[object]]$Pairs,
        [hashtable]$PairKeys,
        [AllowNull()][string]$OldHex,
        [AllowNull()][string]$NewHex,
        [string]$SourceTag
    )

    if (-not (Is-UsableHexPayload -Hex $OldHex) -or -not (Is-UsableHexPayload -Hex $NewHex)) {
        return
    }

    $oldNorm = $OldHex.Trim().ToUpperInvariant()
    $newNorm = $NewHex.Trim().ToUpperInvariant()
    $key = "$oldNorm|$newNorm"
    if ($PairKeys.ContainsKey($key)) {
        return
    }

    $PairKeys[$key] = $true
    $Pairs.Add([pscustomobject]@{
        old_hex = $OldHex
        new_hex = $NewHex
        source  = $SourceTag
    })
}

function Get-LsnSortKey {
    param([AllowNull()][string]$LsnText)
    if ([string]::IsNullOrWhiteSpace($LsnText)) { return "FFFFFFFFFFFFFFFFFFFF" }
    $s = $LsnText.Trim().ToUpperInvariant()
    if ($s -match "^([0-9A-F]{8}):([0-9A-F]{8}):([0-9A-F]{4})$") {
        return ($Matches[1] + $Matches[2] + $Matches[3])
    }
    return $s
}

function Get-RowLogPayloadScore {
    param([psobject]$ManifestRow)
    if ($null -eq $ManifestRow) { return 0 }
    $score = 0
    if ((Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog0_hex"))) -and (Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog1_hex")))) { $score++ }
    if ((Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog2_hex"))) -and (Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog3_hex")))) { $score++ }
    if ((Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog4_hex"))) -and (Is-UsableHexPayload -Hex ([string](Get-PropertyValue -Object $ManifestRow -Name "rowlog5_hex")))) { $score++ }
    return $score
}

function Add-RowLogPairsFromRows {
    param(
        [object[]]$Rows,
        [System.Collections.Generic.List[object]]$Pairs,
        [hashtable]$PairKeys,
        [string]$SourcePrefix = "tx"
    )

    foreach ($tr in @($Rows)) {
        if ($null -eq $tr) { continue }
        $lsn = [string](Get-PropertyValue -Object $tr -Name "current_lsn")
        $tagBase = "{0}:{1}" -f $SourcePrefix, $lsn
        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog0_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog1_hex")) -SourceTag ($tagBase + ":0/1")
        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog2_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog3_hex")) -SourceTag ($tagBase + ":2/3")
        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog4_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog5_hex")) -SourceTag ($tagBase + ":4/5")
    }
}

function Get-HexPayloadLength {
    param([AllowNull()][string]$Hex)
    if (-not (Is-UsableHexPayload -Hex $Hex)) { return 0 }
    $h = $Hex.Trim()
    if ($h.StartsWith("0x", [System.StringComparison]::OrdinalIgnoreCase)) {
        $h = $h.Substring(2)
    }
    return [int]($h.Length / 2)
}

function Add-RowLogPairsFromRowsOperationAware {
    param(
        [object[]]$Rows,
        [System.Collections.Generic.List[object]]$Pairs,
        [hashtable]$PairKeys,
        [string]$SourcePrefix = "tx"
    )

    foreach ($tr in @($Rows)) {
        if ($null -eq $tr) { continue }
        $lsn = [string](Get-PropertyValue -Object $tr -Name "current_lsn")
        $op = ([string](Get-PropertyValue -Object $tr -Name "operation_name")).ToUpperInvariant()
        $tagBase = "{0}:{1}" -f $SourcePrefix, $lsn

        if ($op -eq "LOP_MODIFY_COLUMNS") {
            # MODIFY_COLUMNS commonly stores richer before/after payload in 4/5 for wide variable updates.
            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog4_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog5_hex")) -SourceTag ($tagBase + ":4/5")
            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog2_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog3_hex")) -SourceTag ($tagBase + ":2/3")
            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog0_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog1_hex")) -SourceTag ($tagBase + ":0/1")
            continue
        }

        if ($op -eq "LOP_MODIFY_ROW") {
            # MODIFY_ROW can carry tiny fragments; prefer substantial payloads and avoid noisy short pairs.
            $l01 = [Math]::Min((Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog0_hex"))), (Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog1_hex"))))
            $l23 = [Math]::Min((Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog2_hex"))), (Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog3_hex"))))
            $l45 = [Math]::Min((Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog4_hex"))), (Get-HexPayloadLength -Hex ([string](Get-PropertyValue -Object $tr -Name "rowlog5_hex"))))

            if ($l23 -ge 8) {
                Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog2_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog3_hex")) -SourceTag ($tagBase + ":2/3")
            }
            if ($l45 -ge 8) {
                Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog4_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog5_hex")) -SourceTag ($tagBase + ":4/5")
            }
            if ($l01 -ge 4) {
                Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog0_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog1_hex")) -SourceTag ($tagBase + ":0/1")
            }
            continue
        }

        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog0_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog1_hex")) -SourceTag ($tagBase + ":0/1")
        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog2_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog3_hex")) -SourceTag ($tagBase + ":2/3")
        Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys -OldHex ([string](Get-PropertyValue -Object $tr -Name "rowlog4_hex")) -NewHex ([string](Get-PropertyValue -Object $tr -Name "rowlog5_hex")) -SourceTag ($tagBase + ":4/5")
    }
}

function Add-LinkedAdjacentRowLogPairs {
    param(
        [object[]]$Rows,
        [System.Collections.Generic.List[object]]$Pairs,
        [hashtable]$PairKeys,
        [string]$SourcePrefix = "linked"
    )

    $groups = @{}
    foreach ($tr in @($Rows)) {
        if ($null -eq $tr) { continue }
        $phys = Resolve-PhysicalLocation -ManifestRow $tr
        if ($null -eq $phys) { continue }
        $alloc = [string](Get-PropertyValue -Object $tr -Name "alloc_unit_name")
        $gk = ("{0}|{1}:{2}:{3}" -f $alloc.ToUpperInvariant(), $phys.file_id, $phys.page_id, $phys.slot_id)
        if (-not $groups.ContainsKey($gk)) {
            $groups[$gk] = New-Object System.Collections.Generic.List[object]
        }
        $groups[$gk].Add($tr)
    }

    foreach ($gk in $groups.Keys) {
        $ordered = @($groups[$gk] | Sort-Object @{ Expression = { Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $_ -Name "current_lsn")) } })
        if ($ordered.Count -lt 2) { continue }
        for ($i = 0; $i -lt ($ordered.Count - 1); $i++) {
            $a = $ordered[$i]
            $b = $ordered[$i + 1]
            $aLsn = [string](Get-PropertyValue -Object $a -Name "current_lsn")
            $bLsn = [string](Get-PropertyValue -Object $b -Name "current_lsn")
            $tag = "{0}:{1}->{2}" -f $SourcePrefix, $aLsn, $bLsn

            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys `
                -OldHex ([string](Get-PropertyValue -Object $a -Name "rowlog0_hex")) `
                -NewHex ([string](Get-PropertyValue -Object $b -Name "rowlog1_hex")) `
                -SourceTag ($tag + ":adj0/1")
            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys `
                -OldHex ([string](Get-PropertyValue -Object $a -Name "rowlog2_hex")) `
                -NewHex ([string](Get-PropertyValue -Object $b -Name "rowlog3_hex")) `
                -SourceTag ($tag + ":adj2/3")
            Add-RowLogPair -Pairs $Pairs -PairKeys $PairKeys `
                -OldHex ([string](Get-PropertyValue -Object $a -Name "rowlog4_hex")) `
                -NewHex ([string](Get-PropertyValue -Object $b -Name "rowlog5_hex")) `
                -SourceTag ($tag + ":adj4/5")
        }
    }
}

function Get-LinkedTxRowsForDecode {
    param(
        [psobject]$SelectedRow,
        [object[]]$TxRows,
        [string]$TargetSchema,
        [string]$TargetTable
    )

    $selMk = ([string](Get-PropertyValue -Object $SelectedRow -Name "manifest_key")).ToUpperInvariant()
    $selAlloc = [string](Get-PropertyValue -Object $SelectedRow -Name "alloc_unit_name")
    $selPhys = Resolve-PhysicalLocation -ManifestRow $SelectedRow
    $targetBase = ("{0}.{1}" -f $TargetSchema, $TargetTable).ToUpperInvariant()

    $scored = New-Object System.Collections.Generic.List[object]
    foreach ($tr in @($TxRows)) {
        if ($null -eq $tr) { continue }

        $alloc = [string](Get-PropertyValue -Object $tr -Name "alloc_unit_name")
        if ([string]::IsNullOrWhiteSpace($alloc)) { continue }
        $allocUpper = $alloc.ToUpperInvariant()
        if (-not ($allocUpper -eq $targetBase -or $allocUpper.StartsWith($targetBase + "."))) { continue }

        $score = 0
        $mk = ([string](Get-PropertyValue -Object $tr -Name "manifest_key")).ToUpperInvariant()
        if ($mk -eq $selMk) { $score += 120 }
        if ($alloc -eq $selAlloc) { $score += 40 }
        if ($allocUpper -eq $targetBase) { $score += 45 }

        $ctx = ([string](Get-PropertyValue -Object $tr -Name "context_name")).ToUpperInvariant()
        if ($ctx -eq "LCX_PFS") {
            $score -= 25
        } else {
            $score += 20
        }

        $op = ([string](Get-PropertyValue -Object $tr -Name "operation_name")).ToUpperInvariant()
        if ($op -like "LOP_MODIFY*") { $score += 25 }
        elseif ($op -eq "LOP_INSERT_ROWS" -or $op -eq "LOP_DELETE_ROWS") { $score += 10 }

        $payloadScore = Get-RowLogPayloadScore -ManifestRow $tr
        $score += ($payloadScore * 3)

        $phys = Resolve-PhysicalLocation -ManifestRow $tr
        if ($phys) {
            $score += 5
            if ($selPhys -and
                $selPhys.file_id -eq $phys.file_id -and
                $selPhys.page_id -eq $phys.page_id -and
                $selPhys.slot_id -eq $phys.slot_id) {
                $score += 35
            }
        }

        $scored.Add([pscustomobject]@{
            row = $tr
            score = $score
            lsn_key = Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $tr -Name "current_lsn"))
        })
    }

    return @($scored | Sort-Object @{ Expression = { $_.score }; Descending = $true }, @{ Expression = { $_.lsn_key } } | Select-Object -ExpandProperty row)
}

function Is-TargetAllocUnit {
    param(
        [AllowNull()][string]$AllocUnitName,
        [string]$SchemaName,
        [string]$TableName
    )
    if ([string]::IsNullOrWhiteSpace($AllocUnitName)) { return $false }
    $allocUpper = $AllocUnitName.Trim().ToUpperInvariant()
    $base = ("{0}.{1}" -f $SchemaName, $TableName).ToUpperInvariant()
    return ($allocUpper -eq $base -or $allocUpper.StartsWith($base + "."))
}

function Get-TxRowClassRank {
    param(
        [psobject]$Row,
        [string]$SchemaName,
        [string]$TableName
    )

    $alloc = [string](Get-PropertyValue -Object $Row -Name "alloc_unit_name")
    $allocUpper = $alloc.ToUpperInvariant()
    $base = ("{0}.{1}" -f $SchemaName, $TableName).ToUpperInvariant()
    $ctx = ([string](Get-PropertyValue -Object $Row -Name "context_name")).ToUpperInvariant()

    if ($allocUpper -eq $base) { return 0 }
    if ($ctx -eq "LCX_HEAP" -or $ctx -eq "LCX_CLUSTERED" -or $ctx -eq "LCX_CLUSTERED_LEAF") { return 1 }
    if ($allocUpper -like ("{0}.PK_*" -f $base)) { return 2 }
    if ($allocUpper.StartsWith($base + ".")) { return 3 }
    return 9
}

function Get-TxRowOperationRank {
    param([psobject]$Row)
    $op = ([string](Get-PropertyValue -Object $Row -Name "operation_name")).ToUpperInvariant()
    if ($op -like "LOP_MODIFY*") { return 3 }
    if ($op -eq "LOP_INSERT_ROWS" -or $op -eq "LOP_DELETE_ROWS") { return 2 }
    return 1
}

function Get-TxRowIdentityKey {
    param([psobject]$Row)
    $action = ([string](Get-PropertyValue -Object $Row -Name "action")).ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($action)) { $action = "UNKNOWN" }

    $phys = Resolve-PhysicalLocation -ManifestRow $Row
    if ($phys) {
        return ("{0}|{1}:{2}:{3}" -f $action, $phys.file_id, $phys.page_id, $phys.slot_id)
    }

    $mk = [string](Get-PropertyValue -Object $Row -Name "manifest_key")
    if (-not [string]::IsNullOrWhiteSpace($mk)) {
        return ("{0}|{1}" -f $action, $mk.ToUpperInvariant())
    }

    $lsn = [string](Get-PropertyValue -Object $Row -Name "current_lsn")
    if (-not [string]::IsNullOrWhiteSpace($lsn)) {
        return ("{0}|{1}" -f $action, $lsn.ToUpperInvariant())
    }

    $alloc = [string](Get-PropertyValue -Object $Row -Name "alloc_unit_name")
    return ("{0}|{1}" -f $action, $alloc.ToUpperInvariant())
}

function Collapse-TxRows {
    param(
        [object[]]$Rows,
        [string]$SchemaName,
        [string]$TableName
    )

    $rowsArray = @($Rows)
    if ($rowsArray.Count -le 1) { return $rowsArray }

    $targetRows = @($rowsArray | Where-Object {
        Is-TargetAllocUnit -AllocUnitName ([string](Get-PropertyValue -Object $_ -Name "alloc_unit_name")) -SchemaName $SchemaName -TableName $TableName
    })
    if ($targetRows.Count -eq 0) {
        return @($rowsArray | Sort-Object @{ Expression = { Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $_ -Name "current_lsn")) } })
    }

    $scored = @($targetRows | ForEach-Object {
        [pscustomobject]@{
            row = $_
            class_rank = Get-TxRowClassRank -Row $_ -SchemaName $SchemaName -TableName $TableName
            op_rank = Get-TxRowOperationRank -Row $_
            payload_score = Get-RowLogPayloadScore -ManifestRow $_
            identity = Get-TxRowIdentityKey -Row $_
            lsn_key = Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $_ -Name "current_lsn"))
        }
    })

    $minClass = ($scored | Measure-Object class_rank -Minimum).Minimum
    $candidates = @($scored | Where-Object { $_.class_rank -eq $minClass })

    $collapsed = New-Object System.Collections.Generic.List[object]
    $groups = @($candidates | Group-Object identity)
    foreach ($g in $groups) {
        $best = @($g.Group | Sort-Object @{
            Expression = { $_.payload_score }; Descending = $true
        }, @{
            Expression = { $_.op_rank }; Descending = $true
        }, @{
            Expression = { $_.lsn_key }
        } | Select-Object -First 1)
        if ($best.Count -gt 0) {
            $collapsed.Add($best[0].row) | Out-Null
        }
    }

    return @($collapsed.ToArray() | Sort-Object @{ Expression = { Parse-CommitTime -Text ([string](Get-PropertyValue -Object $_ -Name "commit_time")) } }, @{ Expression = { Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $_ -Name "current_lsn")) } })
}

function Resolve-RowDataFromCandidateRows {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [object[]]$CandidateRows,
        [pscustomobject[]]$Metadata,
        [int]$MaxAttempts = 8,
        [bool]$NoLiveFallback = $false,
        [bool]$AllowOfflineKeyPatch = $false
)

    if (
        $SchemaName.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and
        $TableName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        foreach ($cand in @($CandidateRows)) {
            if ($null -eq $cand) { continue }
            $decodedKeyFast = Get-DecodedWhereKeyCached -ManifestRow $cand -SchemaName $SchemaName -TableName $TableName
            if ($null -eq $decodedKeyFast) { continue }

            $offlineRowFast = Get-OfflineRowDataForManifestRow -ManifestRow $cand -Metadata $Metadata
            if ($offlineRowFast -ne $null) {
                return [pscustomobject]@{
                    row_data = $offlineRowFast
                    source_row = $cand
                    source_phys = (Resolve-PhysicalLocation -ManifestRow $cand)
                    source_mode = "offline_cache_fast"
                }
            }

            if (-not $NoLiveFallback) {
                try {
                    $rowFast = Get-RowByDecodedKey -SchemaName $SchemaName -TableName $TableName -DecodedKey $decodedKeyFast -Metadata $Metadata
                    if ($rowFast -ne $null) {
                        return [pscustomobject]@{
                            row_data = $rowFast
                            source_row = $cand
                            source_phys = (Resolve-PhysicalLocation -ManifestRow $cand)
                            source_mode = "live_query_key_fast"
                        }
                    }
                } catch {
                    # continue to generic resolver
                }
            }
        }
    }

    $seenPhys = @{}
    $attempts = 0
    foreach ($cand in @($CandidateRows)) {
        if ($null -eq $cand) { continue }
        $phys = Resolve-PhysicalLocation -ManifestRow $cand
        if ($null -eq $phys) { continue }

        $physKey = ("{0}:{1}:{2}" -f $phys.file_id, $phys.page_id, $phys.slot_id)
        if ($seenPhys.ContainsKey($physKey)) { continue }
        $seenPhys[$physKey] = $true

        $decodedKey = Get-DecodedWhereKeyCached -ManifestRow $cand -SchemaName $SchemaName -TableName $TableName
        $offlineRow = Get-OfflineRowDataForManifestRow -ManifestRow $cand -Metadata $Metadata
        if ($EnableOfflineKeyMatchFallback -and $offlineRow -eq $null -and $null -ne $decodedKey) {
            $offlineByKey = Get-OfflineRowDataByDecodedKey -DecodedKey $decodedKey -Metadata $Metadata
            if ($offlineByKey -ne $null) {
                return [pscustomobject]@{
                    row_data = $offlineByKey
                    source_row = $cand
                    source_phys = $phys
                    source_mode = "offline_cache_keymatch"
                }
            }
        }
        if ($offlineRow -ne $null) {
            $rowKeyOk = Test-RowDataMatchesDecodedKey -RowData $offlineRow -Metadata $Metadata -DecodedKey $decodedKey
            if (-not $rowKeyOk -and $AllowOfflineKeyPatch -and $null -ne $decodedKey) {
                [void](Apply-DecodedKeyToRowData -RowData $offlineRow -Metadata $Metadata -DecodedKey $decodedKey)
                $rowKeyOk = Test-RowDataMatchesDecodedKey -RowData $offlineRow -Metadata $Metadata -DecodedKey $decodedKey
                if ($rowKeyOk) {
                    return [pscustomobject]@{
                        row_data = $offlineRow
                        source_row = $cand
                        source_phys = $phys
                        source_mode = "offline_cache_keypatched"
                    }
                }
            }
            if (-not $rowKeyOk) {
                $attempts++
                if ($attempts -ge $MaxAttempts) { break }
                continue
            }
            return [pscustomobject]@{
                row_data = $offlineRow
                source_row = $cand
                source_phys = $phys
                source_mode = "offline_cache"
            }
        }

        if ($NoLiveFallback) {
            $attempts++
            if ($attempts -ge $MaxAttempts) { break }
            continue
        }

        $row = $null
        $sourceMode = "live_query_physloc"
        if ($null -ne $decodedKey) {
            try {
                $row = Get-RowByDecodedKey -SchemaName $SchemaName -TableName $TableName -DecodedKey $decodedKey -Metadata $Metadata
                if ($row -ne $null) { $sourceMode = "live_query_key" }
            } catch {
                $row = $null
            }
        }
        if ($row -eq $null) {
            try {
                $row = Get-RowByPhysicalLocation -SchemaName $SchemaName -TableName $TableName -FileId $phys.file_id -PageId $phys.page_id -SlotId $phys.slot_id -Metadata $Metadata
            } catch {
                $row = $null
            }
        }
        if ($row -ne $null) {
            return [pscustomobject]@{
                row_data = $row
                source_row = $cand
                source_phys = $phys
                source_mode = $sourceMode
            }
        }

        $attempts++
        if ($attempts -ge $MaxAttempts) { break }
    }

    return $null
}

function Build-InsertFromRowData {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [bool]$IncludeNulls = $true
    )

    $cols = @()
    $vals = @()
    foreach ($col in $Metadata) {
        $cn = $col.column_name
        if (-not $RowData.Table.Columns.Contains($cn)) { continue }
        $v = $RowData[$cn]
        if ((-not $IncludeNulls) -and ($v -is [System.DBNull])) { continue }
        $cols += "[" + $cn.Replace("]", "]]") + "]"
        if ($v -is [System.DBNull]) {
            $vals += "NULL"
        } else {
            $vals += (Convert-TypedValueToSqlLiteral -Value $v -Column $col)
        }
    }
    if ($cols.Count -eq 0) { return $null }
    return "INSERT INTO [$SchemaName].[$TableName] ($($cols -join ', ')) VALUES ($($vals -join ', '));"
}

function Test-IsInternalDeleteCompanionRow {
    param(
        [psobject]$Row
    )

    if ($null -eq $Row) { return $false }
    $action = ([string](Get-PropertyValue -Object $Row -Name "action")).ToUpperInvariant()
    if ($action -ne "DELETE") { return $false }

    $op = ([string](Get-PropertyValue -Object $Row -Name "operation_name")).ToUpperInvariant()
    if ($op -ne "LOP_DELETE_ROWS") { return $false }

    $ctx = ([string](Get-PropertyValue -Object $Row -Name "context_name")).ToUpperInvariant()
    if ($ctx -ne "LCX_MARK_AS_GHOST" -and $ctx -ne "LCX_TEXT_MIX") { return $false }

    $hasPayload =
        -not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Object $Row -Name "rowlog2_hex")) -or
        -not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Object $Row -Name "rowlog3_hex")) -or
        -not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Object $Row -Name "rowlog4_hex")) -or
        -not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Object $Row -Name "rowlog5_hex"))

    return (-not $hasPayload)
}

function Should-SkipInternalDeleteCompanionRow {
    param(
        [psobject]$Row,
        [object[]]$TxRows
    )

    if (-not (Test-IsInternalDeleteCompanionRow -Row $Row)) { return $false }
    if ($null -eq $TxRows -or $TxRows.Count -eq 0) { return $false }

    foreach ($txr in $TxRows) {
        if ($null -eq $txr) { continue }
        $sameRef = $false
        try { $sameRef = [object]::ReferenceEquals($txr, $Row) } catch { $sameRef = $false }
        if ($sameRef) { continue }

        $action = ([string](Get-PropertyValue -Object $txr -Name "action")).ToUpperInvariant()
        if ($action -ne "DELETE") { continue }
        $op = ([string](Get-PropertyValue -Object $txr -Name "operation_name")).ToUpperInvariant()
        if ($op -ne "LOP_DELETE_ROWS") { continue }

        # If transaction contains at least one non-companion delete row,
        # this row is internal noise and can be dropped safely.
        if (-not (Test-IsInternalDeleteCompanionRow -Row $txr)) {
            return $true
        }
    }

    # Keep companion rows for delete-only transactions where they may be
    # the only available delete evidence.
    return $false
}

function Test-IsBaseRowManifestRecord {
    param([psobject]$Row)

    if ($null -eq $Row) { return $false }
    $ctx = ([string](Get-PropertyValue -Object $Row -Name "context_name")).ToUpperInvariant()
    $op = ([string](Get-PropertyValue -Object $Row -Name "operation_name")).ToUpperInvariant()

    # INSERT/UPDATE keep only true base-row contexts.
    if ($op -eq "LOP_INSERT_ROWS" -or $op -eq "LOP_MODIFY_ROW" -or $op -eq "LOP_MODIFY_COLUMNS") {
        return ($ctx -eq "LCX_CLUSTERED" -or $ctx -eq "LCX_HEAP")
    }

    # DELETE keeps base-row rows + ghost companion rows.
    if ($op -eq "LOP_DELETE_ROWS") {
        return ($ctx -eq "LCX_CLUSTERED" -or $ctx -eq "LCX_HEAP" -or $ctx -eq "LCX_MARK_AS_GHOST")
    }

    return ($ctx -eq "LCX_CLUSTERED" -or $ctx -eq "LCX_HEAP")
}

function Build-WhereClausesFromRowData {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$WhereKeyColumns
    )

    $whereClauses = @()
    foreach ($kcol in $WhereKeyColumns) {
        if (-not $RowData.Table.Columns.Contains($kcol.column_name)) { continue }
        $safeKey = $kcol.column_name.Replace("]", "]]")
        $whereClauses += "[$safeKey] = $(Convert-TypedValueToSqlLiteral -Value $RowData[$kcol.column_name] -Column $kcol)"
    }
    return @($whereClauses)
}

function Convert-RowDataToObject {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata
    )

    if ($null -eq $RowData) { return $null }

    $names = @()
    if ($Metadata -and $Metadata.Count -gt 0) {
        $names = @($Metadata | Sort-Object column_id | ForEach-Object { [string]$_.column_name })
    } else {
        foreach ($c in $RowData.Table.Columns) {
            $names += [string]$c.ColumnName
        }
    }

    $obj = [ordered]@{}
    foreach ($cn in $names) {
        if (-not $RowData.Table.Columns.Contains($cn)) { continue }
        $v = $RowData[$cn]
        if ($v -is [System.DBNull]) {
            $obj[$cn] = $null
        } else {
            $obj[$cn] = $v
        }
    }

    return [pscustomobject]$obj
}

function Build-UndoUpdateSql {
    param(
        [string]$SchemaName,
        [string]$TableName,
        [object[]]$ChangedColumns,
        [string[]]$WhereClauses
    )

    if (-not $ChangedColumns -or $ChangedColumns.Count -eq 0) { return $null }
    if (-not $WhereClauses -or $WhereClauses.Count -eq 0) { return $null }

    $setClauses = @()
    foreach ($chg in @($ChangedColumns | Where-Object { [string]$_.old_sql -ne "[unknown]" } | Sort-Object column_name)) {
        $safeCol = ([string]$chg.column_name).Replace("]", "]]")
        $setClauses += "[$safeCol] = $([string]$chg.old_sql)"
    }
    if ($setClauses.Count -eq 0) { return $null }

    return "UPDATE [$SchemaName].[$TableName] SET $($setClauses -join ', ') WHERE $($WhereClauses -join ' AND ');"
}

function Try-DecodeChscPoDeleteKeyFromIdxPoRow {
    param(
        [psobject]$ManifestRow
    )

    if ($null -eq $ManifestRow) { return $null }
    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if ($alloc -ne "oasis.CHSC_PO.IDX_PO") { return $null }

    $hex = [string](Get-PropertyValue -Object $ManifestRow -Name "rowlog0_hex")
    if ([string]::IsNullOrWhiteSpace($hex)) { return $null }

    $bytes = Convert-HexToBytes -Hex $hex
    if ($bytes.Length -lt 5) { return $null }

    # IDX_PO payload reliably carries POID as LE int at offset 1.
    $poid = [int64][BitConverter]::ToUInt32($bytes, 1)
    if ($poid -le 0) { return $null }

    $tokens = @(Get-RowLogTextTokens -Bytes $bytes | Where-Object { $_ -match "^[A-Za-z0-9_]{3,32}$" })
    if ($tokens.Count -eq 0) { return $null }
    $dbid = ($tokens | Sort-Object Length -Descending | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($dbid)) { return $null }

    return [pscustomobject]@{
        DBID = [string]$dbid
        POID = [int64]$poid
    }
}

function Try-DecodeChscPoDeleteKeyFromPkRow {
    param(
        [psobject]$ManifestRow
    )

    if ($null -eq $ManifestRow) { return $null }
    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if ($alloc -ne "oasis.CHSC_PO.PK_CHSC_PO") { return $null }

    foreach ($field in @("rowlog0_hex", "rowlog1_hex")) {
        $hex = [string](Get-PropertyValue -Object $ManifestRow -Name $field)
        if ([string]::IsNullOrWhiteSpace($hex)) { continue }
        $bytes = Convert-HexToBytes -Hex $hex
        if ($bytes.Length -lt 8) { continue }

        $poid = $null
        # Observed clustered/ghost delete payload:
        # 30 00 ?? 00 <POID:4 LE> ...
        if ($bytes[0] -eq 0x30 -and $bytes[1] -eq 0x00) {
            $poid = [int64][BitConverter]::ToUInt32($bytes, 4)
        } elseif ($bytes[0] -eq 0x36 -and $bytes.Length -ge 9) {
            # Defensive fallback for leaf-like rowlog shape.
            $poid = [int64][BitConverter]::ToUInt32($bytes, 5)
        }

        if ($null -eq $poid -or $poid -le 0) { continue }
        $dbid = Resolve-ChscPoDbidByPoid -Poid $poid
        if ([string]::IsNullOrWhiteSpace($dbid)) { continue }

        return [pscustomobject]@{
            DBID = [string]$dbid
            POID = [int64]$poid
        }
    }

    return $null
}

function Try-DecodeChscPoLineKeyFromRowLog {
    param(
        [psobject]$ManifestRow
    )

    if ($null -eq $ManifestRow) { return $null }

    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if (-not ($alloc -like "oasis.CHSC_POLINE.*")) { return $null }

    $dbid = $null

    foreach ($field in @("rowlog0_hex", "rowlog1_hex", "rowlog2_hex", "rowlog3_hex")) {
        $hex = [string](Get-PropertyValue -Object $ManifestRow -Name $field)
        if ([string]::IsNullOrWhiteSpace($hex)) { continue }

        $bytes = Convert-HexToBytes -Hex $hex
        if ($bytes.Length -lt 12) { continue }

        # Prefer extracting DBID once from printable rowlog payload.
        if ([string]::IsNullOrWhiteSpace($dbid)) {
            $tokens = @(Get-RowLogTextTokens -Bytes $bytes | Where-Object { $_ -match "^[A-Za-z0-9_]{3,32}$" })
            if ($tokens.Count -gt 0) {
                $dbid = ($tokens | Sort-Object Length -Descending | Select-Object -First 1)
            }
        }

        $poid = $null
        $lineNumber = $null

        # Observed nonclustered index leaf payload shape:
        # 36 00 00 00 00 <POID:4 LE> <LINENUMBER:4 LE> ...
        if ($bytes[0] -eq 0x36 -and $bytes.Length -ge 13) {
            $poid = [int64][BitConverter]::ToUInt32($bytes, 5)
            $lineNumber = [int64][BitConverter]::ToUInt32($bytes, 9)
        }
        # Observed clustered/ghost payload shape:
        # 30 00 ?? 00 <POID:4 LE> <LINENUMBER:4 LE> ...
        elseif ($bytes[0] -eq 0x30 -and $bytes[1] -eq 0x00 -and $bytes.Length -ge 12) {
            $poid = [int64][BitConverter]::ToUInt32($bytes, 4)
            $lineNumber = [int64][BitConverter]::ToUInt32($bytes, 8)
        }

        if ($null -eq $poid -or $null -eq $lineNumber) { continue }
        if ($poid -le 0 -or $lineNumber -lt 0 -or $lineNumber -gt 2000000000) { continue }
        if ([string]::IsNullOrWhiteSpace($dbid)) {
            $dbid = Resolve-ChscPoLineDbidByPoid -Poid $poid
        }
        if ([string]::IsNullOrWhiteSpace($dbid)) {
            $dbid = Resolve-ChscPoDbidByPoid -Poid $poid
        }
        if ([string]::IsNullOrWhiteSpace($dbid)) { continue }

        return [pscustomobject]@{
            DBID = [string]$dbid
            POID = [int64]$poid
            LINENUMBER = [int64]$lineNumber
        }
    }

    return $null
}

function Resolve-ChscPoLineDbidByPoid {
    param([int64]$Poid)

    if ($Poid -le 0) { return $null }
    $cacheKey = [string]$Poid
    if ($script:PoLineDbidByPoidCache.ContainsKey($cacheKey)) {
        return $script:PoLineDbidByPoidCache[$cacheKey]
    }

    $sql = @"
SELECT TOP (1) [DBID]
FROM [oasis].[CHSC_POLINE] WITH (READUNCOMMITTED)
WHERE [POID] = $Poid
ORDER BY [DBID]
"@
    try {
        $dt = Invoke-SqlQuery -Sql $sql
        if ($dt.Rows.Count -gt 0) {
            $dbid = [string]$dt.Rows[0]["DBID"]
            if (-not [string]::IsNullOrWhiteSpace($dbid)) {
                $script:PoLineDbidByPoidCache[$cacheKey] = $dbid
                return $dbid
            }
        }
    } catch {
        # keep fallback null
    }

    $script:PoLineDbidByPoidCache[$cacheKey] = $null
    return $null
}

function Resolve-ChscPoDbidByPoid {
    param([int64]$Poid)

    if ($Poid -le 0) { return $null }
    $cacheKey = [string]$Poid
    if ($script:PoDbidByPoidCache.ContainsKey($cacheKey)) {
        return $script:PoDbidByPoidCache[$cacheKey]
    }

    $sql = @"
SELECT TOP (1) [DBID]
FROM [oasis].[CHSC_PO] WITH (READUNCOMMITTED)
WHERE [POID] = $Poid
ORDER BY [DBID]
"@
    try {
        $dt = Invoke-SqlQuery -Sql $sql
        if ($dt.Rows.Count -gt 0) {
            $dbid = [string]$dt.Rows[0]["DBID"]
            if (-not [string]::IsNullOrWhiteSpace($dbid)) {
                $script:PoDbidByPoidCache[$cacheKey] = $dbid
                return $dbid
            }
        }
    } catch {
        # keep fallback null
    }

    $script:PoDbidByPoidCache[$cacheKey] = $null
    return $null
}

function Try-DecodeChscQuoteLineKeyFromRowLog {
    param(
        [psobject]$ManifestRow
    )

    if ($null -eq $ManifestRow) { return $null }
    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if ($alloc -ne "oasis.CHSC_QUOTELINE.PK_CHSC_QUOTELINE") { return $null }

    $hex = [string](Get-PropertyValue -Object $ManifestRow -Name "rowlog2_hex")
    if ([string]::IsNullOrWhiteSpace($hex)) { return $null }

    $bytes = Convert-HexToBytes -Hex $hex
    if ($bytes.Length -lt 5) { return $null }

    $quoteId = [int64][BitConverter]::ToUInt32($bytes, 1)
    if ($quoteId -le 0) { return $null }
    $lineNumber = [int64][BitConverter]::ToUInt32($bytes, 5)
    if ($lineNumber -lt 0) { return $null }

    $tokens = @(Get-RowLogTextTokens -Bytes $bytes | Where-Object { $_ -match "^[A-Za-z0-9_]{3,32}$" })
    if ($tokens.Count -eq 0) { return $null }
    $dbid = ($tokens | Sort-Object Length -Descending | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($dbid)) { return $null }

    return [pscustomobject]@{
        DBID = [string]$dbid
        QUOTEID = [int64]$quoteId
        LINENUMBER = [int64]$lineNumber
    }
}

function Try-DecodeChscQuoteLineKeyFromRowLogFast {
    param([psobject]$ManifestRow)

    if ($null -eq $ManifestRow) { return $null }
    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if ($alloc -ne "oasis.CHSC_QUOTELINE.PK_CHSC_QUOTELINE") { return $null }

    $hex = [string](Get-PropertyValue -Object $ManifestRow -Name "rowlog2_hex")
    if ([string]::IsNullOrWhiteSpace($hex)) { return $null }

    $bytes = Convert-HexPrefixToBytes -Hex $hex -MaxBytes 320
    if ($bytes.Length -lt 9) { return $null }

    $quoteId = [int64][BitConverter]::ToUInt32($bytes, 1)
    $lineNumber = [int64][BitConverter]::ToUInt32($bytes, 5)
    if ($quoteId -le 0 -or $lineNumber -lt 0) { return $null }

    $tokens = @(Get-RowLogTextTokens -Bytes $bytes | Where-Object { $_ -match "^[A-Za-z0-9_]{6,32}$" })
    if ($tokens.Count -eq 0) { return $null }
    $dbid = ($tokens | Sort-Object Length -Descending | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($dbid)) { return $null }

    return [pscustomobject]@{
        DBID = [string]$dbid
        QUOTEID = [int64]$quoteId
        LINENUMBER = [int64]$lineNumber
    }
}

function Resolve-ChscQuoteDbidByQuoteId {
    param([int64]$QuoteId)

    if ($QuoteId -le 0) { return $null }
    $cacheKey = [string]$QuoteId
    if ($script:QuoteDbidByQuoteIdCache.ContainsKey($cacheKey)) {
        return $script:QuoteDbidByQuoteIdCache[$cacheKey]
    }

    $sql = @"
SELECT TOP (1) [DBID]
FROM [oasis].[CHSC_QUOTE] WITH (READUNCOMMITTED)
WHERE [QUOTEID] = $QuoteId
ORDER BY [DBID]
"@
    try {
        $dt = Invoke-SqlQuery -Sql $sql
        if ($dt.Rows.Count -gt 0) {
            $dbid = [string]$dt.Rows[0]["DBID"]
            if (-not [string]::IsNullOrWhiteSpace($dbid)) {
                $script:QuoteDbidByQuoteIdCache[$cacheKey] = $dbid
                return $dbid
            }
        }
    } catch {
        # keep fallback null
    }

    $script:QuoteDbidByQuoteIdCache[$cacheKey] = $null
    return $null
}

function Try-DecodeChscQuoteLineDeleteKeyFromRowLogPattern {
    param([psobject]$ManifestRow)

    if ($null -eq $ManifestRow) { return $null }
    $alloc = [string](Get-PropertyValue -Object $ManifestRow -Name "alloc_unit_name")
    if ($alloc -ne "oasis.CHSC_QUOTELINE.PK_CHSC_QUOTELINE") { return $null }

    foreach ($field in @("rowlog0_hex", "rowlog1_hex")) {
        $hex = [string](Get-PropertyValue -Object $ManifestRow -Name $field)
        if ([string]::IsNullOrWhiteSpace($hex)) { continue }
        $bytes = Convert-HexToBytes -Hex $hex
        if ($bytes.Length -lt 12) { continue }

        # Observed delete-key pattern for CHSC_QUOTELINE PK in rowlog0/1:
        # 30 00 DD 00 <QUOTEID:4 LE> <LINENUMBER:4 LE> ...
        if ($bytes[0] -ne 0x30 -or $bytes[1] -ne 0x00 -or $bytes[2] -ne 0xDD -or $bytes[3] -ne 0x00) { continue }

        $quoteId = [int64][BitConverter]::ToUInt32($bytes, 4)
        $lineNumber = [int64][BitConverter]::ToUInt32($bytes, 8)
        if ($quoteId -le 0 -or $lineNumber -lt 0 -or $lineNumber -gt 2000000000) { continue }

        $dbid = Resolve-ChscQuoteDbidByQuoteId -QuoteId $quoteId
        if ([string]::IsNullOrWhiteSpace($dbid)) { continue }

        return [pscustomobject]@{
            DBID = [string]$dbid
            QUOTEID = [int64]$quoteId
            LINENUMBER = [int64]$lineNumber
        }
    }

    return $null
}

function Try-DecodeWhereKeyFromRowLog {
    param(
        [psobject]$ManifestRow,
        [string]$SchemaName,
        [string]$TableName
    )

    if ($null -eq $ManifestRow) { return $null }
    $s = [string]$SchemaName
    $t = [string]$TableName

    if ($s.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and $t.Equals("CHSC_PO", [System.StringComparison]::OrdinalIgnoreCase)) {
        $decodedPo = Try-DecodeChscPoDeleteKeyFromIdxPoRow -ManifestRow $ManifestRow
        if ($null -ne $decodedPo) { return $decodedPo }
        return (Try-DecodeChscPoDeleteKeyFromPkRow -ManifestRow $ManifestRow)
    }

    if ($s.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and $t.Equals("CHSC_POLINE", [System.StringComparison]::OrdinalIgnoreCase)) {
        return (Try-DecodeChscPoLineKeyFromRowLog -ManifestRow $ManifestRow)
    }

    if ($s.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and $t.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase)) {
        $decoded = Try-DecodeChscQuoteLineKeyFromRowLog -ManifestRow $ManifestRow
        if ($null -ne $decoded) { return $decoded }
        return (Try-DecodeChscQuoteLineDeleteKeyFromRowLogPattern -ManifestRow $ManifestRow)
    }

    return $null
}

function Get-DecodedWhereKeyCached {
    param(
        [psobject]$ManifestRow,
        [string]$SchemaName,
        [string]$TableName
    )

    if ($null -eq $ManifestRow) { return $null }
    $mk = ([string](Get-PropertyValue -Object $ManifestRow -Name "manifest_key")).ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($mk)) {
        return (Try-DecodeWhereKeyFromRowLog -ManifestRow $ManifestRow -SchemaName $SchemaName -TableName $TableName)
    }
    if ($script:DecodedWhereKeyCache.ContainsKey($mk)) {
        return $script:DecodedWhereKeyCache[$mk]
    }
    $decoded = $null
    if (
        $SchemaName.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and
        $TableName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        $decoded = Try-DecodeChscQuoteLineKeyFromRowLogFast -ManifestRow $ManifestRow
    }
    if ($null -eq $decoded) {
        $decoded = Try-DecodeWhereKeyFromRowLog -ManifestRow $ManifestRow -SchemaName $SchemaName -TableName $TableName
    }
    $script:DecodedWhereKeyCache[$mk] = $decoded
    return $decoded
}

function Build-WhereClausesFromKeyObject {
    param(
        [psobject]$KeyObject,
        [pscustomobject[]]$Metadata
    )

    if ($null -eq $KeyObject) { return @() }
    if ($null -eq $Metadata -or $Metadata.Count -eq 0) { return @() }

    $metaByName = @{}
    foreach ($m in $Metadata) {
        $metaByName[[string]$m.column_name.ToUpperInvariant()] = $m
    }

    $clauses = New-Object System.Collections.Generic.List[string]
    foreach ($p in $KeyObject.PSObject.Properties) {
        $name = [string]$p.Name
        $key = $name.ToUpperInvariant()
        if (-not $metaByName.ContainsKey($key)) { continue }
        $col = $metaByName[$key]
        $safeCol = $name.Replace("]", "]]")
        $val = $p.Value
        $literal = if ($null -eq $val) { "NULL" } else { Convert-TypedValueToSqlLiteral -Value $val -Column $col }
        if ($literal -eq "NULL") {
            $clauses.Add("[$safeCol] IS NULL") | Out-Null
        } else {
            $clauses.Add("[$safeCol] = $literal") | Out-Null
        }
    }
    return @($clauses.ToArray())
}

function Get-KeyObjectSignature {
    param([psobject]$KeyObject)

    if ($null -eq $KeyObject) { return "" }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($KeyObject.PSObject.Properties | Sort-Object Name)) {
        $name = [string]$p.Name
        $val = if ($null -eq $p.Value) { "<NULL>" } else { [string]$p.Value }
        $parts.Add(("{0}={1}" -f $name.ToUpperInvariant(), $val.ToUpperInvariant())) | Out-Null
    }
    return ($parts -join ";")
}

function Test-RowDataMatchesDecodedKey {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [psobject]$DecodedKey
    )

    if ($null -eq $RowData) { return $false }
    if ($null -eq $DecodedKey) { return $true }
    if ($null -eq $Metadata -or $Metadata.Count -eq 0) { return $true }

    $metaByName = @{}
    foreach ($m in $Metadata) {
        $metaByName[[string]$m.column_name.ToUpperInvariant()] = $m
    }

    foreach ($p in $DecodedKey.PSObject.Properties) {
        $name = [string]$p.Name
        if (-not $RowData.Table.Columns.Contains($name)) { continue }
        $key = $name.ToUpperInvariant()
        if (-not $metaByName.ContainsKey($key)) { continue }

        $col = $metaByName[$key]
        $rowVal = $RowData[$name]
        if ($rowVal -is [System.DBNull]) { return $false }

        $rowSql = Convert-TypedValueToSqlLiteral -Value $rowVal -Column $col
        $keySql = if ($null -eq $p.Value) { "NULL" } else { Convert-TypedValueToSqlLiteral -Value $p.Value -Column $col }
        if ($rowSql -ne $keySql) { return $false }
    }

    return $true
}

function Apply-DecodedKeyToRowData {
    param(
        [System.Data.DataRow]$RowData,
        [pscustomobject[]]$Metadata,
        [psobject]$DecodedKey
    )

    if ($null -eq $RowData -or $null -eq $DecodedKey) { return $false }

    $metaByName = @{}
    foreach ($m in @($Metadata)) {
        $metaByName[[string]$m.column_name.ToUpperInvariant()] = $m
    }

    $changed = $false
    foreach ($p in $DecodedKey.PSObject.Properties) {
        $name = [string]$p.Name
        $key = $name.ToUpperInvariant()
        if (-not $RowData.Table.Columns.Contains($name)) { continue }
        if (-not $metaByName.ContainsKey($key)) { continue }
        $col = $metaByName[$key]
        $newVal = $p.Value
        $newSql = if ($null -eq $newVal) { "NULL" } else { Convert-TypedValueToSqlLiteral -Value $newVal -Column $col }
        $cur = $RowData[$name]
        $curSql = if ($cur -is [System.DBNull]) { "NULL" } else { Convert-TypedValueToSqlLiteral -Value $cur -Column $col }
        if ($curSql -ne $newSql) {
            if ($null -eq $newVal) { $RowData[$name] = [System.DBNull]::Value } else { $RowData[$name] = $newVal }
            $changed = $true
        }
    }
    return $changed
}

function New-StatementBlock {
    param(
        [string[]]$Lines
    )
    $action = ""
    $stmt = $null
    $confidence = "low"
    foreach ($ln in $Lines) {
        if (($ln -match '^--(INSERT|UPDATE|DELETE) \(') -and [string]::IsNullOrWhiteSpace($action)) {
            $action = $Matches[1]
        }
        if (($ln -match '^(INSERT|UPDATE|DELETE) ') -and -not $stmt) {
            $stmt = $ln
        }
        if ($ln -match 'confidence=(high|medium|low)') {
            $confidence = $Matches[1]
        }
    }
    $concrete = $false
    if ($stmt -and ($stmt -notmatch '/\*')) {
        $concrete = $true
    }
    return [pscustomobject]@{
        action = $action
        confidence = $confidence
        concrete = $concrete
        lines = @($Lines)
    }
}

function Split-GeneratedOutput {
    param([string[]]$Lines)

    $header = @()
    $blocks = @()
    $cur = @()
    $inBlock = $false

    foreach ($ln in $Lines) {
        if ($ln -match '^--(INSERT|UPDATE|DELETE) \(') {
            if ($cur.Length -gt 0) {
                $blocks += ,(New-StatementBlock -Lines $cur)
                $cur = @()
            }
            $inBlock = $true
        }

        if ($inBlock) {
            $cur += $ln
        } else {
            $header += $ln
        }
    }

    if ($cur.Length -gt 0) {
        $blocks += ,(New-StatementBlock -Lines $cur)
    }

    return [pscustomobject]@{
        header = $header
        blocks = $blocks
    }
}

function Build-OutputLines {
    param(
        [string[]]$Header,
        [object[]]$Blocks
    )

    $counts = @{
        INSERT = 0
        UPDATE = 0
        DELETE = 0
    }
    $high = 0
    $medium = 0
    $low = 0

    foreach ($b in $Blocks) {
        if ($counts.ContainsKey($b.action)) {
            $counts[$b.action]++
        }
        switch ($b.confidence) {
            "high" { $high++ }
            "medium" { $medium++ }
            default { $low++ }
        }
    }

    $out = New-Object System.Collections.Generic.List[string]
    $summaryLine = "-- Summary: total=$($Blocks.Count); insert=$($counts.INSERT); update=$($counts.UPDATE); delete=$($counts.DELETE); high=$high; medium=$medium; low=$low"
    $out.Add($summaryLine)
    foreach ($ln in $Header) {
        $out.Add($ln)
    }

    if ($Blocks.Count -eq 0) {
        $out.Add("-- No rows selected for hybrid reconstruction.")
    } else {
        foreach ($b in $Blocks) {
            foreach ($ln in $b.lines) {
                $out.Add($ln)
            }
        }
    }

    return @($out)
}

function Test-EventSafeForApply {
    param(
        [psobject]$Event,
        [string]$Mode
    )

    if ($null -eq $Event) {
        return [pscustomobject]@{
            safe = $false
            reason = "event_missing"
        }
    }

    if ($Mode -eq "off") {
        return [pscustomobject]@{
            safe = [bool]$Event.recovered
            reason = if ([bool]$Event.recovered) { "mode_off" } else { "not_recovered" }
        }
    }

    if (-not [bool]$Event.recovered) {
        return [pscustomobject]@{
            safe = $false
            reason = "not_recovered"
        }
    }

    $action = [string]$Event.action
    $confidence = [string]$Event.confidence
    $hobt = $Event.hobt_match
    $hasWhere = (@($Event.where_clauses).Count -gt 0)
    $fallbackMode = [string]$Event.fallback_mode

    switch ($action) {
        "INSERT" {
            if ($confidence -ne "high") {
                return [pscustomobject]@{ safe = $false; reason = "insert_requires_high_confidence" }
            }
            if ($hobt -ne $true) {
                return [pscustomobject]@{ safe = $false; reason = "insert_requires_hobt_match_true" }
            }
            if (-not $hasWhere) {
                return [pscustomobject]@{ safe = $false; reason = "insert_missing_where_key" }
            }
            return [pscustomobject]@{ safe = $true; reason = "insert_strict_pass" }
        }
        "DELETE" {
            if ($confidence -ne "high") {
                return [pscustomobject]@{ safe = $false; reason = "delete_requires_high_confidence" }
            }
            if ($hobt -ne $true) {
                return [pscustomobject]@{ safe = $false; reason = "delete_requires_hobt_match_true" }
            }
            if (-not $hasWhere) {
                return [pscustomobject]@{ safe = $false; reason = "delete_missing_where_key" }
            }
            return [pscustomobject]@{ safe = $true; reason = "delete_strict_pass" }
        }
        "UPDATE" {
            if (-not $hasWhere) {
                return [pscustomobject]@{ safe = $false; reason = "update_missing_where_key" }
            }
            if ($fallbackMode -eq "adaptive_replace") {
                return [pscustomobject]@{ safe = $false; reason = "update_fell_back_to_replace" }
            }
            return [pscustomobject]@{ safe = $true; reason = "update_strict_pass" }
        }
        default {
            return [pscustomobject]@{
                safe = $false
                reason = "unsupported_action"
            }
        }
    }
}

$manifestScopeRows = @($manifest.records | Where-Object {
    ([string]$_.schema_name).Equals($targetSchema, [System.StringComparison]::OrdinalIgnoreCase) -and
    ([string]$_.table_name).Equals($targetName, [System.StringComparison]::OrdinalIgnoreCase) -and
    ([string]$_.action -in @("INSERT", "UPDATE", "DELETE")) -and
    (([string]$_.context_name).ToUpperInvariant() -ne "LCX_PFS")
})

$baseRows = @($manifestScopeRows | Where-Object { Test-IsBaseRowManifestRecord -Row $_ })
$manifestRows = @()
if ($baseRows.Count -gt 0) {
    $manifestRows = @($baseRows)

    $baseInsertCount = @($baseRows | Where-Object { ([string]$_.action).ToUpperInvariant() -eq "INSERT" }).Count
    $insertLeafGroups = @(
        $manifestScopeRows |
            Where-Object {
                ([string]$_.action).ToUpperInvariant() -eq "INSERT" -and
                ([string]$_.context_name).ToUpperInvariant() -eq "LCX_INDEX_LEAF" -and
                -not [string]::IsNullOrWhiteSpace([string]$_.alloc_unit_name)
            } |
            Group-Object alloc_unit_name |
            Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } }
    )

    if ($insertLeafGroups.Count -gt 0) {
        $bestInsertLeaf = @($insertLeafGroups[0].Group)
        $bestInsertLeafCount = $bestInsertLeaf.Count
        if ($baseInsertCount -eq 0 -or ($baseInsertCount -lt 10 -and $bestInsertLeafCount -ge 100)) {
            $dedup = @{}
            $reduced = New-Object System.Collections.Generic.List[object]
            $combined = @(
                @($baseRows | Where-Object { ([string]$_.action).ToUpperInvariant() -ne "INSERT" }) +
                $bestInsertLeaf
            )
            foreach ($rr in @($combined | Sort-Object @{ Expression = { Parse-CommitTime -Text ([string](Get-PropertyValue -Object $_ -Name "commit_time")) } }, @{ Expression = { Get-LsnSortKey -LsnText ([string](Get-PropertyValue -Object $_ -Name "current_lsn")) } })) {
                $k = ("{0}|{1}|{2}" -f ([string](Get-PropertyValue -Object $rr -Name "action")).ToUpperInvariant(), [string](Get-PropertyValue -Object $rr -Name "tx_id"), [string](Get-PropertyValue -Object $rr -Name "current_lsn")).ToUpperInvariant()
                if ($dedup.ContainsKey($k)) { continue }
                $dedup[$k] = $true
                $reduced.Add($rr) | Out-Null
            }
            $manifestRows = @($reduced.ToArray())
        }
    }
} else {
    $manifestRows = @($manifestScopeRows)
}

$hybridByKey = @{}
foreach ($h in @($hybrid.records)) {
    $k = ([string]$h.manifest_key).ToUpperInvariant()
    if (-not $hybridByKey.ContainsKey($k)) {
        $hybridByKey[$k] = New-Object System.Collections.Generic.List[object]
    }
    $hybridByKey[$k].Add($h)
}

# Per transaction: collapse index fan-out to canonical logical row events.
$selected = New-Object System.Collections.Generic.List[object]
$byTx = $manifestRows | Group-Object tx_id
$txRowsById = @{}
foreach ($txGroup in $byTx) {
    $txRows = @($txGroup.Group)
    $txKey = [string]$txGroup.Name
    if (-not [string]::IsNullOrWhiteSpace($txKey)) {
        $txRowsById[$txKey.ToUpperInvariant()] = $txRows
    }
    $collapsed = @(Collapse-TxRows -Rows $txRows -SchemaName $targetSchema -TableName $targetName)
    if ($collapsed.Count -eq 0) {
        $collapsed = $txRows
    }

    $txHasDecodableDelete = $false
    foreach ($txr in $txRows) {
        if (([string](Get-PropertyValue -Object $txr -Name "action")).ToUpperInvariant() -ne "DELETE") { continue }
        $dk = Get-DecodedWhereKeyCached -ManifestRow $txr -SchemaName $targetSchema -TableName $targetName
        if ($null -ne $dk) { $txHasDecodableDelete = $true; break }
    }
    $seenTxDeleteKeys = @{}

    foreach ($r in $collapsed) {
        if (Should-SkipInternalDeleteCompanionRow -Row $r -TxRows $txRows) { continue }
        if (([string](Get-PropertyValue -Object $r -Name "action")).ToUpperInvariant() -eq "DELETE" -and $txHasDecodableDelete) {
            $dk = Get-DecodedWhereKeyCached -ManifestRow $r -SchemaName $targetSchema -TableName $targetName
            if ($null -eq $dk) { continue }
            $sig = Get-KeyObjectSignature -KeyObject $dk
            if (-not [string]::IsNullOrWhiteSpace($sig)) {
                if ($seenTxDeleteKeys.ContainsKey($sig)) { continue }
                $seenTxDeleteKeys[$sig] = $true
            }
        }
        $selected.Add($r) | Out-Null
    }
}

$ordered = @($selected | Sort-Object @{ Expression = { Parse-CommitTime -Text ([string]$_.commit_time) } }, @{ Expression = { [string]$_.current_lsn } })

$decodeEnabled = (-not $DisableDecode) -and ($ServerInstance -and $Database)
$metadata = @()
$indexes = @()
$whereKeyColumns = @()
$whereKeyLabel = "none"
if ($decodeEnabled) {
    try {
        $metadata = @(Get-TableMetadata -SchemaName $targetSchema -TableName $targetName)
        $indexes = @(Get-TableIndexes -SchemaName $targetSchema -TableName $targetName)
        $whereSpec = Resolve-WhereKeyColumns -Metadata $metadata -Indexes $indexes
        $whereKeyColumns = @($whereSpec.columns)
        $whereKeyLabel = [string]$whereSpec.label
    } catch {
        Write-Warning ("Decode mode disabled due to metadata load failure: {0}" -f $_.Exception.Message)
        $decodeEnabled = $false
    }
}

if ($decodeEnabled -and -not $DisableLiveRowLookup) {
    if ($targetSchema.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and $targetName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase)) {
        try {
            [void](Prefetch-ChscQuoteLineRowsByDecodedKeys -Rows $ordered -Metadata $metadata)
        } catch {
            # Keep normal per-row live fallback on prefetch failure.
        }
    }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- Hybrid reconstructed DML for $TargetTable")
$lines.Add("-- Source manifest: $ManifestPath")
$lines.Add("-- Source hybrid match: $HybridPath")
$lines.Add("-- Generated UTC: $((Get-Date).ToUniversalTime().ToString('o'))")
$lines.Add("-- Decode mode: $decodeEnabled")
$lines.Add("-- Heuristics profile: $HeuristicsProfile")
$lines.Add("-- Byte ops mode: $(if ($UseLegacyByteOps) { 'legacy' } else { 'optimized' })")
$lines.Add("-- Adaptive fast replace (non-high confidence): $AdaptiveFastReplaceNonHighConfidence")
if ($MaxRowLogPairs -gt 0) {
    $lines.Add("-- Max rowlog pairs per event: $MaxRowLogPairs")
}
$lines.Add("-- Apply safety mode: $ApplySafetyMode")
if ($decodeEnabled) {
    if (-not [string]::IsNullOrWhiteSpace($MetadataSnapshotPath)) {
        $lines.Add("-- Metadata source: static snapshot ($MetadataSnapshotPath)")
    } else {
        $lines.Add("-- Metadata source: $MetadataServerInstance/$MetadataDatabase")
    }
    $lines.Add("-- Row source: $ServerInstance/$Database")
    $lines.Add("-- WHERE key source: $whereKeyLabel")
}
$lines.Add("")

$counts = @{
    INSERT = 0
    UPDATE = 0
    DELETE = 0
}
$high = 0
$medium = 0
$low = 0
$eventRecords = New-Object System.Collections.Generic.List[object]

foreach ($r in $ordered) {
    $eventSw = [System.Diagnostics.Stopwatch]::StartNew()
    $eventRowResolveStart = [int64]$phaseTiming.row_resolve_ms
    $eventDecodeStart = [int64]$phaseTiming.heuristic_decode_ms
    $eventSqlRenderStart = [int64]$phaseTiming.sql_render_ms

    $action = [string]$r.action
    $lsn = [string]$r.current_lsn
    $tx = [string]$r.tx_id
    $alloc = [string]$r.alloc_unit_name
    $commit = [string]$r.commit_time
    $mk = ([string]$r.manifest_key).ToUpperInvariant()
    $phaseTiming.events_total++
    switch ($action) {
        "UPDATE" { $phaseTiming.events_update++ }
        "INSERT" { $phaseTiming.events_insert++ }
        "DELETE" { $phaseTiming.events_delete++ }
    }

    $evidence = $null
    if ($hybridByKey.ContainsKey($mk) -and $hybridByKey[$mk].Count -gt 0) {
        $evidence = $hybridByKey[$mk] | Sort-Object @{ Expression = { if ($_.hobt_match) { 0 } else { 1 } } }, offset | Select-Object -First 1
    }

    $confidence = "low"
    if ($evidence -and $evidence.hobt_match) {
        $confidence = "high"
        $high++
    } elseif ($alloc -like "*.PK_*") {
        $confidence = "medium"
        $medium++
    } else {
        $low++
    }

    $sourceTag = if ($evidence) { "live+offline" } else { "live-only" }
    $hobtTag = if ($evidence) { ("hobt_match={0}" -f [string]$evidence.hobt_match) } else { "hobt_match=n/a" }

    $lines.Add("--$action ($lsn)")
    $lines.Add("-- tx=$tx; commit=$commit; confidence=$confidence; source=$sourceTag; $hobtTag; alloc=$alloc")

    $wroteConcrete = $false
    $rowData = $null
    $rowDataSourceLsn = $null
    $rowDataSourceMode = $null
    $redoSqlStatements = New-Object System.Collections.Generic.List[string]
    $undoSqlStatements = New-Object System.Collections.Generic.List[string]
    $changedForEvent = New-Object System.Collections.Generic.List[object]
    $eventWhereClauses = @()
    $beforeRowForEvent = $null
    $afterRowForEvent = $null
    $fallbackMode = $null
    $preDecodedDeleteWhereClauses = @()
    $skipDeleteRowResolve = $false
    $txRows = @()
    $txKeyUpper = $tx.ToUpperInvariant()
    if ($txRowsById.ContainsKey($txKeyUpper)) {
        $txRows = @($txRowsById[$txKeyUpper])
    }
    if ($txRows.Count -eq 0) {
        $txRows = @($r)
    }

    $decodeRows = @($r)
    if ($decodeEnabled -and $action -eq "UPDATE") {
        # Hot-path guard: linking every row against full tx rows is O(n^2) on large transactions.
        # For CHSC_QUOTELINE we can decode reliably from the selected row key and keep fallback logic.
        $skipExpensiveTxLinking = (
            $targetSchema.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and
            $targetName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase) -and
            $txRows.Count -gt 64
        )
        if ($skipExpensiveTxLinking) {
            $decodeRows = @($r)
        } else {
            $linkedRows = @(Get-LinkedTxRowsForDecode -SelectedRow $r -TxRows $txRows -TargetSchema $targetSchema -TargetTable $targetName)
            if ($linkedRows.Count -gt 0) {
                $decodeRows = @($linkedRows)
            }
        }
    }

    if ($decodeEnabled -and $action -eq "DELETE") {
        $needDeleteRowImage = ($GenerateUndo -or $ExportBeforeAfter -or $ExportRowHistory)
        if (-not $needDeleteRowImage) {
            $skipDeleteRowResolve = $true
            $decodedDeleteKey = Get-DecodedWhereKeyCached -ManifestRow $r -SchemaName $targetSchema -TableName $targetName
            if ($null -eq $decodedDeleteKey) {
                foreach ($cand in @($decodeRows)) {
                    $decodedDeleteKey = Get-DecodedWhereKeyCached -ManifestRow $cand -SchemaName $targetSchema -TableName $targetName
                    if ($null -ne $decodedDeleteKey) { break }
                }
            }
            if ($null -ne $decodedDeleteKey) {
                $preDecodedDeleteWhereClauses = @(Build-WhereClausesFromKeyObject -KeyObject $decodedDeleteKey -Metadata $metadata)
            }
        }
    }

    if ($decodeEnabled -and -not $skipDeleteRowResolve) {
        $swRowResolve = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $rowResolveCandidates = @($r)
            if ($action -eq "UPDATE") {
                $useFastSingleCandidate = (
                    $HeuristicsProfile -eq "fast" -and
                    $targetSchema.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and
                    $targetName.Equals("CHSC_QUOTELINE", [System.StringComparison]::OrdinalIgnoreCase)
                )
                if (-not $useFastSingleCandidate) {
                    $rowResolveCandidates = @($decodeRows)
                }
            }
            $resolvedRow = Resolve-RowDataFromCandidateRows -SchemaName $targetSchema -TableName $targetName -CandidateRows $rowResolveCandidates -Metadata $metadata -NoLiveFallback $DisableLiveRowLookup -AllowOfflineKeyPatch $OfflineAllowKeyPatch
            if ($resolvedRow -and $resolvedRow.row_data) {
                $rowData = $resolvedRow.row_data
                if ($resolvedRow.source_row) {
                    $rowDataSourceLsn = [string](Get-PropertyValue -Object $resolvedRow.source_row -Name "current_lsn")
                }
                if ($resolvedRow.source_mode) {
                    $rowDataSourceMode = [string]$resolvedRow.source_mode
                    $lines.Add("-- resolver: row_data_source=$rowDataSourceMode")
                }
            }
        } finally {
            $swRowResolve.Stop()
            $phaseTiming.row_resolve_ms += [int64]$swRowResolve.ElapsedMilliseconds
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($rowDataSourceLsn) -and $rowDataSourceLsn -ne $lsn) {
        $lines.Add("-- resolver: row_data_from_lsn=$rowDataSourceLsn")
    }

    switch ($action) {
        "UPDATE" {
            $whereClauses = @()
            $decodedWhereKey = $null
            $decodedWhereClauses = @()
            if ($decodeEnabled) {
                $decodedWhereKey = Get-DecodedWhereKeyCached -ManifestRow $r -SchemaName $targetSchema -TableName $targetName
                if ($null -eq $decodedWhereKey) {
                    foreach ($cand in @($decodeRows)) {
                        $decodedWhereKey = Get-DecodedWhereKeyCached -ManifestRow $cand -SchemaName $targetSchema -TableName $targetName
                        if ($null -ne $decodedWhereKey) { break }
                    }
                }
                if ($null -ne $decodedWhereKey) {
                    $decodedWhereClauses = @(Build-WhereClausesFromKeyObject -KeyObject $decodedWhereKey -Metadata $metadata)
                }
            }
            if ($decodeEnabled -and $rowData -ne $null -and $whereKeyColumns.Count -gt 0) {
                $whereClauses = @(Build-WhereClausesFromRowData -RowData $rowData -WhereKeyColumns $whereKeyColumns)
                $eventWhereClauses = @($whereClauses)
                $afterRowForEvent = Convert-RowDataToObject -RowData $rowData -Metadata $metadata
                $forceReplaceFast = ($UpdateMode -eq "adaptive" -and $AdaptiveFastReplaceNonHighConfidence -and $confidence -ne "high")
                if ($UpdateMode -eq "replace" -or $forceReplaceFast) {
                    $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                    try {
                        $insertSql = Build-InsertFromRowData -SchemaName $targetSchema -TableName $targetName -RowData $rowData -Metadata $metadata -IncludeNulls $true
                        if ($whereClauses.Count -gt 0 -and $insertSql) {
                            $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE $($whereClauses -join ' AND ');"
                            if ($forceReplaceFast) {
                                $lines.Add("-- adaptive fast-path: replace mode (confidence=$confidence)")
                            }
                            $lines.Add($deleteSql)
                            $lines.Add($insertSql)
                            $redoSqlStatements.Add($deleteSql)
                            $redoSqlStatements.Add($insertSql)
                            $fallbackMode = if ($forceReplaceFast) { "adaptive_replace_fast" } else { "replace" }
                            $wroteConcrete = $true
                        }
                    } finally {
                        $swSqlRender.Stop()
                        $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                    }
                }

                if (-not $wroteConcrete) {
                    $swPairBuild = [System.Diagnostics.Stopwatch]::StartNew()
                    $pairKeys = @{}
                    $rowLogPairs = New-Object System.Collections.Generic.List[object]
                    Add-RowLogPairsFromRowsOperationAware -Rows @($decodeRows) -Pairs $rowLogPairs -PairKeys $pairKeys -SourcePrefix "linked"
                    Add-LinkedAdjacentRowLogPairs -Rows @($decodeRows) -Pairs $rowLogPairs -PairKeys $pairKeys -SourcePrefix "linked"

                    # For index key updates encoded as DELETE+INSERT pairs, synthesize old/new rowlog pair.
                    $txDeletes = @($txRows | Where-Object { ([string]$_.operation_name) -eq "LOP_DELETE_ROWS" })
                    $txInserts = @($txRows | Where-Object { ([string]$_.operation_name) -eq "LOP_INSERT_ROWS" })
                    foreach ($d in $txDeletes) {
                        $dAlloc = [string](Get-PropertyValue -Object $d -Name "alloc_unit_name")
                        $ins = @($txInserts | Where-Object { ([string](Get-PropertyValue -Object $_ -Name "alloc_unit_name")) -eq $dAlloc } | Sort-Object current_lsn)
                        if ($ins.Count -gt 0) {
                            $firstInsert = $ins[0]
                            Add-RowLogPair -Pairs $rowLogPairs -PairKeys $pairKeys `
                                -OldHex ([string](Get-PropertyValue -Object $d -Name "rowlog0_hex")) `
                                -NewHex ([string](Get-PropertyValue -Object $firstInsert -Name "rowlog0_hex")) `
                                -SourceTag ("tx:{0}:delins" -f $dAlloc)
                        }
                    }

                    if ($HeuristicsProfile -eq "full") {
                        # Add a synthetic aggregate pair to catch updates split across multiple rowlog payload slots.
                        $aggOldBytes = New-Object System.Collections.Generic.List[byte]
                        $aggNewBytes = New-Object System.Collections.Generic.List[byte]
                        foreach ($pair in $rowLogPairs) {
                            try {
                                $ob = Convert-HexToBytes -Hex ([string]$pair.old_hex)
                                if ($ob.Length -gt 0) { $aggOldBytes.AddRange($ob) }
                            } catch {}
                            try {
                                $nb = Convert-HexToBytes -Hex ([string]$pair.new_hex)
                                if ($nb.Length -gt 0) { $aggNewBytes.AddRange($nb) }
                            } catch {}
                        }
                        if ($aggOldBytes.Count -gt 0 -and $aggNewBytes.Count -gt 0) {
                            Add-RowLogPair -Pairs $rowLogPairs -PairKeys $pairKeys `
                                -OldHex (Bytes-ToHexLiteral -Bytes $aggOldBytes.ToArray()) `
                                -NewHex (Bytes-ToHexLiteral -Bytes $aggNewBytes.ToArray()) `
                                -SourceTag "aggregate:0|2|4->1|3|5"
                        }
                    }

                    $decodePairs = New-Object System.Collections.Generic.List[object]
                    foreach ($pair in $rowLogPairs) {
                        $decodePairs.Add($pair) | Out-Null
                    }
                    if ($MaxRowLogPairs -gt 0 -and $decodePairs.Count -gt $MaxRowLogPairs) {
                        $limitedPairs = New-Object System.Collections.Generic.List[object]
                        foreach ($pair in @($decodePairs | Select-Object -First $MaxRowLogPairs)) {
                            $limitedPairs.Add($pair) | Out-Null
                        }
                        $decodePairs = $limitedPairs
                    }
                    $swPairBuild.Stop()
                    $phaseTiming.pair_build_ms += [int64]$swPairBuild.ElapsedMilliseconds

                    $swHeuristicDecode = [System.Diagnostics.Stopwatch]::StartNew()
                    $changedByCol = @{}
                    if ($HeuristicsProfile -eq "full") {
                        foreach ($pair in $decodePairs) {
                            try {
                                $candidate = @(Get-UpdatedColumns -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                                Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                            } catch {
                                continue
                            }
                        }
                    }

                    foreach ($pair in $decodePairs) {
                        $candidate = @(Get-UpdatedColumnsTextHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex -AllowMultiple $true)
                        Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                    }

                    foreach ($pair in $decodePairs) {
                        $candidate = @(Get-UpdatedColumnsNumericHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                        Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                    }

                    foreach ($pair in $decodePairs) {
                        $candidate = @(Get-UpdatedColumnsTemporalHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                        Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                    }

                    if ($HeuristicsProfile -eq "full") {
                        foreach ($pair in $decodePairs) {
                            $candidate = @(Get-UpdatedColumnsTextPresenceHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                            Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                        }

                        foreach ($pair in $decodePairs) {
                            if (-not ([string]$pair.source -like "*:delins")) { continue }
                            $candidate = @(Get-UpdatedColumnsShortTextHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                            Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                        }

                        foreach ($pair in $decodePairs) {
                            $candidate = @(Get-UpdatedColumnsNumericPresenceHeuristic -RowData $rowData -Metadata $metadata -RowLogOldHex $pair.old_hex -RowLogNewHex $pair.new_hex)
                            Merge-ChangedCandidateSet -Target $changedByCol -Candidates $candidate
                        }
                    }

                    $changed = @($changedByCol.Values)
                    $swHeuristicDecode.Stop()
                    $phaseTiming.heuristic_decode_ms += [int64]$swHeuristicDecode.ElapsedMilliseconds

                    if ($changed.Count -gt 0) {
                        $setClauses = @()
                        $hasUnknownOld = $false
                        foreach ($chg in ($changed | Sort-Object column_name)) {
                            $safeCol = $chg.column_name.Replace("]", "]]")
                            $setClauses += "[$safeCol] = $($chg.new_sql)"
                            $changedForEvent.Add([pscustomobject]@{
                                column_name = [string]$chg.column_name
                                old_sql = [string]$chg.old_sql
                                new_sql = [string]$chg.new_sql
                            })
                            if ([string]$chg.old_sql -eq "[unknown]") {
                                $hasUnknownOld = $true
                                $lines.Add("-- changed: [$($chg.column_name)] [old unknown] -> $($chg.new_sql)")
                            } else {
                                $lines.Add("-- changed: [$($chg.column_name)] $($chg.old_sql) -> $($chg.new_sql)")
                            }
                        }

                        if ($setClauses.Count -gt 0 -and $whereClauses.Count -gt 0) {
                            $useUpdateInAdaptive = ($confidence -eq "high" -and -not $hasUnknownOld -and $whereKeyLabel -eq "primary_key")
                            if ($UpdateMode -eq "adaptive" -and -not $useUpdateInAdaptive) {
                                $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                                try {
                                    $insertSql = Build-InsertFromRowData -SchemaName $targetSchema -TableName $targetName -RowData $rowData -Metadata $metadata -IncludeNulls $true
                                    if ($insertSql) {
                                        $lines.Add("-- adaptive: falling back to replace mode (confidence=$confidence, old_unknown=$hasUnknownOld)")
                                        $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE $($whereClauses -join ' AND ');"
                                        $lines.Add($deleteSql)
                                        $lines.Add($insertSql)
                                        $redoSqlStatements.Add($deleteSql)
                                        $redoSqlStatements.Add($insertSql)
                                        $fallbackMode = "adaptive_replace"
                                        $undoUpdateSql = Build-UndoUpdateSql `
                                            -SchemaName $targetSchema `
                                            -TableName $targetName `
                                            -ChangedColumns @($changedForEvent.ToArray()) `
                                            -WhereClauses @($whereClauses | ForEach-Object { [string]$_ })
                                        if ($undoUpdateSql) {
                                            $undoSqlStatements.Add($undoUpdateSql)
                                        }
                                        $beforeObj = [ordered]@{}
                                        foreach ($chg in @($changedForEvent | Where-Object { [string]$_.old_sql -ne "[unknown]" })) {
                                            $beforeObj[[string]$chg.column_name] = [string]$chg.old_sql
                                        }
                                        if ($beforeObj.Count -gt 0) {
                                            $beforeRowForEvent = [pscustomobject]$beforeObj
                                        }
                                        $wroteConcrete = $true
                                    }
                                } finally {
                                    $swSqlRender.Stop()
                                    $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                                }
                            }
                            if (-not $wroteConcrete) {
                                $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                                try {
                                    $updateSql = "UPDATE [$targetSchema].[$targetName] SET $($setClauses -join ', ') WHERE $($whereClauses -join ' AND ');"
                                    $lines.Add($updateSql)
                                    $redoSqlStatements.Add($updateSql)
                                    $undoUpdateSql = Build-UndoUpdateSql `
                                        -SchemaName $targetSchema `
                                        -TableName $targetName `
                                        -ChangedColumns @($changedForEvent.ToArray()) `
                                        -WhereClauses @($whereClauses | ForEach-Object { [string]$_ })
                                    if ($undoUpdateSql) {
                                        $undoSqlStatements.Add($undoUpdateSql)
                                    }
                                    $beforeObj = [ordered]@{}
                                    foreach ($chg in @($changedForEvent | Where-Object { [string]$_.old_sql -ne "[unknown]" })) {
                                        $beforeObj[[string]$chg.column_name] = [string]$chg.old_sql
                                    }
                                    if ($beforeObj.Count -gt 0) {
                                        $beforeRowForEvent = [pscustomobject]$beforeObj
                                    }
                                    $wroteConcrete = $true
                                } finally {
                                    $swSqlRender.Stop()
                                    $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                                }
                            }
                        }
                    }
                }

                if (-not $wroteConcrete -and $whereClauses.Count -gt 0 -and ($UpdateMode -eq "adaptive" -or $UpdateMode -eq "replace")) {
                    $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                    try {
                        $insertSql = Build-InsertFromRowData -SchemaName $targetSchema -TableName $targetName -RowData $rowData -Metadata $metadata -IncludeNulls $true
                        if ($insertSql) {
                            $lines.Add("-- fallback: replace mode (no decodable changed columns)")
                            $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE $($whereClauses -join ' AND ');"
                            $lines.Add($deleteSql)
                            $lines.Add($insertSql)
                            $redoSqlStatements.Add($deleteSql)
                            $redoSqlStatements.Add($insertSql)
                            $fallbackMode = if ($UpdateMode -eq "adaptive") { "adaptive_replace" } else { "replace" }
                            $wroteConcrete = $true
                        }
                    } finally {
                        $swSqlRender.Stop()
                        $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                    }
                }
            }

            if (-not $wroteConcrete) {
                if ($decodedWhereClauses.Count -gt 0) {
                    $eventWhereClauses = @($decodedWhereClauses)
                    $lines.Add("UPDATE [$targetSchema].[$targetName] SET /* decoded changed columns */ WHERE $($decodedWhereClauses -join ' AND ');")
                    $lines.Add("-- fallback: WHERE key decoded from rowlog; SET values unresolved")
                } else {
                    $lines.Add("UPDATE [$targetSchema].[$targetName] SET /* decoded changed columns */ WHERE /* PK predicate */;")
                }
            }
            $counts.UPDATE++
        }
        "INSERT" {
            if ($decodeEnabled -and $rowData -ne $null) {
                $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $cols = @()
                    $vals = @()
                    foreach ($col in $metadata) {
                        $cn = $col.column_name
                        if (-not $rowData.Table.Columns.Contains($cn)) { continue }
                        $v = $rowData[$cn]
                        if ($v -is [System.DBNull]) { continue }
                        $cols += "[" + $cn.Replace("]", "]]") + "]"
                        $vals += (Convert-TypedValueToSqlLiteral -Value $v -Column $col)
                    }
                    if ($cols.Count -gt 0) {
                        $insertSql = "INSERT INTO [$targetSchema].[$targetName] ($($cols -join ', ')) VALUES ($($vals -join ', '));"
                        $lines.Add($insertSql)
                        $redoSqlStatements.Add($insertSql)
                        $afterRowForEvent = Convert-RowDataToObject -RowData $rowData -Metadata $metadata
                        if ($whereKeyColumns.Count -gt 0) {
                            $whereClauses = @(Build-WhereClausesFromRowData -RowData $rowData -WhereKeyColumns $whereKeyColumns)
                            $eventWhereClauses = @($whereClauses)
                            if ($whereClauses.Count -gt 0) {
                                $undoSqlStatements.Add("DELETE FROM [$targetSchema].[$targetName] WHERE $($whereClauses -join ' AND ');")
                            }
                        }
                        $wroteConcrete = $true
                    }
                } finally {
                    $swSqlRender.Stop()
                    $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                }
            }
            if (-not $wroteConcrete) {
                $lines.Add("INSERT INTO [$targetSchema].[$targetName] (/* columns */) VALUES (/* values */);")
            }
            $counts.INSERT++
        }
        "DELETE" {
            if ($decodeEnabled -and $rowData -ne $null -and $whereKeyColumns.Count -gt 0) {
                $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $whereClauses = @()
                    foreach ($kcol in $whereKeyColumns) {
                        if (-not $rowData.Table.Columns.Contains($kcol.column_name)) { continue }
                        $safeKey = $kcol.column_name.Replace("]", "]]")
                        $whereClauses += "[$safeKey] = $(Convert-TypedValueToSqlLiteral -Value $rowData[$kcol.column_name] -Column $kcol)"
                    }
                    $eventWhereClauses = @($whereClauses)
                    if ($whereClauses.Count -gt 0) {
                        $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE $($whereClauses -join ' AND ');"
                        $lines.Add($deleteSql)
                        $redoSqlStatements.Add($deleteSql)
                        $beforeRowForEvent = Convert-RowDataToObject -RowData $rowData -Metadata $metadata
                        $undoInsertSql = Build-InsertFromRowData -SchemaName $targetSchema -TableName $targetName -RowData $rowData -Metadata $metadata -IncludeNulls $true
                        if ($undoInsertSql) {
                            $undoSqlStatements.Add($undoInsertSql)
                        }
                        $wroteConcrete = $true
                    }
                } finally {
                    $swSqlRender.Stop()
                    $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                }
            }
            if (-not $wroteConcrete) {
                $decodedWhereKey = $null
                $decodedWhereClauses = @($preDecodedDeleteWhereClauses)
                if ($decodeEnabled) {
                    if ($decodedWhereClauses.Count -eq 0) {
                        $decodedWhereKey = Get-DecodedWhereKeyCached -ManifestRow $r -SchemaName $targetSchema -TableName $targetName
                        if ($null -eq $decodedWhereKey) {
                            foreach ($cand in @($decodeRows)) {
                                $decodedWhereKey = Get-DecodedWhereKeyCached -ManifestRow $cand -SchemaName $targetSchema -TableName $targetName
                                if ($null -ne $decodedWhereKey) { break }
                            }
                        }
                        if ($null -ne $decodedWhereKey) {
                            $decodedWhereClauses = @(Build-WhereClausesFromKeyObject -KeyObject $decodedWhereKey -Metadata $metadata)
                        }
                    }
                }
                if ($decodedWhereClauses.Count -gt 0) {
                    $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                    try {
                        $eventWhereClauses = @($decodedWhereClauses)
                        $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE $($decodedWhereClauses -join ' AND ');"
                        $lines.Add($deleteSql)
                        $lines.Add("-- fallback: DELETE WHERE decoded from rowlog")
                        $redoSqlStatements.Add($deleteSql)
                        $wroteConcrete = $true
                    } finally {
                        $swSqlRender.Stop()
                        $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                    }
                }
            }
            if (-not $wroteConcrete -and $targetSchema.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase) -and $targetName.Equals("CHSC_PO", [System.StringComparison]::OrdinalIgnoreCase)) {
                $decoded = Try-DecodeChscPoDeleteKeyFromIdxPoRow -ManifestRow $r
                if ($decoded) {
                    $swSqlRender = [System.Diagnostics.Stopwatch]::StartNew()
                    try {
                    $safeDbid = ([string]$decoded.DBID).Replace("'", "''")
                    $deleteSql = "DELETE FROM [$targetSchema].[$targetName] WHERE [DBID] = '$safeDbid' AND [POID] = $([int64]$decoded.POID);"
                    $lines.Add($deleteSql)
                    $redoSqlStatements.Add($deleteSql)
                    $eventWhereClauses = @("[DBID] = '$safeDbid'", "[POID] = $([int64]$decoded.POID)")
                    $wroteConcrete = $true
                    } finally {
                        $swSqlRender.Stop()
                        $phaseTiming.sql_render_ms += [int64]$swSqlRender.ElapsedMilliseconds
                    }
                }
            }
            if (-not $wroteConcrete) {
                $lines.Add("DELETE FROM [$targetSchema].[$targetName] WHERE /* PK predicate */;")
            }
            $counts.DELETE++
        }
    }
    $hobtMatchValue = $null
    if ($evidence -and ($evidence.PSObject.Properties.Name -contains "hobt_match")) {
        $rawHobt = $evidence.hobt_match
        if ($rawHobt -is [bool]) {
            $hobtMatchValue = [bool]$rawHobt
        } elseif ($rawHobt -is [string]) {
            $tmpBool = $false
            if ([bool]::TryParse([string]$rawHobt, [ref]$tmpBool)) {
                $hobtMatchValue = $tmpBool
            }
        } elseif ($rawHobt -is [int] -or $rawHobt -is [long]) {
            $hobtMatchValue = ([int64]$rawHobt -ne 0)
        }
    }

    $eventMap = [ordered]@{}
    $eventMap["manifest_key"] = [string]$mk
    $eventMap["action"] = [string]$action
    $eventMap["current_lsn"] = [string]$lsn
    $eventMap["tx_id"] = [string]$tx
    $eventMap["commit_time"] = [string]$commit
    $eventMap["alloc_unit_name"] = [string]$alloc
    $eventMap["confidence"] = [string]$confidence
    $eventMap["source"] = [string]$sourceTag
    $eventMap["hobt_match"] = $hobtMatchValue
    $eventMap["recovered"] = [bool]$wroteConcrete
    $eventMap["row_data_source_mode"] = if ([string]::IsNullOrWhiteSpace($rowDataSourceMode)) { $null } else { $rowDataSourceMode }
    $eventMap["update_mode"] = [string]$UpdateMode
    $eventMap["fallback_mode"] = if ($null -eq $fallbackMode) { $null } else { [string]$fallbackMode }
    $eventMap["where_clauses"] = @($eventWhereClauses | ForEach-Object { [string]$_ })
    $eventMap["changed_columns"] = @($changedForEvent.ToArray())
    $eventMap["redo_statements"] = @($redoSqlStatements.ToArray())
    $eventMap["undo_statements"] = @($undoSqlStatements.ToArray())
    $eventMap["before_row"] = $beforeRowForEvent
    $eventMap["after_row"] = $afterRowForEvent
    $safety = Test-EventSafeForApply -Event ([pscustomobject]$eventMap) -Mode $ApplySafetyMode
    $eventMap["safe_apply"] = [bool]$safety.safe
    $eventMap["safe_apply_reason"] = [string]$safety.reason
    $eventMap["apply_safety_mode"] = [string]$ApplySafetyMode
    $lines.Add("-- apply_safety: mode=$ApplySafetyMode; safe=$([bool]$safety.safe); reason=$([string]$safety.reason)")
    $eventRecord = [pscustomobject]$eventMap
    $eventRecords.Add($eventRecord) | Out-Null
    $lines.Add("GO")
    $lines.Add("")

    $eventSw.Stop()
    $actionKey = $action.ToUpperInvariant()
    if ($phaseTimingByAction.ContainsKey($actionKey)) {
        $a = $phaseTimingByAction[$actionKey]
        $a.events = [int]$a.events + 1
        if ($wroteConcrete) {
            $a.resolved = [int]$a.resolved + 1
        } else {
            $a.unresolved = [int]$a.unresolved + 1
        }
        $a.total_ms = [int64]$a.total_ms + [int64]$eventSw.ElapsedMilliseconds
        $a.row_resolve_ms = [int64]$a.row_resolve_ms + ([int64]$phaseTiming.row_resolve_ms - $eventRowResolveStart)
        $a.heuristic_decode_ms = [int64]$a.heuristic_decode_ms + ([int64]$phaseTiming.heuristic_decode_ms - $eventDecodeStart)
        $a.sql_render_ms = [int64]$a.sql_render_ms + ([int64]$phaseTiming.sql_render_ms - $eventSqlRenderStart)
    }
}
$split = Split-GeneratedOutput -Lines @($lines)
$blocksWithMeta = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $split.blocks.Count; $i++) {
    $b = $split.blocks[$i]
    $ev = $null
    if ($i -lt $eventRecords.Count) {
        $ev = $eventRecords[$i]
    }
    $safeApply = $false
    $safeReason = "event_mismatch"
    if ($ev) {
        $safeApply = [bool]$ev.safe_apply
        $safeReason = [string]$ev.safe_apply_reason
    }
    $blocksWithMeta.Add([pscustomobject]@{
        action = [string]$b.action
        confidence = [string]$b.confidence
        concrete = [bool]$b.concrete
        safe_apply = [bool]$safeApply
        safe_apply_reason = [string]$safeReason
        lines = @($b.lines)
    })
}
if ($split.blocks.Count -ne $eventRecords.Count) {
    Write-Warning ("Block/event mismatch: blocks={0}, events={1}. Safety classification may be partial." -f $split.blocks.Count, $eventRecords.Count)
}

$blocksWithMetaArray = @($blocksWithMeta.ToArray())
$outputBlocks = @($blocksWithMetaArray)
$unresolvedBlocks = @()
$quarantineBlocks = @()
if ($OutputSuccessfulOnly) {
    $outputBlocks = @($blocksWithMetaArray | Where-Object { $_.concrete -and $_.safe_apply })
    $unresolvedBlocks = @($blocksWithMetaArray | Where-Object { -not $_.concrete })
    $quarantineBlocks = @($blocksWithMetaArray | Where-Object { $_.concrete -and -not $_.safe_apply })
}

$mainOutputLines = Build-OutputLines -Header @($split.header) -Blocks $outputBlocks

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
$mainOutputLines | Set-Content -LiteralPath $OutputPath -Encoding ASCII
$swFileWrite.Stop()
$phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds

if ($OutputSuccessfulOnly) {
    if ([string]::IsNullOrWhiteSpace($UnresolvedOutputPath)) {
        $mainDir = Split-Path -Parent $OutputPath
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
        $ext = [System.IO.Path]::GetExtension($OutputPath)
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $ext = ".trn"
        }
        $UnresolvedOutputPath = Join-Path -Path $mainDir -ChildPath ($baseName + ".unresolved" + $ext)
    }
    if ([string]::IsNullOrWhiteSpace($QuarantineOutputPath)) {
        $mainDir = Split-Path -Parent $OutputPath
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
        $ext = [System.IO.Path]::GetExtension($OutputPath)
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $ext = ".trn"
        }
        $QuarantineOutputPath = Join-Path -Path $mainDir -ChildPath ($baseName + ".quarantine" + $ext)
    }

    $unresolvedOutputLines = Build-OutputLines -Header @($split.header) -Blocks $unresolvedBlocks
    $unresolvedDir = Split-Path -Parent $UnresolvedOutputPath
    if ($unresolvedDir -and -not (Test-Path -LiteralPath $unresolvedDir)) {
        New-Item -ItemType Directory -Path $unresolvedDir | Out-Null
    }
    $swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
    $unresolvedOutputLines | Set-Content -LiteralPath $UnresolvedOutputPath -Encoding ASCII
    $swFileWrite.Stop()
    $phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds
    $quarantineOutputLines = Build-OutputLines -Header @($split.header) -Blocks $quarantineBlocks
    $quarantineDir = Split-Path -Parent $QuarantineOutputPath
    if ($quarantineDir -and -not (Test-Path -LiteralPath $quarantineDir)) {
        New-Item -ItemType Directory -Path $quarantineDir | Out-Null
    }
    $swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
    $quarantineOutputLines | Set-Content -LiteralPath $QuarantineOutputPath -Encoding ASCII
    $swFileWrite.Stop()
    $phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds
    Write-Host ("Wrote {0} successful hybrid DML statements to {1}" -f $outputBlocks.Count, (Resolve-Path -LiteralPath $OutputPath))
    Write-Host ("Wrote {0} quarantined hybrid DML statements to {1}" -f $quarantineBlocks.Count, (Resolve-Path -LiteralPath $QuarantineOutputPath))
    Write-Host ("Wrote {0} unresolved hybrid DML statements to {1}" -f $unresolvedBlocks.Count, (Resolve-Path -LiteralPath $UnresolvedOutputPath))
} else {
    Write-Host ("Wrote {0} hybrid DML statements to {1}" -f $outputBlocks.Count, (Resolve-Path -LiteralPath $OutputPath))
}

$eventRecordsToExport = New-Object System.Collections.Generic.List[object]
foreach ($er in $eventRecords) {
    if ($OutputSuccessfulOnly -and (-not [bool]$er.safe_apply)) { continue }
    $eventRecordsToExport.Add($er) | Out-Null
}
$eventRecordsToExport = $eventRecordsToExport.ToArray()

if ($GenerateUndo) {
    $undoEvents = @($eventRecordsToExport | Where-Object { @($_.undo_statements).Count -gt 0 } | Sort-Object `
        @{ Expression = { Parse-CommitTime -Text ([string]$_.commit_time) }; Descending = $true }, `
        @{ Expression = { [string]$_.current_lsn }; Descending = $true })
    if ($null -eq $undoEvents) {
        $undoEvents = @()
    } elseif ($undoEvents -isnot [array]) {
        $undoEvents = @($undoEvents)
    }

    $undoLines = New-Object System.Collections.Generic.List[string]
    $undoCounts = @{
        INSERT = 0
        UPDATE = 0
        DELETE = 0
    }
    foreach ($ev in $undoEvents) {
        $actionName = [string]$ev.action
        if ($undoCounts.ContainsKey($actionName)) {
            $undoCounts[$actionName]++
        }
    }
    $undoLines.Add("-- Summary: total=$($undoEvents.Count); insert=$($undoCounts.INSERT); update=$($undoCounts.UPDATE); delete=$($undoCounts.DELETE)")
    $undoLines.Add("-- Hybrid UNDO DML for $TargetTable")
    $undoLines.Add("-- Generated UTC: $((Get-Date).ToUniversalTime().ToString('o'))")
    $undoLines.Add("-- Source redo output: $OutputPath")
    $undoLines.Add("")
    foreach ($ev in $undoEvents) {
        $undoLines.Add("--UNDO-$([string]$ev.action) ($([string]$ev.current_lsn))")
        $undoLines.Add("-- tx=$([string]$ev.tx_id); commit=$([string]$ev.commit_time); confidence=$([string]$ev.confidence); source=$([string]$ev.source)")
        foreach ($stmt in @($ev.undo_statements)) {
            $undoLines.Add([string]$stmt)
        }
        $undoLines.Add("GO")
        $undoLines.Add("")
    }

    $undoDir = Split-Path -Parent $UndoOutputPath
    if ($undoDir -and -not (Test-Path -LiteralPath $undoDir)) {
        New-Item -ItemType Directory -Path $undoDir | Out-Null
    }
    $swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
    $undoLines | Set-Content -LiteralPath $UndoOutputPath -Encoding ASCII
    $swFileWrite.Stop()
    $phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds
    Write-Host ("Wrote {0} hybrid UNDO DML statements to {1}" -f $undoEvents.Count, (Resolve-Path -LiteralPath $UndoOutputPath))
}

if ($ExportBeforeAfter) {
    $beforeAfter = [pscustomobject]@{
        generated_utc      = (Get-Date).ToUniversalTime().ToString("o")
        target_table       = $TargetTable
        output_success_only = $OutputSuccessfulOnly
        record_count       = $eventRecordsToExport.Count
        records            = $eventRecordsToExport
    }

    $beforeAfterDir = Split-Path -Parent $BeforeAfterJsonPath
    if ($beforeAfterDir -and -not (Test-Path -LiteralPath $beforeAfterDir)) {
        New-Item -ItemType Directory -Path $beforeAfterDir | Out-Null
    }
    $swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
    $beforeAfter | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $BeforeAfterJsonPath -Encoding UTF8
    $swFileWrite.Stop()
    $phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds
    Write-Host ("Wrote {0} before/after records to {1}" -f $eventRecordsToExport.Count, (Resolve-Path -LiteralPath $BeforeAfterJsonPath))
}

if ($ExportRowHistory) {
    if ($null -eq $eventRecords) {
        $historyRows = @()
    } elseif ($eventRecords -is [System.Collections.Generic.List[object]]) {
        # Explicitly materialize generic list to avoid sporadic binder issues on @(...)
        $historyRows = @($eventRecords.ToArray())
    } else {
        $historyRows = @($eventRecords)
        if ($historyRows -isnot [array]) {
            $historyRows = @($historyRows)
        }
    }

    $historyOrdered = @(
        $historyRows |
            Sort-Object `
                @{ Expression = { Parse-CommitTime -Text ([string]$_.commit_time) } }, `
                @{ Expression = { Get-LsnSortKey -LsnText ([string]$_.current_lsn) } }, `
                @{ Expression = { [string]$_.manifest_key } }
    )

    $txGroups = @($historyOrdered | Group-Object tx_id)
    $transactions = New-Object System.Collections.Generic.List[object]
    foreach ($g in $txGroups) {
        $ops = @(
            @($g.Group) |
                Sort-Object `
                    @{ Expression = { Parse-CommitTime -Text ([string]$_.commit_time) } }, `
                    @{ Expression = { Get-LsnSortKey -LsnText ([string]$_.current_lsn) } }, `
                    @{ Expression = { [string]$_.manifest_key } }
        )
        if ($ops.Count -eq 0) { continue }
        $firstCommit = [string]$ops[0].commit_time
        $lastCommit = [string]$ops[$ops.Count - 1].commit_time
        $transactions.Add([pscustomobject]@{
            tx_id = [string]$g.Name
            operation_count = [int]$ops.Count
            first_commit_time = $firstCommit
            last_commit_time = $lastCommit
            operations = $ops
        }) | Out-Null
    }

    $rowHistory = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        target_table = $TargetTable
        total_operations = [int]$historyOrdered.Count
        transaction_count = [int]$transactions.Count
        transactions = @($transactions.ToArray())
    }

    $rowHistoryDir = Split-Path -Parent $RowHistoryJsonPath
    if ($rowHistoryDir -and -not (Test-Path -LiteralPath $rowHistoryDir)) {
        New-Item -ItemType Directory -Path $rowHistoryDir | Out-Null
    }
    $swFileWrite = [System.Diagnostics.Stopwatch]::StartNew()
    $rowHistory | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $RowHistoryJsonPath -Encoding UTF8
    $swFileWrite.Stop()
    $phaseTiming.file_write_ms += [int64]$swFileWrite.ElapsedMilliseconds
    Write-Host ("Wrote row history with {0} operations across {1} transactions to {2}" -f $historyOrdered.Count, $transactions.Count, (Resolve-Path -LiteralPath $RowHistoryJsonPath))
}

$scriptStartWatch.Stop()
$phaseTiming.total_ms = [int64]$scriptStartWatch.ElapsedMilliseconds
$phaseTiming.row_lookup_live_reads = [int64]$script:RowByPhysLiveReadCount
$phaseTiming.row_lookup_cache_hits = [int64]$script:RowByPhysCacheHitCount
$phaseTiming.by_action = [pscustomobject]@{
    INSERT = [pscustomobject]$phaseTimingByAction["INSERT"]
    UPDATE = [pscustomobject]$phaseTimingByAction["UPDATE"]
    DELETE = [pscustomobject]$phaseTimingByAction["DELETE"]
}

if (-not [string]::IsNullOrWhiteSpace($PhaseTimingOutputPath)) {
    $phaseDir = Split-Path -Parent $PhaseTimingOutputPath
    if ($phaseDir -and -not (Test-Path -LiteralPath $phaseDir)) {
        New-Item -ItemType Directory -Path $phaseDir | Out-Null
    }
    $phasePayload = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        output_path = $OutputPath
        target_table = $TargetTable
        timings_ms = [pscustomobject]$phaseTiming
    }
    $phasePayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $PhaseTimingOutputPath -Encoding UTF8
    Write-Host ("Wrote convert phase timings to {0}" -f (Resolve-Path -LiteralPath $PhaseTimingOutputPath))
}
