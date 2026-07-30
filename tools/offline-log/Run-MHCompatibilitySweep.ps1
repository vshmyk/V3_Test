param(
    [Parameter(Mandatory = $false)]
    [string[]]$ConfigPaths = @(
        ".\tools\offline-log\runner.config.mh-den08.raw-cb-d2.json",
        ".\tools\offline-log\runner.config.mh-den08.raw-cb-d2.commercial-adjustment.json",
        ".\tools\offline-log\runner.config.mh-den08.raw-cb-d2.invoice.json",
        ".\tools\offline-log\runner.config.mh-den08.raw-cb-d2.attachment.json"
    ),

    [Parameter(Mandatory = $false)]
    [string]$RunnerProjectPath = ".\tools\offline-log\aotransact-runner\AOtransact.Runner.csproj",

    [Parameter(Mandatory = $false)]
    [string]$RecordsRoot = ".\output",

    [Parameter(Mandatory = $false)]
    [string]$LatestMatrixPath = ".\output\compatibility-matrix.latest.csv",

    [Parameter(Mandatory = $false)]
    [string]$HistoryMatrixPath = ".\output\compatibility-matrix.history.csv",

    [Parameter(Mandatory = $false)]
    [string]$HealthOutputPath = ".\output\compatibility-health.latest.json",

    [Parameter(Mandatory = $false)]
    [switch]$Build,

    [Parameter(Mandatory = $false)]
    [switch]$ResetState,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRuns
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-PathOrThrow {
    param([string]$PathValue)
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
}

function Resolve-PathAllowMissing {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathValue))
}

function Resolve-PathRelativeToBase {
    param(
        [string]$PathValue,
        [string]$BaseDir
    )
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $PathValue))
}

function Sanitize-Name {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return "unknown" }
    return (($Name -replace '[^A-Za-z0-9._-]', '_').Trim('_'))
}

function Get-LatestCompatibilityRecord {
    param([string]$OutputDir)
    if (-not (Test-Path -LiteralPath $OutputDir)) { return $null }
    return Get-ChildItem -LiteralPath $OutputDir -Filter "compatibility-record.*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime |
        Select-Object -Last 1
}

$runnerProjectResolved = Resolve-PathOrThrow -PathValue $RunnerProjectPath
$recordsRootResolved = Resolve-PathOrThrow -PathValue $RecordsRoot
$latestMatrixResolved = Resolve-PathAllowMissing -PathValue $LatestMatrixPath
$historyMatrixResolved = Resolve-PathAllowMissing -PathValue $HistoryMatrixPath
$healthOutputResolved = Resolve-PathAllowMissing -PathValue $HealthOutputPath

$compareScript = Resolve-PathOrThrow -PathValue ".\tools\offline-log\Compare-CompatibilityRecords.ps1"
$exportScript = Resolve-PathOrThrow -PathValue ".\tools\offline-log\Export-CompatibilityMatrixCsv.ps1"
$historyScript = Resolve-PathOrThrow -PathValue ".\tools\offline-log\Update-CompatibilityMatrixHistory.ps1"
$healthScript = Resolve-PathOrThrow -PathValue ".\tools\offline-log\Test-CompatibilityMatrixHealth.ps1"

if ($Build.IsPresent) {
    Write-Host "Building runner..."
    dotnet build $runnerProjectResolved -c Release | Out-Host
}

