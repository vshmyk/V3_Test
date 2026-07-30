param(
    [Parameter(Mandatory = $true)]
    [string]$RowHex,

    [Parameter(Mandatory = $true)]
    [string]$MetadataSnapshotPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetTable,

    [Parameter()]
    [int]$PagePminlen = -1,

    [Parameter()]
    [int]$PageLevel = -1,

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Numerics | Out-Null
$script:NumericAsVariableMode = $false

function Get-RecordTypeName {
    param([int]$StatusA)
    $typeCode = (($StatusA -band 0x0E) -shr 1)
    switch ($typeCode) {
        0 { return "Primary" }
        1 { return "Forwarded" }
        2 { return "ForwardingStub" }
        3 { return "Index" }
        4 { return "BlobFragment" }
        5 { return "GhostIndex" }
        6 { return "GhostData" }
        7 { return "GhostVersion" }
        default { return ("Unknown:{0}" -f $typeCode) }
    }
}

function Convert-HexToBytes {
    param([string]$Hex)
    $clean = $Hex.Trim()
    if ($clean.StartsWith("0x")) { $clean = $clean.Substring(2) }
    if (($clean.Length % 2) -ne 0) { throw "Invalid hex length." }
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $clean.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($clean.Substring($i, 2), 16)
    }
    return ,$bytes
}

function Bytes-ToHex {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return "0x" }
    return "0x" + [BitConverter]::ToString($Bytes).Replace("-", "")
}

function Get-BytesSlice {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [int]$Length
    )
    if ($Length -le 0) { return ,([byte[]]@()) }
    $out = New-Object byte[] $Length
    [Array]::Copy($Bytes, $Offset, $out, 0, $Length)
    return ,$out
}

function Is-VariableType {
    param([string]$TypeName)
    $t = $TypeName.ToLowerInvariant()
    if ($script:NumericAsVariableMode -and (@("decimal","numeric") -contains $t)) { return $true }
    return @("varchar","nvarchar","varbinary","text","ntext","image","xml","sql_variant") -contains $t
}

function Get-FixedStorageLength {
    param([pscustomobject]$Column)

    $t = ([string]$Column.data_type).ToLowerInvariant()
    switch ($t) {
        "bit" { return 1 }
        "tinyint" { return 1 }
        "smallint" { return 2 }
        "int" { return 4 }
        "bigint" { return 8 }
        "real" { return 4 }
        "float" { return 8 }
        "smallmoney" { return 4 }
        "money" { return 8 }
        "date" { return 3 }
        "smalldatetime" { return 4 }
        "datetime" { return 8 }
        "datetime2" { return [int]$Column.max_length }
        "time" { return [int]$Column.max_length }
        "datetimeoffset" { return [int]$Column.max_length }
        "uniqueidentifier" { return 16 }
        "char" { return [int]$Column.max_length }
        "nchar" { return [int]$Column.max_length }
        "binary" { return [int]$Column.max_length }
        "decimal" {
            $p = [int]$Column.precision
            if ($p -le 9) { return 5 }
            if ($p -le 19) { return 9 }
            if ($p -le 28) { return 13 }
            return 17
        }
        "numeric" {
            $p = [int]$Column.precision
            if ($p -le 9) { return 5 }
            if ($p -le 19) { return 9 }
            if ($p -le 28) { return 13 }
            return 17
        }
        default {
            if ([int]$Column.max_length -gt 0) { return [int]$Column.max_length }
            throw "Unsupported fixed type for length: $($Column.data_type)"
        }
    }
}

function Get-NullBit {
    param(
        [byte[]]$NullBitmap,
        [int]$ColumnOrdinalZeroBased
    )
    $byteIndex = [Math]::Floor($ColumnOrdinalZeroBased / 8)
    $bitIndex = $ColumnOrdinalZeroBased % 8
    if ($byteIndex -lt 0 -or $byteIndex -ge $NullBitmap.Length) { return $false }
    return (($NullBitmap[$byteIndex] -band (1 -shl $bitIndex)) -ne 0)
}

