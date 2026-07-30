param(
    [Parameter(Mandatory = $false)]
    [string]$RecordsRoot = ".\output",

    [Parameter(Mandatory = $false)]
    [string]$HistoryPath = ".\output\compatibility-matrix.history.csv"
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

function Get-RowValue {
    param(
        [object]$RowObject,
        [string]$PropertyName
    )
    if ($null -eq $RowObject) { return $null }
    $prop = $RowObject.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Normalize-MatrixRow {
    param([object]$RowObject)

    return [PSCustomObject]@{
        generated_utc = Get-RowValue -RowObject $RowObject -PropertyName "generated_utc"
        session_name = Get-RowValue -RowObject $RowObject -PropertyName "session_name"
        service_name = Get-RowValue -RowObject $RowObject -PropertyName "service_name"
        source_file = Get-RowValue -RowObject $RowObject -PropertyName "source_file"
        ldf_file_name = Get-RowValue -RowObject $RowObject -PropertyName "ldf_file_name"
        read_mode = Get-RowValue -RowObject $RowObject -PropertyName "read_mode"
        live_server_instance = Get-RowValue -RowObject $RowObject -PropertyName "live_server_instance"
        live_database = Get-RowValue -RowObject $RowObject -PropertyName "live_database"
        client_id = Get-RowValue -RowObject $RowObject -PropertyName "client_id"
        environment = Get-RowValue -RowObject $RowObject -PropertyName "environment"
        sql_version_hint = Get-RowValue -RowObject $RowObject -PropertyName "sql_version_hint"
        selected_profile = Get-RowValue -RowObject $RowObject -PropertyName "selected_profile"
        selected_window_start = Get-RowValue -RowObject $RowObject -PropertyName "selected_window_start"
        selected_window_length = Get-RowValue -RowObject $RowObject -PropertyName "selected_window_length"
        start_lsn_used = Get-RowValue -RowObject $RowObject -PropertyName "start_lsn_used"
        scan_end_lsn = Get-RowValue -RowObject $RowObject -PropertyName "scan_end_lsn"
        action_filter = Get-RowValue -RowObject $RowObject -PropertyName "action_filter"
        db_marker_filter = Get-RowValue -RowObject $RowObject -PropertyName "db_marker_filter"
        semantic_event_filter = Get-RowValue -RowObject $RowObject -PropertyName "semantic_event_filter"
        raw_candidate_count = Get-RowValue -RowObject $RowObject -PropertyName "raw_candidate_count"
        commit_count = Get-RowValue -RowObject $RowObject -PropertyName "commit_count"
        manifest_record_count = Get-RowValue -RowObject $RowObject -PropertyName "manifest_record_count"
        extracted_record_count = Get-RowValue -RowObject $RowObject -PropertyName "extracted_record_count"
        transaction_bundle_count = Get-RowValue -RowObject $RowObject -PropertyName "transaction_bundle_count"
        command_candidate_count = Get-RowValue -RowObject $RowObject -PropertyName "command_candidate_count"
        semantic_event_count = Get-RowValue -RowObject $RowObject -PropertyName "semantic_event_count"
        business_event_feed_count = Get-RowValue -RowObject $RowObject -PropertyName "business_event_feed_count"
        invoice_activity_count = Get-RowValue -RowObject $RowObject -PropertyName "invoice_activity_count"
        attachment_activity_count = Get-RowValue -RowObject $RowObject -PropertyName "attachment_activity_count"
        commercial_adjustment_count = Get-RowValue -RowObject $RowObject -PropertyName "commercial_adjustment_count"
        history_activity_count = Get-RowValue -RowObject $RowObject -PropertyName "history_activity_count"
        db_marker_0xCB_count = Get-RowValue -RowObject $RowObject -PropertyName "db_marker_0xCB_count"
        db_marker_0xD2_count = Get-RowValue -RowObject $RowObject -PropertyName "db_marker_0xD2_count"
        semantic_event_kind_counts_json = Get-RowValue -RowObject $RowObject -PropertyName "semantic_event_kind_counts_json"
        db_marker_counts_json = Get-RowValue -RowObject $RowObject -PropertyName "db_marker_counts_json"
    }
}

function Build-MatrixRowFromRecord {
    param([System.IO.FileInfo]$RecordFile)

    $doc = Get-Content -LiteralPath $RecordFile.FullName -Raw | ConvertFrom-Json
    $counts = $doc.counts
    $kindCounts = $doc.semantic_event_kind_counts
    $markerCounts = $doc.db_marker_counts

    return [PSCustomObject]@{
        generated_utc = $doc.generated_utc
        session_name = $doc.session_name
        service_name = $doc.service_name
        source_file = $RecordFile.FullName
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

$recordsRootResolved = Resolve-PathOrThrow -PathValue $RecordsRoot
$recordFiles = Get-ChildItem -Path $recordsRootResolved -Recurse -Filter "compatibility-record.*.json" | Sort-Object LastWriteTime

if ($recordFiles.Count -eq 0) {
    throw "No compatibility-record files found under '$recordsRootResolved'."
}

$historyRows = @()
$historyIndex = @{}

if (Test-Path -LiteralPath $HistoryPath) {
    $historyRows = @(Import-Csv -LiteralPath $HistoryPath | ForEach-Object { Normalize-MatrixRow -RowObject $_ })
    for ($i = 0; $i -lt $historyRows.Count; $i++) {
        $row = $historyRows[$i]
        if (-not [string]::IsNullOrWhiteSpace($row.source_file)) {
            $historyIndex[$row.source_file] = $i
        }
    }
}

$added = 0
$updated = 0
foreach ($recordFile in $recordFiles) {
    if ($historyIndex.ContainsKey($recordFile.FullName)) {
        $existingIndex = [int]$historyIndex[$recordFile.FullName]
        $existing = $historyRows[$existingIndex]
        $missingTagContext = [string]::IsNullOrWhiteSpace([string]$existing.client_id) -and
            [string]::IsNullOrWhiteSpace([string]$existing.environment) -and
            [string]::IsNullOrWhiteSpace([string]$existing.sql_version_hint)

        if ($missingTagContext) {
            $row = Build-MatrixRowFromRecord -RecordFile $recordFile
            $historyRows[$existingIndex] = Normalize-MatrixRow -RowObject $row
            $updated++
        }
        continue
    }

    $row = Build-MatrixRowFromRecord -RecordFile $recordFile
    $row = Normalize-MatrixRow -RowObject $row
    $historyRows += $row
    $historyIndex[$recordFile.FullName] = ($historyRows.Count - 1)
    $added++
}

$sortedRows = $historyRows | Sort-Object generated_utc, session_name

$outDir = Split-Path -Path $HistoryPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$sortedRows | Export-Csv -LiteralPath $HistoryPath -NoTypeInformation -Encoding UTF8

Write-Host ("Compatibility history CSV written to: {0}" -f (Resolve-Path -LiteralPath $HistoryPath).Path)
Write-Host ("Rows total: {0}" -f $sortedRows.Count)
Write-Host ("Rows added this run: {0}" -f $added)
Write-Host ("Rows refreshed this run: {0}" -f $updated)
