param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$MdfPath,

    [Parameter()]
    [string]$TargetTable = "oasis.CHSC_POLINE",

    [Parameter()]
    [string]$OutputPath = ".\\output\\offline-mdf-rows.json",

    [Parameter()]
    [bool]$DeduplicateByPhysLoc = $true,

    [Parameter()]
    [int]$PageSize = 8192
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-PageIdParts {
    param([Parameter(Mandatory = $true)][string]$PageText)

    $t = $PageText.Trim()
    $parts = $t.Split(":")
    if ($parts.Count -ne 2) { return $null }
    try {
        $fileId = [Convert]::ToInt32($parts[0], 16)
        $pageId = [Convert]::ToInt32($parts[1], 16)
        return [pscustomobject]@{
            file_id = $fileId
            page_id = $pageId
            file_token = [string]$parts[0]
            page_token = [string]$parts[1]
        }
    } catch {
        return $null
    }
}

function Normalize-SlotOffset {
    param([int]$RawOffset, [int]$InputPageSize)

    if ($RawOffset -ge 0 -and $RawOffset -lt $InputPageSize) { return $RawOffset }
    $masked = ($RawOffset -band 0x1FFF)
    if ($masked -ge 0 -and $masked -lt $InputPageSize) { return $masked }
    return -1
}

function Bytes-ToHex {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return "0x" }
    return "0x" + [System.BitConverter]::ToString($Bytes).Replace("-", "")
}

function Is-PlausibleRowPage {
    param(
        [int]$PageType,
        [int]$PagePminlen,
        [string]$ContextName
    )

    $ctx = if ($null -eq $ContextName) { "" } else { [string]$ContextName }

    # Data/index pages only; reject clearly non-row pages.
    if ($PageType -notin @(1, 2, 3)) { return $false }

    # A zero pminlen has consistently indicated non-decodable rows in this pipeline.
    if ($PagePminlen -le 0) { return $false }

    # For clustered/heap row operations, prefer classic data/index pages.
    if ($ctx -match "^LCX_(CLUSTERED|HEAP)") {
        if ($PageType -notin @(1, 2)) { return $false }
    }

    return $true
}

function Read-PageBuffer {
    param(
        [System.IO.FileStream]$FileStream,
        [hashtable]$Cache,
        [int]$FileId,
        [int]$PageId,
        [int]$InputPageSize,
        [int64]$InputFileLength,
        [ref]$PageReadsRef,
        [ref]$PageCacheHitsRef
    )

    $k = ("{0}:{1}" -f $FileId, $PageId)
    if ($Cache.ContainsKey($k)) {
        $PageCacheHitsRef.Value = [int]$PageCacheHitsRef.Value + 1
        return [byte[]]$Cache[$k]
    }

    $off = [int64]$PageId * [int64]$InputPageSize
    if ($off + $InputPageSize -gt $InputFileLength) { return $null }

    $buf = New-Object byte[] $InputPageSize
    [void]$FileStream.Seek($off, [System.IO.SeekOrigin]::Begin)
    $read = $FileStream.Read($buf, 0, $InputPageSize)
    if ($read -ne $InputPageSize) { return $null }

    $PageReadsRef.Value = [int]$PageReadsRef.Value + 1
    $Cache[$k] = $buf
    return $buf
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest path not found: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $MdfPath)) {
    throw "MDF path not found: $MdfPath"
}
if ($TargetTable -notmatch "^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$") {
    throw "TargetTable must be schema.table format."
}

$tt = $TargetTable.Split(".")
$targetSchema = $tt[0]
$targetName = $tt[1]

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$records = @($manifest.records)
if ($records.Count -eq 0) {
    throw "Manifest contains no records."
}

$selected = @($records | Where-Object {
    ([string]$_.schema_name).Equals($targetSchema, [System.StringComparison]::OrdinalIgnoreCase) -and
    ([string]$_.table_name).Equals($targetName, [System.StringComparison]::OrdinalIgnoreCase) -and
    -not [string]::IsNullOrWhiteSpace([string]$_.page_id) -and
    ($_.slot_id -ne $null)
})

if ($selected.Count -eq 0) {
    throw "No matching manifest records with page/slot for $TargetTable."
}

