param(
    [Parameter(Mandatory = $true)]
    [string]$LdfPath,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter()]
    [string]$OutputPath = ".\output\raw-ldf-hybrid-matches.json",

    [Parameter()]
    [int]$TailBytes = 0,

    [Parameter()]
    [bool]$EnableChunkIndex = $false,

    [Parameter()]
    [string]$ChunkIndexPath,

    [Parameter()]
    [int]$ChunkSizeMB = 64,

    [Parameter()]
    [int]$ChunkOverlapBytes = 96,

    [Parameter()]
    [bool]$RebuildChunkIndex = $false,

    [Parameter()]
    [int]$ChunkSelectMaxPercent = 85,

    [Parameter()]
    [ValidateSet("balanced", "key_only", "lsn_only", "recent_tail", "index_ranked")]
    [string]$ChunkSelectStrategy = "balanced",

    [Parameter()]
    [int]$RecentTailChunkCount = 1
,
    [Parameter()]
    [bool]$EnableDescriptorIndex = $false,

    [Parameter()]
    [string]$DescriptorIndexPath,

    [Parameter()]
    [bool]$RebuildDescriptorIndex = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LdfPath)) {
    throw "LDF path not found: $LdfPath"
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest path not found: $ManifestPath"
}

if ($TailBytes -lt 0) {
    throw "TailBytes must be >= 0."
}

if ($ChunkSizeMB -lt 1) {
    throw "ChunkSizeMB must be >= 1."
}

if ($ChunkOverlapBytes -lt 48) {
    throw "ChunkOverlapBytes must be >= 48."
}

if ($ChunkSelectMaxPercent -lt 1 -or $ChunkSelectMaxPercent -gt 100) {
    throw "ChunkSelectMaxPercent must be in [1..100]."
}
if ($RecentTailChunkCount -lt 1) {
    throw "RecentTailChunkCount must be >= 1."
}

function Get-PropertyValue {
    param(
        [psobject]$Object,
        [string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $null
}

function Convert-OperationToAction {
    param([string]$Operation)
    switch ($Operation) {
        "LOP_INSERT_ROWS" { return "INSERT" }
        "LOP_DELETE_ROWS" { return "DELETE" }
        "LOP_MODIFY_ROW" { return "UPDATE" }
        "LOP_MODIFY_COLUMNS" { return "UPDATE" }
        default { return $null }
    }
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

function Try-ParseTxIdToUInt32 {
    param(
        [string]$TxText,
        [ref]$OutValue
    )

    $OutValue.Value = [uint32]0
    if ([string]::IsNullOrWhiteSpace($TxText)) {
        return $false
    }

    if ($TxText -notmatch "^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$") {
        return $false
    }

    try {
        $OutValue.Value = [Convert]::ToUInt32($Matches[1], 16)
        return $true
    } catch {
        return $false
    }
}

function Get-LsnLexKey {
    param([AllowNull()][string]$LsnText)

    if ([string]::IsNullOrWhiteSpace($LsnText)) {
        return $null
    }
    if ($LsnText -notmatch "^([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8}):([0-9A-Fa-f]{4})$") {
        return $null
    }
    return ($Matches[1] + $Matches[2] + $Matches[3]).ToUpperInvariant()
}

function Test-LsnRangeOverlap {
    param(
        [AllowNull()][string]$RangeMin,
        [AllowNull()][string]$RangeMax,
        [AllowNull()][string]$ProbeMin,
        [AllowNull()][string]$ProbeMax
    )

    if ([string]::IsNullOrWhiteSpace($RangeMin) -or [string]::IsNullOrWhiteSpace($RangeMax)) {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($ProbeMin) -or [string]::IsNullOrWhiteSpace($ProbeMax)) {
        return $false
    }

    return (
        [string]::CompareOrdinal($RangeMin, $ProbeMax) -le 0 -and
        [string]::CompareOrdinal($RangeMax, $ProbeMin) -ge 0
    )
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
        return [pscustomobject]@{ head_sha1 = $headHash; tail_sha1 = $tailHash }
    } finally {
        $fs.Dispose()
    }
}

$manifestJson = Get-Content -LiteralPath $ManifestPath -Raw
$manifest = $manifestJson | ConvertFrom-Json
$manifestRecords = @($manifest.records)

$manifestByKey = @{}
$manifestByActionTx = @{}
$manifestTxIdSet = New-Object 'System.Collections.Generic.HashSet[uint32]'
$manifestTxTextSet = New-Object 'System.Collections.Generic.HashSet[string]'
$manifestActionsByTx = @{}
foreach ($r in $manifestRecords) {
    $manifestKey = Get-PropertyValue -Object $r -Name "manifest_key"
    if (-not $manifestKey) {
        $tx = Get-PropertyValue -Object $r -Name "tx_id"
        if (-not $tx) {
            $tx = Get-PropertyValue -Object $r -Name "transaction_id"
        }
        $lsn = Get-PropertyValue -Object $r -Name "current_lsn"
        $action = Get-PropertyValue -Object $r -Name "action"
        if (-not $action) {
            $op = Get-PropertyValue -Object $r -Name "operation_name"
            $action = Convert-OperationToAction -Operation ([string]$op)
        }
        if (-not $tx -or -not $lsn -or -not $action) {
            continue
        }
        $manifestKey = ("{0}|{1}|{2}" -f $action, $tx, $lsn)
    }

    $key = ([string]$manifestKey).ToUpperInvariant()
    if (-not $manifestByKey.ContainsKey($key)) {
        $manifestByKey[$key] = New-Object System.Collections.Generic.List[object]
    }
    $manifestByKey[$key].Add($r)

    $txForBucket = Get-PropertyValue -Object $r -Name "tx_id"
    if (-not $txForBucket) {
        $txForBucket = Get-PropertyValue -Object $r -Name "transaction_id"
    }
    $actionForBucket = Get-PropertyValue -Object $r -Name "action"
    if (-not $actionForBucket) {
        $opForBucket = Get-PropertyValue -Object $r -Name "operation_name"
        $actionForBucket = Convert-OperationToAction -Operation ([string]$opForBucket)
    }
    if ($txForBucket -and $actionForBucket) {
        $actionTxKey = ("{0}|{1}" -f [string]$actionForBucket, [string]$txForBucket).ToUpperInvariant()
        if (-not $manifestByActionTx.ContainsKey($actionTxKey)) {
            $manifestByActionTx[$actionTxKey] = New-Object System.Collections.Generic.List[object]
        }
        $manifestByActionTx[$actionTxKey].Add($r)

        $txBucketKey = ([string]$txForBucket).ToUpperInvariant()
        [void]$manifestTxTextSet.Add($txBucketKey)
        if (-not $manifestActionsByTx.ContainsKey($txBucketKey)) {
            $manifestActionsByTx[$txBucketKey] = New-Object 'System.Collections.Generic.HashSet[string]'
        }
        [void]$manifestActionsByTx[$txBucketKey].Add(([string]$actionForBucket).ToUpperInvariant())
    }

    $txForDiag = $txForBucket
    if (-not $txForDiag) {
        $txForDiag = Get-PropertyValue -Object $r -Name "tx_id"
        if (-not $txForDiag) {
            $txForDiag = Get-PropertyValue -Object $r -Name "transaction_id"
        }
    }
    $txUInt = [uint32]0
    if (Try-ParseTxIdToUInt32 -TxText ([string]$txForDiag) -OutValue ([ref]$txUInt)) {
        [void]$manifestTxIdSet.Add($txUInt)
    }
}

$manifestActionTxKeySet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($k in $manifestByActionTx.Keys) {
    [void]$manifestActionTxKeySet.Add(([string]$k).ToUpperInvariant())
}

$manifestLsnMinKey = $null
$manifestLsnMaxKey = $null
foreach ($r in $manifestRecords) {
    $lsnText = [string](Get-PropertyValue -Object $r -Name "current_lsn")
    $lsnKey = Get-LsnLexKey -LsnText $lsnText
    if ([string]::IsNullOrWhiteSpace($lsnKey)) {
        continue
    }
    if ([string]::IsNullOrWhiteSpace($manifestLsnMinKey) -or [string]::CompareOrdinal($lsnKey, $manifestLsnMinKey) -lt 0) {
        $manifestLsnMinKey = $lsnKey
    }
    if ([string]::IsNullOrWhiteSpace($manifestLsnMaxKey) -or [string]::CompareOrdinal($lsnKey, $manifestLsnMaxKey) -gt 0) {
        $manifestLsnMaxKey = $lsnKey
    }
}

$matched = New-Object System.Collections.Generic.List[object]
$matchedManifestKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$seenMatchKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$usedParsedCandidates = New-Object 'System.Collections.Generic.HashSet[string]'
$targetManifestKeyCount = $manifestByKey.Keys.Count
$allManifestMatched = ($targetManifestKeyCount -eq 0)
$parsedCandidatesByActionTx = @{}
$parsedCandidatesByTx = @{}
$parsedCandidatesByAllocToken = @{}
$parsedCandidatesByPageSlot = @{}
$parsedCandidateSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$parsedCandidateByDedupeKey = @{}
$parsedCandidatePageSlotIndexed = New-Object 'System.Collections.Generic.HashSet[string]'
$parsedCandidateTotal = 0
$parsedCandidatePageSlotCount = 0
$physlocAttachAttempts = 0
$physlocAttachSuccess = 0
$physlocParseAttempts = 0
$physlocParseSuccess = 0
$fallbackRegisterCalls = 0
$fallbackRegisterNew = 0
$diagPatternCounts = @{}
$diagManifestTxRowsScanned = 0
$diagManifestTxRowsAcceptedByParser = 0
$descriptorIndexLoaded = $false
$descriptorIndexUsed = $false
$descriptorIndexSatisfiedManifest = $false
$descriptorIndexPathEffective = $null
$descriptorIndexRecordCount = 0
$descriptorIndexScript = Join-Path -Path $PSScriptRoot -ChildPath "Prepare-RawLdfDescriptorIndex.ps1"

function Add-IndexCandidate {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Index,
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][object]$Candidate
    )

    $k = ([string]$Key).ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($k)) { return }
    if (-not $Index.ContainsKey($k)) {
        $Index[$k] = New-Object System.Collections.Generic.List[object]
    }
    $Index[$k].Add($Candidate)
}

