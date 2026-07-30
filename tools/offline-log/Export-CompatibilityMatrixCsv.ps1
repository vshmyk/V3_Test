param(
    [Parameter(Mandatory = $false)]
    [string]$RecordsRoot = ".\output",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\compatibility-matrix.latest.csv"
)

$ErrorActionPreference = "Stop"

function Resolve-PathOrThrow {
    param([string]$PathValue)
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
}

function To-JsonCompact {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ($Value | ConvertTo-Json -Depth 20 -Compress)
}

function Get-CountValue {
    param(
        [object]$CountsObject,
        [string]$PropertyName
    )
    if ($null -eq $CountsObject) { return 0 }
    $prop = $CountsObject.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) { return 0 }
    return [int]$prop.Value
}

$recordsRootResolved = Resolve-PathOrThrow -PathValue $RecordsRoot
$recordFiles = Get-ChildItem -Path $recordsRootResolved -Recurse -Filter "compatibility-record.*.json" | Sort-Object LastWriteTime

if ($recordFiles.Count -eq 0) {
    throw "No compatibility-record files found under '$recordsRootResolved'."
}

$rows = foreach ($file in $recordFiles) {
    $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $counts = $doc.counts
    $kindCounts = $doc.semantic_event_kind_counts
    $markerCounts = $doc.db_marker_counts

    [PSCustomObject]@{
        generated_utc = $doc.generated_utc
        session_name = $doc.session_name
        service_name = $doc.service_name
        source_file = $file.FullName
        ldf_file_name = $doc.ldf_file_name
        read_mode = $doc.read_mode
        live_server_instance = $doc.live_server_instance
        live_database = $doc.live_database
        client_id = $doc.client_id
        environment = $doc.environment
        sql_version_hint = $doc.sql_version_hint
        selected_profile = $doc.selected_profile
        selected_window_start = $doc.selected_window_start
        selected_window_length = $doc.selected_window_length
        start_lsn_used = $doc.start_lsn_used
        scan_end_lsn = $doc.scan_end_lsn
        action_filter = (($doc.action_filter | ForEach-Object { $_.ToString() }) -join ";")
        db_marker_filter = (($doc.db_marker_filter | ForEach-Object { $_.ToString() }) -join ";")
        semantic_event_filter = (($doc.semantic_event_filter | ForEach-Object { $_.ToString() }) -join ";")
        raw_candidate_count = if ($null -ne $counts) { [int]$counts.raw_candidate_count } else { 0 }
        commit_count = if ($null -ne $counts) { [int]$counts.commit_count } else { 0 }
        manifest_record_count = if ($null -ne $counts) { [int]$counts.manifest_record_count } else { 0 }
        extracted_record_count = if ($null -ne $counts) { [int]$counts.extracted_record_count } else { 0 }
        transaction_bundle_count = if ($null -ne $counts) { [int]$counts.transaction_bundle_count } else { 0 }
        command_candidate_count = if ($null -ne $counts) { [int]$counts.command_candidate_count } else { 0 }
        semantic_event_count = if ($null -ne $counts) { [int]$counts.semantic_event_count } else { 0 }
        business_event_feed_count = if ($null -ne $counts) { [int]$counts.business_event_feed_count } else { 0 }
        invoice_activity_count = Get-CountValue -CountsObject $kindCounts -PropertyName "invoice_activity"
        attachment_activity_count = Get-CountValue -CountsObject $kindCounts -PropertyName "attachment_activity"
        commercial_adjustment_count = Get-CountValue -CountsObject $kindCounts -PropertyName "commercial_adjustment"
        history_activity_count = Get-CountValue -CountsObject $kindCounts -PropertyName "history_activity"
        db_marker_0xCB_count = Get-CountValue -CountsObject $markerCounts -PropertyName "0xCB"
        db_marker_0xD2_count = Get-CountValue -CountsObject $markerCounts -PropertyName "0xD2"
        semantic_event_kind_counts_json = To-JsonCompact -Value $kindCounts
        db_marker_counts_json = To-JsonCompact -Value $markerCounts
    }
}

$outDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host ("Compatibility matrix CSV written to: {0}" -f (Resolve-Path -LiteralPath $OutputPath).Path)
Write-Host ("Rows exported: {0}" -f $rows.Count)
