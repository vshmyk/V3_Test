param(
    [Parameter(Mandatory = $false)]
    [string]$MatrixPath = ".\output\compatibility-matrix.history.csv",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\compatibility-health.latest.json",

    [Parameter(Mandatory = $false)]
    [string]$BaselineSessionName,

    [Parameter(Mandatory = $false)]
    [string]$BaselineServiceName
)

$ErrorActionPreference = "Stop"

function Parse-IntOrZero {
    param([object]$Value)
    if ($null -eq $Value) { return 0 }
    $parsed = 0
    if ([int]::TryParse($Value.ToString(), [ref]$parsed)) { return $parsed }
    return 0
}

function Parse-DateOrMin {
    param([object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value.ToString())) { return [datetimeoffset]::MinValue }
    return [datetimeoffset]::Parse($Value.ToString(), [System.Globalization.CultureInfo]::InvariantCulture)
}

function Normalize-TokenList {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return (($Value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object) -join ';')
}

if (-not (Test-Path -LiteralPath $MatrixPath)) {
    throw "Matrix file not found: $MatrixPath"
}

$rows = @(Import-Csv -LiteralPath $MatrixPath)
if ($rows.Count -eq 0) {
    throw "Matrix file has no rows: $MatrixPath"
}

$ordered = $rows | Sort-Object { Parse-DateOrMin $_.generated_utc }, session_name
$candidate = $ordered[-1]

$baseline = $null
if (-not [string]::IsNullOrWhiteSpace($BaselineSessionName)) {
    $baseline = $ordered | Where-Object { $_.session_name -eq $BaselineSessionName } | Select-Object -Last 1
}
elseif (-not [string]::IsNullOrWhiteSpace($BaselineServiceName)) {
    $baseline = $ordered | Where-Object { $_.service_name -eq $BaselineServiceName } | Select-Object -Last 1
}
else {
    # Default baseline: latest broad run (empty semantic filter)
    $baseline = $ordered | Where-Object { [string]::IsNullOrWhiteSpace($_.semantic_event_filter) } | Select-Object -Last 1
}

if ($null -eq $baseline) {
    $baseline = $ordered[0]
}

$notes = New-Object System.Collections.Generic.List[string]

$sameProfile = ($candidate.selected_profile -eq $baseline.selected_profile)
if (-not $sameProfile) {
    $notes.Add("Selected profile changed from '$($baseline.selected_profile)' to '$($candidate.selected_profile)'.")
}

$sameScanEndLsn = ($candidate.scan_end_lsn -eq $baseline.scan_end_lsn)
if (-not $sameScanEndLsn) {
    $notes.Add("Scan end LSN changed from '$($baseline.scan_end_lsn)' to '$($candidate.scan_end_lsn)'.")
}

$sameDbMarkerFilter = (Normalize-TokenList $candidate.db_marker_filter) -eq (Normalize-TokenList $baseline.db_marker_filter)
if (-not $sameDbMarkerFilter) {
    $notes.Add("DB marker filter changed from '$($baseline.db_marker_filter)' to '$($candidate.db_marker_filter)'.")
}

$sameClientId = ($candidate.client_id -eq $baseline.client_id)
if (-not $sameClientId) {
    $notes.Add("Client tag changed from '$($baseline.client_id)' to '$($candidate.client_id)'.")
}

$sameEnvironment = ($candidate.environment -eq $baseline.environment)
if (-not $sameEnvironment) {
    $notes.Add("Environment tag changed from '$($baseline.environment)' to '$($candidate.environment)'.")
}

$sameSqlVersionHint = ($candidate.sql_version_hint -eq $baseline.sql_version_hint)
if (-not $sameSqlVersionHint) {
    $notes.Add("SQL version hint changed from '$($baseline.sql_version_hint)' to '$($candidate.sql_version_hint)'.")
}

$sameDbMarkerCb = (Parse-IntOrZero $candidate.db_marker_0xCB_count) -eq (Parse-IntOrZero $baseline.db_marker_0xCB_count)
$sameDbMarkerD2 = (Parse-IntOrZero $candidate.db_marker_0xD2_count) -eq (Parse-IntOrZero $baseline.db_marker_0xD2_count)
if (-not $sameDbMarkerCb -or -not $sameDbMarkerD2) {
    $notes.Add("DB marker counts changed (0xCB or 0xD2).")
}

