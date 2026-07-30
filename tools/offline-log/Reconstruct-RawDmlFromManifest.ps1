param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$CommandsPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputSqlPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputSummaryPath,

    [Parameter(Mandatory = $false)]
    [int]$MaxStatements = 0,

    [Parameter(Mandatory = $false)]
    [switch]$NewestFirst,

    [Parameter(Mandatory = $false)]
    [switch]$StripSchema,

    [Parameter(Mandatory = $false)]
    [string]$SchemaOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RequiredPath {
    param([string]$PathValue)
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
}

function Get-SessionNameFromManifestPath {
    param([string]$PathValue)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($PathValue)
    foreach ($prefix in @("live-dml-manifest.", "records.live-dml-manifest.")) {
        if ($name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $name.Substring($prefix.Length)
        }
    }
    return $name
}

function Normalize-Identifier {
    param([string]$Value)

    $useSchemaOverride = -not [string]::IsNullOrWhiteSpace($SchemaOverride)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($StripSchema.IsPresent) {
            return "[UNKNOWN_TABLE]"
        }
        if ($useSchemaOverride) {
            return ("[{0}].[UNKNOWN_TABLE]" -f $SchemaOverride.Trim('[', ']'))
        }
        return "[UNKNOWN_TABLE]"
    }

    $parts = $Value.Split('.', 2)
    $rawSchema = ""
    $rawTable = $Value
    if ($parts.Count -eq 2) {
        $rawSchema = $parts[0]
        $rawTable = $parts[1]
    }

    $tableName = $rawTable.Trim('[', ']')
    if ($StripSchema.IsPresent) {
        return ("[{0}]" -f $tableName)
    }
    if ($useSchemaOverride) {
        return ("[{0}].[{1}]" -f $SchemaOverride.Trim('[', ']'), $tableName)
    }
    if ($parts.Count -eq 2) {
        return ("[{0}].[{1}]" -f $rawSchema.Trim('[', ']'), $tableName)
    }
    return ("[{0}]" -f $tableName)
}

function Short-Hex {
    param(
        [string]$HexValue,
        [int]$MaxChars = 96
    )
    if ([string]::IsNullOrWhiteSpace($HexValue)) { return "" }
    if ($HexValue.Length -le $MaxChars) { return $HexValue }
    return ($HexValue.Substring(0, $MaxChars) + "...")
}

function Get-RecordValue {
    param(
        [object]$Record,
        [string[]]$Names
    )
    foreach ($name in $Names) {
        $prop = $Record.PSObject.Properties[$name]
        if ($null -ne $prop) { return $prop.Value }
    }
    return $null
}

function Add-Count {
    param(
        [hashtable]$Table,
        [string]$Key
    )
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if ($Table.ContainsKey($Key)) { $Table[$Key] += 1 }
    else { $Table[$Key] = 1 }
}

function Select-BestKey {
    param([hashtable]$Table)
    if ($null -eq $Table -or $Table.Count -eq 0) { return $null }
    return $Table.GetEnumerator() |
        Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { $_.Name }; Descending = $false } |
        Select-Object -First 1 -ExpandProperty Key
}

$manifestResolved = Resolve-RequiredPath -PathValue $ManifestPath
$manifestDoc = Get-Content -LiteralPath $manifestResolved -Raw | ConvertFrom-Json

if ($null -eq $manifestDoc.records) {
    throw "Manifest file does not contain 'records': $manifestResolved"
}

$manifestRecords = @($manifestDoc.records)
$normalizedRecords = @(
    foreach ($r in $manifestRecords) {
        $actionRaw = Get-RecordValue -Record $r -Names @("action", "Action")
        $txRaw = Get-RecordValue -Record $r -Names @("tx_id", "TransactionId")
        $lsnRaw = Get-RecordValue -Record $r -Names @("current_lsn", "CurrentLsn")
        $offsetRaw = Get-RecordValue -Record $r -Names @("offset", "Offset")
        $tokenRaw = Get-RecordValue -Record $r -Names @("primary_token", "PrimaryToken")
        $markerRaw = Get-RecordValue -Record $r -Names @("db_marker", "DbMarker")
        $sliceHexRaw = Get-RecordValue -Record $r -Names @("slice_hex", "CaptureHex")
        [PSCustomObject]@{
            action = if ($null -eq $actionRaw) { "" } else { $actionRaw.ToString().ToUpperInvariant() }
            tx_id = if ($null -eq $txRaw) { "" } else { $txRaw.ToString() }
            current_lsn = if ($null -eq $lsnRaw) { "" } else { $lsnRaw.ToString() }
            offset = if ($null -eq $offsetRaw) { 0 } else { [int64]$offsetRaw }
            primary_token = if ($null -eq $tokenRaw) { $null } else { $tokenRaw }
            db_marker = if ($null -eq $markerRaw) { "" } else { $markerRaw.ToString() }
            slice_hex = if ($null -eq $sliceHexRaw) { "" } else { $sliceHexRaw.ToString() }
        }
    }
)
$dmlRecords = @($normalizedRecords | Where-Object { $_.action -in @("INSERT", "UPDATE", "DELETE") })