$fs = $null
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fileLength = (Get-Item -LiteralPath $MdfPath).Length
$pageCache = @{}
$pageCacheHits = 0
$pageReads = 0
$bad = New-Object System.Collections.Generic.List[object]
$outRows = New-Object System.Collections.Generic.List[object]
$seenPhys = @{}

try {
    $fs = [System.IO.File]::Open($MdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

    foreach ($r in $selected) {
        $pageObj = Parse-PageIdParts -PageText ([string]$r.page_id)
        if ($null -eq $pageObj) { continue }
        $pageParseMode = "hex"

        $slotId = [int]$r.slot_id
        if ($slotId -lt 0) { continue }

        $physKey = ("{0}:{1}:{2}" -f $pageObj.file_id, $pageObj.page_id, $slotId)
        if ($DeduplicateByPhysLoc -and $seenPhys.ContainsKey($physKey)) {
            continue
        }
        $seenPhys[$physKey] = $true

        $pageKey = ("{0}:{1}" -f $pageObj.file_id, $pageObj.page_id)
        $pageBuf = $null
        if ($pageCache.ContainsKey($pageKey)) {
            $pageCacheHits++
            $pageBuf = [byte[]]$pageCache[$pageKey]
        } else {
            $offset = [int64]$pageObj.page_id * [int64]$PageSize
            if ($offset + $PageSize -gt $fileLength) {
                $bad.Add([pscustomobject]@{
                    page_id = $pageObj.page_id
                    slot_id = $slotId
                    reason = "out_of_range"
                    lsn = [string]$r.current_lsn
                    operation = [string]$r.operation_name
                    context = [string]$r.context_name
                }) | Out-Null
                continue
            }

            $buf = New-Object byte[] $PageSize
            [void]$fs.Seek($offset, [System.IO.SeekOrigin]::Begin)
            $read = $fs.Read($buf, 0, $PageSize)
            if ($read -ne $PageSize) {
                $bad.Add([pscustomobject]@{
                    page_id = $pageObj.page_id
                    slot_id = $slotId
                    reason = "short_read"
                    lsn = [string]$r.current_lsn
                    operation = [string]$r.operation_name
                    context = [string]$r.context_name
                }) | Out-Null
                continue
            }
            $pageReads++
            $pageCache[$pageKey] = $buf
            $pageBuf = $buf
        }

        $slotCount = [int][BitConverter]::ToUInt16($pageBuf, 22) # m_slotCnt
        $pageType = [int]$pageBuf[1]
        $pageLevel = [int]$pageBuf[3]
        $pagePminlen = [int][BitConverter]::ToUInt16($pageBuf, 14)
        $needsFallback = $false
        $isCurrentPagePlausible = Is-PlausibleRowPage -PageType $pageType -PagePminlen $pagePminlen -ContextName ([string]$r.context_name)
        if ($slotId -ge $slotCount) {
            $needsFallback = $true
        } elseif (-not $isCurrentPagePlausible) {
            # Keep reading current page when slot is in-range; shape is used only to prefer better fallback page.
            $needsFallback = $true
        }

        if ($needsFallback) {
            $fallbackApplied = $false
            # Fallback: for all-digit page token, retry with decimal page-id interpretation.
            # Some manifests carry numeric page IDs that can be misread if assumed hex.
            $pageToken = [string]$pageObj.page_token
            if (-not [string]::IsNullOrWhiteSpace($pageToken) -and $pageToken -match '^[0-9]+$') {
                try {
                    $altPageId = [int][Convert]::ToInt32($pageToken, 10)
                    if ($altPageId -ne $pageObj.page_id) {
                        $altPageKey = ("{0}:{1}" -f $pageObj.file_id, $altPageId)
                        $altPageBuf = $null
                        $altPageBuf = Read-PageBuffer -FileStream $fs -Cache $pageCache -FileId $pageObj.file_id -PageId $altPageId -InputPageSize $PageSize -InputFileLength $fileLength -PageReadsRef ([ref]$pageReads) -PageCacheHitsRef ([ref]$pageCacheHits)

                        if ($null -ne $altPageBuf) {
                            $altSlotCount = [int][BitConverter]::ToUInt16($altPageBuf, 22)
                            $altPageType = [int]$altPageBuf[1]
                            $altPagePminlen = [int][BitConverter]::ToUInt16($altPageBuf, 14)
                            $altPlausible = Is-PlausibleRowPage -PageType $altPageType -PagePminlen $altPagePminlen -ContextName ([string]$r.context_name)
                            if (($slotId -lt $altSlotCount) -and $altPlausible) {
                                $pageObj = [pscustomobject]@{
                                    file_id = $pageObj.file_id
                                    page_id = $altPageId
                                    file_token = [string]$pageObj.file_token
                                    page_token = [string]$pageObj.page_token
                                }
                                $pageBuf = $altPageBuf
                                $slotCount = $altSlotCount
                                $pageType = $altPageType
                                $pageLevel = [int]$pageBuf[3]
                                $pagePminlen = $altPagePminlen
                                $pageParseMode = "decimal_fallback"
                                $fallbackApplied = $true
                            }
                        }
                    }
                } catch {
                    # Ignore fallback parse/read errors and keep original reason path.
                }
            }

            # Secondary fallback: local neighborhood probe for off-by-page mapping drift.
            # Applies when slot is out-of-bounds OR current page shape is implausible.
            if ((-not $fallbackApplied) -and (($slotId -ge $slotCount) -or (-not $isCurrentPagePlausible))) {
                $probeBest = $null
                foreach ($delta in @(-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32)) {
                    $candPageId = [int]$pageObj.page_id + [int]$delta
                    if ($candPageId -lt 0) { continue }
                    $candBuf = Read-PageBuffer -FileStream $fs -Cache $pageCache -FileId $pageObj.file_id -PageId $candPageId -InputPageSize $PageSize -InputFileLength $fileLength -PageReadsRef ([ref]$pageReads) -PageCacheHitsRef ([ref]$pageCacheHits)
                    if ($null -eq $candBuf) { continue }
                    $candSlotCount = [int][BitConverter]::ToUInt16($candBuf, 22)
                    if ($slotId -ge $candSlotCount) { continue }
                    $candType = [int]$candBuf[1]
                    $candPmin = [int][BitConverter]::ToUInt16($candBuf, 14)
                    if (-not (Is-PlausibleRowPage -PageType $candType -PagePminlen $candPmin -ContextName ([string]$r.context_name))) { continue }

                    $probeBest = [pscustomobject]@{
                        page_id = $candPageId
                        page_buf = $candBuf
                        slot_count = $candSlotCount
                        page_type = $candType
                        page_pminlen = $candPmin
                        page_level = [int]$candBuf[3]
                    }
                    break
                }

                if ($null -ne $probeBest) {
                    $pageObj = [pscustomobject]@{
                        file_id = $pageObj.file_id
                        page_id = [int]$probeBest.page_id
                        file_token = [string]$pageObj.file_token
                        page_token = [string]$pageObj.page_token
                    }
                    $pageBuf = [byte[]]$probeBest.page_buf
                    $slotCount = [int]$probeBest.slot_count
                    $pageType = [int]$probeBest.page_type
                    $pagePminlen = [int]$probeBest.page_pminlen
                    $pageLevel = [int]$probeBest.page_level
                    $pageParseMode = "neighbor_probe_fallback"
                    $fallbackApplied = $true
                }
            }

            if (-not $fallbackApplied) {
            if (($slotId -lt $slotCount) -and (-not $isCurrentPagePlausible)) {
                # Slot exists; continue with current page and let decoder decide.
                $needsFallback = $false
            } else {
            $bad.Add([pscustomobject]@{
                page_id = $pageObj.page_id
                slot_id = $slotId
                reason = if ($slotId -ge $slotCount) { ("slot_oob:{0}" -f $slotCount) } else { ("page_shape:{0}:{1}" -f $pageType, $pagePminlen) }
                lsn = [string]$r.current_lsn
                operation = [string]$r.operation_name
                context = [string]$r.context_name
            }) | Out-Null
            continue
            }
            }
        }

        $slotArrayStart = $PageSize - ($slotCount * 2)
        $rawOffsets = New-Object System.Collections.Generic.List[int]
        $normOffsets = New-Object System.Collections.Generic.List[int]
        for ($i = 0; $i -lt $slotCount; $i++) {
            $raw = [int][BitConverter]::ToUInt16($pageBuf, $PageSize - (($i + 1) * 2))
            $norm = Normalize-SlotOffset -RawOffset $raw -InputPageSize $PageSize
            $rawOffsets.Add($raw) | Out-Null
            $normOffsets.Add($norm) | Out-Null
        }

        $rowStart = $normOffsets[$slotId]
        if ($rowStart -lt 96 -or $rowStart -ge $slotArrayStart) {
            $bad.Add([pscustomobject]@{
                page_id = $pageObj.page_id
                slot_id = $slotId
                reason = ("slot_norm:{0}" -f $rowStart)
                lsn = [string]$r.current_lsn
                operation = [string]$r.operation_name
                context = [string]$r.context_name
            }) | Out-Null
            continue
        }

        $freeData = [int][BitConverter]::ToUInt16($pageBuf, 30)
        $candidateEnds = @()
        foreach ($off in $normOffsets) {
            if ($off -gt $rowStart -and $off -lt $slotArrayStart) {
                $candidateEnds += $off
            }
        }
        if ($freeData -gt $rowStart -and $freeData -le $slotArrayStart) {
            $candidateEnds += $freeData
        }
        $rowEnd = if ($candidateEnds.Count -gt 0) { ($candidateEnds | Sort-Object | Select-Object -First 1) } else { $slotArrayStart }
        $rowLen = $rowEnd - $rowStart
        if ($rowLen -le 0) {
            $bad.Add([pscustomobject]@{
                page_id = $pageObj.page_id
                slot_id = $slotId
                reason = "row_len<=0"
                lsn = [string]$r.current_lsn
                operation = [string]$r.operation_name
                context = [string]$r.context_name
            }) | Out-Null
            continue
        }

        $rowBytes = New-Object byte[] $rowLen
        [Array]::Copy($pageBuf, $rowStart, $rowBytes, 0, $rowLen)

        $outRows.Add([pscustomobject]@{
            manifest_key = [string]$r.manifest_key
            current_lsn = [string]$r.current_lsn
            tx_id = [string]$r.tx_id
            action = [string]$r.action
            operation_name = [string]$r.operation_name
            context_name = [string]$r.context_name
            alloc_unit_name = [string]$r.alloc_unit_name
            page_id = [string]$r.page_id
            page_parse_mode = $pageParseMode
            slot_id = $slotId
            file_id = $pageObj.file_id
            page_id_dec = $pageObj.page_id
            page_type = $pageType
            page_level = $pageLevel
            page_pminlen = $pagePminlen
            page_slot_count = $slotCount
            row_start = $rowStart
            row_end = $rowEnd
            row_length = $rowLen
            status_a = [int]$rowBytes[0]
            status_b = if ($rowBytes.Length -ge 2) { [int]$rowBytes[1] } else { $null }
            fixed_len_end = if ($rowBytes.Length -ge 4) { [int][BitConverter]::ToUInt16($rowBytes, 2) } else { $null }
            row_hex = (Bytes-ToHex -Bytes $rowBytes)
        }) | Out-Null
    }
}
finally {
    if ($fs) { $fs.Dispose() }
    $sw.Stop()
}

$rowArray = @($outRows.ToArray())
$badArray = @($bad.ToArray() | Select-Object -First 500)

$result = [pscustomobject]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    manifest_path = $ManifestPath
    mdf_path = $MdfPath
    target_table = $TargetTable
    deduplicate_by_physloc = $DeduplicateByPhysLoc
    manifest_record_count = $selected.Count
    resolved_row_count = $outRows.Count
    unresolved_row_count = $bad.Count
    page_reads = $pageReads
    page_cache_hits = $pageCacheHits
    elapsed_ms = [int64]$sw.ElapsedMilliseconds
    rows = $rowArray
    unresolved = $badArray
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Wrote {0} resolved offline MDF rows ({1} unresolved) to {2}" -f $outRows.Count, $bad.Count, (Resolve-Path -LiteralPath $OutputPath))
