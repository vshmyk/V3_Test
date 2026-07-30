param(
    [Parameter(Mandatory = $true)]
    [string]$LdfPath,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [int]$ChunkSizeMB = 64,

    [Parameter()]
    [int]$ChunkOverlapBytes = 96,

    [Parameter()]
    [bool]$ForceRebuild = $false,

    [Parameter()]
    [bool]$LiteMode = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LdfPath)) {
    throw "LDF path not found: $LdfPath"
}
if ($ChunkSizeMB -lt 1) {
    throw "ChunkSizeMB must be >= 1."
}
if ($ChunkOverlapBytes -lt 48) {
    throw "ChunkOverlapBytes must be >= 48."
}

function Format-TxId {
    param([uint32]$TxId)
    return ("0000:{0}" -f $TxId.ToString("X8"))
}

function Format-LsnHeuristic {
    param(
        [byte]$DbMarker,
        [uint32]$SeqPart,
        [uint16]$RecPart
    )
    return ("{0}:{1}:{2}" -f $DbMarker.ToString("X8"), $SeqPart.ToString("X8"), $RecPart.ToString("X4"))
}

function Parse-DmlAction {
    param([byte]$MajorOp)
    switch ($MajorOp) {
        0x02 { return "INSERT" }
        0x03 { return "DELETE" }
        0x04 { return "UPDATE" }
        0x05 { return "UPDATE" }
        0x06 { return "UPDATE" }
        default { return $null }
    }
}

function Get-LsnLexKey {
    param([AllowNull()][string]$LsnText)
    if ([string]::IsNullOrWhiteSpace($LsnText)) { return $null }
    if ($LsnText -notmatch "^([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8}):([0-9A-Fa-f]{4})$") { return $null }
    return ($Matches[1] + $Matches[2] + $Matches[3]).ToUpperInvariant()
}

function Get-FileEdgeSha1 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$ProbeBytes = 4096
    )
    $fi = Get-Item -LiteralPath $Path
    $len = [int64]$fi.Length
    $probe = [Math]::Min([int64]$ProbeBytes, $len)
    if ($probe -le 0) {
        return [pscustomobject]@{ head_sha1 = ""; tail_sha1 = "" }
    }

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $head = New-Object byte[] $probe
        [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
        [void]$fs.Read($head, 0, $head.Length)

        $tail = New-Object byte[] $probe
        [void]$fs.Seek($len - $probe, [System.IO.SeekOrigin]::Begin)
        [void]$fs.Read($tail, 0, $tail.Length)

        $sha = [System.Security.Cryptography.SHA1]::Create()
        try {
            $headHash = -join ($sha.ComputeHash($head) | ForEach-Object { $_.ToString("x2") })
            $tailHash = -join ($sha.ComputeHash($tail) | ForEach-Object { $_.ToString("x2") })
        } finally {
            $sha.Dispose()
        }
        return [pscustomobject]@{
            head_sha1 = $headHash
            tail_sha1 = $tailHash
        }
    } finally {
        $fs.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outDir = ".\output"
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $OutputPath = Join-Path -Path $outDir -ChildPath (([System.IO.Path]::GetFileName($LdfPath)) + ".chunk-index.json")
}

$fileInfo = Get-Item -LiteralPath $LdfPath
$fileLength = [int64]$fileInfo.Length
$edge = Get-FileEdgeSha1 -Path $LdfPath
$chunkSizeBytes = [int64]$ChunkSizeMB * 1MB
$scanCarryBytes = [Math]::Max(96, $ChunkOverlapBytes)

if ((-not $ForceRebuild) -and (Test-Path -LiteralPath $OutputPath)) {
    try {
        $existing = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
        $valid = $false
        if ($existing -and ([int]$existing.version -ge 2)) {
            $existingMode = [string]$existing.index_mode
            if ([string]::IsNullOrWhiteSpace($existingMode)) { $existingMode = "full" }
            $requiredMode = if ($LiteMode) { "lite" } else { "full_dml_v3" }
            $valid =
                ([string]$existing.ldf_file_name).Equals(([System.IO.Path]::GetFileName($LdfPath)), [System.StringComparison]::OrdinalIgnoreCase) -and
                ([int64]$existing.ldf_file_length -eq $fileLength) -and
                ([int64]$existing.chunk_size_bytes -eq $chunkSizeBytes) -and
                ([string]$existing.ldf_last_write_utc -eq $fileInfo.LastWriteTimeUtc.ToString("o")) -and
                ([string]$existing.head_sha1 -eq $edge.head_sha1) -and
                ([string]$existing.tail_sha1 -eq $edge.tail_sha1) -and
                ([string]$existingMode -eq [string]$requiredMode) -and
                ($existing.PSObject.Properties.Name -contains "chunks")
        }
        if ($valid) {
            Write-Host ("Raw LDF index already up to date: {0}" -f (Resolve-Path -LiteralPath $OutputPath))
            exit 0
        }
    } catch {
        # Rebuild on invalid index.
    }
}