$sessionName = Get-SessionNameFromManifestPath -PathValue $manifestResolved
$outDir = Split-Path -Parent $manifestResolved
if ([string]::IsNullOrWhiteSpace($OutputSqlPath)) {
    $OutputSqlPath = Join-Path $outDir ("reconstructed-dml.{0}.sql" -f $sessionName)
}
if ([string]::IsNullOrWhiteSpace($OutputSummaryPath)) {
    $OutputSummaryPath = Join-Path $outDir ("reconstructed-dml.{0}.summary.json" -f $sessionName)
}

$resolvedCommandsPath = $null
if (-not [string]::IsNullOrWhiteSpace($CommandsPath)) {
    $resolvedCommandsPath = Resolve-RequiredPath -PathValue $CommandsPath
}

$txTableVotesStrong = @{}
$tokenTableVotesStrong = @{}
$txTableVotesWeak = @{}
$tokenTableVotesWeak = @{}

if (-not [string]::IsNullOrWhiteSpace($resolvedCommandsPath)) {
    $commandDoc = Get-Content -LiteralPath $resolvedCommandsPath -Raw | ConvertFrom-Json
    $commands = @($commandDoc.commands)
    foreach ($cmd in $commands) {
        if ($null -eq $cmd.Inference -or $null -eq $cmd.Inference.candidate_tables) { continue }
        $candidateTables = @($cmd.Inference.candidate_tables | ForEach-Object { $_.ToString() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($candidateTables.Count -eq 0) { continue }
        $confidence = ""
        if ($null -ne $cmd.Inference.confidence) {
            $confidence = $cmd.Inference.confidence.ToString().Trim().ToLowerInvariant()
        }
        $isStrong = $confidence -in @("medium", "high")
        $targetTxVotes = if ($isStrong) { $txTableVotesStrong } else { $txTableVotesWeak }
        $targetTokenVotes = if ($isStrong) { $tokenTableVotesStrong } else { $tokenTableVotesWeak }

        $txId = [string]$cmd.TransactionId
        if (-not [string]::IsNullOrWhiteSpace($txId)) {
            if (-not $targetTxVotes.ContainsKey($txId)) {
                $targetTxVotes[$txId] = @{}
            }
            foreach ($tableName in $candidateTables) {
                Add-Count -Table $targetTxVotes[$txId] -Key $tableName
            }
        }

        $tokensSeen = @()
        if ($null -ne $cmd.TokensSeen) {
            $tokensSeen = @($cmd.TokensSeen)
        }
        foreach ($token in $tokensSeen) {
            if ($null -eq $token) { continue }
            $tokenKey = $token.ToString()
            if (-not $targetTokenVotes.ContainsKey($tokenKey)) {
                $targetTokenVotes[$tokenKey] = @{}
            }
            foreach ($tableName in $candidateTables) {
                Add-Count -Table $targetTokenVotes[$tokenKey] -Key $tableName
            }
        }
    }
}

$ordered = if ($NewestFirst.IsPresent) {
    $dmlRecords | Sort-Object offset -Descending
}
else {
    $dmlRecords | Sort-Object offset
}

if ($MaxStatements -gt 0) {
    $ordered = @($ordered | Select-Object -First $MaxStatements)
}
else {
    $ordered = @($ordered)
}

$sqlLines = New-Object System.Collections.Generic.List[string]
$sqlLines.Add("-- Reconstructed best-effort DML templates from raw offline manifest")
$sqlLines.Add(("-- Generated UTC: {0}" -f (Get-Date).ToUniversalTime().ToString("o")))
$sqlLines.Add(("-- Source manifest: {0}" -f $manifestResolved))
if (-not [string]::IsNullOrWhiteSpace($resolvedCommandsPath)) {
    $sqlLines.Add(("-- Source commands: {0}" -f $resolvedCommandsPath))
}
$sqlLines.Add(("-- Total manifest records: {0}" -f $manifestRecords.Count))
$sqlLines.Add(("-- Total DML candidates in output: {0}" -f $ordered.Count))
$sqlLines.Add("-- NOTE: statements are templates and require row decode for exact predicates/values.")
$sqlLines.Add("")

$countsByAction = @{ INSERT = 0; UPDATE = 0; DELETE = 0 }
$countsByTable = @{}

$rowIndex = 0
foreach ($r in $ordered) {
    $rowIndex++
    $action = [string]$r.action
    if ([string]::IsNullOrWhiteSpace($action)) { continue }
    $txId = [string]$r.tx_id
    $lsn = [string]$r.current_lsn
    $offset = [int64]$r.offset
    $token = if ($null -ne $r.primary_token) { $r.primary_token.ToString() } else { "" }
    $dbMarker = [string]$r.db_marker
    $sliceHex = [string]$r.slice_hex
    $tableCandidate = $null
    $sourceTag = "unknown"

    if (-not [string]::IsNullOrWhiteSpace($txId) -and $txTableVotesStrong.ContainsKey($txId)) {
        $tableCandidate = Select-BestKey -Table $txTableVotesStrong[$txId]
        if (-not [string]::IsNullOrWhiteSpace($tableCandidate)) {
            $sourceTag = "tx_inference_strong"
        }
    }

    if ([string]::IsNullOrWhiteSpace($tableCandidate) -and -not [string]::IsNullOrWhiteSpace($token) -and $tokenTableVotesStrong.ContainsKey($token)) {
        $tableCandidate = Select-BestKey -Table $tokenTableVotesStrong[$token]
        if (-not [string]::IsNullOrWhiteSpace($tableCandidate)) {
            $sourceTag = "token_inference_strong"
        }
    }

    if ([string]::IsNullOrWhiteSpace($tableCandidate) -and -not [string]::IsNullOrWhiteSpace($txId) -and $txTableVotesWeak.ContainsKey($txId)) {
        $tableCandidate = Select-BestKey -Table $txTableVotesWeak[$txId]
        if (-not [string]::IsNullOrWhiteSpace($tableCandidate)) {
            $sourceTag = "tx_inference_weak"
        }
    }

    if ([string]::IsNullOrWhiteSpace($tableCandidate) -and -not [string]::IsNullOrWhiteSpace($token) -and $tokenTableVotesWeak.ContainsKey($token)) {
        $tableCandidate = Select-BestKey -Table $tokenTableVotesWeak[$token]
        if (-not [string]::IsNullOrWhiteSpace($tableCandidate)) {
            $sourceTag = "token_inference_weak"
        }
    }

    $tableSql = Normalize-Identifier -Value $tableCandidate
    Add-Count -Table $countsByTable -Key $tableSql
    if ($countsByAction.ContainsKey($action)) { $countsByAction[$action] += 1 }

    $sqlLines.Add(("-- row={0} tx={1} lsn={2} off={3} token={4} marker={5} table_source={6}" -f $rowIndex, $txId, $lsn, $offset, $token, $dbMarker, $sourceTag))

    switch ($action.ToUpperInvariant()) {
        "INSERT" {
            $sqlLines.Add(("INSERT INTO {0} (/* unknown_columns */) VALUES (/* decode_from_rowlog: {1} */);" -f $tableSql, (Short-Hex -HexValue $sliceHex)))
        }
        "DELETE" {
            $sqlLines.Add(("DELETE FROM {0} WHERE /* token={1} tx_id='{2}' lsn='{3}' decode_predicate */ 1=1;" -f $tableSql, $token, $txId, $lsn))
        }
        default {
            $sqlLines.Add(("UPDATE {0} SET /* decode_from_rowlog: {1} */ WHERE /* token={2} tx_id='{3}' lsn='{4}' decode_predicate */ 1=1;" -f $tableSql, (Short-Hex -HexValue $sliceHex), $token, $txId, $lsn))
        }
    }

    $sqlLines.Add("GO")
    $sqlLines.Add("")
}

$sqlText = [string]::Join([Environment]::NewLine, $sqlLines)
Set-Content -LiteralPath $OutputSqlPath -Value $sqlText -Encoding UTF8

$summary = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    manifest_path = $manifestResolved
    commands_path = $resolvedCommandsPath
    output_sql_path = $OutputSqlPath
    strip_schema = $StripSchema.IsPresent
    schema_override = if ([string]::IsNullOrWhiteSpace($SchemaOverride)) { $null } else { $SchemaOverride }
    total_manifest_records = $manifestRecords.Count
    total_dml_records = $dmlRecords.Count
    output_statement_count = $ordered.Count
    max_statements = $MaxStatements
    newest_first = $NewestFirst.IsPresent
    action_counts = $countsByAction
    top_tables = @(
        $countsByTable.GetEnumerator() |
            Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { $_.Name }; Descending = $false } |
            Select-Object -First 20 |
            ForEach-Object { [ordered]@{ table = $_.Key; count = $_.Value } }
    )
}

$summaryJson = $summary | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutputSummaryPath -Value $summaryJson -Encoding UTF8

Write-Host ("Reconstructed SQL written to: {0}" -f (Resolve-Path -LiteralPath $OutputSqlPath).Path)
Write-Host ("Summary written to: {0}" -f (Resolve-Path -LiteralPath $OutputSummaryPath).Path)
Write-Host ("Statements generated: {0}" -f $ordered.Count)