$rawDelta = (Parse-IntOrZero $candidate.raw_candidate_count) - (Parse-IntOrZero $baseline.raw_candidate_count)
$commitDelta = (Parse-IntOrZero $candidate.commit_count) - (Parse-IntOrZero $baseline.commit_count)
$manifestDelta = (Parse-IntOrZero $candidate.manifest_record_count) - (Parse-IntOrZero $baseline.manifest_record_count)
$semanticDelta = (Parse-IntOrZero $candidate.semantic_event_count) - (Parse-IntOrZero $baseline.semantic_event_count)

if ($rawDelta -ne 0 -or $commitDelta -ne 0 -or $manifestDelta -ne 0) {
    $notes.Add("Structural counts changed (raw/commit/manifest).")
}

$semanticFilterChanged = (Normalize-TokenList $candidate.semantic_event_filter) -ne (Normalize-TokenList $baseline.semantic_event_filter)
if ($semanticDelta -ne 0) {
    if ($semanticFilterChanged) {
        $notes.Add("Semantic event counts changed (expected when semantic_event_filter differs).")
    }
    else {
        $notes.Add("Semantic event counts changed with the same semantic_event_filter.")
    }
}

$status = if ($sameProfile -and $sameScanEndLsn -and $sameDbMarkerFilter -and $sameDbMarkerCb -and $sameDbMarkerD2) { "ok" } else { "attention" }

$report = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    matrix_path = (Resolve-Path -LiteralPath $MatrixPath).Path
    status = $status
    baseline = [ordered]@{
        session_name = $baseline.session_name
        service_name = $baseline.service_name
        source_file = $baseline.source_file
        generated_utc = $baseline.generated_utc
        client_id = $baseline.client_id
        environment = $baseline.environment
        sql_version_hint = $baseline.sql_version_hint
        selected_profile = $baseline.selected_profile
        scan_end_lsn = $baseline.scan_end_lsn
        db_marker_filter = $baseline.db_marker_filter
        semantic_event_filter = $baseline.semantic_event_filter
    }
    candidate = [ordered]@{
        session_name = $candidate.session_name
        service_name = $candidate.service_name
        source_file = $candidate.source_file
        generated_utc = $candidate.generated_utc
        client_id = $candidate.client_id
        environment = $candidate.environment
        sql_version_hint = $candidate.sql_version_hint
        selected_profile = $candidate.selected_profile
        scan_end_lsn = $candidate.scan_end_lsn
        db_marker_filter = $candidate.db_marker_filter
        semantic_event_filter = $candidate.semantic_event_filter
    }
    checks = [ordered]@{
        same_profile = $sameProfile
        same_scan_end_lsn = $sameScanEndLsn
        same_client_id = $sameClientId
        same_environment = $sameEnvironment
        same_sql_version_hint = $sameSqlVersionHint
        same_db_marker_filter = $sameDbMarkerFilter
        same_db_marker_0xCB_count = $sameDbMarkerCb
        same_db_marker_0xD2_count = $sameDbMarkerD2
    }
    deltas = [ordered]@{
        raw_candidate_count = $rawDelta
        commit_count = $commitDelta
        manifest_record_count = $manifestDelta
        semantic_event_count = $semanticDelta
        invoice_activity_count = (Parse-IntOrZero $candidate.invoice_activity_count) - (Parse-IntOrZero $baseline.invoice_activity_count)
        attachment_activity_count = (Parse-IntOrZero $candidate.attachment_activity_count) - (Parse-IntOrZero $baseline.attachment_activity_count)
        commercial_adjustment_count = (Parse-IntOrZero $candidate.commercial_adjustment_count) - (Parse-IntOrZero $baseline.commercial_adjustment_count)
        history_activity_count = (Parse-IntOrZero $candidate.history_activity_count) - (Parse-IntOrZero $baseline.history_activity_count)
    }
    notes = @($notes)
}

$outDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$json = $report | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $OutputPath -Value $json

Write-Host ("Compatibility health report written to: {0}" -f (Resolve-Path -LiteralPath $OutputPath).Path)
Write-Host ("Status: {0}" -f $status)
if ($notes.Count -gt 0) {
    Write-Host ("Notes: {0}" -f ($notes -join " | "))
}