$totalChunkSlots = [int][Math]::Ceiling(($fileLength * 1.0) / $chunkSizeBytes)
if ($totalChunkSlots -lt 1) { $totalChunkSlots = 1 }

if ($LiteMode) {
    $chunkItems = New-Object System.Collections.Generic.List[object]
    for ($chunkId = 0; $chunkId -lt $totalChunkSlots; $chunkId++) {
        $offsetStart = [int64]$chunkId * $chunkSizeBytes
        $offsetEnd = [Math]::Min($fileLength, $offsetStart + $chunkSizeBytes)
        $chunkItems.Add([pscustomobject]@{
            chunk_id       = $chunkId
            offset_start   = [int64]$offsetStart
            offset_end     = [int64]$offsetEnd
            record_count   = 0
            lsn_min_key    = $null
            lsn_max_key    = $null
            action_tx_keys = @()
            tx_ids         = @()
            major_op_counts = [pscustomobject]@{}
        }) | Out-Null
    }

    $idxLite = [pscustomobject]@{
        version             = 3
        collected_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
        ldf_file_name       = [System.IO.Path]::GetFileName($LdfPath)
        ldf_file_length     = [int64]$fileLength
        ldf_last_write_utc  = $fileInfo.LastWriteTimeUtc.ToString("o")
        head_sha1           = $edge.head_sha1
        tail_sha1           = $edge.tail_sha1
        chunk_size_bytes    = [int64]$chunkSizeBytes
        chunk_overlap_bytes = [int]$scanCarryBytes
        chunk_count         = $chunkItems.Count
        index_mode          = "lite"
        chunks              = @($chunkItems.ToArray())
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    $idxLite | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host ("Prepared raw LDF index (lite): {0} (chunks={1})" -f (Resolve-Path -LiteralPath $OutputPath), $idxLite.chunk_count)
    exit 0
}

$chunkBuildMap = @{}
$stream = [System.IO.File]::Open($LdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
try {
    $bufferSize = 8MB
    $chunk = New-Object byte[] $bufferSize
    [byte[]]$carry = @()
    $absolutePos = [int64]0
    $remaining = $fileLength

    while ($remaining -gt 0) {
        $request = [int][Math]::Min([int64]$bufferSize, $remaining)
        $read = $stream.Read($chunk, 0, $request)
        if ($read -le 0) { break }

        $scan = New-Object byte[] ($carry.Length + $read)
        if ($carry.Length -gt 0) { [Array]::Copy($carry, 0, $scan, 0, $carry.Length) }
        [Array]::Copy($chunk, 0, $scan, $carry.Length, $read)

        $scanBaseOffset = $absolutePos - $carry.Length
        $limit = $scan.Length - 48
        for ($i = 0; $i -lt $limit; $i++) {
            if ($scan[$i] -ne 0x00 -or $scan[$i + 1] -ne 0x00 -or $scan[$i + 3] -ne 0x00) { continue }

            $hdrLen = [int]$scan[$i + 2]
            if ($hdrLen -lt 0x20 -or $hdrLen -gt 0x90) { continue }

            $txId = [BitConverter]::ToUInt32($scan, $i + 16)
            if ($txId -eq 0) { continue }

            $action = $null
            $majorCandidates = @($scan[$i + 22], $scan[$i + 21], $scan[$i + 23], $scan[$i + 24])
            foreach ($maj in $majorCandidates) {
                $action = Parse-DmlAction -MajorOp $maj
                if ($action) { break }
            }

            $dbMarker = $scan[$i + 4]
            $seqPart = [BitConverter]::ToUInt32($scan, $i + 8)
            $recPart = [BitConverter]::ToUInt16($scan, $i + 12)
            $lsnText = Format-LsnHeuristic -DbMarker $dbMarker -SeqPart $seqPart -RecPart $recPart
            $lsnLex = Get-LsnLexKey -LsnText $lsnText

            $absoluteOffset = [int64]$scanBaseOffset + [int64]$i
            $chunkId = [int][Math]::Floor(([double]$absoluteOffset) / ([double]$chunkSizeBytes))
            if (-not $chunkBuildMap.ContainsKey($chunkId)) {
                $offsetStart = [int64]$chunkId * $chunkSizeBytes
                $offsetEnd = [Math]::Min($fileLength, $offsetStart + $chunkSizeBytes)
                $chunkBuildMap[$chunkId] = [pscustomobject]@{
                    chunk_id        = $chunkId
                    offset_start    = [int64]$offsetStart
                    offset_end      = [int64]$offsetEnd
                    lsn_min_key     = $null
                    lsn_max_key     = $null
                    action_tx_keys  = (New-Object 'System.Collections.Generic.HashSet[string]')
                    tx_ids          = (New-Object 'System.Collections.Generic.HashSet[string]')
                    major_op_counts = @{}
                    record_count    = 0
                }
            }

            $st = $chunkBuildMap[$chunkId]
            $txText = Format-TxId -TxId $txId
            [void]$st.tx_ids.Add($txText.ToUpperInvariant())
            $st.record_count = [int]$st.record_count + 1
            if ($action) {
                [void]$st.action_tx_keys.Add(("{0}|{1}" -f $action, $txText).ToUpperInvariant())
            }
            $majHex = ("0x{0}" -f ([byte]$scan[$i + 22]).ToString("X2"))
            if ($st.major_op_counts.ContainsKey($majHex)) {
                $st.major_op_counts[$majHex] = [int]$st.major_op_counts[$majHex] + 1
            } else {
                $st.major_op_counts[$majHex] = 1
            }
            if (-not [string]::IsNullOrWhiteSpace($lsnLex)) {
                if ([string]::IsNullOrWhiteSpace($st.lsn_min_key) -or [string]::CompareOrdinal($lsnLex, $st.lsn_min_key) -lt 0) { $st.lsn_min_key = $lsnLex }
                if ([string]::IsNullOrWhiteSpace($st.lsn_max_key) -or [string]::CompareOrdinal($lsnLex, $st.lsn_max_key) -gt 0) { $st.lsn_max_key = $lsnLex }
            }
        }

        $keep = [Math]::Min($scanCarryBytes, $scan.Length)
        $carry = New-Object byte[] $keep
        [Array]::Copy($scan, $scan.Length - $keep, $carry, 0, $keep)

        $absolutePos += $read
        $remaining -= $read
    }
} finally {
    $stream.Dispose()
}

$chunkItems = New-Object System.Collections.Generic.List[object]
for ($chunkId = 0; $chunkId -lt $totalChunkSlots; $chunkId++) {
    $st = $null
    if ($chunkBuildMap.ContainsKey($chunkId)) {
        $st = $chunkBuildMap[$chunkId]
    } else {
        $offsetStart = [int64]$chunkId * $chunkSizeBytes
        $offsetEnd = [Math]::Min($fileLength, $offsetStart + $chunkSizeBytes)
        $st = [pscustomobject]@{
            chunk_id        = $chunkId
            offset_start    = [int64]$offsetStart
            offset_end      = [int64]$offsetEnd
            lsn_min_key     = $null
            lsn_max_key     = $null
            action_tx_keys  = (New-Object 'System.Collections.Generic.HashSet[string]')
            tx_ids          = (New-Object 'System.Collections.Generic.HashSet[string]')
            major_op_counts = @{}
            record_count    = 0
        }
    }
    $chunkItems.Add([pscustomobject]@{
        chunk_id       = [int]$st.chunk_id
        offset_start   = [int64]$st.offset_start
        offset_end     = [int64]$st.offset_end
        record_count   = [int]$st.record_count
        lsn_min_key    = [string]$st.lsn_min_key
        lsn_max_key    = [string]$st.lsn_max_key
        action_tx_keys = @($st.action_tx_keys)
        tx_ids         = @($st.tx_ids)
        major_op_counts = [pscustomobject]$st.major_op_counts
    }) | Out-Null
}

$idx = [pscustomobject]@{
    version             = 3
    collected_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
    ldf_file_name       = [System.IO.Path]::GetFileName($LdfPath)
    ldf_file_length     = [int64]$fileLength
    ldf_last_write_utc  = $fileInfo.LastWriteTimeUtc.ToString("o")
    head_sha1           = $edge.head_sha1
    tail_sha1           = $edge.tail_sha1
    chunk_size_bytes    = [int64]$chunkSizeBytes
    chunk_overlap_bytes = [int]$scanCarryBytes
    chunk_count         = $chunkItems.Count
    index_mode          = "full_dml_v3"
    chunks              = @($chunkItems.ToArray())
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$idx | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Prepared raw LDF index: {0} (chunks={1})" -f (Resolve-Path -LiteralPath $OutputPath), $idx.chunk_count)
