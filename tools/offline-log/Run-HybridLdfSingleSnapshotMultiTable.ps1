param(
    [Parameter()]
    [string]$SourceDrive = "E:",

    [Parameter()]
    [string]$SnapshotDataPath = "DATA\Oasis",

    [Parameter()]
    [string]$LdfName = "OASIS_MH_log.ldf",

    [Parameter()]
    [string]$MdfName,

    [Parameter()]
    [string]$LiveServerInstance = "LOCALHOST\\SQLEXPRESS",

    [Parameter()]
    [string]$LiveDatabase = "OASIS_MH",

    [Parameter()]
    [ValidateSet("fn_dblog", "fn_full_dblog", "sys.fn_dblog", "sys.fn_full_dblog", "master.sys.fn_dblog", "master.sys.fn_full_dblog")]
    [string]$LogReaderFunction = "fn_dblog",

    [Parameter()]
    [string]$MetadataServerInstance,

    [Parameter()]
    [string]$MetadataDatabase,

    [Parameter()]
    [string]$MetadataSnapshotPath,

    [Parameter(Mandatory = $true)]
    [string[]]$Tables,

    [Parameter()]
    [string[]]$Operations = @("DMLALL"),

    [Parameter()]
    [int]$WindowMinutes = 120,

    [Parameter()]
    [string]$StartLsn,

    [Parameter()]
    [string]$StatePath = ".\\output\\LastOffset.json",

    [Parameter()]
    [bool]$BootstrapFirstRun = $true,

    [Parameter()]
    [int[]]$Spids,

    [Parameter()]
    [string[]]$Users,

    [Parameter()]
    [string[]]$ExcludeUsers,

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword,

    [Parameter()]
    [bool]$OutputSuccessfulOnly = $true,

    [Parameter()]
    [ValidateSet("update", "replace", "adaptive")]
    [string]$UpdateMode = "adaptive",

    [Parameter()]
    [ValidateSet("off", "strict")]
    [string]$ApplySafetyMode = "off",

    [Parameter()]
    [bool]$GenerateUndo = $true,

    [Parameter()]
    [bool]$ExportBeforeAfter = $true,

    [Parameter()]
    [bool]$ExportRowHistory = $true,

    [Parameter()]
    [bool]$ApplyToTarget = $true,

    [Parameter()]
    [string]$ApplyTargetServerInstance = "LOCALHOST\\SQLEXPRESS",

    [Parameter()]
    [string]$ApplyTargetDatabase = "OASIS_MH",

    [Parameter()]
    [bool]$ApplyStopOnError = $true,

    [Parameter()]
    [bool]$ApplyWrapInTransaction = $false,

    [Parameter()]
    [string]$SessionName,

    [Parameter()]
    [string]$OutputDir = ".\\output",

    [Parameter()]
    [ValidateSet("standard", "turbo_extract")]
    [string]$PerformanceProfile = "standard",

    [Parameter()]
    [ValidateSet("standard", "edge_profile")]
    [string]$RecoveryProfile = "standard",

    [Parameter()]
    [bool]$EdgeAllowLiveFallback = $true,

    [Parameter()]
    [bool]$EdgeLiveLookupIncludeBinaryPayload = $false,

    [Parameter()]
    [ValidateSet("auto", "build", "skip")]
    [string]$EdgeOfflineCacheMode = "auto",

    [Parameter()]
    [bool]$BenchmarkMode = $false,

    [Parameter()]
    [ValidateSet("full", "fast")]
    [string]$HeuristicsProfile = "full",

    [Parameter()]
    [int]$MaxRowLogPairs = 0,

    [Parameter()]
    [bool]$DisableDecode = $false,

    [Parameter()]
    [bool]$AdaptiveFastReplaceNonHighConfidence = $false,

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
    [int]$ChunkSelectMaxPercent = 85
,
    [Parameter()]
    [ValidateSet("balanced", "key_only", "lsn_only", "recent_tail", "index_ranked")]
    [string]$ChunkSelectStrategy = "index_ranked",

    [Parameter()]
    [int]$RecentTailChunkCount = 1,

    [Parameter()]
    [bool]$AutoWidenRecentTail = $true,

    [Parameter()]
    [int]$AutoWidenMaxAttempts = 4,

    [Parameter()]
    [bool]$PrepareRawLdfIndex = $false,

    [Parameter()]
    [ValidateSet("lite", "full")]
    [string]$PrepareRawLdfIndexMode = "full",

    [Parameter()]
    [bool]$EnableDescriptorIndex = $false,

    [Parameter()]
    [string]$DescriptorIndexPath,

    [Parameter()]
    [bool]$RebuildDescriptorIndex = $false,

    [Parameter()]
    [ValidateSet("auto", "full", "skip")]
    [string]$RawMatchMode = "auto",

    [Parameter()]
    [bool]$FailFastOnParserHealth = $true,

    [Parameter()]
    [int]$ParserHealthMinAcceptedRows = 1,

    [Parameter()]
    [string]$ReuseShadowDevice,

    [Parameter()]
    [bool]$SkipShadowCleanup = $false,

    [Parameter()]
    [bool]$UseShadowLdfCopy = $false,

    [Parameter()]
    [string]$ShadowLdfCopyPath
,
    [Parameter()]
    [bool]$SkipLsnHeadPrecheck = $false
,
    [Parameter()]
    [int]$MaxPhaseMinutes = 5
,
    [Parameter()]
    [bool]$UseCompiledConverter = $true
,
    [Parameter()]
    [string]$CompiledConverterPath
,
    [Parameter()]
    [bool]$CompiledConverterFallbackToPs = $true
,
    [Parameter()]
    [bool]$AllowStartLsnRetryWithoutBound = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Default Step-3 optimization profile:
# prefer descriptor streaming path (with graceful fallback to raw scan when index is unavailable).
if (-not $PSBoundParameters.ContainsKey("EnableDescriptorIndex")) {
    $EnableDescriptorIndex = $true
}
if (-not $PSBoundParameters.ContainsKey("EnableChunkIndex")) {
    $EnableChunkIndex = $true
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Invoke-ScriptWithTimeout {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Params,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$PhaseName,
        [Parameter()][switch]$Force
    )

    if ($TimeoutSeconds -le 0) {
        & $ScriptPath @Params
        return
    }

    $workingDir = (Get-Location).Path
    $job = Start-Job -ScriptBlock {
        param($sp, $prm, $wd)
        Set-Location -LiteralPath $wd
        & $sp @prm
    } -ArgumentList $ScriptPath, $Params, $workingDir

    try {
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        if (-not $completed) {
            Stop-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
            throw ("{0} exceeded timeout cap of {1} seconds." -f $PhaseName, $TimeoutSeconds)
        }

        $jobErrors = @($job.ChildJobs | ForEach-Object { $_.Error } | Where-Object { $_ })
        if ($jobErrors.Count -gt 0) {
            throw ("{0} failed: {1}" -f $PhaseName, ($jobErrors[0].ToString()))
        }

        $output = Receive-Job -Job $job -ErrorAction Stop
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$PhaseName
    )

    $workingDir = (Get-Location).Path
    $stdoutPath = Join-Path -Path $env:TEMP -ChildPath ("ao_tx_stdout_{0}.log" -f ([Guid]::NewGuid().ToString("N")))
    $stderrPath = Join-Path -Path $env:TEMP -ChildPath ("ao_tx_stderr_{0}.log" -f ([Guid]::NewGuid().ToString("N")))
    try {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $workingDir -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if ($TimeoutSeconds -gt 0) {
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                try { $proc.Kill() } catch {}
                throw ("{0} exceeded timeout cap of {1} seconds." -f $PhaseName, $TimeoutSeconds)
            }
        } else {
            $proc.WaitForExit()
        }

        $stdoutLines = @()
        $stderrText = ""
        if (Test-Path -LiteralPath $stdoutPath) {
            $stdoutLines = @(Get-Content -LiteralPath $stdoutPath)
            $stdoutLines | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) { Write-Host $_ } }
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $stderrText = (Get-Content -LiteralPath $stderrPath -Raw)
        }

        $exitCode = if ($null -eq $proc.ExitCode) { 0 } else { [int]$proc.ExitCode }
        if ($exitCode -ne 0) {
            $err = ""
            $err = $stderrText
            if ([string]::IsNullOrWhiteSpace($err) -and (Test-Path -LiteralPath $stdoutPath)) {
                $err = (Get-Content -LiteralPath $stdoutPath -Raw)
            }
            throw ("{0} failed (exit {1}): {2}" -f $PhaseName, $exitCode, $err.Trim())
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            StdOutLines = $stdoutLines
            StdErr = $stderrText
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
    }
}

function Is-ValidLsn {
    param([AllowNull()][string]$Lsn)
    return (-not [string]::IsNullOrWhiteSpace($Lsn)) -and ($Lsn -match "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")
}

function Compare-Lsn {
    param(
        [Parameter(Mandatory = $true)][string]$A,
        [Parameter(Mandatory = $true)][string]$B
    )

    if (-not (Is-ValidLsn -Lsn $A) -or -not (Is-ValidLsn -Lsn $B)) {
        throw "Compare-Lsn requires valid LSN values."
    }

    $aParts = $A.Split(":")
    $bParts = $B.Split(":")
    for ($i = 0; $i -lt 3; $i++) {
        $aNum = [Convert]::ToInt64($aParts[$i], 16)
        $bNum = [Convert]::ToInt64($bParts[$i], 16)
        if ($aNum -lt $bNum) { return -1 }
        if ($aNum -gt $bNum) { return 1 }
    }
    return 0
}

