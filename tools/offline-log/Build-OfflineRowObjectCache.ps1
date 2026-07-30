param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$MdfPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetTable,

    [Parameter(Mandatory = $true)]
    [string]$MetadataSnapshotPath,

    [Parameter()]
    [string]$OutputPath = ".\\output\\offline-row-object-cache.json",

    [Parameter()]
    [bool]$DeduplicateByPhysLoc = $false,

    [Parameter()]
    [bool]$ExportDiagnostics = $true,

    [Parameter()]
    [string]$DiagnosticsOutputPath,

    [Parameter()]
    [bool]$ExpandDataPagesAllSlots = $false,

    [Parameter()]
    [int]$MaxExpandedPages = 256,

    [Parameter()]
    [bool]$EnableGuidedSlotRecovery = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "ManifestPath not found: $ManifestPath" }
if (-not (Test-Path -LiteralPath $MdfPath)) { throw "MdfPath not found: $MdfPath" }
if (-not (Test-Path -LiteralPath $MetadataSnapshotPath)) { throw "MetadataSnapshotPath not found: $MetadataSnapshotPath" }

function Convert-HexToBytesLocal {
    param([string]$Hex)
    $clean = [string]$Hex
    if ([string]::IsNullOrWhiteSpace($clean)) { return @() }
    $clean = $clean.Trim()
    if ($clean.StartsWith("0x")) { $clean = $clean.Substring(2) }
    if (($clean.Length % 2) -ne 0) { return @() }
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $clean.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($clean.Substring($i, 2), 16)
    }
    return $bytes
}

function Decode-QuoteLineKeyFromManifestRow {
    param([psobject]$Row)

    if ($null -eq $Row) { return $null }
    $hex = [string]$Row.rowlog2_hex
    if ([string]::IsNullOrWhiteSpace($hex)) { return $null }
    $b = Convert-HexToBytesLocal -Hex $hex
    if ($b.Length -lt 9) { return $null }

    $quoteId = [int64][BitConverter]::ToUInt32($b, 1)
    $lineNum = [int64][BitConverter]::ToUInt32($b, 5)
    if ($quoteId -le 0 -or $lineNum -lt 0) { return $null }

    $txt = [System.Text.Encoding]::ASCII.GetString($b)
    $m = [regex]::Match($txt, "([A-Z0-9_]{6,32})")
    if (-not $m.Success) { return $null }
    $dbid = [string]$m.Groups[1].Value

    return [pscustomobject]@{
        DBID = $dbid
        QUOTEID = $quoteId
        LINENUMBER = $lineNum
    }
}

function Normalize-SlotOffsetLocal {
    param([int]$RawOffset, [int]$PageSize)
    if ($RawOffset -ge 0 -and $RawOffset -lt $PageSize) { return $RawOffset }
    $masked = ($RawOffset -band 0x1FFF)
    if ($masked -ge 0 -and $masked -lt $PageSize) { return $masked }
    return -1
}

