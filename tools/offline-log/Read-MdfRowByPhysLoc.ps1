param(
    [Parameter(Mandatory = $true)]
    [string]$MdfPath,

    [Parameter(Mandatory = $true)]
    [string]$PageId,

    [Parameter(Mandatory = $true)]
    [int]$SlotId,

    [Parameter()]
    [int]$ExpectedFileId = 1,

    [Parameter()]
    [int]$PageSize = 8192,

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-PageIdValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText
    )

    $t = $InputText.Trim()
    if ($t -match '^[0-9]+$') {
        return [int64]$t
    }
    if ($t -match '^[0-9A-Fa-f]+$') {
        return [Convert]::ToInt64($t, 16)
    }
    throw "Unsupported PageId format '$InputText'. Use decimal (e.g. 32728) or hex without prefix (e.g. 00007FD8)."
}

function Normalize-SlotOffset {
    param(
        [Parameter(Mandatory = $true)]
        [int]$RawOffset,
        [Parameter(Mandatory = $true)]
        [int]$InputPageSize
    )

    if ($RawOffset -ge 0 -and $RawOffset -lt $InputPageSize) {
        return $RawOffset
    }

    # Some slot values can carry flag bits in high bits; 13-bit mask keeps 0..8191 offsets.
    $masked = ($RawOffset -band 0x1FFF)
    if ($masked -ge 0 -and $masked -lt $InputPageSize) {
        return $masked
    }
    return -1
}

function Bytes-ToHex {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return "0x" }
    return "0x" + [System.BitConverter]::ToString($Bytes).Replace("-", "")
}

if (-not (Test-Path -LiteralPath $MdfPath)) {
    throw "MDF path not found: $MdfPath"
}

if ($PageSize -lt 1024 -or $PageSize -gt 65536) {
    throw "Invalid PageSize=$PageSize."
}

if ($SlotId -lt 0) {
    throw "SlotId must be >= 0."
}

$pageIdNum = Parse-PageIdValue -InputText $PageId
if ($pageIdNum -lt 0) {
    throw "Invalid PageId value '$PageId'."
}

$fs = $null
try {
    # Snapshot paths are read-only; allow other open handles.
    $fs = [System.IO.File]::Open($MdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $fileLength = $fs.Length
    $pageOffset = [int64]$pageIdNum * [int64]$PageSize
    if ($pageOffset + $PageSize -gt $fileLength) {
        throw "Page offset out of range. page_id=$pageIdNum, file_length=$fileLength"
    }

    $buffer = New-Object byte[] $PageSize
    [void]$fs.Seek($pageOffset, [System.IO.SeekOrigin]::Begin)
    $read = $fs.Read($buffer, 0, $PageSize)
    if ($read -ne $PageSize) {
        throw "Could not read full page. read=$read expected=$PageSize"
    }

    # SQL Server page header fields used for row extraction.
    $pageHeaderVersion = [int]$buffer[0]
    $pageType = [int]$buffer[1]
    $pageLevel = [int]$buffer[3]
    $slotCount = [int][BitConverter]::ToUInt16($buffer, 22)   # m_slotCnt
    $freeCount = [int][BitConverter]::ToUInt16($buffer, 28)   # m_freeCnt
    $freeData = [int][BitConverter]::ToUInt16($buffer, 30)    # m_freeData
    $pageIdHeader = [int64][BitConverter]::ToUInt32($buffer, 32)
    $fileIdHeader = [int][BitConverter]::ToUInt16($buffer, 36)

    if ($ExpectedFileId -gt 0 -and $fileIdHeader -ne $ExpectedFileId) {
        throw "FileId mismatch: expected=$ExpectedFileId actual=$fileIdHeader"
    }
    if ($pageIdHeader -ne $pageIdNum) {
        throw "PageId mismatch in header: expected=$pageIdNum actual=$pageIdHeader"
    }
    if ($slotCount -le 0) {
        throw "No slots on page. page_id=$pageIdNum"
    }
    if ($SlotId -ge $slotCount) {
        throw "SlotId out of range. slot_id=$SlotId slot_count=$slotCount"
    }

    $slotArrayStart = $PageSize - ($slotCount * 2)
    if ($slotArrayStart -lt 96) {
        throw "Invalid slot array start: $slotArrayStart"
    }

    $rawOffsets = New-Object System.Collections.Generic.List[int]
    $normOffsets = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $slotCount; $i++) {
        $raw = [int][BitConverter]::ToUInt16($buffer, $PageSize - (($i + 1) * 2))
        $norm = Normalize-SlotOffset -RawOffset $raw -InputPageSize $PageSize
        $rawOffsets.Add($raw) | Out-Null
        $normOffsets.Add($norm) | Out-Null
    }

    $rowStart = $normOffsets[$SlotId]
    if ($rowStart -lt 96 -or $rowStart -ge $slotArrayStart) {
        throw "Invalid normalized row start for slot_id=$SlotId. row_start=$rowStart"
    }

    $candidateEnds = @()
    foreach ($off in $normOffsets) {
        if ($off -gt $rowStart -and $off -lt $slotArrayStart) {
            $candidateEnds += $off
        }
    }
    if ($freeData -gt $rowStart -and $freeData -le $slotArrayStart) {
        $candidateEnds += $freeData
    }
    if ($candidateEnds.Count -eq 0) {
        $rowEnd = $slotArrayStart
    } else {
        $rowEnd = ($candidateEnds | Sort-Object | Select-Object -First 1)
    }

    $rowLength = $rowEnd - $rowStart
    if ($rowLength -le 0) {
        throw "Computed row length is invalid. row_start=$rowStart row_end=$rowEnd"
    }

    $rowBytes = New-Object byte[] $rowLength
    [Array]::Copy($buffer, $rowStart, $rowBytes, 0, $rowLength)

    $statusA = if ($rowBytes.Length -ge 1) { [int]$rowBytes[0] } else { $null }
    $statusB = if ($rowBytes.Length -ge 2) { [int]$rowBytes[1] } else { $null }
    $fixedLenEnd = if ($rowBytes.Length -ge 4) { [int][BitConverter]::ToUInt16($rowBytes, 2) } else { $null }

    $result = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        mdf_path = $MdfPath
        page = [pscustomobject]@{
            page_id = $pageIdNum
            file_id = $fileIdHeader
            page_type = $pageType
            page_level = $pageLevel
            header_version = $pageHeaderVersion
            slot_count = $slotCount
            free_count = $freeCount
            free_data = $freeData
            slot_array_start = $slotArrayStart
        }
        row = [pscustomobject]@{
            slot_id = $SlotId
            row_start = $rowStart
            row_end = $rowEnd
            row_length = $rowLength
            status_a = $statusA
            status_b = $statusB
            fixed_len_end = $fixedLenEnd
            raw_slot_offset = $rawOffsets[$SlotId]
            normalized_slot_offset = $rowStart
            row_hex = (Bytes-ToHex -Bytes $rowBytes)
        }
        note = "Phase-1 offline MDF read: row bytes by file/page/slot. Column-level decode is not included in this script."
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $dir = Split-Path -Parent $OutputPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        Write-Host ("Wrote MDF row read result to {0}" -f (Resolve-Path -LiteralPath $OutputPath))
    } else {
        $result | ConvertTo-Json -Depth 8
    }
}
finally {
    if ($fs) {
        $fs.Dispose()
    }
}