function Get-TableSetKey {
    param([Parameter(Mandatory = $true)][string[]]$InputTables)

    $normalized = @($InputTables | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Sort-Object -Unique)
    return ($normalized -join "|")
}

function Get-HybridCounts {
    param(
        [Parameter(Mandatory = $true)][object]$HybridObj,
        [Parameter(Mandatory = $true)][int]$DefaultManifestCount
    )

    $matched = Get-JsonIntValue -Object $HybridObj -Names @("matched_record_count")
    $manifest = Get-JsonIntValue -Object $HybridObj -Names @("manifest_record_count") -Default $DefaultManifestCount
    $unmatched = Get-JsonIntValue -Object $HybridObj -Names @("unmatched_record_count") -Default ($manifest - $matched)
    return [pscustomobject]@{
        matched = [int]$matched
        manifest = [int]$manifest
        unmatched = [int]$unmatched
    }
}

function Copy-FileBuffered {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $destDir = Split-Path -Parent $DestinationPath
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    $in = [System.IO.File]::Open($SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $out = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $buf = New-Object byte[] (4MB)
            while ($true) {
                $n = $in.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $out.Write($buf, 0, $n)
            }
            $out.Flush()
        } finally {
            $out.Dispose()
        }
    } finally {
        $in.Dispose()
    }
}

function Get-FiltersKey {
    param(
        [int[]]$InputSpids,
        [string[]]$InputUsers,
        [string[]]$InputExcludeUsers
    )

    $ops = "DMLALL"
    $spids = if ($InputSpids) { @($InputSpids | ForEach-Object { [int]$_ } | Sort-Object -Unique) } else { @() }
    $users = if ($InputUsers) { @($InputUsers | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) } else { @() }
    $excludeUsers = if ($InputExcludeUsers) { @($InputExcludeUsers | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) } else { @() }

    return ("ops={0};spids={1};users={2};exclude={3}" -f $ops, ($spids -join ","), ($users -join ","), ($excludeUsers -join ","))
}

function Load-State {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-Warning ("State file cannot be parsed and will be ignored: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Get-StringProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    foreach ($name in $Names) {
        $prop = $Object.PSObject.Properties[$name]
        if ($null -ne $prop -and $null -ne $prop.Value) {
            return [string]$prop.Value
        }
    }
    return $null
}