function Read-RowFromPageSlot {
    param(
        [System.IO.FileStream]$FileStream,
        [int64]$FileLength,
        [int]$PageId,
        [int]$SlotId,
        [int]$PageSize = 8192
    )

    $off = [int64]$PageId * [int64]$PageSize
    if ($off + $PageSize -gt $FileLength) { return $null }
    $buf = New-Object byte[] $PageSize
    [void]$FileStream.Seek($off, [System.IO.SeekOrigin]::Begin)
    $read = $FileStream.Read($buf, 0, $PageSize)
    if ($read -ne $PageSize) { return $null }

    $slotCount = [int][BitConverter]::ToUInt16($buf, 22)
    if ($SlotId -lt 0 -or $SlotId -ge $slotCount) { return $null }
    $slotArrayStart = $PageSize - ($slotCount * 2)
    $rawOffsets = New-Object System.Collections.Generic.List[int]
    $normOffsets = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $slotCount; $i++) {
        $raw = [int][BitConverter]::ToUInt16($buf, $PageSize - (($i + 1) * 2))
        $norm = Normalize-SlotOffsetLocal -RawOffset $raw -PageSize $PageSize
        $rawOffsets.Add($raw) | Out-Null
        $normOffsets.Add($norm) | Out-Null
    }
    $rowStart = [int]$normOffsets[$SlotId]
    if ($rowStart -lt 96 -or $rowStart -ge $slotArrayStart) { return $null }
    $freeData = [int][BitConverter]::ToUInt16($buf, 30)
    $candidateEnds = @()
    foreach ($n in $normOffsets) {
        if ($n -gt $rowStart -and $n -lt $slotArrayStart) { $candidateEnds += $n }
    }
    if ($freeData -gt $rowStart -and $freeData -le $slotArrayStart) { $candidateEnds += $freeData }
    $rowEnd = if ($candidateEnds.Count -gt 0) { ($candidateEnds | Sort-Object | Select-Object -First 1) } else { $slotArrayStart }
    $rowLen = $rowEnd - $rowStart
    if ($rowLen -le 0) { return $null }

    $rowBytes = New-Object byte[] $rowLen
    [Array]::Copy($buf, $rowStart, $rowBytes, 0, $rowLen)
    $rowHex = "0x" + [System.BitConverter]::ToString($rowBytes).Replace("-", "")

    return [pscustomobject]@{
        page_type = [int]$buf[1]
        page_level = [int]$buf[3]
        page_pminlen = [int][BitConverter]::ToUInt16($buf, 14)
        page_slot_count = $slotCount
        row_length = $rowLen
        fixed_len_end = if ($rowLen -ge 4) { [int][BitConverter]::ToUInt16($rowBytes, 2) } else { $null }
        row_hex = $rowHex
    }
}

$thisDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$readScript = Join-Path $thisDir "Read-MdfRowsFromManifest.ps1"
$decodeScript = Join-Path $thisDir "Decode-MdfRowHex.ps1"
if (-not (Test-Path -LiteralPath $readScript)) { throw "Missing script: $readScript" }
if (-not (Test-Path -LiteralPath $decodeScript)) { throw "Missing script: $decodeScript" }

$tmpRowsPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ("offline_rows_{0}.json" -f [guid]::NewGuid().ToString("N")))
$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    & $readScript `
        -ManifestPath $ManifestPath `
        -MdfPath $MdfPath `
        -TargetTable $TargetTable `
        -OutputPath $tmpRowsPath `
        -DeduplicateByPhysLoc $DeduplicateByPhysLoc | Out-Null

    $rowsObj = Get-Content -LiteralPath $tmpRowsPath -Raw | ConvertFrom-Json
    $resolvedRows = @($rowsObj.rows)
    $readUnresolvedInitial = @($rowsObj.unresolved)

    # Targeted recovery for slot_oob rows using decoded CHSC_QUOTELINE key and nearby-page probe.
    if ($EnableGuidedSlotRecovery -and $TargetTable.ToUpperInvariant() -eq "OASIS.CHSC_QUOTELINE") {
        $manifestObj = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $manifestByLsn = @{}
        foreach ($mr in @($manifestObj.records)) {
            $lsn = [string]$mr.current_lsn
            if ([string]::IsNullOrWhiteSpace($lsn)) { continue }
            $manifestByLsn[$lsn] = $mr
        }

        $fsProbe = $null
        $fileLenProbe = (Get-Item -LiteralPath $MdfPath).Length
        try {
            $fsProbe = [System.IO.File]::Open($MdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

            $keptUnresolved = New-Object System.Collections.Generic.List[object]
            foreach ($u in $readUnresolvedInitial) {
                $reason = [string]$u.reason
                if ($reason -notlike "slot_oob:*") {
                    $keptUnresolved.Add($u) | Out-Null
                    continue
                }

                $lsn = [string]$u.lsn
                if (-not $manifestByLsn.ContainsKey($lsn)) {
                    $keptUnresolved.Add($u) | Out-Null
                    continue
                }
                $mrow = $manifestByLsn[$lsn]
                $k = Decode-QuoteLineKeyFromManifestRow -Row $mrow
                if ($null -eq $k) {
                    $keptUnresolved.Add($u) | Out-Null
                    continue
                }

                $basePage = [int]$u.page_id
                $slotId = [int]$u.slot_id
                $matched = $false

                foreach ($delta in @(-128..128 | Where-Object { $_ -ne 0 })) {
                    $candPage = $basePage + [int]$delta
                    if ($candPage -lt 0) { continue }
                    $rowObj = Read-RowFromPageSlot -FileStream $fsProbe -FileLength $fileLenProbe -PageId $candPage -SlotId $slotId
                    if ($null -eq $rowObj) { continue }
                    if (($rowObj.page_type -notin @(1,2,3))) { continue }

                    try {
                        $decodedJson = & $decodeScript -RowHex $rowObj.row_hex -PagePminlen ([int]$rowObj.page_pminlen) -PageLevel ([int]$rowObj.page_level) -MetadataSnapshotPath $MetadataSnapshotPath -TargetTable $TargetTable
                        $decoded = $decodedJson | ConvertFrom-Json
                    } catch {
                        continue
                    }

                    if ($null -eq $decoded -or -not ($decoded.PSObject.Properties.Name -contains "values")) { continue }
                    $vals = $decoded.values
                    if ($null -eq $vals) { continue }

                    $dbid = [string]$vals.DBID
                    $qid = $vals.QUOTEID
                    $ln = $vals.LINENUMBER
                    if ([string]::IsNullOrWhiteSpace($dbid)) { continue }
                    if ($null -eq $qid -or $null -eq $ln) { continue }

                    if ($dbid.Equals([string]$k.DBID, [System.StringComparison]::OrdinalIgnoreCase) -and ([int64]$qid -eq [int64]$k.QUOTEID) -and ([int64]$ln -eq [int64]$k.LINENUMBER)) {
                        $resolvedRows += [pscustomobject]@{
                            manifest_key = [string]$mrow.manifest_key
                            current_lsn = [string]$mrow.current_lsn
                            tx_id = [string]$mrow.tx_id
                            action = [string]$mrow.action
                            alloc_unit_name = [string]$mrow.alloc_unit_name
                            page_id = [string]$mrow.page_id
                            slot_id = [int]$mrow.slot_id
                            file_id = 1
                            page_id_dec = $candPage
                            page_pminlen = [int]$rowObj.page_pminlen
                            page_level = [int]$rowObj.page_level
                            decode_record_type = if ($decoded.PSObject.Properties.Name -contains "record_type") { [string]$decoded.record_type } else { $null }
                            decode_layout_mode = if ($decoded.PSObject.Properties.Name -contains "layout_mode") { [string]$decoded.layout_mode } else { $null }
                            decode_has_variable = if ($decoded.PSObject.Properties.Name -contains "has_variable_flag") { [bool]$decoded.has_variable_flag } else { $null }
                            decode_has_null_bitmap = if ($decoded.PSObject.Properties.Name -contains "has_null_bitmap_flag") { [bool]$decoded.has_null_bitmap_flag } else { $null }
                            row_ref = [pscustomobject]@{
                                file_id = 1
                                page_id = $candPage
                                slot_id = $slotId
                            }
                            values = $vals
                        }
                        $matched = $true
                        break
                    }
                }

                if (-not $matched) {
                    $keptUnresolved.Add($u) | Out-Null
                }
            }

            $rowsObj | Add-Member -NotePropertyName unresolved -NotePropertyValue @($keptUnresolved.ToArray()) -Force
            $rowsObj | Add-Member -NotePropertyName unresolved_row_count -NotePropertyValue ([int]$keptUnresolved.Count) -Force
        } finally {
            if ($null -ne $fsProbe) { $fsProbe.Dispose() }
        }
    }

    if ($ExpandDataPagesAllSlots -and $resolvedRows.Count -gt 0) {
        $seenPhys = @{}
        foreach ($rr in $resolvedRows) {
            if (($rr.PSObject.Properties.Name -contains "file_id") -and
                ($rr.PSObject.Properties.Name -contains "page_id_dec") -and
                ($rr.PSObject.Properties.Name -contains "slot_id")) {
                $k = ("{0}:{1}:{2}" -f [int]$rr.file_id, [int]$rr.page_id_dec, [int]$rr.slot_id)
                $seenPhys[$k] = $true
            }
        }

        $candidatePages = @(
            $resolvedRows |
                Where-Object {
                    ($_.PSObject.Properties.Name -contains "file_id") -and
                    ($_.PSObject.Properties.Name -contains "page_id_dec") -and
                    ($_.PSObject.Properties.Name -contains "page_type") -and
                    ($_.PSObject.Properties.Name -contains "page_pminlen") -and
                    (([int]$_.page_type) -in @(1,2)) -and
                    ([int]$_.page_pminlen -gt 0)
                } |
                Group-Object @{ Expression = { "{0}:{1}" -f [int]$_.file_id, [int]$_.page_id_dec } } |
                Select-Object -First $MaxExpandedPages
        )

        if ($candidatePages.Count -gt 0) {
            $fs = $null
            try {
                $fileLen = (Get-Item -LiteralPath $MdfPath).Length
                $fs = [System.IO.File]::Open($MdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

                foreach ($pg in $candidatePages) {
                    $parts = ([string]$pg.Name).Split(":")
                    if ($parts.Count -ne 2) { continue }
                    $fileId = [int]$parts[0]
                    $pageId = [int]$parts[1]
                    $pageOffset = [int64]$pageId * 8192L
                    if ($pageOffset + 8192L -gt $fileLen) { continue }

                    $buf = New-Object byte[] 8192
                    [void]$fs.Seek($pageOffset, [System.IO.SeekOrigin]::Begin)
                    $read = $fs.Read($buf, 0, 8192)
                    if ($read -ne 8192) { continue }

                    $slotCount = [int][BitConverter]::ToUInt16($buf, 22)
                    if ($slotCount -le 0) { continue }
                    $slotArrayStart = 8192 - ($slotCount * 2)
                    $freeData = [int][BitConverter]::ToUInt16($buf, 30)
                    $pageType = [int]$buf[1]
                    $pageLevel = [int]$buf[3]
                    $pagePmin = [int][BitConverter]::ToUInt16($buf, 14)

                    $normOffsets = New-Object System.Collections.Generic.List[int]
                    for ($i = 0; $i -lt $slotCount; $i++) {
                        $raw = [int][BitConverter]::ToUInt16($buf, 8192 - (($i + 1) * 2))
                        $norm = $raw
                        if ($norm -lt 0 -or $norm -ge 8192) { $norm = ($raw -band 0x1FFF) }
                        $normOffsets.Add($norm) | Out-Null
                    }

                    for ($slotId = 0; $slotId -lt $slotCount; $slotId++) {
                        $physKey = ("{0}:{1}:{2}" -f $fileId, $pageId, $slotId)
                        if ($seenPhys.ContainsKey($physKey)) { continue }
                        $seenPhys[$physKey] = $true

                        $rowStart = [int]$normOffsets[$slotId]
                        if ($rowStart -lt 96 -or $rowStart -ge $slotArrayStart) { continue }

                        $candidateEnds = New-Object System.Collections.Generic.List[int]
                        foreach ($off in $normOffsets) {
                            if ($off -gt $rowStart -and $off -lt $slotArrayStart) { $candidateEnds.Add([int]$off) | Out-Null }
                        }
                        if ($freeData -gt $rowStart -and $freeData -le $slotArrayStart) {
                            $candidateEnds.Add([int]$freeData) | Out-Null
                        }
                        $rowEnd = if ($candidateEnds.Count -gt 0) { [int](($candidateEnds | Sort-Object | Select-Object -First 1)) } else { $slotArrayStart }
                        $rowLen = $rowEnd - $rowStart
                        if ($rowLen -le 0) { continue }

                        $rowBytes = New-Object byte[] $rowLen
                        [Array]::Copy($buf, $rowStart, $rowBytes, 0, $rowLen)
                        $rowHex = "0x" + [System.BitConverter]::ToString($rowBytes).Replace("-", "")

                        $resolvedRows += [pscustomobject]@{
                            manifest_key = ("EXPAND:{0}:{1}:{2}" -f $fileId, $pageId, $slotId)
                            current_lsn = $null
                            tx_id = $null
                            action = "EXPAND"
                            operation_name = $null
                            context_name = "EXPANDED_PAGE_SLOT"
                            alloc_unit_name = $null
                            page_id = ("{0:X4}:{1:X8}" -f $fileId, $pageId)
                            slot_id = $slotId
                            file_id = $fileId
                            page_id_dec = $pageId
                            page_pminlen = $pagePmin
                            page_level = $pageLevel
                            page_type = $pageType
                            row_length = $rowLen
                            fixed_len_end = if ($rowLen -ge 4) { [int][BitConverter]::ToUInt16($rowBytes, 2) } else { $null }
                            row_hex = $rowHex
                        }
                    }
                }
            } finally {
                if ($null -ne $fs) { $fs.Dispose() }
            }
        }
    }
    $decodeCache = @{}
    $outRows = New-Object System.Collections.Generic.List[object]
    $decodeFailures = 0
    $decodeFailureRows = New-Object System.Collections.Generic.List[object]

    foreach ($r in $resolvedRows) {
        $rowHex = [string]$r.row_hex
        if ([string]::IsNullOrWhiteSpace($rowHex)) { continue }

        $decoded = $null
        $pagePminlen = if ($r.PSObject.Properties.Name -contains "page_pminlen") { [int]$r.page_pminlen } else { -1 }
        $pageLevel = if ($r.PSObject.Properties.Name -contains "page_level") { [int]$r.page_level } else { -1 }
        $rowLength = if ($r.PSObject.Properties.Name -contains "row_length") { [int]$r.row_length } else { -1 }
        $fixedLenEnd = if ($r.PSObject.Properties.Name -contains "fixed_len_end") { [int]$r.fixed_len_end } else { -1 }
        $decodeKey = ("{0}|{1}|{2}" -f $rowHex, $pagePminlen, $pageLevel)

        # Keep attempting decode even for pmin=0/fixed=rowlen rows.
        # Decoder has fallback probes for these row shapes.

        if ($decodeCache.ContainsKey($decodeKey)) {
            $decoded = $decodeCache[$decodeKey]
        } else {
            try {
                $decodeJson = & $decodeScript `
                    -RowHex $rowHex `
                    -PagePminlen $pagePminlen `
                    -PageLevel $pageLevel `
                    -MetadataSnapshotPath $MetadataSnapshotPath `
                    -TargetTable $TargetTable
                $decoded = $decodeJson | ConvertFrom-Json
                $decodeCache[$decodeKey] = $decoded
            } catch {
                $decodeFailures++
                $decodeFailureRows.Add([pscustomobject]@{
                    manifest_key = [string]$r.manifest_key
                    current_lsn = [string]$r.current_lsn
                    tx_id = [string]$r.tx_id
                    action = [string]$r.action
                    operation_name = [string]$r.operation_name
                    context_name = [string]$r.context_name
                    alloc_unit_name = [string]$r.alloc_unit_name
                    page_id = [string]$r.page_id
                    slot_id = [int]$r.slot_id
                    file_id = [int]$r.file_id
                    page_id_dec = [int]$r.page_id_dec
                    page_pminlen = $pagePminlen
                    page_level = $pageLevel
                    row_length = if ($r.PSObject.Properties.Name -contains "row_length") { [int]$r.row_length } else { $null }
                    decode_error = [string]$_.Exception.Message
                    reason = "decode_failure"
                }) | Out-Null
                continue
            }
        }

        $values = $null
        if ($decoded.PSObject.Properties.Name -contains "values") {
            $values = $decoded.values
        }
        $decodeRecordType = if ($decoded.PSObject.Properties.Name -contains "record_type") { [string]$decoded.record_type } else { $null }
        $decodeLayoutMode = if ($decoded.PSObject.Properties.Name -contains "layout_mode") { [string]$decoded.layout_mode } else { $null }
        $decodeHasVar = if ($decoded.PSObject.Properties.Name -contains "has_variable_flag") { [bool]$decoded.has_variable_flag } else { $null }
        $decodeHasNull = if ($decoded.PSObject.Properties.Name -contains "has_null_bitmap_flag") { [bool]$decoded.has_null_bitmap_flag } else { $null }

        $outRows.Add([pscustomobject]@{
            manifest_key = [string]$r.manifest_key
            current_lsn = [string]$r.current_lsn
            tx_id = [string]$r.tx_id
            action = [string]$r.action
            alloc_unit_name = [string]$r.alloc_unit_name
            page_id = [string]$r.page_id
            slot_id = [int]$r.slot_id
            file_id = [int]$r.file_id
            page_id_dec = [int]$r.page_id_dec
            page_pminlen = $pagePminlen
            page_level = $pageLevel
            decode_record_type = $decodeRecordType
            decode_layout_mode = $decodeLayoutMode
            decode_has_variable = $decodeHasVar
            decode_has_null_bitmap = $decodeHasNull
            row_ref = [pscustomobject]@{
                file_id = [int]$r.file_id
                page_id = [int]$r.page_id_dec
                slot_id = [int]$r.slot_id
            }
            values = $values
        }) | Out-Null
    }

    $sw.Stop()
    $result = [pscustomobject]@{
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        manifest_path = $ManifestPath
        mdf_path = $MdfPath
        target_table = $TargetTable
        metadata_snapshot_path = $MetadataSnapshotPath
        deduplicate_by_physloc = $DeduplicateByPhysLoc
        resolved_row_count = [int]$outRows.Count
        unresolved_row_count = [int]$rowsObj.unresolved_row_count
        decode_failure_count = [int]$decodeFailures
        page_reads = [int]$rowsObj.page_reads
        page_cache_hits = [int]$rowsObj.page_cache_hits
        elapsed_ms = [int64]$sw.ElapsedMilliseconds
        rows = @($outRows.ToArray())
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host ("Wrote offline row object cache to {0}" -f (Resolve-Path -LiteralPath $OutputPath))

    if ($ExportDiagnostics) {
        if ([string]::IsNullOrWhiteSpace($DiagnosticsOutputPath)) {
            $diagDir = Split-Path -Parent $OutputPath
            $diagBase = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
            $diagExt = [System.IO.Path]::GetExtension($OutputPath)
            if ([string]::IsNullOrWhiteSpace($diagExt)) { $diagExt = ".json" }
            $DiagnosticsOutputPath = Join-Path -Path $diagDir -ChildPath ($diagBase + ".diagnostics" + $diagExt)
        }

        $readUnresolved = @($rowsObj.unresolved)
        $decodeUnresolved = @($decodeFailureRows.ToArray())
        $allUnresolved = @($readUnresolved + $decodeUnresolved)
        $reasonBuckets = @()
        if ($allUnresolved.Count -gt 0) {
            $reasonBuckets = @(
                $allUnresolved |
                    Group-Object reason |
                    Sort-Object Count -Descending |
                    ForEach-Object {
                        [pscustomobject]@{
                            reason = [string]$_.Name
                            count = [int]$_.Count
                        }
                    }
            )
        }

        $topPages = @()
        if ($allUnresolved.Count -gt 0) {
            $topPages = @(
                $allUnresolved |
                    Group-Object page_id |
                    Sort-Object Count -Descending |
                    Select-Object -First 20 |
                    ForEach-Object {
                        [pscustomobject]@{
                            page_id = [string]$_.Name
                            count = [int]$_.Count
                        }
                    }
            )
        }

        $diag = [pscustomobject]@{
            generated_utc = (Get-Date).ToUniversalTime().ToString("o")
            manifest_path = $ManifestPath
            mdf_path = $MdfPath
            target_table = $TargetTable
            output_cache_path = $OutputPath
            totals = [pscustomobject]@{
                manifest_record_count = [int]$rowsObj.manifest_record_count
                resolved_row_count = [int]$outRows.Count
                unresolved_row_count = [int]$rowsObj.unresolved_row_count
                decode_failure_count = [int]$decodeFailures
                unresolved_total = [int]($rowsObj.unresolved_row_count + $decodeFailures)
            }
            unresolved_by_reason = $reasonBuckets
            unresolved_top_pages = $topPages
            unresolved_read_stage = $readUnresolved
            unresolved_decode_stage = $decodeUnresolved
        }

        $diagDir2 = Split-Path -Parent $DiagnosticsOutputPath
        if ($diagDir2 -and -not (Test-Path -LiteralPath $diagDir2)) {
            New-Item -ItemType Directory -Path $diagDir2 | Out-Null
        }
        $diag | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $DiagnosticsOutputPath -Encoding UTF8
        Write-Host ("Wrote offline row diagnostics to {0}" -f (Resolve-Path -LiteralPath $DiagnosticsOutputPath))
    }
}
finally {
    if (Test-Path -LiteralPath $tmpRowsPath) {
        Remove-Item -LiteralPath $tmpRowsPath -Force -ErrorAction SilentlyContinue
    }
}
