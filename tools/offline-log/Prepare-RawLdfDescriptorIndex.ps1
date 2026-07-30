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
    [bool]$ForceRebuild = $false
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

function ConvertTo-JsonQuoted {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return "null" }
    $escaped = $Value.Replace("\", "\\").Replace('"', '\"').Replace("`r", "\r").Replace("`n", "\n").Replace("`t", "\t")
    return ('"' + $escaped + '"')
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outDir = ".\output"
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $OutputPath = Join-Path -Path $outDir -ChildPath (([System.IO.Path]::GetFileName($LdfPath)) + ".descriptor-index.json")
}

$fileInfo = Get-Item -LiteralPath $LdfPath
$fileLength = [int64]$fileInfo.Length
$edge = Get-FileEdgeSha1 -Path $LdfPath
$chunkSizeBytes = [int64]$ChunkSizeMB * 1MB
$scanCarryBytes = [Math]::Max(96, $ChunkOverlapBytes)
$recordsPath = ($OutputPath + ".records.jsonl")

if ((-not $ForceRebuild) -and (Test-Path -LiteralPath $OutputPath)) {
    try {
        $existing = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
        $valid =
            $existing -and
            ([int](($existing.version | ForEach-Object { $_ }) -as [int]) -ge 3) -and
            ([string]$existing.ldf_file_name).Equals(([System.IO.Path]::GetFileName($LdfPath)), [System.StringComparison]::OrdinalIgnoreCase) -and
            ([int64]$existing.ldf_file_length -eq $fileLength) -and
            ([int64]$existing.chunk_size_bytes -eq $chunkSizeBytes) -and
            ([string]$existing.ldf_last_write_utc -eq $fileInfo.LastWriteTimeUtc.ToString("o")) -and
            ([string]$existing.head_sha1 -eq $edge.head_sha1) -and
            ([string]$existing.tail_sha1 -eq $edge.tail_sha1) -and
            ([string](($existing.format | ForEach-Object { $_ }) -as [string]) -eq "jsonl") -and
            ($existing.PSObject.Properties.Name -contains "records_path") -and
            (Test-Path -LiteralPath ([string]$existing.records_path))
        if ($valid) {
            Write-Host ("Raw LDF descriptor index already up to date: {0}" -f (Resolve-Path -LiteralPath $OutputPath))
            exit 0
        }
    } catch {
        # Rebuild on invalid descriptor index.
    }
}

$recordCount = 0
$stream = [System.IO.File]::Open($LdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$writer = $null
try {
    $recordsDir = Split-Path -Parent $recordsPath
    if ($recordsDir -and -not (Test-Path -LiteralPath $recordsDir)) {
        New-Item -ItemType Directory -Path $recordsDir | Out-Null
    }
    $writer = New-Object System.IO.StreamWriter($recordsPath, $false, (New-Object System.Text.UTF8Encoding($false)))

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
            $majorOp = [byte]0
            $majorCandidates = @($scan[$i + 22], $scan[$i + 21], $scan[$i + 23], $scan[$i + 24])
            foreach ($maj in $majorCandidates) {
                $parsedAction = Parse-DmlAction -MajorOp $maj
                if ($parsedAction) {
                    $action = $parsedAction
                    $majorOp = [byte]$maj
                    break
                }
            }
            $actionUpper = $null
            $actionTxKey = $null
            if ($action) {
                $actionUpper = ([string]$action).ToUpperInvariant()
            }

            $dbMarker = $scan[$i + 4]
            $seqPart = [BitConverter]::ToUInt32($scan, $i + 8)
            $recPart = [BitConverter]::ToUInt16($scan, $i + 12)
            $absoluteOffset = [int64]$scanBaseOffset + [int64]$i
            $txText = Format-TxId -TxId $txId
            $lsnText = Format-LsnHeuristic -DbMarker $dbMarker -SeqPart $seqPart -RecPart $recPart
            $lsnLexKey = Get-LsnLexKey -LsnText $lsnText
            $parsedHobtToken = [int64][BitConverter]::ToUInt32($scan, $i + 32)
            $chunkId = [int][Math]::Floor(([double]$absoluteOffset) / ([double]$chunkSizeBytes))
            if (-not [string]::IsNullOrWhiteSpace($actionUpper)) {
                $actionTxKey = ("{0}|{1}" -f $actionUpper, $txText).ToUpperInvariant()
            }

            $jsonLine = ("{{""action"":{0},""action_tx_key"":{1},""tx_id"":{2},""lsn_heuristic"":{3},""lsn_lex_key"":{4},""offset"":{5},""parsed_hobt_token"":{6},""chunk_id"":{7},""major_op_hex"":{8},""header_len"":{9}}}" -f `
                (ConvertTo-JsonQuoted ([string]$action)),
                (ConvertTo-JsonQuoted ([string]$actionTxKey)),
                (ConvertTo-JsonQuoted ([string]$txText)),
                (ConvertTo-JsonQuoted ([string]$lsnText)),
                (ConvertTo-JsonQuoted ([string]$lsnLexKey)),
                ([int64]$absoluteOffset),
                ([int64]$parsedHobtToken),
                ([int]$chunkId),
                (ConvertTo-JsonQuoted ("0x{0}" -f $majorOp.ToString("X2"))),
                ([int]$hdrLen)
            )
            $writer.WriteLine($jsonLine)
            $recordCount++
        }

        $keep = [Math]::Min($scanCarryBytes, $scan.Length)
        $carry = New-Object byte[] $keep
        [Array]::Copy($scan, $scan.Length - $keep, $carry, 0, $keep)

        $absolutePos += $read
        $remaining -= $read
    }
} finally {
    if ($null -ne $writer) {
        $writer.Flush()
        $writer.Dispose()
    }
    $stream.Dispose()
}

$outObj = [pscustomobject]@{
    version             = 3
    collected_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
    ldf_file_name       = [System.IO.Path]::GetFileName($LdfPath)
    ldf_file_length     = [int64]$fileLength
    ldf_last_write_utc  = $fileInfo.LastWriteTimeUtc.ToString("o")
    head_sha1           = $edge.head_sha1
    tail_sha1           = $edge.tail_sha1
    chunk_size_bytes    = [int64]$chunkSizeBytes
    chunk_overlap_bytes = [int]$scanCarryBytes
    format              = "jsonl"
    records_path        = $recordsPath
    record_count        = [int]$recordCount
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$outObj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Prepared raw LDF descriptor index: {0} (records={1}; records_path={2})" -f (Resolve-Path -LiteralPath $OutputPath), $recordCount, $recordsPath)
