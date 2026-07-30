param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Write-LogLine {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $line = "{0} {1}" -f (Get-Date).ToUniversalTime().ToString("o"), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-StringOrDefault {
    param($Obj, [string]$Name, [string]$DefaultValue = "")
    if ($null -eq $Obj) { return $DefaultValue }
    if ($Obj.PSObject.Properties.Name -contains $Name) {
        $v = [string]$Obj.$Name
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
    }
    return $DefaultValue
}

function Get-BoolOrDefault {
    param($Obj, [string]$Name, [bool]$DefaultValue = $false)
    if ($null -eq $Obj) { return $DefaultValue }
    if ($Obj.PSObject.Properties.Name -contains $Name) { return [bool]$Obj.$Name }
    return $DefaultValue
}

function Get-IntOrDefault {
    param($Obj, [string]$Name, [int]$DefaultValue = 0)
    if ($null -eq $Obj) { return $DefaultValue }
    if ($Obj.PSObject.Properties.Name -contains $Name) { return [int]$Obj.$Name }
    return $DefaultValue
}

function Get-ArrayOrEmpty {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return @() }
    if ($Obj.PSObject.Properties.Name -contains $Name -and $null -ne $Obj.$Name) {
        return @($Obj.$Name)
    }
    return @()
}

function Invoke-ArchiveOldFiles {
    param(
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$ArchiveDir,
        [Parameter(Mandatory = $true)][int]$ArchiveAfterHours,
        [Parameter(Mandatory = $true)][bool]$DeleteOriginalAfterArchive,
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    if ($ArchiveAfterHours -le 0) { return }
    $thresholdUtc = (Get-Date).ToUniversalTime().AddHours(-1 * $ArchiveAfterHours)
    Ensure-ParentDirectory -Path (Join-Path $ArchiveDir "placeholder.txt")
    $oldFiles = Get-ChildItem -LiteralPath $OutputDir -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTimeUtc -lt $thresholdUtc -and
            $_.Extension -in @(".trn", ".json", ".log")
        }
    if ($oldFiles.Count -eq 0) { return }

    $zipName = "archive_{0}.zip" -f (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
    $zipPath = Join-Path $ArchiveDir $zipName
    Compress-Archive -Path @($oldFiles.FullName) -DestinationPath $zipPath -CompressionLevel Optimal
    Write-LogLine -LogPath $LogPath -Message ("Archived {0} files to {1}" -f $oldFiles.Count, $zipPath)

    if ($DeleteOriginalAfterArchive) {
        foreach ($f in $oldFiles) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        }
        Write-LogLine -LogPath $LogPath -Message ("Deleted archived originals: {0}" -f $oldFiles.Count)
    }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "ConfigPath not found: $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$svc = $cfg.service
$paths = $cfg.paths
$pipe = $cfg.pipeline
$sec = $cfg.security

$serviceName = Get-StringOrDefault -Obj $svc -Name "name" -DefaultValue "AOTransact"
$loop = if ($Once.IsPresent) { $false } else { Get-BoolOrDefault -Obj $svc -Name "loop" -DefaultValue $false }
$intervalMinutes = [Math]::Max(1, (Get-IntOrDefault -Obj $svc -Name "interval_minutes" -DefaultValue 15))
$maxCycleMinutes = [Math]::Max(1, (Get-IntOrDefault -Obj $svc -Name "max_cycle_minutes" -DefaultValue 12))
$allowUnboundedRetry = Get-BoolOrDefault -Obj $svc -Name "allow_start_lsn_retry_without_bound" -DefaultValue $false

$outputDir = Get-StringOrDefault -Obj $paths -Name "output_dir" -DefaultValue ".\output"
$statePath = Get-StringOrDefault -Obj $paths -Name "state_path" -DefaultValue (Join-Path $outputDir "service\last-offset.json")
$metadataSnapshotPath = Get-StringOrDefault -Obj $paths -Name "metadata_snapshot_path" -DefaultValue (Join-Path $outputDir "chsc_metadata_flux.snapshot.json")
$lockFilePath = Get-StringOrDefault -Obj $paths -Name "lock_file_path" -DefaultValue (Join-Path $outputDir "service\aotransact.lock")
$healthFilePath = Get-StringOrDefault -Obj $paths -Name "health_file_path" -DefaultValue (Join-Path $outputDir "service\last-run.json")
$logDir = Get-StringOrDefault -Obj $paths -Name "log_dir" -DefaultValue (Join-Path $outputDir "service\logs")
$archiveDir = Get-StringOrDefault -Obj $paths -Name "archive_dir" -DefaultValue (Join-Path $outputDir "service\archive")
$archiveAfterHours = [Math]::Max(0, (Get-IntOrDefault -Obj $paths -Name "archive_after_hours" -DefaultValue 24))
$deleteAfterArchive = Get-BoolOrDefault -Obj $paths -Name "delete_original_after_archive" -DefaultValue $false

Ensure-ParentDirectory -Path $statePath
Ensure-ParentDirectory -Path $healthFilePath
Ensure-ParentDirectory -Path (Join-Path $logDir "placeholder.txt")
Ensure-ParentDirectory -Path $lockFilePath
Ensure-ParentDirectory -Path (Join-Path $archiveDir "placeholder.txt")

$logPath = Join-Path $logDir ("{0}_{1}.log" -f $serviceName, (Get-Date).ToUniversalTime().ToString("yyyyMMdd"))

$lockStream = $null
try {
    $lockStream = [System.IO.File]::Open($lockFilePath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch {
    Write-LogLine -LogPath $logPath -Message "Another instance is running; exiting."
    exit 10
}

$runnerScript = Join-Path $PSScriptRoot "Run-HybridLdfSingleSnapshotMultiTable.ps1"
if (-not (Test-Path -LiteralPath $runnerScript)) {
    throw "Runner script not found: $runnerScript"
}

$sourceDrive = Get-StringOrDefault -Obj $pipe -Name "source_drive" -DefaultValue "E:"
$snapshotDataPath = Get-StringOrDefault -Obj $pipe -Name "snapshot_data_path" -DefaultValue "DATA\Oasis"
$ldfName = Get-StringOrDefault -Obj $pipe -Name "ldf_name" -DefaultValue "OASIS_FLUX_log.ldf"
$liveServer = Get-StringOrDefault -Obj $pipe -Name "live_server_instance" -DefaultValue "LOCALHOST\SQLEXPRESS"
$liveDb = Get-StringOrDefault -Obj $pipe -Name "live_database" -DefaultValue "OASIS_FLUX"
$metaServer = Get-StringOrDefault -Obj $pipe -Name "metadata_server_instance" -DefaultValue $liveServer
$metaDb = Get-StringOrDefault -Obj $pipe -Name "metadata_database" -DefaultValue $liveDb
$tables = Get-ArrayOrEmpty -Obj $pipe -Name "tables"
$users = Get-ArrayOrEmpty -Obj $pipe -Name "users"
$excludeUsers = Get-ArrayOrEmpty -Obj $pipe -Name "exclude_users"
$spids = Get-ArrayOrEmpty -Obj $pipe -Name "spids"
$windowMinutes = [Math]::Max(1, (Get-IntOrDefault -Obj $pipe -Name "window_minutes" -DefaultValue 15))
$bootstrapFirstRun = Get-BoolOrDefault -Obj $pipe -Name "bootstrap_first_run" -DefaultValue $true
$rawMatchMode = Get-StringOrDefault -Obj $pipe -Name "raw_match_mode" -DefaultValue "skip"
$applyToTarget = Get-BoolOrDefault -Obj $pipe -Name "apply_to_target" -DefaultValue $false
$generateUndo = Get-BoolOrDefault -Obj $pipe -Name "generate_undo" -DefaultValue $false
$exportBeforeAfter = Get-BoolOrDefault -Obj $pipe -Name "export_before_after" -DefaultValue $false
$exportRowHistory = Get-BoolOrDefault -Obj $pipe -Name "export_row_history" -DefaultValue $false
$useCompiled = Get-BoolOrDefault -Obj $pipe -Name "use_compiled_converter" -DefaultValue $true
$fallbackToPs = Get-BoolOrDefault -Obj $pipe -Name "compiled_converter_fallback_to_ps" -DefaultValue $false

$useSqlAuth = Get-BoolOrDefault -Obj $sec -Name "use_sql_auth" -DefaultValue $false
$sqlUser = Get-StringOrDefault -Obj $sec -Name "sql_user" -DefaultValue ""
$sqlPassword = Get-StringOrDefault -Obj $sec -Name "sql_password" -DefaultValue ""

if ($tables.Count -eq 0) {
    throw "pipeline.tables is empty in config."
}
if (-not (Test-Path -LiteralPath $metadataSnapshotPath)) {
    throw "Metadata snapshot not found: $metadataSnapshotPath"
}

while ($true) {
    $runStartedUtc = (Get-Date).ToUniversalTime()
    $sessionName = "prod_{0}" -f $runStartedUtc.ToString("yyyyMMdd_HHmmss")
    $ok = $false
    $err = $null
    $summaryPath = Join-Path $outputDir ("session.{0}.summary.json" -f $sessionName)

    Write-LogLine -LogPath $logPath -Message ("Cycle start: session={0}" -f $sessionName)
    try {
        $params = @{
            SourceDrive = $sourceDrive
            SnapshotDataPath = $snapshotDataPath
            LdfName = $ldfName
            LiveServerInstance = $liveServer
            LiveDatabase = $liveDb
            MetadataServerInstance = $metaServer
            MetadataDatabase = $metaDb
            MetadataSnapshotPath = $metadataSnapshotPath
            Tables = $tables
            WindowMinutes = $windowMinutes
            StatePath = $statePath
            BootstrapFirstRun = $bootstrapFirstRun
            OutputDir = $outputDir
            SessionName = $sessionName
            RawMatchMode = $rawMatchMode
            ApplyToTarget = $applyToTarget
            GenerateUndo = $generateUndo
            ExportBeforeAfter = $exportBeforeAfter
            ExportRowHistory = $exportRowHistory
            UseCompiledConverter = $useCompiled
            CompiledConverterFallbackToPs = $fallbackToPs
            MaxPhaseMinutes = $maxCycleMinutes
            AllowStartLsnRetryWithoutBound = $allowUnboundedRetry
        }

        if ($users.Count -gt 0) { $params["Users"] = $users }
        if ($excludeUsers.Count -gt 0) { $params["ExcludeUsers"] = $excludeUsers }
        if ($spids.Count -gt 0) { $params["Spids"] = @($spids | ForEach-Object { [int]$_ }) }
        if ($useSqlAuth) {
            $params["SqlUser"] = $sqlUser
            $params["SqlPassword"] = $sqlPassword
        }

        & $runnerScript @params | Out-Null
        $ok = $true
        Write-LogLine -LogPath $logPath -Message ("Cycle success: session={0}" -f $sessionName)
    }
    catch {
        $err = $_.Exception.Message
        Write-LogLine -LogPath $logPath -Message ("Cycle failed: session={0}; error={1}" -f $sessionName, $err)
    }

    $runEndedUtc = (Get-Date).ToUniversalTime()
    $health = [pscustomobject]@{
        service_name = $serviceName
        session = $sessionName
        started_utc = $runStartedUtc.ToString("o")
        ended_utc = $runEndedUtc.ToString("o")
        success = $ok
        error = $err
        summary_path = $summaryPath
        config_path = $ConfigPath
    }
    $health | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $healthFilePath -Encoding UTF8

    Invoke-ArchiveOldFiles -OutputDir $outputDir -ArchiveDir $archiveDir -ArchiveAfterHours $archiveAfterHours -DeleteOriginalAfterArchive $deleteAfterArchive -LogPath $logPath

    if (-not $loop) { break }
    Start-Sleep -Seconds ($intervalMinutes * 60)
}

if ($lockStream) {
    $lockStream.Dispose()
}
