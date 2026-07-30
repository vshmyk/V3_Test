param(
    [Parameter(Mandatory = $true)]
    [string]$LdfPath,

    [Parameter()]
    [string]$OutputPath = ".\output\raw-ldf-committed-dml.json",

    [Parameter()]
    [int[]]$HobtTokens = @(363,364,365,366,367,368,369,370,371,372,373),

    [Parameter()]
    [int]$MaxBytes = 0,

    [Parameter()]
    [int]$TailBytes = 67108864
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LdfPath)) {
    throw "LDF path not found: $LdfPath"
}

if ($MaxBytes -lt 0) {
    throw "MaxBytes must be >= 0."
}

if ($TailBytes -lt 0) {
    throw "TailBytes must be >= 0."
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

function Parse-Action {
    param(
        [byte]$LenMarker,
        [byte]$MajorOp
    )

    if ($LenMarker -eq 0x50 -and $MajorOp -eq 0x81) {
        return "COMMIT"
    }
    if ($LenMarker -eq 0x4C) {
        return "BEGIN"
    }
    if ($LenMarker -ne 0x3E) {
        return $null
    }

    switch ($MajorOp) {
        0x02 { return "INSERT" }
        0x03 { return "DELETE" }
        0x04 { return "UPDATE" }
        0x06 { return "UPDATE" }
        default { return $null }
    }
}

[byte[]]$bytes = $null
$baseOffset = [int64]0
if ($TailBytes -gt 0) {
    $fs = [System.IO.File]::Open($LdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fileLen = [int64]$fs.Length
        $readLen = [Math]::Min([int64]$TailBytes, $fileLen)
        $start = $fileLen - $readLen
        $baseOffset = $start
        $bytes = New-Object byte[] $readLen
        [void]$fs.Seek($start, [System.IO.SeekOrigin]::Begin)
        $read = 0
        while ($read -lt $readLen) {
            $n = $fs.Read($bytes, $read, $readLen - $read)
            if ($n -le 0) { break }
            $read += $n
        }
        if ($read -lt $readLen) {
            $tmp = New-Object byte[] $read
            [Array]::Copy($bytes, 0, $tmp, 0, $read)
            $bytes = $tmp
        }
    } finally {
        $fs.Dispose()
    }
} else {
    $bytes = [System.IO.File]::ReadAllBytes($LdfPath)
}

if ($MaxBytes -gt 0 -and $MaxBytes -lt $bytes.Length) {
    $slice = New-Object byte[] $MaxBytes
    [Array]::Copy($bytes, 0, $slice, 0, $MaxBytes)
    $bytes = $slice
}

$limit = $bytes.Length - 48
if ($limit -le 0) {
    throw "LDF file is too small to scan."
}

$commitsByTx = @{}
$dmlCandidates = New-Object System.Collections.Generic.List[object]
$seenKeys = New-Object System.Collections.Generic.HashSet[string]
$hobtFilter = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($tok in $HobtTokens) {
    [void]$hobtFilter.Add([int]$tok)
}

for ($i = 0; $i -lt $limit; $i++) {
    if ($bytes[$i] -ne 0x00 -or $bytes[$i + 1] -ne 0x00 -or $bytes[$i + 3] -ne 0x00) {
        continue
    }

    $lenMarker = $bytes[$i + 2]
    if ($lenMarker -ne 0x3E -and $lenMarker -ne 0x4C -and $lenMarker -ne 0x50) {
        continue
    }

    $recordType = $bytes[$i + 14]
    if ($bytes[$i + 15] -ne 0x00 -or ($recordType -ne 0x02 -and $recordType -ne 0x22)) {
        continue
    }

    $dbMarker = $bytes[$i + 4]
    if ($dbMarker -ne 0x25 -and $dbMarker -ne 0x26 -and $dbMarker -ne 0x00) {
        continue
    }

    $txId = [BitConverter]::ToUInt32($bytes, $i + 16)
    if ($txId -eq 0) {
        continue
    }

    $majorOp = $bytes[$i + 22]
    $action = Parse-Action -LenMarker $lenMarker -MajorOp $majorOp
    if (-not $action) {
        continue
    }

    $seqPart = [BitConverter]::ToUInt32($bytes, $i + 8)
    $recPart = [BitConverter]::ToUInt16($bytes, $i + 12)
    $hobtToken = [int64][BitConverter]::ToUInt32($bytes, $i + 32)
    $txText = Format-TxId -TxId $txId
    $lsnHeuristic = Format-LsnHeuristic -DbMarker $dbMarker -SeqPart $seqPart -RecPart $recPart
    $dedupeKey = "{0}|{1}|{2}|{3}|{4}" -f $i, $action, $txText, $hobtToken, $lsnHeuristic
    if (-not $seenKeys.Add($dedupeKey)) {
        continue
    }

    if ($action -eq "COMMIT") {
        $commitsByTx[$txText] = ([int64]$baseOffset + [int64]$i)
        continue
    }

    if ($action -eq "BEGIN") {
        continue
    }

    if ($hobtFilter.Count -gt 0) {
        if ($hobtToken -gt [int64][int]::MaxValue) {
            continue
        }
        if (-not $hobtFilter.Contains([int]$hobtToken)) {
            continue
        }
    }

        $dmlCandidates.Add([pscustomobject]@{
        offset         = [int64]$baseOffset + [int64]$i
        action         = $action
        tx_id          = $txText
        lsn_heuristic  = $lsnHeuristic
        hobt_token     = $hobtToken
        major_op_code  = ("0x{0}" -f $majorOp.ToString("X2"))
    })
}

$committed = @(
    $dmlCandidates |
        Where-Object { $commitsByTx.ContainsKey($_.tx_id) } |
        Sort-Object @{ Expression = { $commitsByTx[$_.tx_id] } }, offset
)

$results = @()
foreach ($r in $committed) {
    $results += [pscustomobject]@{
        offset                 = $r.offset
        commit_offset          = $commitsByTx[$r.tx_id]
        tx_id                  = $r.tx_id
        action                 = $r.action
        lsn_heuristic          = $r.lsn_heuristic
        hobt_token             = $r.hobt_token
        confidence             = "low"
        reconstructed_template = ("{0} [oasis].[CHSC_POLINE] /* raw-ldf heuristic */;" -f $r.action)
    }
}

$summary = [pscustomobject]@{
    collected_at_utc      = (Get-Date).ToUniversalTime().ToString("o")
    ldf_path              = $LdfPath
    scanned_bytes         = $bytes.Length
    hobt_tokens_filter    = $HobtTokens
    commit_count          = $commitsByTx.Count
    candidate_dml_count   = $dmlCandidates.Count
    committed_dml_count   = $results.Count
    note                  = "Experimental heuristic parser. Output is best-effort and may contain false positives/negatives."
    records               = $results
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host ("Wrote {0} committed DML candidates to {1}" -f $results.Count, (Resolve-Path -LiteralPath $OutputPath))