function Try-ParseManifestPhysLoc {
    param(
        [Parameter(Mandatory = $true)][psobject]$ManifestRow,
        [ref]$OutPageId,
        [ref]$OutSlotId
    )

    $OutPageId.Value = $null
    $OutSlotId.Value = $null
    $pageText = [string](Get-PropertyValue -Object $ManifestRow -Name "page_id")
    $slotRaw = Get-PropertyValue -Object $ManifestRow -Name "slot_id"
    if ([string]::IsNullOrWhiteSpace($pageText) -or $null -eq $slotRaw) {
        return $false
    }
    if ($pageText -notmatch '^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$') {
        return $false
    }
    try {
        $OutPageId.Value = [int64][Convert]::ToUInt32($Matches[1], 16)
        $OutSlotId.Value = [int64]$slotRaw
        return $true
    } catch {
        return $false
    }
}

function Register-ParsedCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$TxText,
        [Parameter(Mandatory = $true)][string]$LsnText,
        [Parameter(Mandatory = $true)][int64]$AbsoluteOffset,
        [Parameter(Mandatory = $true)][int64]$ParsedHobtToken,
        [AllowNull()][Nullable[int64]]$PageId = $null,
        [AllowNull()][Nullable[int64]]$SlotId = $null
    )

    $candidateAction = ([string]$Action).ToUpperInvariant()
    $actionTxKey = ("{0}|{1}" -f $candidateAction, $TxText).ToUpperInvariant()
    $parsedCandidateKey = ("{0}|{1}|{2}" -f $actionTxKey, $AbsoluteOffset, $ParsedHobtToken)
    $dedupeKey = ("{0}|{1}" -f $parsedCandidateKey, ([string]$LsnText).ToUpperInvariant())

    $candidateObj = [pscustomobject]@{
        action            = $candidateAction
        tx_id             = $TxText
        lsn_heuristic     = $LsnText
        offset            = $AbsoluteOffset
        parsed_hobt_token = $ParsedHobtToken
        page_id           = $PageId
        slot_id           = $SlotId
    }

    if (-not $parsedCandidateSeen.Add($dedupeKey)) {
        if ($parsedCandidateByDedupeKey.ContainsKey($dedupeKey)) {
            $existing = $parsedCandidateByDedupeKey[$dedupeKey]
            $existingHasPageSlot = ($null -ne $existing.page_id -and $null -ne $existing.slot_id)
            $incomingHasPageSlot = ($null -ne $PageId -and $null -ne $SlotId -and [int64]$PageId -gt 0 -and [int64]$SlotId -ge 0)
            if (-not $existingHasPageSlot -and $incomingHasPageSlot) {
                $script:physlocAttachAttempts++
                $existing.page_id = [int64]$PageId
                $existing.slot_id = [int64]$SlotId
                $pageSlotKey = ("{0}:{1}" -f [int64]$PageId, [int64]$SlotId)
                if ($parsedCandidatePageSlotIndexed.Add($pageSlotKey)) {
                    Add-IndexCandidate -Index $parsedCandidatesByPageSlot -Key $pageSlotKey -Candidate $existing
                    $script:parsedCandidatePageSlotCount++
                    $script:physlocAttachSuccess++
                }
            }
        }
        return [pscustomobject]@{
            action_tx_key = $actionTxKey
            candidate_key = $parsedCandidateKey
            candidate     = $(if ($parsedCandidateByDedupeKey.ContainsKey($dedupeKey)) { $parsedCandidateByDedupeKey[$dedupeKey] } else { $candidateObj })
            is_new        = $false
        }
    }

    $parsedCandidateByDedupeKey[$dedupeKey] = $candidateObj
    $script:parsedCandidateTotal++
    Add-IndexCandidate -Index $parsedCandidatesByActionTx -Key $actionTxKey -Candidate $candidateObj
    Add-IndexCandidate -Index $parsedCandidatesByTx -Key $TxText -Candidate $candidateObj
    if ($ParsedHobtToken -ne 0) {
        Add-IndexCandidate -Index $parsedCandidatesByAllocToken -Key ([string]$ParsedHobtToken) -Candidate $candidateObj
    }
    if ($null -ne $PageId -and $null -ne $SlotId -and [int64]$PageId -gt 0 -and [int64]$SlotId -ge 0) {
        $pageSlotKey = ("{0}:{1}" -f [int64]$PageId, [int64]$SlotId)
        if ($parsedCandidatePageSlotIndexed.Add($pageSlotKey)) {
            Add-IndexCandidate -Index $parsedCandidatesByPageSlot -Key $pageSlotKey -Candidate $candidateObj
            $script:parsedCandidatePageSlotCount++
            $script:physlocAttachAttempts++
            $script:physlocAttachSuccess++
        }
    }

    return [pscustomobject]@{
        action_tx_key = $actionTxKey
        candidate_key = $parsedCandidateKey
        candidate     = $candidateObj
        is_new        = $true
    }
}

