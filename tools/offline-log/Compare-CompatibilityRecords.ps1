param(
    [Parameter(Mandatory = $true)]
    [string]$BaselinePath,

    [Parameter(Mandatory = $true)]
    [string]$CandidatePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\output\compatibility-compare.latest.json"
)

$ErrorActionPreference = "Stop"

function Resolve-RequiredPath {
    param([string]$PathValue)
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
}

function Read-JsonFile {
    param([string]$PathValue)
    return Get-Content -LiteralPath $PathValue -Raw | ConvertFrom-Json
}

function Ordered-MarkerNames {
    param($MarkerObject)
    if ($null -eq $MarkerObject) { return @() }
    return @($MarkerObject.PSObject.Properties.Name | Sort-Object)
}

$baselineResolved = Resolve-RequiredPath -PathValue $BaselinePath
$candidateResolved = Resolve-RequiredPath -PathValue $CandidatePath

$baseline = Read-JsonFile -PathValue $baselineResolved
$candidate = Read-JsonFile -PathValue $candidateResolved

$baselineMarkers = Ordered-MarkerNames -MarkerObject $baseline.db_marker_counts
$candidateMarkers = Ordered-MarkerNames -MarkerObject $candidate.db_marker_counts

$sameMarkerKeys = (@($baselineMarkers) -join ",") -eq (@($candidateMarkers) -join ",")
$sameMarkerCounts = $true
foreach ($key in $baselineMarkers) {
    if (($baseline.db_marker_counts.$key) -ne ($candidate.db_marker_counts.$key)) {
        $sameMarkerCounts = $false
        break
    }
}

$comparison = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    source = [ordered]@{
        baseline_record = $baselineResolved
        candidate_record = $candidateResolved
    }
    context = [ordered]@{
        baseline = [ordered]@{
            session_name = $baseline.session_name
            service_name = $baseline.service_name
            client_id = $baseline.client_id
            environment = $baseline.environment
            sql_version_hint = $baseline.sql_version_hint
        }
        candidate = [ordered]@{
            session_name = $candidate.session_name
            service_name = $candidate.service_name
            client_id = $candidate.client_id
            environment = $candidate.environment
            sql_version_hint = $candidate.sql_version_hint
        }
    }
    alignment = [ordered]@{
        same_profile = ($baseline.selected_profile -eq $candidate.selected_profile)
        same_scan_end_lsn = ($baseline.scan_end_lsn -eq $candidate.scan_end_lsn)
        same_client_id = ($baseline.client_id -eq $candidate.client_id)
        same_environment = ($baseline.environment -eq $candidate.environment)
        same_sql_version_hint = ($baseline.sql_version_hint -eq $candidate.sql_version_hint)
        same_db_marker_keys = $sameMarkerKeys
        same_db_marker_counts = $sameMarkerCounts
    }
    counts = [ordered]@{
        baseline = [ordered]@{
            raw_candidate_count = $baseline.counts.raw_candidate_count
            commit_count = $baseline.counts.commit_count
            manifest_record_count = $baseline.counts.manifest_record_count
            semantic_event_count = $baseline.counts.semantic_event_count
            business_event_feed_count = $baseline.counts.business_event_feed_count
        }
        candidate = [ordered]@{
            raw_candidate_count = $candidate.counts.raw_candidate_count
            commit_count = $candidate.counts.commit_count
            manifest_record_count = $candidate.counts.manifest_record_count
            semantic_event_count = $candidate.counts.semantic_event_count
            business_event_feed_count = $candidate.counts.business_event_feed_count
        }
    }
    semantic_filters = [ordered]@{
        baseline = $baseline.semantic_event_filter
        candidate = $candidate.semantic_event_filter
    }
    semantic_event_kind_counts = [ordered]@{
        baseline = $baseline.semantic_event_kind_counts
        candidate = $candidate.semantic_event_kind_counts
    }
    db_marker_counts = [ordered]@{
        baseline = $baseline.db_marker_counts
        candidate = $candidate.db_marker_counts
    }
}

$outDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$json = $comparison | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $OutputPath -Value $json

Write-Host ("Compatibility comparison written to: {0}" -f (Resolve-Path -LiteralPath $OutputPath).Path)