function Decode-DecimalFromBytes {
    param(
        [byte[]]$Bytes,
        [int]$Scale
    )

    if ($Bytes.Length -lt 1) { return $null }
    $sign = [int]$Bytes[0] # 1=positive, 0=negative
    if ($Bytes.Length -eq 1) { return 0 }

    $mag = New-Object byte[] ($Bytes.Length) # +1 zero byte to keep BigInteger positive
    [Array]::Copy($Bytes, 1, $mag, 0, $Bytes.Length - 1)
    $bi = [System.Numerics.BigInteger]::new($mag)
    if ($sign -eq 0) { $bi = -$bi }

    # Use decimal where possible; fallback string for extreme values.
    try {
        $d = [decimal]$bi
        for ($i = 0; $i -lt $Scale; $i++) { $d = $d / [decimal]10 }
        return $d
    } catch {
        $s = $bi.ToString()
        if ($Scale -le 0) { return $s }
        $negative = $s.StartsWith("-")
        if ($negative) { $s = $s.Substring(1) }
        while ($s.Length -le $Scale) { $s = "0" + $s }
        $whole = $s.Substring(0, $s.Length - $Scale)
        $frac = $s.Substring($s.Length - $Scale)
        $out = "$whole.$frac"
        if ($negative) { $out = "-" + $out }
        return $out
    }
}

function Decode-DateTime2FromBytes {
    param(
        [byte[]]$Bytes,
        [int]$Scale
    )
    if ($Bytes.Length -lt 6) { return $null }

    $timeLen = $Bytes.Length - 3
    $timePart = New-Object byte[] 8
    [Array]::Copy($Bytes, 0, $timePart, 0, $timeLen)
    $timeValue = [BitConverter]::ToInt64($timePart, 0)

    $datePart = New-Object byte[] 4
    [Array]::Copy($Bytes, $timeLen, $datePart, 0, 3)
    $days = [BitConverter]::ToInt32($datePart, 0)

    try {
        $base = [datetime]::new(1,1,1,0,0,0,[DateTimeKind]::Unspecified)
        $date = $base.AddDays($days)
        $tickFactor = [Math]::Pow(10, 7 - $Scale)
        $ticks = [int64]($timeValue * $tickFactor)
        return $date.AddTicks($ticks)
    } catch {
        return $null
    }
}

function Decode-DateFromBytes {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ne 3) { return $null }
    $tmp = New-Object byte[] 4
    [Array]::Copy($Bytes, 0, $tmp, 0, 3)
    $days = [BitConverter]::ToInt32($tmp, 0)
    try {
        return ([datetime]::new(1,1,1)).AddDays($days).Date
    } catch {
        return $null
    }
}

function Decode-TimeFromBytes {
    param(
        [byte[]]$Bytes,
        [int]$Scale
    )
    $tmp = New-Object byte[] 8
    [Array]::Copy($Bytes, 0, $tmp, 0, $Bytes.Length)
    $v = [BitConverter]::ToInt64($tmp, 0)
    try {
        $tickFactor = [Math]::Pow(10, 7 - $Scale)
        $ticks = [int64]($v * $tickFactor)
        return ([datetime]::new(1,1,1)).AddTicks($ticks).TimeOfDay
    } catch {
        return $null
    }
}

function Decode-DateTimeFromBytes {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ne 8) { return $null }
    $days = [BitConverter]::ToInt32($Bytes, 0)
    $ticks300 = [BitConverter]::ToInt32($Bytes, 4)
    try {
        $base = [datetime]::new(1900,1,1)
        return $base.AddDays($days).AddMilliseconds(($ticks300 * 1000.0) / 300.0)
    } catch {
        return $null
    }
}

function Decode-SmallDateTimeFromBytes {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ne 4) { return $null }
    $days = [BitConverter]::ToUInt16($Bytes, 0)
    $mins = [BitConverter]::ToUInt16($Bytes, 2)
    try {
        $base = [datetime]::new(1900,1,1)
        return $base.AddDays($days).AddMinutes($mins)
    } catch {
        return $null
    }
}