function Add-ParsedCandidateMatch {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$TxText,
        [Parameter(Mandatory = $true)][string]$LsnText,
        [Parameter(Mandatory = $true)][int64]$AbsoluteOffset,
        [Parameter(Mandatory = $true)][int64]$ParsedHobtToken
    )

    $candidateAction = ([string]$Action).ToUpperInvariant()
    $actionTxKey = ("{0}|{1}" -f $candidateAction, $TxText).ToUpperInvariant()
    if (-not $manifestByActionTx.ContainsKey($actionTxKey)) {
        return
    }

    $manifestKey = ("{0}|{1}|{2}" -f $candidateAction, $TxText, $LsnText).ToUpperInvariant()
    $candidatePageId = $null
    $candidateSlotId = $null
    if ($manifestByKey.ContainsKey($manifestKey) -and $manifestByKey[$manifestKey].Count -gt 0) {
        $physPage = $null
        $physSlot = $null
        if (Try-ParseManifestPhysLoc -ManifestRow $manifestByKey[$manifestKey][0] -OutPageId ([ref]$physPage) -OutSlotId ([ref]$physSlot)) {
            $candidatePageId = $physPage
            $candidateSlotId = $physSlot
        }
    }

    $registered = Register-ParsedCandidate `
        -Action $candidateAction `
        -TxText $TxText `
        -LsnText $LsnText `
        -AbsoluteOffset $AbsoluteOffset `
        -ParsedHobtToken $ParsedHobtToken `
        -PageId $candidatePageId `
        -SlotId $candidateSlotId
    $parsedCandidateKey = [string]$registered.candidate_key

    if (-not $manifestByKey.ContainsKey($manifestKey)) {
        return
    }

    foreach ($m in $manifestByKey[$manifestKey]) {
        $manifestHobt = Get-PropertyValue -Object $m -Name "hobt_token"
        $hobtMatch = $false
        if ($null -ne $manifestHobt) {
            $hobtMatch = ([int64]$manifestHobt -eq $ParsedHobtToken)
        }

        $dedupe = ("{0}|{1}|{2}" -f $manifestKey, $AbsoluteOffset, $ParsedHobtToken)
        if (-not $seenMatchKeys.Add($dedupe)) {
            continue
        }
        [void]$usedParsedCandidates.Add($parsedCandidateKey)
        [void]$matchedManifestKeys.Add($manifestKey)
        if (-not $allManifestMatched -and $matchedManifestKeys.Count -ge $targetManifestKeyCount) {
            $allManifestMatched = $true
        }
        $matched.Add([pscustomobject]@{
            manifest_key           = $manifestKey
            offset                 = $AbsoluteOffset
            action                 = $candidateAction
            tx_id                  = $TxText
            lsn_heuristic          = $LsnText
            parsed_hobt_token      = $ParsedHobtToken
            manifest_hobt_token    = $manifestHobt
            hobt_match             = $hobtMatch
            commit_time            = Get-PropertyValue -Object $m -Name "commit_time"
            alloc_unit_name        = Get-PropertyValue -Object $m -Name "alloc_unit_name"
            confidence             = "high"
            reconstructed_template = ("{0} [oasis].[CHSC_POLINE] /* hybrid live-manifest match */;" -f $candidateAction)
        })
    }
}

function Process-DescriptorRow {
    param([Parameter(Mandatory = $true)][psobject]$DescriptorRow)

    if ($allManifestMatched) { return }

    $actionTxKeyFromIndex = [string](Get-PropertyValue -Object $DescriptorRow -Name "action_tx_key")
    $txText = [string](Get-PropertyValue -Object $DescriptorRow -Name "tx_id")
    if ([string]::IsNullOrWhiteSpace($txText)) { return }

    $candidateActions = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($actionTxKeyFromIndex)) {
        $actionLocal = ([string](Get-PropertyValue -Object $DescriptorRow -Name "action")).ToUpperInvariant()
        if (-not [string]::IsNullOrWhiteSpace($actionLocal)) {
            $actionTxKeyFromIndex = ("{0}|{1}" -f $actionLocal, $txText).ToUpperInvariant()
            $candidateActions.Add($actionLocal) | Out-Null
        } else {
            $txActionKey = $txText.ToUpperInvariant()
            if ($manifestActionsByTx.ContainsKey($txActionKey)) {
                foreach ($a in @($manifestActionsByTx[$txActionKey])) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$a)) {
                        $candidateActions.Add(([string]$a).ToUpperInvariant()) | Out-Null
                    }
                }
            }
            if ($candidateActions.Count -eq 0) { return }
        }
    } else {
        $actionTxKeyFromIndex = $actionTxKeyFromIndex.ToUpperInvariant()
        if ($actionTxKeyFromIndex -match '^([^|]+)\|') {
            $candidateActions.Add($Matches[1].ToUpperInvariant()) | Out-Null
        }
    }

    if (-not $manifestActionTxKeySet.Contains($actionTxKeyFromIndex) -and $candidateActions.Count -eq 0) {
        return
    }

    $lsnText = [string](Get-PropertyValue -Object $DescriptorRow -Name "lsn_heuristic")
    $offset = [int64](Get-PropertyValue -Object $DescriptorRow -Name "offset")
    $hobtToken = [int64](Get-PropertyValue -Object $DescriptorRow -Name "parsed_hobt_token")
    $pageIdValue = Get-PropertyValue -Object $DescriptorRow -Name "page_id"
    $slotIdValue = Get-PropertyValue -Object $DescriptorRow -Name "slot_id"
    $pageId = $null
    $slotId = $null
    if ($null -ne $pageIdValue -and $null -ne $slotIdValue) {
        try {
            $pageId = [int64]$pageIdValue
            $slotId = [int64]$slotIdValue
        } catch {
            $pageId = $null
            $slotId = $null
        }
    }
    if ([string]::IsNullOrWhiteSpace($lsnText)) { return }

    foreach ($candidateAction in @($candidateActions.ToArray())) {
        $actionTxKey = ("{0}|{1}" -f $candidateAction, $txText).ToUpperInvariant()
        $null = Register-ParsedCandidate `
            -Action $candidateAction `
            -TxText $txText `
            -LsnText $lsnText `
            -AbsoluteOffset $offset `
            -ParsedHobtToken $hobtToken `
            -PageId $pageId `
            -SlotId $slotId
        if (-not $manifestByActionTx.ContainsKey($actionTxKey)) { continue }
        Add-ParsedCandidateMatch -Action $candidateAction -TxText $txText -LsnText $lsnText -AbsoluteOffset $offset -ParsedHobtToken $hobtToken
    }
}

function Parse-DescriptorJsonLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $txM = [regex]::Match($Line, '"tx_id":"([^"]+)"')
    if (-not $txM.Success) { return $null }
    $lsnM = [regex]::Match($Line, '"lsn_heuristic":"([^"]+)"')
    if (-not $lsnM.Success) { return $null }
    $offM = [regex]::Match($Line, '"offset":(-?\d+)')
    if (-not $offM.Success) { return $null }
    $hobtM = [regex]::Match($Line, '"parsed_hobt_token":(-?\d+)')
    if (-not $hobtM.Success) { return $null }
    $actionM = [regex]::Match($Line, '"action":(null|"([^"]*)")')
    $actionTxM = [regex]::Match($Line, '"action_tx_key":(null|"([^"]*)")')

    $actionVal = $null
    if ($actionM.Success -and $actionM.Groups[2].Success) {
        $actionVal = $actionM.Groups[2].Value
    }
    $actionTxVal = $null
    if ($actionTxM.Success -and $actionTxM.Groups[2].Success) {
        $actionTxVal = $actionTxM.Groups[2].Value
    }

    return [pscustomobject]@{
        action            = $actionVal
        action_tx_key     = $actionTxVal
        tx_id             = $txM.Groups[1].Value
        lsn_heuristic     = $lsnM.Groups[1].Value
        offset            = [int64]$offM.Groups[1].Value
        parsed_hobt_token = [int64]$hobtM.Groups[1].Value
    }
}