$runRecords = @()
foreach ($configPath in $ConfigPaths) {
    $configResolved = Resolve-PathOrThrow -PathValue $configPath
    $cfg = Get-Content -LiteralPath $configResolved -Raw | ConvertFrom-Json
    $configBaseDir = Split-Path -Parent $configResolved
    $serviceName = [string]$cfg.service.name
    $clientId = [string]$cfg.pipeline.client_id
    $environment = [string]$cfg.pipeline.environment
    $sqlVersionHint = [string]$cfg.pipeline.sql_version_hint
    $outputDir = Resolve-PathRelativeToBase -PathValue ([string]$cfg.paths.output_dir) -BaseDir $configBaseDir
    $statePath = Resolve-PathRelativeToBase -PathValue ([string]$cfg.paths.state_path) -BaseDir $configBaseDir
    $semanticFilter = @()
    if ($cfg.pipeline.PSObject.Properties.Name -contains "semantic_event_kinds" -and $null -ne $cfg.pipeline.semantic_event_kinds) {
        $semanticFilter = @($cfg.pipeline.semantic_event_kinds | ForEach-Object { $_.ToString() })
    }

    Write-Host ("--- Config: {0}" -f $configResolved)
    Write-Host ("Service: {0}" -f $serviceName)
    Write-Host ("Client:  {0}" -f $clientId)
    Write-Host ("Env:     {0}" -f $environment)
    Write-Host ("SQL:     {0}" -f $sqlVersionHint)
    Write-Host ("Output:  {0}" -f $outputDir)
    Write-Host ("Filter:  {0}" -f (($semanticFilter -join ", ")))

    if ($ResetState.IsPresent -and (Test-Path -LiteralPath $statePath)) {
        Remove-Item -LiteralPath $statePath -Force
        Write-Host ("State reset: {0}" -f $statePath)
    }

    if (-not $SkipRuns.IsPresent) {
        dotnet run --project $runnerProjectResolved -c Release -- --config $configResolved --once | Out-Host
    }

    $latestRecord = Get-LatestCompatibilityRecord -OutputDir $outputDir
    if ($null -eq $latestRecord) {
        Write-Warning ("No compatibility record found for output dir: {0}" -f $outputDir)
        continue
    }

    $runRecords += [PSCustomObject]@{
        service_name = $serviceName
        client_id = $clientId
        environment = $environment
        sql_version_hint = $sqlVersionHint
        config_path = $configResolved
        output_dir = $outputDir
        semantic_event_filter = ($semanticFilter -join ";")
        compatibility_record_path = $latestRecord.FullName
        generated_utc = $latestRecord.LastWriteTimeUtc.ToString("o")
    }
}

if ($runRecords.Count -eq 0) {
    throw "No compatibility records collected from sweep."
}

Write-Host "Refreshing matrix artifacts..."
powershell -ExecutionPolicy Bypass -File $exportScript -RecordsRoot $recordsRootResolved -OutputPath $latestMatrixResolved | Out-Host
powershell -ExecutionPolicy Bypass -File $historyScript -RecordsRoot $recordsRootResolved -HistoryPath $historyMatrixResolved | Out-Host
powershell -ExecutionPolicy Bypass -File $healthScript -MatrixPath $historyMatrixResolved -OutputPath $healthOutputResolved | Out-Host

$baseline = $runRecords | Where-Object { [string]::IsNullOrWhiteSpace($_.semantic_event_filter) } | Select-Object -Last 1
if ($null -eq $baseline) {
    $baseline = $runRecords[0]
}

$comparisonOutputs = @()
foreach ($candidate in $runRecords) {
    if ($candidate.compatibility_record_path -eq $baseline.compatibility_record_path) { continue }
    $baseName = Sanitize-Name -Name $baseline.service_name
    $candName = Sanitize-Name -Name $candidate.service_name
    $outPath = Resolve-PathAllowMissing -PathValue (".\output\compatibility-compare.{0}-vs-{1}.latest.json" -f $baseName, $candName)
    powershell -ExecutionPolicy Bypass -File $compareScript -BaselinePath $baseline.compatibility_record_path -CandidatePath $candidate.compatibility_record_path -OutputPath $outPath | Out-Host
    $comparisonOutputs += $outPath
}

$summary = [ordered]@{
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    sweep_config_count = $ConfigPaths.Count
    run_record_count = $runRecords.Count
    baseline_record = $baseline.compatibility_record_path
    latest_matrix_path = $latestMatrixResolved
    history_matrix_path = $historyMatrixResolved
    health_report_path = $healthOutputResolved
    comparison_outputs = $comparisonOutputs
    runs = $runRecords
}

$summaryPath = Resolve-PathAllowMissing -PathValue ".\output\compatibility-sweep.latest.json"
$summaryDir = Split-Path -Parent $summaryPath
if (-not [string]::IsNullOrWhiteSpace($summaryDir)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath

Write-Host ("Sweep summary written to: {0}" -f $summaryPath)