function Decode-TypedValue {
    param(
        [pscustomobject]$Column,
        [byte[]]$RawBytes
    )
    $t = ([string]$Column.data_type).ToLowerInvariant()
    switch ($t) {
        "bit" { return ([int]$RawBytes[0] -ne 0) }
        "tinyint" { return [int]$RawBytes[0] }
        "smallint" { return [BitConverter]::ToInt16($RawBytes, 0) }
        "int" { return [BitConverter]::ToInt32($RawBytes, 0) }
        "bigint" { return [BitConverter]::ToInt64($RawBytes, 0) }
        "real" { return [BitConverter]::ToSingle($RawBytes, 0) }
        "float" { return [BitConverter]::ToDouble($RawBytes, 0) }
        "smallmoney" { return ([decimal][BitConverter]::ToInt32($RawBytes, 0)) / [decimal]10000 }
        "money" { return ([decimal][BitConverter]::ToInt64($RawBytes, 0)) / [decimal]10000 }
        "decimal" { return Decode-DecimalFromBytes -Bytes $RawBytes -Scale ([int]$Column.scale) }
        "numeric" { return Decode-DecimalFromBytes -Bytes $RawBytes -Scale ([int]$Column.scale) }
        "datetime2" { return Decode-DateTime2FromBytes -Bytes $RawBytes -Scale ([int]$Column.scale) }
        "datetime" { return Decode-DateTimeFromBytes -Bytes $RawBytes }
        "smalldatetime" { return Decode-SmallDateTimeFromBytes -Bytes $RawBytes }
        "date" { return Decode-DateFromBytes -Bytes $RawBytes }
        "time" { return Decode-TimeFromBytes -Bytes $RawBytes -Scale ([int]$Column.scale) }
        "char" { return ([Text.Encoding]::GetEncoding(1252).GetString($RawBytes)).TrimEnd(" ") }
        "varchar" { return [Text.Encoding]::GetEncoding(1252).GetString($RawBytes) }
        "nchar" { return ([Text.Encoding]::Unicode.GetString($RawBytes)).TrimEnd([char]0).TrimEnd(" ") }
        "nvarchar" { return ([Text.Encoding]::Unicode.GetString($RawBytes)).TrimEnd([char]0) }
        "binary" { return Bytes-ToHex -Bytes $RawBytes }
        "varbinary" { return Bytes-ToHex -Bytes $RawBytes }
        "uniqueidentifier" {
            if ($RawBytes.Length -eq 16) { return ([Guid]::new($RawBytes)).ToString() }
            return Bytes-ToHex -Bytes $RawBytes
        }
        "text" { return ("<textptr:{0}>" -f (Bytes-ToHex -Bytes $RawBytes)) }
        "ntext" { return ("<ntextptr:{0}>" -f (Bytes-ToHex -Bytes $RawBytes)) }
        "image" { return ("<imageptr:{0}>" -f (Bytes-ToHex -Bytes $RawBytes)) }
        default { return Bytes-ToHex -Bytes $RawBytes }
    }
}