$fileInfo = Get-Item -LiteralPath $LdfPath
$fileLength = [int64]$fileInfo.Length
$startOffset = [int64]0
if ($TailBytes -gt 0) {
    $readLen = [Math]::Min([int64]$TailBytes, $fileLength)
    $startOffset = $fileLength - $readLen
}

$chunkSizeBytes = [int64]$ChunkSizeMB * 1MB
$scanCarryBytes = [Math]::Max(96, $ChunkOverlapBytes)
$chunkIndexData = $null
$chunkIndexLoaded = $false
$chunkIndexSaved = $false
$chunkScanMode = "full_scan"
$selectedChunkCount = 0
$totalChunkCount = 0

if ($EnableChunkIndex) {
    $outDirForIndex = Split-Path -Parent $OutputPath
    if ([string]::IsNullOrWhiteSpace($outDirForIndex)) {
        $outDirForIndex = "."
    }
    if ([string]::IsNullOrWhiteSpace($ChunkIndexPath)) {
        $ChunkIndexPath = Join-Path -Path $outDirForIndex -ChildPath (([System.IO.Path]::GetFileName($LdfPath)) + ".chunk-index.json")
    }

    if ((-not $RebuildChunkIndex) -and (Test-Path -LiteralPath $ChunkIndexPath)) {
        try {
            $loaded = Get-Content -LiteralPath $ChunkIndexPath -Raw | ConvertFrom-Json
            if ($loaded -and $loaded.PSObject.Properties.Name -contains "chunks") {
                $ver = [int](Get-PropertyValue -Object $loaded -Name "version")
                $basicValid =
                    ([int64](Get-PropertyValue -Object $loaded -Name "chunk_size_bytes") -eq $chunkSizeBytes) -and
                    ([string](Get-PropertyValue -Object $loaded -Name "ldf_file_name")).Equals(([System.IO.Path]::GetFileName($LdfPath)), [System.StringComparison]::OrdinalIgnoreCase) -and
                    ([int64](Get-PropertyValue -Object $loaded -Name "ldf_file_length") -eq $fileLength)

                $fingerprintValid = $false
                if ($ver -ge 2) {
                    $fiNow = Get-Item -LiteralPath $LdfPath
                    $edgeNow = Get-FileEdgeSha1 -Path $LdfPath
                    $fingerprintValid =
                        ([string](Get-PropertyValue -Object $loaded -Name "ldf_last_write_utc") -eq $fiNow.LastWriteTimeUtc.ToString("o")) -and
                        ([string](Get-PropertyValue -Object $loaded -Name "head_sha1") -eq $edgeNow.head_sha1) -and
                        ([string](Get-PropertyValue -Object $loaded -Name "tail_sha1") -eq $edgeNow.tail_sha1)
                } else {
                    # Backward compatibility for legacy indices.
                    $fingerprintValid = $true
                }

                if ($basicValid -and $fingerprintValid) {
                    $chunkIndexData = $loaded
                    $chunkIndexLoaded = $true
                }
            }
        } catch {
            # Ignore invalid index; full scan fallback.
        }
    }
}