function Save-State {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][psobject]$State
    )

    Ensure-ParentDirectory -Path $Path
    $State | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Set-StateProperty {
    param(
        [Parameter(Mandatory = $true)][psobject]$State,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    if ($State.PSObject.Properties.Name -contains $Name) {
        $State.$Name = $Value
    } else {
        $State | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Test-ShadowCopyActive {
    param([AllowNull()][string]$ShadowId)
    if ([string]::IsNullOrWhiteSpace($ShadowId)) { return $false }
    $out = @(& vssadmin list shadows /Shadow=$ShadowId 2>&1)
    if ($LASTEXITCODE -ne 0) { return $false }
    $idNorm = $ShadowId.Trim().Trim("{}").ToUpperInvariant()
    foreach ($line in $out) {
        $s = [string]$line
        if ($s -like "*Shadow Copy ID:*") {
            $parsed = ($s.Split(":", 2)[1]).Trim().Trim("{}").ToUpperInvariant()
            if ($parsed -eq $idNorm) { return $true }
        }
    }
    return $false
}

function Remove-ShadowCopyById {
    param([AllowNull()][string]$ShadowId)
    if ([string]::IsNullOrWhiteSpace($ShadowId)) { return $false }
    & vssadmin delete shadows /Shadow=$ShadowId /Quiet | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Update-ShadowTrackingInState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$ShadowId,
        [AllowNull()][string]$ShadowDevice,
        [Parameter(Mandatory = $true)][bool]$Active,
        [AllowNull()][string]$Session
    )

    $st = Load-State -Path $Path
    if (-not $st) {
        $st = [pscustomobject]@{
            version = 1
            updated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    Set-StateProperty -State $st -Name "active_shadow_id" -Value $ShadowId
    Set-StateProperty -State $st -Name "active_shadow_device" -Value $ShadowDevice
    Set-StateProperty -State $st -Name "active_shadow_session" -Value $Session
    Set-StateProperty -State $st -Name "active_shadow_active" -Value $Active
    Set-StateProperty -State $st -Name "active_shadow_updated_utc" -Value ((Get-Date).ToUniversalTime().ToString("o"))
    Save-State -Path $Path -State $st
}

function New-LiveConnectionString {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $LiveServerInstance
    $builder["Initial Catalog"] = $LiveDatabase
    $builder["TrustServerCertificate"] = $true
    if ($SqlUser) {
        $builder["User ID"] = $SqlUser
        $builder["Password"] = $SqlPassword
        $builder["Integrated Security"] = $false
    } else {
        $builder["Integrated Security"] = $true
    }
    return $builder.ConnectionString
}

function Invoke-LiveScalar {
    param([Parameter(Mandatory = $true)][string]$Sql)

    $connection = New-Object System.Data.SqlClient.SqlConnection (New-LiveConnectionString)
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 0
    $command.CommandText = $Sql
    try {
        $connection.Open()
        return $command.ExecuteScalar()
    } finally {
        $connection.Dispose()
    }
}

function Resolve-LogReaderFunction {
    param([Parameter(Mandatory = $true)][string]$ConfiguredValue)

    switch ($ConfiguredValue.Trim().ToLowerInvariant()) {
        "fn_dblog" { return "fn_dblog" }
        "sys.fn_dblog" { return "fn_dblog" }
        "master.sys.fn_dblog" { return "fn_dblog" }
        "fn_full_dblog" { return "fn_full_dblog" }
        "sys.fn_full_dblog" { return "fn_full_dblog" }
        "master.sys.fn_full_dblog" { return "fn_full_dblog" }
        default { throw "Unsupported LogReaderFunction '$ConfiguredValue'. Allowed values: fn_dblog, fn_full_dblog" }
    }
}

$LogReaderFunction = Resolve-LogReaderFunction -ConfiguredValue $LogReaderFunction

function Get-LiveHeadLsn {
    $value = Invoke-LiveScalar -Sql @"
SET NOCOUNT ON;
SELECT TOP (1) [Current LSN]
FROM $LogReaderFunction(NULL, NULL)
ORDER BY [Current LSN] DESC;
"@
    if ($value -and $value -isnot [System.DBNull]) {
        return [string]$value
    }
    return $null
}

function Get-MaxManifestLsn {
    param([AllowNull()][object[]]$ManifestRecords)

    if (-not $ManifestRecords -or $ManifestRecords.Count -eq 0) { return $null }
    $maxLsn = $null
    foreach ($r in $ManifestRecords) {
        $lsn = [string]$r.current_lsn
        if (-not (Is-ValidLsn -Lsn $lsn)) { continue }
        if (-not $maxLsn) {
            $maxLsn = $lsn
            continue
        }
        if ((Compare-Lsn -A $lsn -B $maxLsn) -gt 0) {
            $maxLsn = $lsn
        }
    }
    return $maxLsn
}

function Get-MaxManifestCommitTime {
    param([AllowNull()][object[]]$ManifestRecords)

    if (-not $ManifestRecords -or $ManifestRecords.Count -eq 0) { return $null }
    $maxCommit = $null
    foreach ($r in $ManifestRecords) {
        $raw = $null
        if ($r.PSObject.Properties.Name -contains "commit_time") {
            $raw = [string]$r.commit_time
        }
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        try {
            $parsed = [datetime]$raw
        } catch {
            continue
        }
        if ($null -eq $maxCommit -or $parsed -gt $maxCommit) {
            $maxCommit = $parsed
        }
    }
    if ($null -eq $maxCommit) { return $null }
    return $maxCommit.ToUniversalTime().ToString("o")
}

function Get-JsonIntValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [int]$Default = 0
    )
    foreach ($n in $Names) {
        $p = $Object.PSObject.Properties[$n]
        if ($null -ne $p -and $null -ne $p.Value) {
            return [int]$p.Value
        }
    }
    return $Default
}

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

if (-not $Tables -or $Tables.Count -eq 0) {
    throw "Provide at least one table in schema.table format."
}

if ($WindowMinutes -lt 1) {
    throw "WindowMinutes must be > 0."
}

if ($StartLsn -and ($StartLsn -notmatch "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")) {
    throw "StartLsn format is invalid. Expected 00000025:0000F6C0:0006"
}

if (-not $SessionName) {
    $SessionName = "session_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

if (-not $MetadataServerInstance) { $MetadataServerInstance = $LiveServerInstance }
if (-not $MetadataDatabase) { $MetadataDatabase = $LiveDatabase }

$effectiveApplyToTarget = $ApplyToTarget
$effectiveGenerateUndo = $GenerateUndo
$effectiveExportBeforeAfter = $ExportBeforeAfter
$effectiveExportRowHistory = $ExportRowHistory
$effectiveApplySafetyMode = $ApplySafetyMode
$effectiveHeuristicsProfile = $HeuristicsProfile
$effectiveMaxRowLogPairs = $MaxRowLogPairs
$effectiveDisableDecode = $DisableDecode
$effectiveAdaptiveFastReplaceNonHighConfidence = $AdaptiveFastReplaceNonHighConfidence
$effectiveRawMatchMode = $RawMatchMode
$effectiveEdgeOfflineCacheMode = $EdgeOfflineCacheMode

if ($BenchmarkMode) {
    # Hard isolation mode for performance testing only.
    $effectiveApplyToTarget = $false
    $effectiveGenerateUndo = $false
    $effectiveExportBeforeAfter = $false
    $effectiveExportRowHistory = $false
    $effectiveApplySafetyMode = "off"
    Write-Host "BenchmarkMode active: apply/undo/before_after disabled and apply_safety=off."
}

if ($PerformanceProfile -eq "turbo_extract") {
    # Optimized for fast extraction/reconstruction without target apply.
    $effectiveApplyToTarget = $false
    $effectiveGenerateUndo = $false
    $effectiveExportBeforeAfter = $false
    $effectiveExportRowHistory = $false
    $effectiveApplySafetyMode = "off"
    if (-not $DisableDecode) {
        $effectiveHeuristicsProfile = "fast"
        if ($effectiveMaxRowLogPairs -le 0) { $effectiveMaxRowLogPairs = 8 }
        $effectiveAdaptiveFastReplaceNonHighConfidence = $true
    }
    Write-Host "Performance profile turbo_extract active: apply disabled, undo/before_after disabled, fast heuristics enabled."
    # In turbo mode, skip expensive head-LSN precheck roundtrip unless explicitly overridden.
    if (-not $PSBoundParameters.ContainsKey("SkipLsnHeadPrecheck")) {
        $SkipLsnHeadPrecheck = $true
    }
}

if ($effectiveRawMatchMode -eq "auto") {
    if ($PerformanceProfile -eq "turbo_extract") {
        # Turbo path with chunk index enabled should still use indexed raw-LDF matching.
        # This prevents expensive downstream live fallback when offline matches are available.
        if ($EnableChunkIndex) {
            $effectiveRawMatchMode = "full"
        } else {
            $effectiveRawMatchMode = "skip"
        }
    } elseif ($RecoveryProfile -eq "edge_profile") {
        $effectiveRawMatchMode = "skip"
    } else {
        $effectiveRawMatchMode = "full"
    }
}

if ($effectiveEdgeOfflineCacheMode -eq "auto") {
    if ($RecoveryProfile -eq "edge_profile" -and $EdgeAllowLiveFallback) {
        $effectiveEdgeOfflineCacheMode = "skip"
    } else {
        $effectiveEdgeOfflineCacheMode = "build"
    }
}

if ($RecoveryProfile -eq "edge_profile" -and $PerformanceProfile -eq "standard") {
    # Edge mode aims for throughput; optional exports are expensive.
    $effectiveExportRowHistory = $false
    $effectiveExportBeforeAfter = $false
}

$manifestScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-LiveCommittedDmlManifest.ps1"
$hybridScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-RawLdfHybridMatches.ps1"
$prepareIndexScript = Join-Path -Path $PSScriptRoot -ChildPath "Prepare-RawLdfIndex.ps1"
$convertScript = Join-Path -Path $PSScriptRoot -ChildPath "Convert-HybridToTrn.ps1"
$defaultCompiledConverterPath = Join-Path -Path $PSScriptRoot -ChildPath "fast-quote-convert\bin\Release\net8.0\fast-quote-convert.exe"
$resolvedCompiledConverterPath = if ([string]::IsNullOrWhiteSpace($CompiledConverterPath)) { $defaultCompiledConverterPath } else { $CompiledConverterPath }
$offlineCacheScript = Join-Path -Path $PSScriptRoot -ChildPath "Build-OfflineRowObjectCache.ps1"
$applyScript = Join-Path -Path $PSScriptRoot -ChildPath "Apply-TrnToTarget.ps1"
if ($MaxPhaseMinutes -lt 0) {
    throw "MaxPhaseMinutes must be >= 0."
}
$phaseTimeoutSeconds = [int]([Math]::Floor([double]$MaxPhaseMinutes * 60.0))

$manifestPath = Join-Path -Path $OutputDir -ChildPath ("live-dml-manifest.{0}.json" -f $SessionName)
$hybridPath = Join-Path -Path $OutputDir -ChildPath ("raw-ldf-hybrid-matches.{0}.json" -f $SessionName)
$summaryPath = Join-Path -Path $OutputDir -ChildPath ("session.{0}.summary.json" -f $SessionName)

$shadowId = $null
$shadowDevice = $null
$results = New-Object System.Collections.Generic.List[object]

$tablesKey = Get-TableSetKey -InputTables $Tables
$filtersKey = Get-FiltersKey -InputSpids $Spids -InputUsers $Users -InputExcludeUsers $ExcludeUsers
$normalizedSnapshotPath = ([string]$SnapshotDataPath).Trim()
$normalizedSnapshotPath = ($normalizedSnapshotPath -replace "[\\/]+", "\").Trim("\").ToUpperInvariant()
$normalizedLdfName = ([string]$LdfName).Trim()
$normalizedLdfName = ($normalizedLdfName -replace "[\\/]+", "\").Trim("\").ToUpperInvariant()
$sourceSignature = ("{0}|{1}|{2}" -f $SourceDrive.Trim().ToUpperInvariant(), $normalizedSnapshotPath, $normalizedLdfName)

$stateObj = $null
$effectiveStartLsn = $StartLsn
$effectiveStartLsnPreReset = $effectiveStartLsn
$latestLiveLsn = $null
$lsnResetDetected = $false
$bootstrapPerformed = $false
$startupSw = [System.Diagnostics.Stopwatch]::StartNew()
$startupPreStep0Ms = 0
$startupStateLoadMs = 0
$startupShadowReconcileMs = 0
$startupLsnPrecheckMs = 0
$startupBootstrapMs = 0

if (-not $effectiveStartLsn) {
    $startupStateSw = [System.Diagnostics.Stopwatch]::StartNew()
    $stateObj = Load-State -Path $StatePath
    $startupStateSw.Stop()
    $startupStateLoadMs = [int]$startupStateSw.ElapsedMilliseconds
    if ($stateObj -and [string]::IsNullOrWhiteSpace($ReuseShadowDevice)) {
        $startupShadowSw = [System.Diagnostics.Stopwatch]::StartNew()
        $stateShadowId = Get-StringProperty -Object $stateObj -Names @("active_shadow_id")
        if (-not [string]::IsNullOrWhiteSpace($stateShadowId)) {
            $isActive = Test-ShadowCopyActive -ShadowId $stateShadowId
            if ($isActive) {
                Write-Host ("Found active shadow from prior run in state: {0}. Deleting before new session." -f $stateShadowId)
                $deleted = Remove-ShadowCopyById -ShadowId $stateShadowId
                if ($deleted) {
                    Write-Host ("Deleted stale shadow copy: {0}" -f $stateShadowId)
                } else {
                    Write-Warning ("Could not delete stale shadow copy: {0}" -f $stateShadowId)
                }
            } else {
                Write-Host ("State shadow copy is not active anymore: {0}" -f $stateShadowId)
            }
            Update-ShadowTrackingInState -Path $StatePath -ShadowId $null -ShadowDevice $null -Active $false -Session $SessionName
        }
        $startupShadowSw.Stop()
        $startupShadowReconcileMs = [int]$startupShadowSw.ElapsedMilliseconds
    }
    if ($stateObj) {
        $stateServer = Get-StringProperty -Object $stateObj -Names @("live_server_instance", "server_instance")
        $stateDb = Get-StringProperty -Object $stateObj -Names @("live_database", "database")
        $stateTablesKey = Get-StringProperty -Object $stateObj -Names @("tables_key")
        $stateFiltersKey = $null
        if ($stateObj.PSObject.Properties.Name -contains "filters_key") {
            $stateFiltersKey = [string]$stateObj.filters_key
        }
        $stateSource = Get-StringProperty -Object $stateObj -Names @("source_signature")
        $stateLsn = Get-StringProperty -Object $stateObj -Names @("last_lsn")

        $sourceCompatible = $true
        if (-not [string]::IsNullOrWhiteSpace($stateSource)) {
            $sourceCompatible = $stateSource.Equals($sourceSignature, [System.StringComparison]::OrdinalIgnoreCase)
        }

        if (
            $stateServer.Equals($LiveServerInstance, [System.StringComparison]::OrdinalIgnoreCase) -and
            $stateDb.Equals($LiveDatabase, [System.StringComparison]::OrdinalIgnoreCase) -and
            $stateTablesKey.Equals($tablesKey, [System.StringComparison]::OrdinalIgnoreCase) -and
            (($stateFiltersKey -eq $filtersKey) -or [string]::IsNullOrWhiteSpace($stateFiltersKey)) -and
            $sourceCompatible -and
            (Is-ValidLsn -Lsn $stateLsn)
        ) {
            $effectiveStartLsn = $stateLsn
            Write-Host ("Using saved StartLSN from state: {0}" -f $effectiveStartLsn)
        } else {
            Write-Host "State found but scope/signature does not match current run; ignoring saved LSN."
        }
    } else {
        Write-Host "State not found; no saved StartLSN available."
    }
}

if (-not $effectiveStartLsn -and $BootstrapFirstRun) {
    $startupBootstrapSw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "Bootstrap mode: reading current live head LSN and saving state."
    $latestLiveLsn = Get-LiveHeadLsn
    if (-not (Is-ValidLsn -Lsn $latestLiveLsn)) {
        throw "Bootstrap failed: could not read a valid head LSN from live $LogReaderFunction."
    }

    $bootstrapState = [pscustomobject]@{
        version               = 1
        updated_at_utc        = (Get-Date).ToUniversalTime().ToString("o")
        bootstrap_only        = $true
        live_server_instance  = $LiveServerInstance
        live_database         = $LiveDatabase
        log_reader_function   = $LogReaderFunction
        tables_key            = $tablesKey
        filters_key           = $filtersKey
        source_signature      = $sourceSignature
        last_lsn              = $latestLiveLsn
        last_commit_time      = $null
        operations            = @("DMLALL")
        spids                 = if ($Spids) { ,@($Spids) } else { ,@() }
        users                 = if ($Users) { ,@($Users) } else { ,@() }
        exclude_users         = if ($ExcludeUsers) { ,@($ExcludeUsers) } else { ,@() }
        last_manifest_path    = $null
        last_manifest_records = 0
        last_session          = $SessionName
        note                  = "Bootstrap baseline. No transactions processed in this run."
    }
    Save-State -Path $StatePath -State $bootstrapState
    $bootstrapPerformed = $true
    $startupBootstrapSw.Stop()
    $startupBootstrapMs = [int]$startupBootstrapSw.ElapsedMilliseconds
    $startupSw.Stop()
    $startupPreStep0Ms = [int]$startupSw.ElapsedMilliseconds

    $bootstrapSummary = [pscustomobject]@{
        session              = $SessionName
        bootstrap_only       = $true
        no_op_short_circuit  = $false
        performance_profile  = $PerformanceProfile
        raw_match_mode       = $effectiveRawMatchMode
        edge_offline_cache_mode = $effectiveEdgeOfflineCacheMode
        heuristics_profile   = $effectiveHeuristicsProfile
        max_rowlog_pairs     = $effectiveMaxRowLogPairs
        decode_disabled      = $effectiveDisableDecode
        export_before_after  = $effectiveExportBeforeAfter
        export_row_history   = $effectiveExportRowHistory
        apply_to_target_effective = $effectiveApplyToTarget
        generated_utc        = (Get-Date).ToUniversalTime().ToString("o")
        state_path           = $StatePath
        state_last_lsn_saved = $latestLiveLsn
        start_lsn_input      = $StartLsn
        start_lsn_used       = $null
        source_drive         = $SourceDrive
        snapshot_data_path   = $SnapshotDataPath
        ldf_name             = $LdfName
        live_server_instance = $LiveServerInstance
        live_database        = $LiveDatabase
        log_reader_function  = $LogReaderFunction
        tables               = @($Tables)
        filters_key          = $filtersKey
        wrapper_timings_ms   = [pscustomobject]@{
            startup_pre_step0_ms = [int]$startupPreStep0Ms
            startup_state_load_ms = [int]$startupStateLoadMs
            startup_shadow_reconcile_ms = [int]$startupShadowReconcileMs
            startup_lsn_precheck_ms = [int]$startupLsnPrecheckMs
            startup_bootstrap_ms = [int]$startupBootstrapMs
            step1_shadow_ms = 0
            step2_manifest_ms = 0
            step25_prepare_index_ms = 0
            step3_raw_match_ms = 0
            step4_convert_apply_ms = 0
            step5_summary_ms = 0
            total_pipeline_ms = 0
            total_with_startup_ms = [int]$startupPreStep0Ms
            reused_shadow_device = (-not [string]::IsNullOrWhiteSpace($ReuseShadowDevice))
        }
        results              = @()
        note                 = "Bootstrap completed. Run again after new source transactions are created."
    }
    $bootstrapSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host ("Bootstrap complete. Saved last_lsn={0}" -f $latestLiveLsn)
    Write-Host ("Summary written: {0}" -f (Resolve-Path -LiteralPath $summaryPath))
    return
}

$effectiveStartLsnPreReset = $effectiveStartLsn
if ($effectiveStartLsn -and -not $SkipLsnHeadPrecheck) {
    $startupLsnSw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $latestLiveLsn = Get-LiveHeadLsn
    } catch {
        Write-Warning ("Could not pre-check current live head LSN: {0}" -f $_.Exception.Message)
    }

    if ((Is-ValidLsn -Lsn $effectiveStartLsn) -and (Is-ValidLsn -Lsn $latestLiveLsn)) {
        $lsnCmp = Compare-Lsn -A $latestLiveLsn -B $effectiveStartLsn
        if ($lsnCmp -lt 0) {
            $lsnResetDetected = $true
            Write-Warning ("Saved StartLSN {0} is ahead of current live head LSN {1}; falling back to window scan." -f $effectiveStartLsn, $latestLiveLsn)
            $effectiveStartLsn = $null
        } elseif ($lsnCmp -eq 0) {
            $noOpSummary = [pscustomobject]@{
                session = $SessionName
                performance_profile = $PerformanceProfile
                raw_match_mode = $effectiveRawMatchMode
                edge_offline_cache_mode = $effectiveEdgeOfflineCacheMode
                benchmark_mode = $BenchmarkMode
                no_op_short_circuit = $true
                heuristics_profile = $effectiveHeuristicsProfile
                max_rowlog_pairs = $effectiveMaxRowLogPairs
                decode_disabled = $effectiveDisableDecode
                export_before_after = $effectiveExportBeforeAfter
                export_row_history = $effectiveExportRowHistory
                adaptive_fast_replace_non_high_confidence = $effectiveAdaptiveFastReplaceNonHighConfidence
                apply_to_target_effective = $effectiveApplyToTarget
                generated_utc = (Get-Date).ToUniversalTime().ToString("o")
                start_lsn_input = $StartLsn
                start_lsn_used = $effectiveStartLsn
                start_lsn_before_reset = $effectiveStartLsnPreReset
                latest_live_lsn = $latestLiveLsn
                lsn_reset_detected = $false
                manifest_record_count = 0
                manifest_transaction_count = 0
                state_path = $StatePath
                state_last_lsn_saved = $effectiveStartLsn
                source_drive = $SourceDrive
                snapshot_data_path = $SnapshotDataPath
                ldf_name = $LdfName
                live_server_instance = $LiveServerInstance
                live_database = $LiveDatabase
                log_reader_function = $LogReaderFunction
                tables = @($Tables)
                filters_key = $filtersKey
                wrapper_timings_ms = [pscustomobject]@{
                    startup_pre_step0_ms = 0
                    startup_state_load_ms = [int]$startupStateLoadMs
                    startup_shadow_reconcile_ms = [int]$startupShadowReconcileMs
                    startup_lsn_precheck_ms = 0
                    startup_bootstrap_ms = [int]$startupBootstrapMs
                    step1_shadow_ms = 0
                    step2_manifest_ms = 0
                    step25_prepare_index_ms = 0
                    step3_raw_match_ms = 0
                    step4_convert_apply_ms = 0
                    step5_summary_ms = 0
                    total_pipeline_ms = 0
                    total_with_startup_ms = 0
                    reused_shadow_device = (-not [string]::IsNullOrWhiteSpace($ReuseShadowDevice))
                }
                results = @()
                note = "No new transactions since saved last_lsn; skipped shadow copy and offline processing."
            }
            $startupLsnSw.Stop()
            $startupLsnPrecheckMs = [int]$startupLsnSw.ElapsedMilliseconds
            $startupSw.Stop()
            $startupPreStep0Ms = [int]$startupSw.ElapsedMilliseconds
            $noOpSummary.wrapper_timings_ms.startup_pre_step0_ms = [int]$startupPreStep0Ms
            $noOpSummary.wrapper_timings_ms.startup_lsn_precheck_ms = [int]$startupLsnPrecheckMs
            $noOpSummary.wrapper_timings_ms.total_with_startup_ms = [int]$startupPreStep0Ms
            $noOpSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
            Write-Host ("No-op short-circuit: latest_live_lsn equals start_lsn ({0})." -f $latestLiveLsn)
            Write-Host ("Summary written: {0}" -f (Resolve-Path -LiteralPath $summaryPath))
            return
        }
    }
    $startupLsnSw.Stop()
    $startupLsnPrecheckMs = [int]$startupLsnSw.ElapsedMilliseconds
}
elseif ($effectiveStartLsn -and $SkipLsnHeadPrecheck) {
    Write-Host "Skipping live head-LSN precheck (SkipLsnHeadPrecheck=true)."
}

$startupSw.Stop()
$startupPreStep0Ms = [int]$startupSw.ElapsedMilliseconds
Write-Host ("Pre-step0 timing: {0} ms (state={1}, stale_shadow={2}, lsn_precheck={3}, bootstrap={4})" -f `
    $startupPreStep0Ms, $startupStateLoadMs, $startupShadowReconcileMs, $startupLsnPrecheckMs, $startupBootstrapMs)

$scanEndLsn = $null
$maxManifestLsn = $null
$maxManifestCommitTime = $null
$manifestRecordCount = 0
$manifestTransactionCount = 0
$startLsnFallbackUsed = $false
$savedLastLsn = $null
$pipelineSw = [System.Diagnostics.Stopwatch]::StartNew()
$step1Ms = 0
$step2Ms = 0
$step25Ms = 0
$step3Ms = 0
$step4Ms = 0
$step5Ms = 0
$ldfPathShadow = $null
$ldfPath = $null

try {
    $step1Sw = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not [string]::IsNullOrWhiteSpace($ReuseShadowDevice)) {
        Write-Host ("Step 1/5: Reuse existing shadow device {0}" -f $ReuseShadowDevice)
        $shadowDevice = ([string]$ReuseShadowDevice).Trim().TrimEnd("\")
        $shadowId = $null
    } else {
        Write-Host ("Step 1/5: Create one shadow copy for {0}" -f $SourceDrive)
        $createOut = @(& vssadmin create shadow /for=$SourceDrive 2>&1)
        $shadowIdLine = $createOut | Where-Object { ([string]$_) -like "*Shadow Copy ID:*" } | Select-Object -First 1
        $shadowDeviceLine = $createOut | Where-Object { ([string]$_) -like "*Shadow Copy Volume Name:*" } | Select-Object -First 1
        if (-not $shadowIdLine -or -not $shadowDeviceLine) {
            $rawCreate = ($createOut | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
            throw ("Could not parse shadow copy ID/device from vssadmin output.`nCreate:`n{0}" -f $rawCreate)
        }
        $shadowId = ([string]$shadowIdLine).Split(":", 2)[1].Trim()
        $shadowDevice = ([string]$shadowDeviceLine).Split(":", 2)[1].Trim().TrimEnd("\")
        Update-ShadowTrackingInState -Path $StatePath -ShadowId $shadowId -ShadowDevice $shadowDevice -Active $true -Session $SessionName
        Write-Host ("Saved active shadow to state: id={0}" -f $shadowId)
    }

    $rel = (($SnapshotDataPath -replace "[\\/]+", "\").TrimStart("\"))
    $ldfPathShadow = ("{0}\{1}\{2}" -f $shadowDevice, $rel, $LdfName)
    if (-not (Test-Path -LiteralPath $ldfPathShadow)) {
        throw "LDF file not found in shadow copy: $ldfPathShadow"
    }
    if ($UseShadowLdfCopy) {
        if ([string]::IsNullOrWhiteSpace($ShadowLdfCopyPath)) {
            $copyDir = Join-Path -Path $OutputDir -ChildPath ("shadow-ldf-copy.{0}" -f $SessionName)
            $ShadowLdfCopyPath = Join-Path -Path $copyDir -ChildPath $LdfName
        }
        Write-Host ("Step 1/5: Copy LDF from shadow to local working path: {0}" -f $ShadowLdfCopyPath)
        Copy-FileBuffered -SourcePath $ldfPathShadow -DestinationPath $ShadowLdfCopyPath
        $ldfPath = $ShadowLdfCopyPath
    } else {
        $ldfPath = $ldfPathShadow
    }
    if (-not (Test-Path -LiteralPath $ldfPath)) {
        throw "Working LDF path not found: $ldfPath"
    }
    $effectiveMdfName = $MdfName
    if ([string]::IsNullOrWhiteSpace($effectiveMdfName)) {
        $effectiveMdfName = ($LdfName -replace "_log\.ldf$", ".mdf")
        if ($effectiveMdfName -eq $LdfName) {
            $effectiveMdfName = ($LdfName -replace "\.ldf$", ".mdf")
        }
    }
    $mdfPath = ("{0}\{1}\{2}" -f $shadowDevice, $rel, $effectiveMdfName)
    if ($RecoveryProfile -eq "edge_profile") {
        if ([string]::IsNullOrWhiteSpace($MetadataSnapshotPath)) {
            throw "RecoveryProfile=edge_profile requires MetadataSnapshotPath."
        }
        if (-not (Test-Path -LiteralPath $mdfPath)) {
            throw "MDF file not found in shadow copy: $mdfPath"
        }
    }
    $step1Sw.Stop()
    $step1Ms = [int]$step1Sw.ElapsedMilliseconds
    Write-Host ("Step 1 timing: {0} ms" -f $step1Ms)

    if ($EnableChunkIndex -and $PrepareRawLdfIndex) {
        $step25Sw = [System.Diagnostics.Stopwatch]::StartNew()
        if ([string]::IsNullOrWhiteSpace($ChunkIndexPath)) {
            $ChunkIndexPath = Join-Path -Path $OutputDir -ChildPath (([System.IO.Path]::GetFileName($ldfPath)) + ".chunk-index.json")
        }
        Write-Host "Step 2.5/5: Prepare raw-LDF index"
        $prepareParams = @{
            LdfPath          = $ldfPath
            OutputPath       = $ChunkIndexPath
            ChunkSizeMB      = $ChunkSizeMB
            ChunkOverlapBytes= $ChunkOverlapBytes
            LiteMode         = ($PrepareRawLdfIndexMode -eq "lite")
            ForceRebuild     = $RebuildChunkIndex
        }
        Invoke-ScriptWithTimeout -ScriptPath $prepareIndexScript -Params $prepareParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName "Step 2.5 Prepare-RawLdfIndex"
        $step25Sw.Stop()
        $step25Ms = [int]$step25Sw.ElapsedMilliseconds
        Write-Host ("Step 2.5 timing: {0} ms" -f $step25Ms)
    }

    Write-Host "Step 2/5: Build one live manifest for all tables"
    $step2Sw = [System.Diagnostics.Stopwatch]::StartNew()
    $manifestParams = @{
        ServerInstance = $LiveServerInstance
        Database = $LiveDatabase
        LogReaderFunction = $LogReaderFunction
        Tables = $Tables
        Operations = $Operations
        WindowMinutes = $WindowMinutes
        OutputPath = $manifestPath
    }
    if ($Spids -and $Spids.Count -gt 0) {
        $manifestParams["Spids"] = $Spids
    }
    if ($Users -and $Users.Count -gt 0) {
        $manifestParams["Users"] = $Users
    }
    if ($ExcludeUsers -and $ExcludeUsers.Count -gt 0) {
        $manifestParams["ExcludeUsers"] = $ExcludeUsers
    }
    if ($effectiveStartLsn) {
        $manifestParams["StartLsn"] = $effectiveStartLsn
    }
    if ($SqlUser) {
        $manifestParams["SqlUser"] = $SqlUser
        $manifestParams["SqlPassword"] = $SqlPassword
    }
    try {
        Invoke-ScriptWithTimeout -ScriptPath $manifestScript -Params $manifestParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName "Step 2 Get-LiveCommittedDmlManifest"
    } catch {
        $errText = [string]($_.Exception.Message)
        $canRetryWithoutStartLsn = (
            $manifestParams.ContainsKey("StartLsn") -and
            ($errText -like "*Invalid parameter passed to OpenRowset(DBLog*")
        )
        if ($canRetryWithoutStartLsn -and $AllowStartLsnRetryWithoutBound) {
            Write-Warning ("Step 2 failed with StartLSN={0}: OpenRowset(DBLog) parameter error. Retrying without StartLsn." -f [string]$manifestParams["StartLsn"])
            $null = $manifestParams.Remove("StartLsn")
            $startLsnFallbackUsed = $true
            Invoke-ScriptWithTimeout -ScriptPath $manifestScript -Params $manifestParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName "Step 2 Get-LiveCommittedDmlManifest (retry-no-startlsn)"
        } elseif ($canRetryWithoutStartLsn -and (-not $AllowStartLsnRetryWithoutBound)) {
            throw ("Step 2 failed with StartLSN={0}: OpenRowset(DBLog) parameter error and retry-without-StartLsn is disabled." -f [string]$manifestParams["StartLsn"])
        } else {
            throw
        }
    }

    $manifestObj = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifestRecordCount = Get-JsonIntValue -Object $manifestObj -Names @("record_count")
    $manifestTransactionCount = Get-JsonIntValue -Object $manifestObj -Names @("transaction_count")
    if ($manifestObj.PSObject.Properties.Name -contains "scan_end_lsn") {
        $scanEndLsn = [string]$manifestObj.scan_end_lsn
    }
    $maxManifestLsn = Get-MaxManifestLsn -ManifestRecords @($manifestObj.records)
    $maxManifestCommitTime = Get-MaxManifestCommitTime -ManifestRecords @($manifestObj.records)
    $step2Sw.Stop()
    $step2Ms = [int]$step2Sw.ElapsedMilliseconds
    Write-Host ("Step 2 timing: {0} ms" -f $step2Ms)

    $step3Sw = [System.Diagnostics.Stopwatch]::StartNew()
    $rawMatchAttempts = New-Object System.Collections.Generic.List[object]
    if ($effectiveRawMatchMode -eq "skip" -or [int]$manifestRecordCount -eq 0) {
        Write-Host "Step 3/5: Skip offline raw-LDF match (raw_match_mode=skip)"
        $hybridStub = [pscustomobject]@{
            collected_at_utc       = (Get-Date).ToUniversalTime().ToString("o")
            ldf_path               = $ldfPath
            manifest_path          = $manifestPath
            tail_bytes             = 0
            manifest_record_count  = [int]$manifestRecordCount
            manifest_unique_keys   = [int]$manifestRecordCount
            matched_record_count   = 0
            matched_unique_keys    = 0
            unmatched_record_count = [int]$manifestRecordCount
            parser_diagnostics     = [pscustomobject]@{
                raw_match_mode = if ([int]$manifestRecordCount -eq 0) { "skip_no_manifest_rows" } else { "skip" }
            }
            note                   = if ([int]$manifestRecordCount -eq 0) { "Raw LDF matching skipped because manifest_record_count=0." } else { "Raw LDF matching skipped by runner mode." }
            records                = @()
        }
        $hybridStub | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $hybridPath -Encoding UTF8
    } else {
        Write-Host "Step 3/5: Run one offline raw-LDF match"
        $attempt = 1
        $tailCount = [Math]::Max(1, [int]$RecentTailChunkCount)
        $maxAttempts = [Math]::Max(1, [int]$AutoWidenMaxAttempts)

        while ($true) {
            $hybridParams = @{
                LdfPath = $ldfPath
                ManifestPath = $manifestPath
                OutputPath = $hybridPath
            }
            if ($EnableChunkIndex) {
                $hybridParams["EnableChunkIndex"] = $true
                if (-not [string]::IsNullOrWhiteSpace($ChunkIndexPath)) {
                    $hybridParams["ChunkIndexPath"] = $ChunkIndexPath
                }
                $hybridParams["ChunkSizeMB"] = $ChunkSizeMB
                $hybridParams["ChunkOverlapBytes"] = $ChunkOverlapBytes
                $hybridParams["RebuildChunkIndex"] = $RebuildChunkIndex
                $hybridParams["ChunkSelectMaxPercent"] = $ChunkSelectMaxPercent
                $hybridParams["ChunkSelectStrategy"] = $ChunkSelectStrategy
                $hybridParams["RecentTailChunkCount"] = $tailCount
            }
            if ($EnableDescriptorIndex) {
                $hybridParams["EnableDescriptorIndex"] = $true
                if (-not [string]::IsNullOrWhiteSpace($DescriptorIndexPath)) {
                    $hybridParams["DescriptorIndexPath"] = $DescriptorIndexPath
                }
                $hybridParams["RebuildDescriptorIndex"] = $RebuildDescriptorIndex
            }

            if ($ChunkSelectStrategy -eq "recent_tail") {
                Write-Host ("Step 3 attempt {0}: strategy=recent_tail tail_chunks={1}" -f $attempt, $tailCount)
            }

            $attemptSw = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-ScriptWithTimeout -ScriptPath $hybridScript -Params $hybridParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName ("Step 3 Get-RawLdfHybridMatches attempt " + $attempt)
            $attemptSw.Stop()

            $attemptObj = Get-Content -LiteralPath $hybridPath -Raw | ConvertFrom-Json
            $attemptCounts = Get-HybridCounts -HybridObj $attemptObj -DefaultManifestCount $manifestRecordCount
            $rawMatchAttempts.Add([pscustomobject]@{
                attempt = [int]$attempt
                chunk_select_strategy = $ChunkSelectStrategy
                recent_tail_chunk_count = [int]$tailCount
                elapsed_ms = [int]$attemptSw.ElapsedMilliseconds
                manifest_record_count = [int]$attemptCounts.manifest
                matched_record_count = [int]$attemptCounts.matched
                unmatched_record_count = [int]$attemptCounts.unmatched
            }) | Out-Null

            $shouldWiden = $EnableChunkIndex -and
                           $AutoWidenRecentTail -and
                           ($ChunkSelectStrategy -eq "recent_tail") -and
                           ($attemptCounts.unmatched -gt 0) -and
                           ($attempt -lt $maxAttempts)

            if (-not $shouldWiden) {
                break
            }

            $attempt++
            $tailCount = [Math]::Min(1024, [int]($tailCount * 2))
        }

        if ($FailFastOnParserHealth -and (Test-Path -LiteralPath $hybridPath)) {
            try {
                $hybridObj = Get-Content -LiteralPath $hybridPath -Raw | ConvertFrom-Json
                $matchedRecordCount = Get-JsonIntValue -Object $hybridObj -Names @("matched_record_count")
                $hybridManifestCount = Get-JsonIntValue -Object $hybridObj -Names @("manifest_record_count") -Default $manifestRecordCount
                $acceptedByParser = 0
                if ($hybridObj.PSObject.Properties.Name -contains "parser_diagnostics" -and $null -ne $hybridObj.parser_diagnostics) {
                    $acceptedByParser = Get-JsonIntValue -Object $hybridObj.parser_diagnostics -Names @("manifest_tx_rows_accepted_by_parser")
                }

                if (($hybridManifestCount -gt 0) -and ($matchedRecordCount -eq 0) -and ($acceptedByParser -lt $ParserHealthMinAcceptedRows)) {
                    throw ("Parser health check failed: matched_record_count={0}, manifest_tx_rows_accepted_by_parser={1}, manifest_record_count={2}. " +
                           "Failing fast before Step 4 to avoid long ineffective run. " +
                           "Recommendation: use RawMatchMode='skip' for this run or adjust parser for current LDF format.") -f `
                           $matchedRecordCount, $acceptedByParser, $hybridManifestCount
                }
            } catch {
                throw $_
            }
        }
    }
    $step3Sw.Stop()
    $step3Ms = [int]$step3Sw.ElapsedMilliseconds
    Write-Host ("Step 3 timing: {0} ms" -f $step3Ms)

    Write-Host "Step 4/5: Convert/apply per table within this same snapshot session"
    $step4Sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($table in $Tables) {
        $suffix = $table.ToLowerInvariant().Replace("oasis.", "").Replace(".", "_")
        $trnPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.trn" -f $SessionName, $suffix)
        $unresolvedPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.unresolved.trn" -f $SessionName, $suffix)
        $quarantinePath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.quarantine.trn" -f $SessionName, $suffix)
        $undoPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.undo.trn" -f $SessionName, $suffix)
        $beforeAfterPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.before_after.json" -f $SessionName, $suffix)
        $applyPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.apply.json" -f $SessionName, $suffix)
        $phaseTimingPath = Join-Path -Path $OutputDir -ChildPath ("hybrid.{0}.{1}.phase_timings.json" -f $SessionName, $suffix)
        $offlineCachePath = Join-Path -Path $OutputDir -ChildPath ("offline-row-cache.{0}.{1}.json" -f $SessionName, $suffix)
        $offlineDiagPath = Join-Path -Path $OutputDir -ChildPath ("offline-row-cache.{0}.{1}.diagnostics.json" -f $SessionName, $suffix)

        $convertParams = @{
            ManifestPath = $manifestPath
            HybridPath = $hybridPath
            OutputPath = $trnPath
            UnresolvedOutputPath = $unresolvedPath
            QuarantineOutputPath = $quarantinePath
            UndoOutputPath = $undoPath
            BeforeAfterJsonPath = $beforeAfterPath
            TargetTable = $table
            ServerInstance = $LiveServerInstance
            Database = $LiveDatabase
            MetadataServerInstance = $MetadataServerInstance
            MetadataDatabase = $MetadataDatabase
            OutputSuccessfulOnly = $OutputSuccessfulOnly
            UpdateMode = $UpdateMode
            ApplySafetyMode = $effectiveApplySafetyMode
            GenerateUndo = $effectiveGenerateUndo
            ExportBeforeAfter = $effectiveExportBeforeAfter
            ExportRowHistory = $effectiveExportRowHistory
            HeuristicsProfile = $effectiveHeuristicsProfile
            MaxRowLogPairs = $effectiveMaxRowLogPairs
            DisableDecode = $effectiveDisableDecode
            AdaptiveFastReplaceNonHighConfidence = $effectiveAdaptiveFastReplaceNonHighConfidence
            PhaseTimingOutputPath = $phaseTimingPath
        }
        if ($RecoveryProfile -eq "edge_profile") {
            if ($effectiveEdgeOfflineCacheMode -eq "build") {
                $offlineCacheParams = @{
                    ManifestPath             = $manifestPath
                    MdfPath                  = $mdfPath
                    TargetTable              = $table
                    MetadataSnapshotPath     = $MetadataSnapshotPath
                    OutputPath               = $offlineCachePath
                    DiagnosticsOutputPath    = $offlineDiagPath
                    DeduplicateByPhysLoc     = $false
                    EnableGuidedSlotRecovery = $true
                }
                Invoke-ScriptWithTimeout -ScriptPath $offlineCacheScript -Params $offlineCacheParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName ("Step 4 Build-OfflineRowObjectCache " + $table)

                $convertParams["OfflineRowObjectCachePath"] = $offlineCachePath
                $convertParams["OfflineAllowKeyPatch"] = $true
                $convertParams["EnableOfflineKeyMatchFallback"] = $true
            }
            $convertParams["DisableLiveRowLookup"] = (-not $EdgeAllowLiveFallback)
            $convertParams["LiveLookupIncludeBinaryPayload"] = $EdgeLiveLookupIncludeBinaryPayload
        }
        if (-not [string]::IsNullOrWhiteSpace($MetadataSnapshotPath)) {
            $convertParams["MetadataSnapshotPath"] = $MetadataSnapshotPath
        }
        if ($SqlUser) {
            $convertParams["SqlUser"] = $SqlUser
            $convertParams["SqlPassword"] = $SqlPassword
        }
        $usedCompiledConverter = $false
        $convertFailed = $false
        $convertFailureMessage = $null
        $tableSchema = ($table -split "\.")[0]
        $tableName = ($table -split "\.")[1]
        $metadataForCompiled = $MetadataSnapshotPath
        if ([string]::IsNullOrWhiteSpace($metadataForCompiled)) {
            $fallbackMetadata = Join-Path -Path $OutputDir -ChildPath "chsc_metadata_flux.snapshot.json"
            if (Test-Path -LiteralPath $fallbackMetadata) {
                $metadataForCompiled = $fallbackMetadata
            }
        }

        $canUseCompiledConverter = $UseCompiledConverter -and
            ($RecoveryProfile -eq "standard") -and
            (Test-Path -LiteralPath $resolvedCompiledConverterPath) -and
            (-not [string]::IsNullOrWhiteSpace($metadataForCompiled))

        if ($canUseCompiledConverter) {
            $compiledUpdateMode = "hybrid"
            if ($UpdateMode -eq "replace") { $compiledUpdateMode = "replace" }
            elseif ($UpdateMode -eq "update") { $compiledUpdateMode = "full" }

            $compiledArgs = @(
                "--server", $LiveServerInstance,
                "--database", $LiveDatabase,
                "--schema", $tableSchema,
                "--table", $tableName,
                "--manifest", $manifestPath,
                "--metadata", $metadataForCompiled,
                "--output", $trnPath,
                "--update-emit-mode", $compiledUpdateMode
            )
            $enablePhyslocLookup = $false
            if ($tableSchema.Equals("oasis", [System.StringComparison]::OrdinalIgnoreCase)) {
                # Targeted fallback: enable physloc-assisted key recovery only for tables
                # where we observed endian/partial key decode misses in updates/inserts.
                if ($tableName.Equals("CHSC_QUOTE", [System.StringComparison]::OrdinalIgnoreCase) -or
                    $tableName.Equals("CHSC_QUOTECONTACT", [System.StringComparison]::OrdinalIgnoreCase) -or
                    $tableName.Equals("CHSC_SHIPMENTLINE", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $enablePhyslocLookup = $true
                }
            }
            $compiledArgs += @("--physloc-lookup", ($enablePhyslocLookup.ToString().ToLowerInvariant()))
            if ($SqlUser) {
                $compiledArgs += @("--sql-user", $SqlUser, "--sql-password", $SqlPassword)
            }

            try {
                $compiledResult = Invoke-ProcessWithTimeout -FilePath $resolvedCompiledConverterPath -ArgumentList $compiledArgs -TimeoutSeconds $phaseTimeoutSeconds -PhaseName ("Step 4 fast-quote-convert " + $table)
                $usedCompiledConverter = $true
                $compiledUnresolvedPath = [System.IO.Path]::ChangeExtension($trnPath, ".unresolved.trn")
                if ((Test-Path -LiteralPath $compiledUnresolvedPath) -and ($compiledUnresolvedPath -ne $unresolvedPath)) {
                    Copy-Item -LiteralPath $compiledUnresolvedPath -Destination $unresolvedPath -Force
                }
                if ($phaseTimingPath) {
                    $compiledSummaryLine = $null
                    $compiledTimingLine = $null
                    $compiledCallsLine = $null
                    if ($compiledResult -and $compiledResult.StdOutLines) {
                        foreach ($lnRaw in @($compiledResult.StdOutLines)) {
                            $ln = [string]$lnRaw
                            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
                            if ($ln -like "-- Summary:*") { $compiledSummaryLine = $ln }
                            elseif ($ln -like "-- Timing:*") { $compiledTimingLine = $ln }
                            elseif ($ln -like "-- Live DB Calls:*") { $compiledCallsLine = $ln }
                        }
                    }

                    $summary = [ordered]@{}
                    if ($compiledSummaryLine) {
                        $m = [regex]::Matches($compiledSummaryLine, "([A-Za-z_]+)=([0-9]+)")
                        foreach ($x in $m) {
                            $k = [string]$x.Groups[1].Value
                            $v = [int]$x.Groups[2].Value
                            $summary[$k] = $v
                        }
                    }

                    $timings = [ordered]@{}
                    if ($compiledTimingLine) {
                        $m = [regex]::Matches($compiledTimingLine, "([A-Za-z_]+)=([0-9]+)")
                        foreach ($x in $m) {
                            $k = [string]$x.Groups[1].Value
                            $v = [int]$x.Groups[2].Value
                            $timings[$k] = $v
                        }
                    }

                    $liveCalls = [ordered]@{}
                    if ($compiledCallsLine) {
                        $m = [regex]::Matches($compiledCallsLine, "([A-Za-z_]+)=([0-9]+)")
                        foreach ($x in $m) {
                            $k = [string]$x.Groups[1].Value
                            $v = [int]$x.Groups[2].Value
                            $liveCalls[$k] = $v
                        }
                    }

                    $totalMs = $null
                    if ($timings.Contains("total_run_ms")) { $totalMs = [int]$timings["total_run_ms"] }
                    $timingPayload = [pscustomobject]@{
                        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
                        output_path = $trnPath
                        target_table = $table
                        converter = "fast-quote-convert"
                        timings_ms = [pscustomobject]@{
                            total_ms = $totalMs
                            manifest_read_ms = $(if ($timings.Contains("manifest_read_ms")) { [int]$timings["manifest_read_ms"] } else { $null })
                            total_run_ms = $totalMs
                        }
                        summary = [pscustomobject]$summary
                        live_db_calls = [pscustomobject]$liveCalls
                        converter_stdout = [pscustomobject]@{
                            summary_line = $(if ($compiledSummaryLine) { [string]$compiledSummaryLine } else { $null })
                            timing_line = $(if ($compiledTimingLine) { [string]$compiledTimingLine } else { $null })
                            calls_line = $(if ($compiledCallsLine) { [string]$compiledCallsLine } else { $null })
                        }
                    }
                    $timingPayload | ConvertTo-Json -Depth 6 | Out-File -FilePath $phaseTimingPath -Encoding utf8
                }
            } catch {
                $convertFailed = $true
                $convertFailureMessage = $_.Exception.Message
                Write-Warning ("Compiled converter failed for {0}: {1}" -f $table, $convertFailureMessage)
                if (-not $CompiledConverterFallbackToPs) {
                    throw
                }
            }
        }

        if (-not $usedCompiledConverter) {
            if ($UseCompiledConverter -and -not $canUseCompiledConverter) {
                if (-not (Test-Path -LiteralPath $resolvedCompiledConverterPath)) {
                    Write-Host ("Compiled converter not found at {0}; using PowerShell converter for {1}" -f $resolvedCompiledConverterPath, $table)
                } elseif ($RecoveryProfile -ne "standard") {
                    Write-Host ("Compiled converter is currently enabled only for RecoveryProfile=standard; using PowerShell converter for {0}" -f $table)
                } elseif ([string]::IsNullOrWhiteSpace($metadataForCompiled)) {
                    Write-Host ("Compiled converter requires metadata snapshot path; using PowerShell converter for {0}" -f $table)
                }
            } elseif ($convertFailed -and $CompiledConverterFallbackToPs) {
                Write-Host ("Falling back to PowerShell converter for {0}" -f $table)
            }

            Invoke-ScriptWithTimeout -ScriptPath $convertScript -Params $convertParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName ("Step 4 Convert-HybridToTrn " + $table)
        }

        $appliedCount = 0
        $failedCount = 0
        $batchCount = 0
        if ($effectiveApplyToTarget) {
            $applyParams = @{
                TrnPath = $trnPath
                ServerInstance = $ApplyTargetServerInstance
                Database = $ApplyTargetDatabase
                OutputPath = $applyPath
                StopOnError = $ApplyStopOnError
                WrapInTransaction = $ApplyWrapInTransaction
            }
            if ($SqlUser) {
                $applyParams["SqlUser"] = $SqlUser
                $applyParams["SqlPassword"] = $SqlPassword
            }
            Invoke-ScriptWithTimeout -ScriptPath $applyScript -Params $applyParams -TimeoutSeconds $phaseTimeoutSeconds -PhaseName ("Step 4 Apply-TrnToTarget " + $table)
            $applyObj = Get-Content -LiteralPath $applyPath -Raw | ConvertFrom-Json
            $appliedCount = Get-JsonIntValue -Object $applyObj -Names @("applied_count", "applied_batches")
            $failedCount = Get-JsonIntValue -Object $applyObj -Names @("failed_count", "failed_batches")
            $batchCount = Get-JsonIntValue -Object $applyObj -Names @("batch_count", "total_batches")
        }

        $trnCount = 0
        if (Test-Path -LiteralPath $trnPath) {
            $trnCount = @(
                Select-String -Path $trnPath -Pattern '^--(INSERT|UPDATE|DELETE) \('
            ).Count
        }
        $phaseTimingObj = $null
        if (Test-Path -LiteralPath $phaseTimingPath) {
            try {
                $phaseTimingPayload = Get-Content -LiteralPath $phaseTimingPath -Raw | ConvertFrom-Json
                if ($phaseTimingPayload.PSObject.Properties.Name -contains "timings_ms") {
                    $phaseTimingObj = $phaseTimingPayload.timings_ms
                }
            } catch {}
        }

        $results.Add([pscustomobject]@{
            table = $table
            trn_statements = [int]$trnCount
            apply_batch_count = [int]$batchCount
            apply_applied_count = [int]$appliedCount
            apply_failed_count = [int]$failedCount
            trn_path = $trnPath
            apply_path = $applyPath
            phase_timing_path = $phaseTimingPath
            phase_timings_ms = $phaseTimingObj
            recovery_profile = $RecoveryProfile
            edge_allow_live_fallback = $EdgeAllowLiveFallback
            edge_live_lookup_include_binary_payload = $EdgeLiveLookupIncludeBinaryPayload
            edge_offline_cache_mode = if ($RecoveryProfile -eq "edge_profile") { $effectiveEdgeOfflineCacheMode } else { $null }
            offline_row_cache_path = if ($RecoveryProfile -eq "edge_profile" -and $effectiveEdgeOfflineCacheMode -eq "build") { $offlineCachePath } else { $null }
            offline_diag_path = if ($RecoveryProfile -eq "edge_profile" -and $effectiveEdgeOfflineCacheMode -eq "build") { $offlineDiagPath } else { $null }
        }) | Out-Null
    }
    $step4Sw.Stop()
    $step4Ms = [int]$step4Sw.ElapsedMilliseconds
    Write-Host ("Step 4 timing: {0} ms" -f $step4Ms)

    $savedLastLsn = if (Is-ValidLsn -Lsn $scanEndLsn) {
        $scanEndLsn
    } elseif (Is-ValidLsn -Lsn $maxManifestLsn) {
        $maxManifestLsn
    } else {
        $effectiveStartLsn
    }

    $newState = [pscustomobject]@{
        version                       = 1
        updated_at_utc                = (Get-Date).ToUniversalTime().ToString("o")
        bootstrap_only                = $false
        live_server_instance          = $LiveServerInstance
        live_database                 = $LiveDatabase
        log_reader_function           = $LogReaderFunction
        tables_key                    = $tablesKey
        filters_key                   = $filtersKey
        source_signature              = $sourceSignature
        last_lsn                      = $savedLastLsn
        last_commit_time              = $maxManifestCommitTime
        lsn_reset_detected            = $lsnResetDetected
        start_lsn_input               = $StartLsn
        start_lsn_used                = $effectiveStartLsn
        start_lsn_before_reset        = $effectiveStartLsnPreReset
        start_lsn_fallback_used       = $startLsnFallbackUsed
        latest_live_lsn               = $latestLiveLsn
        operations                    = @("DMLALL")
        spids                         = if ($Spids) { ,@($Spids) } else { ,@() }
        users                         = if ($Users) { ,@($Users) } else { ,@() }
        exclude_users                 = if ($ExcludeUsers) { ,@($ExcludeUsers) } else { ,@() }
        last_manifest_path            = $manifestPath
        last_hybrid_path              = $hybridPath
        last_scan_end_lsn             = $scanEndLsn
        last_manifest_record_count    = [int]$manifestRecordCount
        last_manifest_transaction_count = [int]$manifestTransactionCount
        last_session                  = $SessionName
        active_shadow_id             = if ($SkipShadowCleanup -and -not [string]::IsNullOrWhiteSpace($shadowId)) { $shadowId } else { $null }
        active_shadow_device         = if ($SkipShadowCleanup -and -not [string]::IsNullOrWhiteSpace($shadowDevice)) { $shadowDevice } else { $null }
        active_shadow_session        = if ($SkipShadowCleanup -and -not [string]::IsNullOrWhiteSpace($shadowId)) { $SessionName } else { $null }
        active_shadow_active         = [bool]($SkipShadowCleanup -and -not [string]::IsNullOrWhiteSpace($shadowId))
        active_shadow_updated_utc    = (Get-Date).ToUniversalTime().ToString("o")
    }
    Save-State -Path $StatePath -State $newState
    if (Is-ValidLsn -Lsn $savedLastLsn) {
        Write-Host ("Saved state last_lsn={0}" -f $savedLastLsn)
    } else {
        Write-Host "Saved state without a valid last_lsn (no manifest LSN available)."
    }

    Write-Host "Step 5/5: Write session summary"
    $step5Sw = [System.Diagnostics.Stopwatch]::StartNew()
    $summary = [pscustomobject]@{
        session = $SessionName
        performance_profile = $PerformanceProfile
        raw_match_mode = $effectiveRawMatchMode
        max_phase_minutes = $MaxPhaseMinutes
        benchmark_mode = $BenchmarkMode
        recovery_profile = $RecoveryProfile
        edge_allow_live_fallback = $EdgeAllowLiveFallback
        edge_live_lookup_include_binary_payload = $EdgeLiveLookupIncludeBinaryPayload
        edge_offline_cache_mode = $effectiveEdgeOfflineCacheMode
        no_op_short_circuit = $false
        heuristics_profile = $effectiveHeuristicsProfile
        max_rowlog_pairs = $effectiveMaxRowLogPairs
        decode_disabled = $effectiveDisableDecode
        export_before_after = $effectiveExportBeforeAfter
        export_row_history = $effectiveExportRowHistory
        adaptive_fast_replace_non_high_confidence = $effectiveAdaptiveFastReplaceNonHighConfidence
        apply_to_target_effective = $effectiveApplyToTarget
        chunk_index_enabled = $EnableChunkIndex
        chunk_index_path = $ChunkIndexPath
        descriptor_index_enabled = $EnableDescriptorIndex
        descriptor_index_path = $DescriptorIndexPath
        descriptor_index_rebuild = $RebuildDescriptorIndex
        chunk_size_mb = $ChunkSizeMB
        chunk_overlap_bytes = $ChunkOverlapBytes
        chunk_select_max_percent = $ChunkSelectMaxPercent
        chunk_select_strategy = $ChunkSelectStrategy
        recent_tail_chunk_count = $RecentTailChunkCount
        prepare_raw_ldf_index = $PrepareRawLdfIndex
        prepare_raw_ldf_index_mode = $PrepareRawLdfIndexMode
        auto_widen_recent_tail = $AutoWidenRecentTail
        auto_widen_max_attempts = $AutoWidenMaxAttempts
        source_drive = $SourceDrive
        log_reader_function = $LogReaderFunction
        shadow_id = $shadowId
        shadow_device = $shadowDevice
        ldf_path = $ldfPath
        ldf_path_shadow = $ldfPathShadow
        use_shadow_ldf_copy = $UseShadowLdfCopy
        shadow_ldf_copy_path = $ShadowLdfCopyPath
        mdf_path = if ($RecoveryProfile -eq "edge_profile") { $mdfPath } else { $null }
        manifest_path = $manifestPath
        hybrid_path = $hybridPath
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        start_lsn_input = $StartLsn
        start_lsn_used = $effectiveStartLsn
        start_lsn_before_reset = $effectiveStartLsnPreReset
        start_lsn_fallback_used = $startLsnFallbackUsed
        lsn_reset_detected = $lsnResetDetected
        latest_live_lsn = $latestLiveLsn
        scan_end_lsn = $scanEndLsn
        max_manifest_lsn = $maxManifestLsn
        max_manifest_commit_time = $maxManifestCommitTime
        manifest_record_count = [int]$manifestRecordCount
        manifest_transaction_count = [int]$manifestTransactionCount
        state_path = $StatePath
        state_last_lsn_saved = $savedLastLsn
        bootstrap_first_run = $BootstrapFirstRun
        bootstrap_performed = $bootstrapPerformed
        filters_key = $filtersKey
        wrapper_timings_ms = [pscustomobject]@{
            startup_pre_step0_ms = [int]$startupPreStep0Ms
            startup_state_load_ms = [int]$startupStateLoadMs
            startup_shadow_reconcile_ms = [int]$startupShadowReconcileMs
            startup_lsn_precheck_ms = [int]$startupLsnPrecheckMs
            startup_bootstrap_ms = [int]$startupBootstrapMs
            step1_shadow_ms = [int]$step1Ms
            step2_manifest_ms = [int]$step2Ms
            step25_prepare_index_ms = [int]$step25Ms
            step3_raw_match_ms = [int]$step3Ms
            step4_convert_apply_ms = [int]$step4Ms
            step5_summary_ms = 0
            total_pipeline_ms = 0
            total_with_startup_ms = 0
            reused_shadow_device = (-not [string]::IsNullOrWhiteSpace($ReuseShadowDevice))
        }
        raw_match_attempts = @($rawMatchAttempts.ToArray())
        results = @($results.ToArray())
    }
    $step5Sw.Stop()
    $step5Ms = [int]$step5Sw.ElapsedMilliseconds
    $pipelineSw.Stop()
    $summary.wrapper_timings_ms.step5_summary_ms = [int]$step5Ms
    $summary.wrapper_timings_ms.total_pipeline_ms = [int]$pipelineSw.ElapsedMilliseconds
    $summary.wrapper_timings_ms.total_with_startup_ms = [int]($startupPreStep0Ms + $summary.wrapper_timings_ms.total_pipeline_ms)
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    @($results.ToArray()) | Format-Table -AutoSize
    Write-Host ("Summary written: {0}" -f (Resolve-Path -LiteralPath $summaryPath))
    Write-Host ("Wrapper timing total: pipeline={0} ms, with_startup={1} ms (startup={2}, step1={3}, step2={4}, step2.5={5}, step3={6}, step4={7}, step5={8})" -f `
        $summary.wrapper_timings_ms.total_pipeline_ms, $summary.wrapper_timings_ms.total_with_startup_ms, $startupPreStep0Ms, $step1Ms, $step2Ms, $step25Ms, $step3Ms, $step4Ms, $step5Ms)
}
finally {
    if ($shadowId) {
        if ($SkipShadowCleanup) {
            Write-Host ("Cleanup skipped for shadow copy {0} (SkipShadowCleanup=true)." -f $shadowId)
        } else {
            Write-Host ("Cleanup: deleting shadow copy {0}" -f $shadowId)
            $deletedNow = Remove-ShadowCopyById -ShadowId $shadowId
            if (-not $deletedNow) {
                Write-Warning ("Cleanup failed for shadow copy {0}" -f $shadowId)
            }
            Update-ShadowTrackingInState -Path $StatePath -ShadowId $null -ShadowDevice $null -Active $false -Session $SessionName
        }
    }
}