function Convert-ValueToSqlLiteral {
    param(
        [pscustomobject]$Column,
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) { return "NULL" }
    $t = ([string]$Column.data_type).ToLowerInvariant()
    switch ($t) {
        "bit" { return (if ([bool]$Value) { "1" } else { "0" }) }
        "tinyint" { return [string]$Value }
        "smallint" { return [string]$Value }
        "int" { return [string]$Value }
        "bigint" { return [string]$Value }
        "real" { return ([single]$Value).ToString("R", [Globalization.CultureInfo]::InvariantCulture) }
        "float" { return ([double]$Value).ToString("R", [Globalization.CultureInfo]::InvariantCulture) }
        "smallmoney" { return ([decimal]$Value).ToString([Globalization.CultureInfo]::InvariantCulture) }
        "money" { return ([decimal]$Value).ToString([Globalization.CultureInfo]::InvariantCulture) }
        "decimal" {
            if ($Value -is [decimal]) { return $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
            $s = [string]$Value
            if ($s -match '^-?[0-9]+(\.[0-9]+)?$') { return $s }
            return "'" + $s.Replace("'","''") + "'"
        }
        "numeric" {
            if ($Value -is [decimal]) { return $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
            return [string]$Value
        }
        "datetime2" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss.fffffff") + "'" }
        "datetime" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss.fff") + "'" }
        "smalldatetime" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss") + "'" }
        "date" { return "'" + ([datetime]$Value).ToString("yyyy-MM-dd") + "'" }
        "time" { return "'" + [TimeSpan]$Value + "'" }
        "char" { return "'" + ([string]$Value).Replace("'","''") + "'" }
        "varchar" { return "'" + ([string]$Value).Replace("'","''") + "'" }
        "nchar" { return "N'" + ([string]$Value).Replace("'","''") + "'" }
        "nvarchar" { return "N'" + ([string]$Value).Replace("'","''") + "'" }
        "uniqueidentifier" { return "'" + [string]$Value + "'" }
        "binary" { return [string]$Value }
        "varbinary" { return [string]$Value }
        default { return "'" + ([string]$Value).Replace("'","''") + "'" }
    }
}

function Try-FindPrimaryLayoutCandidate {
    param(
        [byte[]]$RowBytes,
        [int]$MaxExpectedColumns
    )

    if ($null -eq $RowBytes -or $RowBytes.Length -lt 10) { return $null }
    $limit = [Math]::Min($RowBytes.Length - 4, 96)
    for ($pos = 4; $pos -le $limit; $pos += 2) {
        $fixedEnd = [int][BitConverter]::ToUInt16($RowBytes, $pos - 2)
        if ($fixedEnd -lt 4 -or $fixedEnd -gt ($RowBytes.Length - 2)) { continue }
        if ($fixedEnd + 2 -gt $RowBytes.Length) { continue }
        $colCount = [int][BitConverter]::ToUInt16($RowBytes, $fixedEnd)
        if ($colCount -le 0) { continue }
        if ($MaxExpectedColumns -gt 0 -and $colCount -gt ($MaxExpectedColumns * 2)) { continue }

        $nullBytes = [int][Math]::Ceiling($colCount / 8.0)
        $nullStart = $fixedEnd + 2
        if ($nullStart + $nullBytes + 2 -gt $RowBytes.Length) { continue }
        return [pscustomobject]@{
            fixed_len_end = $fixedEnd
            column_count = $colCount
        }
    }
    return $null
}

if (-not (Test-Path -LiteralPath $MetadataSnapshotPath)) {
    throw "Metadata snapshot not found: $MetadataSnapshotPath"
}
if ($TargetTable -notmatch "^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$") {
    throw "TargetTable must be schema.table format."
}

$snap = Get-Content -LiteralPath $MetadataSnapshotPath -Raw | ConvertFrom-Json
$tt = $TargetTable.Split(".")
$schemaName = $tt[0]
$tableName = $tt[1]
$table = @($snap.tables | Where-Object {
    ([string]$_.schema_name).Equals($schemaName, [StringComparison]::OrdinalIgnoreCase) -and
    ([string]$_.table_name).Equals($tableName, [StringComparison]::OrdinalIgnoreCase)
})
if ($table.Count -eq 0) { throw "Table metadata not found for $TargetTable" }
$metadata = @($table[0].columns | Sort-Object column_id | ForEach-Object {
    [pscustomobject]@{
        column_id = [int]$_.column_id
        column_name = [string]$_.column_name
        data_type = [string]$_.data_type
        max_length = [int]$_.max_length
        precision = [int]$_.precision
        scale = [int]$_.scale
        is_nullable = [bool]$_.is_nullable
    }
})

$rowBytes = Convert-HexToBytes -Hex $RowHex
if ($rowBytes.Length -lt 8) { throw "Row hex too short." }

$statusA = [int]$rowBytes[0]
$statusB = if ($rowBytes.Length -ge 2) { [int]$rowBytes[1] } else { 0 }
$recordType = Get-RecordTypeName -StatusA $statusA
$hasNullBitmapFlag = (($statusA -band 0x10) -ne 0)
$hasVariableFlag = (($statusA -band 0x20) -ne 0)
$hasVersioningFlag = (($statusA -band 0x40) -ne 0)

# Forwarding stubs store only statusA + 8-byte pointer; no regular row payload.
if ($recordType -eq "ForwardingStub" -and $rowBytes.Length -ge 9) {
    $fwdPage = [int][BitConverter]::ToUInt32($rowBytes, 1)
    $fwdFile = [int][BitConverter]::ToUInt16($rowBytes, 5)
    $fwdSlot = [int][BitConverter]::ToUInt16($rowBytes, 7)
    $result = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        target_table = $TargetTable
        record_type = $recordType
        has_null_bitmap_flag = [bool]$hasNullBitmapFlag
        has_variable_flag = [bool]$hasVariableFlag
        has_versioning_flag = [bool]$hasVersioningFlag
        numeric_as_variable_mode = [bool]$script:NumericAsVariableMode
        row_length = $rowBytes.Length
        status_a = $statusA
        status_b = $statusB
        fixed_len_end = $null
        column_count = 0
        null_bitmap_length = 0
        var_count = 0
        var_data_start = $null
        forward_pointer = [pscustomobject]@{
            file_id = $fwdFile
            page_id = $fwdPage
            slot_id = $fwdSlot
        }
        values = [pscustomobject]@{}
        columns = @()
        note = "ForwardingStub record; no in-row column payload."
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $dir = Split-Path -Parent $OutputPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
        $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        Write-Host ("Wrote decoded row to {0}" -f (Resolve-Path -LiteralPath $OutputPath))
    } else {
        $result | ConvertTo-Json -Depth 10
    }
    return
}

$fixedLenEnd = $null
$nullStart = $null
$columnCount = 0
$nullBytes = 0
$varCountPos = $null
$varCount = 0
$varOffsetStart = $null
$varDataStart = $null
$layoutMode = "primary"

if ($recordType -eq "Index" -and $PagePminlen -gt 1) {
    # Orca-style index record layout: fixed section starts after statusA and has length pminlen-1.
    $layoutMode = "index"
    $fixedLenEnd = 1 + ([int]$PagePminlen - 1)
    if ($fixedLenEnd -lt 1 -or $fixedLenEnd -gt $rowBytes.Length - 2) {
        throw "Invalid index fixed_len_end=$fixedLenEnd (pminlen=$PagePminlen) for row length=$($rowBytes.Length)"
    }
    $columnCount = [int][BitConverter]::ToUInt16($rowBytes, $fixedLenEnd)
    $nullBytes = [int][Math]::Ceiling($columnCount / 8.0)
    $nullStart = $fixedLenEnd + 2
    $varCountPos = $nullStart + $nullBytes
    $varCount = if ($hasVariableFlag -and $varCountPos + 2 -le $rowBytes.Length) { [int][BitConverter]::ToUInt16($rowBytes, $varCountPos) } else { 0 }
    $varOffsetStart = $varCountPos + 2
    $varDataStart = $varOffsetStart + ($varCount * 2)
} else {
    # Primary-row layout
    $fixedLenEnd = [int][BitConverter]::ToUInt16($rowBytes, 2)
    if ($fixedLenEnd -lt 4 -or $fixedLenEnd -gt $rowBytes.Length - 2) {
        # Fallback: some rows flagged as primary can still decode better with index-style layout.
        # This commonly appears when fixed_len_end points at/near row end and primary header assumptions fail.
        if ($PagePminlen -gt 1) {
            $altFixed = 1 + ([int]$PagePminlen - 1)
            if ($altFixed -ge 1 -and $altFixed -le $rowBytes.Length - 2) {
                $layoutMode = "index_fallback_from_primary"
                $fixedLenEnd = $altFixed
            } else {
                throw "Invalid fixed_len_end=$fixedLenEnd for row length=$($rowBytes.Length)"
            }
        } elseif ($PagePminlen -eq 0 -and $fixedLenEnd -eq $rowBytes.Length) {
            # SQL 2022+ observed row shapes: fixed_len_end can be unusable while a viable
            # primary-like layout still exists deeper in the header region.
            $probe = Try-FindPrimaryLayoutCandidate -RowBytes $rowBytes -MaxExpectedColumns $metadata.Count
            if ($null -ne $probe) {
                $layoutMode = "primary_probe_fallback_pmin0"
                $fixedLenEnd = [int]$probe.fixed_len_end
            } else {
                throw "Invalid fixed_len_end=$fixedLenEnd for row length=$($rowBytes.Length)"
            }
        } else {
            throw "Invalid fixed_len_end=$fixedLenEnd for row length=$($rowBytes.Length)"
        }
    }
    $columnCount = [int][BitConverter]::ToUInt16($rowBytes, $fixedLenEnd)
    $nullBytes = [int][Math]::Ceiling($columnCount / 8.0)
    $nullStart = $fixedLenEnd + 2
    $varCountPos = $nullStart + $nullBytes
    $varCount = if ($hasVariableFlag -and $varCountPos + 2 -le $rowBytes.Length) { [int][BitConverter]::ToUInt16($rowBytes, $varCountPos) } else { 0 }
    $varOffsetStart = $varCountPos + 2
    $varDataStart = $varOffsetStart + ($varCount * 2)
}

$nullBitmap = if ($nullBytes -gt 0 -and $nullStart -ge 0 -and ($nullStart + $nullBytes) -le $rowBytes.Length) {
    Get-BytesSlice -Bytes $rowBytes -Offset $nullStart -Length $nullBytes
} else {
    [byte[]]@()
}

$fixedColumns = @()
$varColumns = @()
foreach ($c in $metadata) {
    if (Is-VariableType -TypeName $c.data_type) {
        $varColumns += $c
    } else {
        $fixedColumns += $c
    }
}

# Some legacy row formats store decimal/numeric in variable section.
# If fixed length section is too short for standard fixed layout, retry in numeric-as-variable mode.
$minFixedRequired = 4
foreach ($c in $metadata) {
    if (-not (Is-VariableType -TypeName $c.data_type)) {
        $minFixedRequired += (Get-FixedStorageLength -Column $c)
    }
}
if ($layoutMode -ne "index" -and $fixedLenEnd -lt $minFixedRequired) {
    $script:NumericAsVariableMode = $true
    $fixedColumns = @()
    $varColumns = @()
    foreach ($c in $metadata) {
        if (Is-VariableType -TypeName $c.data_type) {
            $varColumns += $c
        } else {
            $fixedColumns += $c
        }
    }
}

$parsed = New-Object System.Collections.Generic.List[object]
$fixedCursor = if ($layoutMode -eq "index") { 1 } else { 4 }
$ordinal = 0
foreach ($c in $metadata) {
    $isNull = Get-NullBit -NullBitmap $nullBitmap -ColumnOrdinalZeroBased $ordinal
    $ordinal++

    if (Is-VariableType -TypeName $c.data_type) { continue }

    $len = Get-FixedStorageLength -Column $c
    if ($fixedCursor + $len -gt $fixedLenEnd) {
        # Some rows expose shorter fixed sections than metadata implies (legacy/variant row shapes).
        # Soft-fail this column to preserve partial decode instead of aborting whole row.
        $parsed.Add([pscustomobject]@{
            column_id = $c.column_id
            column_name = $c.column_name
            data_type = $c.data_type
            is_null = $true
            raw_hex = "0x"
            value = $null
            sql_literal = "NULL"
            note = "fixed_parse_overflow"
        }) | Out-Null
        continue
    }
    $raw = Get-BytesSlice -Bytes $rowBytes -Offset $fixedCursor -Length $len
    $fixedCursor += $len

    $value = $null
    if (-not $isNull) {
        $value = Decode-TypedValue -Column $c -RawBytes $raw
    }
    $parsed.Add([pscustomobject]@{
        column_id = $c.column_id
        column_name = $c.column_name
        data_type = $c.data_type
        is_null = $isNull
        raw_hex = (Bytes-ToHex -Bytes $raw)
        value = $value
        sql_literal = (Convert-ValueToSqlLiteral -Column $c -Value $value)
    }) | Out-Null
}

$varOrdinalMap = New-Object System.Collections.Generic.List[object]
foreach ($c in $metadata) {
    if (Is-VariableType -TypeName $c.data_type) { $varOrdinalMap.Add($c) | Out-Null }
}

$ordinal = 0
foreach ($c in $metadata) {
    if (-not (Is-VariableType -TypeName $c.data_type)) { $ordinal++ ; continue }

    $isNull = Get-NullBit -NullBitmap $nullBitmap -ColumnOrdinalZeroBased $ordinal
    $ordinal++

    $varIndex = @($varOrdinalMap | Select-Object -ExpandProperty column_id).IndexOf($c.column_id)
    if ($varIndex -lt 0 -or $varIndex -ge $varCount) {
        $parsed.Add([pscustomobject]@{
            column_id = $c.column_id
            column_name = $c.column_name
            data_type = $c.data_type
            is_null = $true
            raw_hex = "0x"
            value = $null
            sql_literal = "NULL"
        }) | Out-Null
        continue
    }

    $endPos = [int][BitConverter]::ToUInt16($rowBytes, $varOffsetStart + ($varIndex * 2))
    $prevEnd = if ($varIndex -eq 0) { $varDataStart } else { [int][BitConverter]::ToUInt16($rowBytes, $varOffsetStart + (($varIndex - 1) * 2)) }
    if ($endPos -lt $prevEnd -or $endPos -gt $rowBytes.Length) {
        $parsed.Add([pscustomobject]@{
            column_id = $c.column_id
            column_name = $c.column_name
            data_type = $c.data_type
            is_null = $true
            raw_hex = "0x"
            value = $null
            sql_literal = "NULL"
            note = "invalid_var_bounds"
        }) | Out-Null
        continue
    }

    $rawLen = $endPos - $prevEnd
    $raw = Get-BytesSlice -Bytes $rowBytes -Offset $prevEnd -Length $rawLen
    $value = $null
    if (-not $isNull) {
        $value = Decode-TypedValue -Column $c -RawBytes $raw
    }

    $parsed.Add([pscustomobject]@{
        column_id = $c.column_id
        column_name = $c.column_name
        data_type = $c.data_type
        is_null = $isNull
        raw_hex = (Bytes-ToHex -Bytes $raw)
        value = $value
        sql_literal = (Convert-ValueToSqlLiteral -Column $c -Value $value)
    }) | Out-Null
}

$ordered = @($parsed.ToArray() | Sort-Object column_id)
$valuesMap = [ordered]@{}
foreach ($c in $ordered) {
    $valuesMap[[string]$c.column_name] = $c.value
}
$result = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    target_table = $TargetTable
    record_type = $recordType
    layout_mode = $layoutMode
    has_null_bitmap_flag = [bool]$hasNullBitmapFlag
    has_variable_flag = [bool]$hasVariableFlag
    has_versioning_flag = [bool]$hasVersioningFlag
    page_pminlen = if ($PagePminlen -gt 0) { [int]$PagePminlen } else { $null }
    page_level = if ($PageLevel -ge 0) { [int]$PageLevel } else { $null }
    numeric_as_variable_mode = [bool]$script:NumericAsVariableMode
    row_length = $rowBytes.Length
    status_a = $statusA
    status_b = $statusB
    fixed_len_end = $fixedLenEnd
    column_count = $columnCount
    null_bitmap_length = $nullBytes
    var_count = $varCount
    var_data_start = $varDataStart
    values = [pscustomobject]$valuesMap
    columns = $ordered
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host ("Wrote decoded row to {0}" -f (Resolve-Path -LiteralPath $OutputPath))
} else {
    $result | ConvertTo-Json -Depth 10
}