if ($EnableDescriptorIndex) {
    $outDirForDescriptor = Split-Path -Parent $OutputPath
    if ([string]::IsNullOrWhiteSpace($outDirForDescriptor)) {
        $outDirForDescriptor = "."
    }
    if ([string]::IsNullOrWhiteSpace($DescriptorIndexPath)) {
        $DescriptorIndexPath = Join-Path -Path $outDirForDescriptor -ChildPath (([System.IO.Path]::GetFileName($LdfPath)) + ".descriptor-index.json")
    }
    $descriptorIndexPathEffective = $DescriptorIndexPath

    if ($RebuildDescriptorIndex -or -not (Test-Path -LiteralPath $DescriptorIndexPath)) {
        if (Test-Path -LiteralPath $descriptorIndexScript) {
            & $descriptorIndexScript `
                -LdfPath $LdfPath `
                -OutputPath $DescriptorIndexPath `
                -ChunkSizeMB $ChunkSizeMB `
                -ChunkOverlapBytes $ChunkOverlapBytes `
                -ForceRebuild $true | Out-Null
        }
    }

    if (Test-Path -LiteralPath $DescriptorIndexPath) {
        try {
            $loadedDescriptor = Get-Content -LiteralPath $DescriptorIndexPath -Raw | ConvertFrom-Json
            $descriptorValid =
                $loadedDescriptor -and
                ([int](Get-PropertyValue -Object $loadedDescriptor -Name "version") -ge 1) -and
                ([string](Get-PropertyValue -Object $loadedDescriptor -Name "ldf_file_name")).Equals(([System.IO.Path]::GetFileName($LdfPath)), [System.StringComparison]::OrdinalIgnoreCase) -and
                ([int64](Get-PropertyValue -Object $loadedDescriptor -Name "ldf_file_length") -eq $fileLength)
            if ($descriptorValid) {
                $descriptorIndexLoaded = $true
                $descriptorFormat = ([string](Get-PropertyValue -Object $loadedDescriptor -Name "format")).ToLowerInvariant()
                if ($descriptorFormat -eq "jsonl") {
                    $recordsPath = [string](Get-PropertyValue -Object $loadedDescriptor -Name "records_path")
                    if (-not [System.IO.Path]::IsPathRooted($recordsPath)) {
                        if (-not (Test-Path -LiteralPath $recordsPath)) {
                            $recordsPath = Join-Path -Path (Split-Path -Parent $DescriptorIndexPath) -ChildPath $recordsPath
                        }
                    }
                    if (Test-Path -LiteralPath $recordsPath) {
                        $txAnchor = '"tx_id":"'
                        foreach ($line in [System.IO.File]::ReadLines($recordsPath)) {
                            if ($allManifestMatched) { break }
                            if ([string]::IsNullOrWhiteSpace($line)) { continue }
                            $txIdx = $line.IndexOf($txAnchor, [System.StringComparison]::Ordinal)
                            if ($txIdx -lt 0) { continue }
                            $txStart = $txIdx + $txAnchor.Length
                            $txEnd = $line.IndexOf('"', $txStart)
                            if ($txEnd -le $txStart) { continue }
                            $txCandidate = $line.Substring($txStart, $txEnd - $txStart).ToUpperInvariant()
                            if (-not $manifestTxTextSet.Contains($txCandidate)) { continue }
                            $d = Parse-DescriptorJsonLine -Line $line
                            if ($null -eq $d) { continue }
                            $descriptorIndexRecordCount++
                            Process-DescriptorRow -DescriptorRow $d
                        }
                    }
                } else {
                    $descriptorRecords = @($loadedDescriptor.records)
                    $descriptorIndexRecordCount = $descriptorRecords.Count
                    foreach ($d in $descriptorRecords) {
                        if ($allManifestMatched) { break }
                        Process-DescriptorRow -DescriptorRow $d
                    }
                }
                $descriptorIndexUsed = $true
                if ($allManifestMatched) {
                    $descriptorIndexSatisfiedManifest = $true
                    $chunkScanMode = "descriptor_index_full_match"
                } else {
                    $chunkScanMode = "descriptor_index"
                }
            }
        } catch {
            $descriptorIndexLoaded = $false
            $descriptorIndexUsed = $false
        }
    }
}

$rawWindows = New-Object System.Collections.Generic.List[object]
$useSelectiveChunkScan = $false

if (-not $descriptorIndexSatisfiedManifest -and $chunkIndexLoaded -and $chunkIndexData -and @($chunkIndexData.chunks).Count -gt 0) {
    $totalChunkCount = @($chunkIndexData.chunks).Count
    $selectedChunks = New-Object System.Collections.Generic.List[object]

    $allChunks = @($chunkIndexData.chunks)
    foreach ($c in $allChunks) {
        $offsetStart = [int64](Get-PropertyValue -Object $c -Name "offset_start")
        $offsetEnd = [int64](Get-PropertyValue -Object $c -Name "offset_end")
        if ($offsetEnd -le $startOffset) {
            continue
        }

        $keyHit = $false
        foreach ($k in @($c.action_tx_keys)) {
            $ku = ([string]$k).ToUpperInvariant()
            if ($manifestActionTxKeySet.Contains($ku)) {
                $keyHit = $true
                break
            }
        }

        $txHit = $false
        if ($c.PSObject.Properties.Name -contains "tx_ids") {
            foreach ($txk in @($c.tx_ids)) {
                $txu = ([string]$txk).ToUpperInvariant()
                if ($manifestTxTextSet.Contains($txu)) {
                    $txHit = $true
                    break
                }
            }
        }

        $lsnHit = Test-LsnRangeOverlap `
            -RangeMin ([string](Get-PropertyValue -Object $c -Name "lsn_min_key")) `
            -RangeMax ([string](Get-PropertyValue -Object $c -Name "lsn_max_key")) `
            -ProbeMin $manifestLsnMinKey `
            -ProbeMax $manifestLsnMaxKey

        $selectChunk = $false
        switch ($ChunkSelectStrategy) {
            "key_only" { $selectChunk = ($keyHit -or $txHit); break }
            "lsn_only" { $selectChunk = $lsnHit; break }
            "recent_tail" { $selectChunk = $false; break }
            "index_ranked" { $selectChunk = $false; break }
            default { $selectChunk = ($keyHit -or $txHit -or $lsnHit); break }
        }

        if ($selectChunk) {
            $selectedChunks.Add($c) | Out-Null
        }
    }

    if ($ChunkSelectStrategy -eq "recent_tail") {
        $tailCandidates = @(
            $allChunks |
                Sort-Object { [int](Get-PropertyValue -Object $_ -Name "chunk_id") } -Descending |
                Select-Object -First $RecentTailChunkCount
        )
        foreach ($tc in $tailCandidates) {
            $selectedChunks.Add($tc) | Out-Null
        }
        if ($tailCandidates.Count -gt 0) {
            $chunkScanMode = "chunk_index_recent_tail"
        }
    }
    elseif ($ChunkSelectStrategy -eq "index_ranked") {
        $chunkScanMode = "chunk_index_index_ranked"
        $scored = New-Object System.Collections.Generic.List[object]
        foreach ($c in $allChunks) {
            $offsetStart = [int64](Get-PropertyValue -Object $c -Name "offset_start")
            $offsetEnd = [int64](Get-PropertyValue -Object $c -Name "offset_end")
            if ($offsetEnd -le $startOffset) { continue }

            $actionHits = 0
            foreach ($k in @($c.action_tx_keys)) {
                if ($manifestActionTxKeySet.Contains(([string]$k).ToUpperInvariant())) { $actionHits++ }
            }
            $txHits = 0
            foreach ($txk in @($c.tx_ids)) {
                if ($manifestTxTextSet.Contains(([string]$txk).ToUpperInvariant())) { $txHits++ }
            }
            $lsnHitLocal = Test-LsnRangeOverlap `
                -RangeMin ([string](Get-PropertyValue -Object $c -Name "lsn_min_key")) `
                -RangeMax ([string](Get-PropertyValue -Object $c -Name "lsn_max_key")) `
                -ProbeMin $manifestLsnMinKey `
                -ProbeMax $manifestLsnMaxKey

            $score = ($actionHits * 10) + ($txHits * 3) + ($(if ($lsnHitLocal) { 1 } else { 0 }))
            if ($score -le 0) { continue }

            $scored.Add([pscustomobject]@{
                chunk  = $c
                score  = [int]$score
                txHits = [int]$txHits
                actionHits = [int]$actionHits
                chunk_id = [int](Get-PropertyValue -Object $c -Name "chunk_id")
            }) | Out-Null
        }

        $remainingTx = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($tx in $manifestTxTextSet) { [void]$remainingTx.Add($tx) }

        foreach ($row in @($scored | Sort-Object score, txHits, actionHits, chunk_id -Descending)) {
            $c = $row.chunk
            $newCoverage = 0
            foreach ($txk in @($c.tx_ids)) {
                $u = ([string]$txk).ToUpperInvariant()
                if ($remainingTx.Contains($u)) { $newCoverage++ }
            }
            if ($newCoverage -le 0 -and $selectedChunks.Count -gt 0) { continue }
            $selectedChunks.Add($c) | Out-Null
            foreach ($txk in @($c.tx_ids)) {
                [void]$remainingTx.Remove(([string]$txk).ToUpperInvariant())
            }
            if ($remainingTx.Count -eq 0) { break }
        }
        if ($selectedChunks.Count -eq 0 -and $allChunks.Count -gt 0) {
            $selectedChunks.Add(($allChunks | Sort-Object { [int](Get-PropertyValue -Object $_ -Name "chunk_id") } -Descending | Select-Object -First 1)) | Out-Null
        }
    }

    $selectedChunkCount = $selectedChunks.Count
    $selectedPct = if ($totalChunkCount -gt 0) { [int][Math]::Ceiling(($selectedChunkCount * 100.0) / $totalChunkCount) } else { 100 }
    if ($selectedChunkCount -gt 0 -and $selectedPct -le $ChunkSelectMaxPercent) {
        $useSelectiveChunkScan = $true
        $chunkScanMode = "chunk_index_selective"
        foreach ($c in @($selectedChunks.ToArray())) {
            $baseStart = [int64](Get-PropertyValue -Object $c -Name "offset_start")
            $baseEnd = [int64](Get-PropertyValue -Object $c -Name "offset_end")
            if ($baseEnd -le $startOffset) {
                continue
            }
            if ($baseStart -lt $startOffset) {
                $baseStart = $startOffset
            }
            $readStart = [Math]::Max($startOffset, $baseStart - [int64]$scanCarryBytes)
            $readEnd = [Math]::Min($fileLength, $baseEnd + [int64]$scanCarryBytes)
            if ($readEnd -gt $readStart) {
                $rawWindows.Add([pscustomobject]@{
                    read_start = [int64]$readStart
                    read_end   = [int64]$readEnd
                }) | Out-Null
            }
        }
    } else {
        $chunkScanMode = "chunk_index_full_fallback"
    }
}

if (-not $useSelectiveChunkScan) {
    $rawWindows.Add([pscustomobject]@{
        read_start = [int64]$startOffset
        read_end   = [int64]$fileLength
    }) | Out-Null
}

$scanWindows = New-Object System.Collections.Generic.List[object]
if ($rawWindows.Count -gt 0) {
    $sortedWindows = @($rawWindows | Sort-Object read_start, read_end)
    $currentStart = [int64]$sortedWindows[0].read_start
    $currentEnd = [int64]$sortedWindows[0].read_end
    for ($wIdx = 1; $wIdx -lt $sortedWindows.Count; $wIdx++) {
        $w = $sortedWindows[$wIdx]
        $wStart = [int64]$w.read_start
        $wEnd = [int64]$w.read_end
        if ($wStart -le $currentEnd) {
            if ($wEnd -gt $currentEnd) {
                $currentEnd = $wEnd
            }
        } else {
            $scanWindows.Add([pscustomobject]@{
                read_start = [int64]$currentStart
                read_end   = [int64]$currentEnd
            }) | Out-Null
            $currentStart = $wStart
            $currentEnd = $wEnd
        }
    }
    $scanWindows.Add([pscustomobject]@{
        read_start = [int64]$currentStart
        read_end   = [int64]$currentEnd
    }) | Out-Null
}

$chunkBuildMap = @{}
$captureChunkIndexDuringScan = $EnableChunkIndex -and (-not $useSelectiveChunkScan) -and ($startOffset -eq 0) -and (-not $descriptorIndexUsed)

if (-not $descriptorIndexUsed) {
$stream = [System.IO.File]::Open($LdfPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
try {
    $bufferSize = 8MB
    $chunk = New-Object byte[] $bufferSize

    foreach ($window in @($scanWindows.ToArray())) {
        if ($allManifestMatched) { break }
        $windowStart = [int64]$window.read_start
        $windowEnd = [int64]$window.read_end
        if ($windowEnd -le $windowStart) {
            continue
        }

        [void]$stream.Seek($windowStart, [System.IO.SeekOrigin]::Begin)
        $remaining = $windowEnd - $windowStart
        [byte[]]$carry = @()
        $absolutePos = $windowStart

        while ($remaining -gt 0) {
            if ($allManifestMatched) { break }
            $request = [int][Math]::Min([int64]$bufferSize, $remaining)
            $read = $stream.Read($chunk, 0, $request)
            if ($read -le 0) {
                break
            }

            $scan = New-Object byte[] ($carry.Length + $read)
            if ($carry.Length -gt 0) {
                [Array]::Copy($carry, 0, $scan, 0, $carry.Length)
            }
            [Array]::Copy($chunk, 0, $scan, $carry.Length, $read)

            $scanBaseOffset = $absolutePos - $carry.Length
            $limit = $scan.Length - 48
            for ($i = 0; $i -lt $limit; $i++) {
                if ($allManifestMatched) { break }
                if ($scan[$i] -ne 0x00 -or $scan[$i + 1] -ne 0x00 -or $scan[$i + 3] -ne 0x00) {
                    continue
                }

                $txIdForDiag = [BitConverter]::ToUInt32($scan, $i + 16)
                if ($txIdForDiag -ne 0 -and $manifestTxIdSet.Contains($txIdForDiag)) {
                    $diagManifestTxRowsScanned++
                    $diagLen = $scan[$i + 2]
                    $diagRecordType = $scan[$i + 14]
                    $diagRecordType2 = $scan[$i + 15]
                    $diagMajor = $scan[$i + 22]
                    $diagPatternKey = ("0x{0}|0x{1}|0x{2}|0x{3}" -f $diagLen.ToString("X2"), $diagRecordType.ToString("X2"), $diagRecordType2.ToString("X2"), $diagMajor.ToString("X2"))
                    if ($diagPatternCounts.ContainsKey($diagPatternKey)) {
                        $diagPatternCounts[$diagPatternKey] = [int]$diagPatternCounts[$diagPatternKey] + 1
                    } else {
                        $diagPatternCounts[$diagPatternKey] = 1
                    }
                }

                # Fast gate: we only care about transactions present in the live manifest set.
                # This dramatically reduces false positives when using relaxed header parsing.
                if ($txIdForDiag -eq 0 -or (-not $manifestTxIdSet.Contains($txIdForDiag))) {
                    continue
                }

                # Header-length sanity check only (do not hard-require 0x3E; newer builds vary).
                $hdrLen = [int]$scan[$i + 2]
                if ($hdrLen -lt 0x20 -or $hdrLen -gt 0x90) {
                    continue
                }

                # SQL log row records can use shifted op offsets across versions/builds.
                $action = $null
                $majorCandidates = @(
                    $scan[$i + 22],
                    $scan[$i + 21],
                    $scan[$i + 23],
                    $scan[$i + 24]
                )
                foreach ($maj in $majorCandidates) {
                    $action = Parse-DmlAction -MajorOp $maj
                    if ($action) { break }
                }
                $txId = $txIdForDiag
                if ($txId -eq 0) {
                    continue
                }

                $dbMarker = $scan[$i + 4]
                $seqPart = [BitConverter]::ToUInt32($scan, $i + 8)
                $recPart = [BitConverter]::ToUInt16($scan, $i + 12)
                $absoluteOffset = [int64]$scanBaseOffset + [int64]$i
                $txText = Format-TxId -TxId $txId
                $lsnText = Format-LsnHeuristic -DbMarker $dbMarker -SeqPart $seqPart -RecPart $recPart
                $candidateActions = New-Object System.Collections.Generic.List[string]
                if ($action) {
                    $candidateActions.Add(([string]$action).ToUpperInvariant()) | Out-Null
                } else {
                    $txActionKey = ([string]$txText).ToUpperInvariant()
                    if ($manifestActionsByTx.ContainsKey($txActionKey)) {
                        foreach ($a in @($manifestActionsByTx[$txActionKey])) {
                            $candidateActions.Add(([string]$a).ToUpperInvariant()) | Out-Null
                        }
                    }
                }
                if ($candidateActions.Count -eq 0) {
                    continue
                }
                $diagManifestTxRowsAcceptedByParser++

                $parsedHobtToken = [int64][BitConverter]::ToUInt32($scan, $i + 32)
                foreach ($candidateActionUpper in @($candidateActions.ToArray())) {
                    $candidateAction = [string]$candidateActionUpper
                    $actionTxKey = ("{0}|{1}" -f $candidateAction, $txText).ToUpperInvariant()

                    if ($captureChunkIndexDuringScan) {
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
                                record_count    = 0
                            }
                        }
                        $chunkState = $chunkBuildMap[$chunkId]
                        [void]$chunkState.action_tx_keys.Add($actionTxKey)
                        [void]$chunkState.tx_ids.Add(([string]$txText).ToUpperInvariant())
                        $chunkState.record_count = [int]$chunkState.record_count + 1
                        $lsnLex = Get-LsnLexKey -LsnText $lsnText
                        if (-not [string]::IsNullOrWhiteSpace($lsnLex)) {
                            if ([string]::IsNullOrWhiteSpace($chunkState.lsn_min_key) -or [string]::CompareOrdinal($lsnLex, $chunkState.lsn_min_key) -lt 0) {
                                $chunkState.lsn_min_key = $lsnLex
                            }
                            if ([string]::IsNullOrWhiteSpace($chunkState.lsn_max_key) -or [string]::CompareOrdinal($lsnLex, $chunkState.lsn_max_key) -gt 0) {
                                $chunkState.lsn_max_key = $lsnLex
                            }
                        }
                    }

                    $registeredCandidate = Register-ParsedCandidate `
                        -Action $candidateAction `
                        -TxText $txText `
                        -LsnText $lsnText `
                        -AbsoluteOffset $absoluteOffset `
                        -ParsedHobtToken $parsedHobtToken
                    if (-not $manifestByActionTx.ContainsKey($actionTxKey)) { continue }
                    $manifestKey = ("{0}|{1}|{2}" -f $candidateAction, $txText, $lsnText).ToUpperInvariant()
                    $parsedCandidateKey = [string]$registeredCandidate.candidate_key

                    if (-not $manifestByKey.ContainsKey($manifestKey)) {
                        continue
                    }

                    foreach ($m in $manifestByKey[$manifestKey]) {
                        $physPage = $null
                        $physSlot = $null
                        if (Try-ParseManifestPhysLoc -ManifestRow $m -OutPageId ([ref]$physPage) -OutSlotId ([ref]$physSlot)) {
                            [void](Register-ParsedCandidate `
                                -Action $candidateAction `
                                -TxText $txText `
                                -LsnText $lsnText `
                                -AbsoluteOffset $absoluteOffset `
                                -ParsedHobtToken $parsedHobtToken `
                                -PageId $physPage `
                                -SlotId $physSlot)
                        }

                        $manifestHobt = Get-PropertyValue -Object $m -Name "hobt_token"
                        $hobtMatch = $false
                        if ($null -ne $manifestHobt) {
                            $hobtMatch = ([int64]$manifestHobt -eq $parsedHobtToken)
                        }

                        $dedupe = ("{0}|{1}|{2}" -f $manifestKey, $absoluteOffset, $parsedHobtToken)
                        if (-not $seenMatchKeys.Add($dedupe)) {
                            continue
                        }
                        [void]$usedParsedCandidates.Add($parsedCandidateKey)

                        [void]$matchedManifestKeys.Add($manifestKey)
                        if (-not $allManifestMatched -and $matchedManifestKeys.Count -ge $targetManifestKeyCount) {
                            $allManifestMatched = $true
                        }
                        $matched.Add([pscustomobject]@{
                            manifest_key           = $manifestKey
                            offset                 = $absoluteOffset
                            action                 = $candidateAction
                            tx_id                  = $txText
                            lsn_heuristic          = $lsnText
                            parsed_hobt_token      = $parsedHobtToken
                            manifest_hobt_token    = $manifestHobt
                            hobt_match             = $hobtMatch
                            commit_time            = Get-PropertyValue -Object $m -Name "commit_time"
                            alloc_unit_name        = Get-PropertyValue -Object $m -Name "alloc_unit_name"
                            confidence             = "high"
                            reconstructed_template = ("{0} [oasis].[CHSC_POLINE] /* hybrid live-manifest match */;" -f $candidateAction)
                        })
                    }
                }
            }

            $keep = [Math]::Min($scanCarryBytes, $scan.Length)
            $carry = New-Object byte[] $keep
            [Array]::Copy($scan, $scan.Length - $keep, $carry, 0, $keep)

            $absolutePos += $read
            $remaining -= $read
        }
    }
} finally {
    $stream.Dispose()
}

if ($captureChunkIndexDuringScan) {
    $chunkItems = New-Object System.Collections.Generic.List[object]
    $totalChunkSlots = [int][Math]::Ceiling(($fileLength * 1.0) / $chunkSizeBytes)
    if ($totalChunkSlots -lt 1) { $totalChunkSlots = 1 }
    for ($chunkId = 0; $chunkId -lt $totalChunkSlots; $chunkId++) {
        $chunkState = $null
        if ($chunkBuildMap.ContainsKey($chunkId)) {
            $chunkState = $chunkBuildMap[$chunkId]
        } else {
            $offsetStart = [int64]$chunkId * $chunkSizeBytes
            $offsetEnd = [Math]::Min($fileLength, $offsetStart + $chunkSizeBytes)
            $chunkState = [pscustomobject]@{
                chunk_id        = $chunkId
                offset_start    = [int64]$offsetStart
                offset_end      = [int64]$offsetEnd
                lsn_min_key     = $null
                lsn_max_key     = $null
                action_tx_keys  = (New-Object 'System.Collections.Generic.HashSet[string]')
                tx_ids          = (New-Object 'System.Collections.Generic.HashSet[string]')
                record_count    = 0
            }
        }
        $chunkItems.Add([pscustomobject]@{
            chunk_id       = [int]$chunkState.chunk_id
            offset_start   = [int64]$chunkState.offset_start
            offset_end     = [int64]$chunkState.offset_end
            record_count   = [int]$chunkState.record_count
            lsn_min_key    = [string]$chunkState.lsn_min_key
            lsn_max_key    = [string]$chunkState.lsn_max_key
            action_tx_keys = @($chunkState.action_tx_keys)
            tx_ids         = @($chunkState.tx_ids)
        }) | Out-Null
    }

    $fiNow = Get-Item -LiteralPath $LdfPath
    $edgeNow = Get-FileEdgeSha1 -Path $LdfPath
    $chunkIndexObj = [pscustomobject]@{
        version           = 3
        collected_at_utc  = (Get-Date).ToUniversalTime().ToString("o")
        ldf_file_name     = [System.IO.Path]::GetFileName($LdfPath)
        ldf_file_length   = [int64]$fileLength
        ldf_last_write_utc = $fiNow.LastWriteTimeUtc.ToString("o")
        head_sha1         = $edgeNow.head_sha1
        tail_sha1         = $edgeNow.tail_sha1
        chunk_size_bytes  = [int64]$chunkSizeBytes
        chunk_overlap_bytes = [int]$scanCarryBytes
        chunk_count       = $chunkItems.Count
        index_mode        = "full_dml_v3"
        chunks            = @($chunkItems.ToArray())
    }

    try {
        $idxDir = Split-Path -Parent $ChunkIndexPath
        if ($idxDir -and -not (Test-Path -LiteralPath $idxDir)) {
            New-Item -ItemType Directory -Path $idxDir | Out-Null
        }
        $chunkIndexObj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ChunkIndexPath -Encoding UTF8
        $chunkIndexSaved = $true
    } catch {
        # Non-fatal: matching output is still valid.
    }
}
}

# Fallback alignment: when exact action+tx+lsn is not available, pair remaining
# parsed rows and manifest rows by action+tx in LSN order.
foreach ($actionTxKey in $manifestByActionTx.Keys) {
    $candidateSource = $null
    if ($parsedCandidatesByActionTx.ContainsKey($actionTxKey)) {
        $candidateSource = $parsedCandidatesByActionTx[$actionTxKey]
    } else {
        $parts = $actionTxKey.Split('|', 2)
        if ($parts.Length -eq 2) {
            $txOnlyKey = ([string]$parts[1]).ToUpperInvariant()
            $actionOnly = ([string]$parts[0]).ToUpperInvariant()
            if ($parsedCandidatesByTx.ContainsKey($txOnlyKey)) {
                $candidateSource = @($parsedCandidatesByTx[$txOnlyKey] | Where-Object { ([string]$_.action).ToUpperInvariant() -eq $actionOnly })
            }
        }
    }
    if ($null -eq $candidateSource) { continue }

    $manifestRemaining = @(
        $manifestByActionTx[$actionTxKey] |
            Where-Object {
                $mk = ([string](Get-PropertyValue -Object $_ -Name "manifest_key")).ToUpperInvariant()
                -not $matchedManifestKeys.Contains($mk)
            } |
            Sort-Object @{
                Expression = { ([string](Get-PropertyValue -Object $_ -Name "current_lsn")).ToUpperInvariant() }
            }
    )
    if ($manifestRemaining.Count -eq 0) {
        continue
    }

    $candidateRemaining = @(
        $candidateSource |
            Where-Object {
                $ck = ("{0}|{1}|{2}" -f $actionTxKey, [string]$_.offset, [string]$_.parsed_hobt_token)
                -not $usedParsedCandidates.Contains($ck)
            } |
            Sort-Object @{
                Expression = { ([string]$_.lsn_heuristic).ToUpperInvariant() }
            }, offset
    )
    if ($candidateRemaining.Count -eq 0) {
        continue
    }

    $pairCount = [Math]::Min($manifestRemaining.Count, $candidateRemaining.Count)
    for ($idx = 0; $idx -lt $pairCount; $idx++) {
        $m = $manifestRemaining[$idx]
        $c = $candidateRemaining[$idx]
        $manifestKey = ([string](Get-PropertyValue -Object $m -Name "manifest_key")).ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($manifestKey)) {
            continue
        }

        $physPage = $null
        $physSlot = $null
        $script:physlocParseAttempts++
        if (Try-ParseManifestPhysLoc -ManifestRow $m -OutPageId ([ref]$physPage) -OutSlotId ([ref]$physSlot)) {
            $script:physlocParseSuccess++
            $script:fallbackRegisterCalls++
            $reg = Register-ParsedCandidate `
                -Action ([string]$c.action) `
                -TxText ([string]$c.tx_id) `
                -LsnText ([string]$c.lsn_heuristic) `
                -AbsoluteOffset ([int64]$c.offset) `
                -ParsedHobtToken ([int64]$c.parsed_hobt_token) `
                -PageId $physPage `
                -SlotId $physSlot
            if ($reg.is_new) { $script:fallbackRegisterNew++ }
        }

        $candidateKey = ("{0}|{1}|{2}" -f $actionTxKey, [string]$c.offset, [string]$c.parsed_hobt_token)
        if (-not $usedParsedCandidates.Add($candidateKey)) {
            continue
        }

        $manifestHobt = Get-PropertyValue -Object $m -Name "hobt_token"
        $hobtMatch = $false
        if ($null -ne $manifestHobt) {
            $hobtMatch = ([int64]$manifestHobt -eq [int64]$c.parsed_hobt_token)
        }

        $dedupe = ("{0}|{1}|{2}|FALLBACK" -f $manifestKey, [string]$c.offset, [string]$c.parsed_hobt_token)
        if (-not $seenMatchKeys.Add($dedupe)) {
            continue
        }

        [void]$matchedManifestKeys.Add($manifestKey)
        $matched.Add([pscustomobject]@{
            manifest_key           = $manifestKey
            offset                 = [int64]$c.offset
            action                 = [string]$c.action
            tx_id                  = [string]$c.tx_id
            lsn_heuristic          = [string]$c.lsn_heuristic
            parsed_hobt_token      = [int64]$c.parsed_hobt_token
            manifest_hobt_token    = $manifestHobt
            hobt_match             = $hobtMatch
            commit_time            = Get-PropertyValue -Object $m -Name "commit_time"
            alloc_unit_name        = Get-PropertyValue -Object $m -Name "alloc_unit_name"
            confidence             = if ($hobtMatch) { "high" } else { "medium" }
            match_strategy         = "action_tx_order_fallback"
            reconstructed_template = ("{0} [oasis].[CHSC_POLINE] /* hybrid fallback match */;" -f [string]$c.action)
        })
    }
}

$unmatched = New-Object System.Collections.Generic.List[object]
foreach ($k in $manifestByKey.Keys) {
    if (-not $matchedManifestKeys.Contains($k)) {
        foreach ($m in $manifestByKey[$k]) {
            $unmatched.Add($m)
        }
    }
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$summary = [pscustomobject]@{
    collected_at_utc       = (Get-Date).ToUniversalTime().ToString("o")
    ldf_path               = $LdfPath
    manifest_path          = $ManifestPath
    tail_bytes             = $TailBytes
    manifest_record_count  = $manifestRecords.Count
    manifest_unique_keys   = $manifestByKey.Keys.Count
    matched_record_count   = $matched.Count
    matched_unique_keys    = $matchedManifestKeys.Count
    unmatched_record_count = $unmatched.Count
    parser_diagnostics     = [pscustomobject]@{
        manifest_tx_id_count                    = $manifestTxIdSet.Count
        manifest_tx_rows_scanned                = $diagManifestTxRowsScanned
        manifest_tx_rows_accepted_by_parser     = $diagManifestTxRowsAcceptedByParser
        chunk_index_enabled                     = $EnableChunkIndex
        chunk_index_loaded                      = $chunkIndexLoaded
        chunk_index_saved                       = $chunkIndexSaved
        chunk_index_path                        = $ChunkIndexPath
        descriptor_index_enabled                = $EnableDescriptorIndex
        descriptor_index_loaded                 = $descriptorIndexLoaded
        descriptor_index_used                   = $descriptorIndexUsed
        descriptor_index_path                   = $descriptorIndexPathEffective
        descriptor_index_record_count           = $descriptorIndexRecordCount
        parsed_candidate_total                  = $parsedCandidateTotal
        parsed_candidate_distinct_action_tx     = $parsedCandidatesByActionTx.Keys.Count
        parsed_candidate_distinct_tx            = $parsedCandidatesByTx.Keys.Count
        parsed_candidate_distinct_alloc_tokens  = $parsedCandidatesByAllocToken.Keys.Count
        parsed_candidate_distinct_page_slots    = $parsedCandidatesByPageSlot.Keys.Count
        parsed_candidate_with_page_slot_count   = $parsedCandidatePageSlotCount
        physloc_attach_attempts                 = $physlocAttachAttempts
        physloc_attach_success                  = $physlocAttachSuccess
        physloc_parse_attempts                  = $physlocParseAttempts
        physloc_parse_success                   = $physlocParseSuccess
        fallback_register_calls                = $fallbackRegisterCalls
        fallback_register_new                  = $fallbackRegisterNew
        chunk_scan_mode                         = $chunkScanMode
        chunk_size_bytes                        = $chunkSizeBytes
        chunk_overlap_bytes                     = $scanCarryBytes
        chunk_total_count                       = $totalChunkCount
        chunk_selected_count                    = $selectedChunkCount
        chunk_select_strategy                   = $ChunkSelectStrategy
        chunk_index_mode                        = [string](Get-PropertyValue -Object $chunkIndexData -Name "index_mode")
        scan_window_count                       = $scanWindows.Count
        top_manifest_tx_signature_patterns      = @(
            $diagPatternCounts.GetEnumerator() |
                Sort-Object Value -Descending |
                Select-Object -First 25 |
                ForEach-Object {
                    [pscustomobject]@{
                        signature = [string]$_.Key
                        count     = [int]$_.Value
                    }
                }
        )
    }
    note                   = "Hybrid result: only records matched by action+tx_id+lsn between live manifest and raw LDF parse."
    records                = @($matched | Sort-Object offset)
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

if ($EnableChunkIndex) {
    if ($chunkScanMode -eq "chunk_index_selective") {
        Write-Host ("Chunk index selective scan: selected {0}/{1} chunks across {2} merged windows." -f $selectedChunkCount, $totalChunkCount, $scanWindows.Count)
    } else {
        Write-Host ("Chunk index mode: {0}; scan windows={1}." -f $chunkScanMode, $scanWindows.Count)
    }
    if ($chunkIndexSaved -and -not [string]::IsNullOrWhiteSpace($ChunkIndexPath)) {
        Write-Host ("Chunk index saved: {0}" -f (Resolve-Path -LiteralPath $ChunkIndexPath))
    }
}
if ($EnableDescriptorIndex -and $descriptorIndexLoaded) {
    if ($descriptorIndexUsed) {
        Write-Host ("Descriptor index used: records={0}; path={1}" -f $descriptorIndexRecordCount, $descriptorIndexPathEffective)
    } else {
        Write-Host ("Descriptor index loaded but not used; path={0}" -f $descriptorIndexPathEffective)
    }
}

Write-Host ("Wrote {0} hybrid matched records ({1} unmatched manifest rows) to {2}" -f $matched.Count, $unmatched.Count, (Resolve-Path -LiteralPath $OutputPath))
