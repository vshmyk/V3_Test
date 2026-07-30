param(
    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [string]$SourceDrive = "E:",

    [Parameter()]
    # Deprecated: no longer used. Shadow access now uses direct \\?\GLOBALROOT path.
    [string]$ShadowLinkPath = "E:\DATA_Shadow",

    [Parameter()]
    [string]$SnapshotDataPath = "DATA\Oasis",

    [Parameter()]
    [string]$LdfName = "OASIS_MH_log.ldf",

    [Parameter()]
    [string]$CopiedLdfPath = "E:\AOexpress\Logs\OASIS_MH_log_shadow.ldf",

    [Parameter()]
    [ValidateSet("direct", "copy")]
    [string]$LdfReadMode = "direct",

    [Parameter()]
    [string]$LiveServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$LiveDatabase = "OASIS_MH",

    [Parameter()]
    [ValidateSet("fn_dblog", "fn_full_dblog", "sys.fn_dblog", "sys.fn_full_dblog", "master.sys.fn_dblog", "master.sys.fn_full_dblog")]
    [string]$LogReaderFunction = "fn_dblog",

    [Parameter()]
    [string]$MetadataServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$MetadataDatabase = "OASIS_MH",

    [Parameter()]
    [string]$MetadataSnapshotPath,

    [Parameter()]
    [string[]]$Tables = @("oasis.CHSC_POLINE", "oasis.CHSC_PO"),

    [Parameter()]
    [string[]]$Operations = @("DMLALL"),

    [Parameter()]
    [int[]]$Spids,

    [Parameter()]
    [string[]]$Users,

    [Parameter()]
    [string[]]$ExcludeUsers,

    [Parameter()]
    [int]$WindowMinutes = 360,

    [Parameter()]
    [string]$StartLsn,

    [Parameter()]
    [string]$StatePath = ".\output\HybridLastOffset.json",

    [Parameter()]
    [string]$LockFilePath = ".\output\HybridFlow.lock",

    [Parameter()]
    [string]$MetricsPath = ".\output\HybridRunMetrics.json",

    [Parameter()]
    [string]$ManifestPath = ".\output\live-dml-manifest.json",

    [Parameter()]
    [string]$HybridMatchesPath = ".\output\raw-ldf-hybrid-matches.json",

    [Parameter()]
    [string]$HybridTrnPath = ".\output\mh.trn",

    [Parameter()]
    [string]$HybridUnresolvedTrnPath = ".\output\mh.unresolved.trn",

    [Parameter()]
    [string]$HybridQuarantineTrnPath = ".\output\mh.quarantine.trn",

    [Parameter()]
    [string]$UndoTrnPath = ".\output\mh.undo.trn",

    [Parameter()]
    [string]$BeforeAfterJsonPath = ".\output\mh.before_after.json",

    [Parameter()]
    [bool]$OutputSuccessfulOnly = $true,

    [Parameter()]
    [bool]$GenerateUndo = $true,

    [Parameter()]
    [bool]$ExportBeforeAfter = $true,

    [Parameter()]
    [bool]$ApplyToTarget = $false,

    [Parameter()]
    [string]$ApplyTargetServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$ApplyTargetDatabase = "OASIS_MH",

    [Parameter()]
    [string]$ApplyTargetSqlUser,

    [Parameter()]
    [string]$ApplyTargetSqlPassword,

    [Parameter()]
    [string]$ApplyResultPath = ".\output\mh.apply.json",

    [Parameter()]
    [bool]$ApplyStopOnError = $true,

    [Parameter()]
    [bool]$ApplyWrapInTransaction = $false,

    [Parameter()]
    [string]$TargetTable = "oasis.CHSC_POLINE",

    [Parameter()]
    [ValidateSet("update", "replace", "adaptive")]
    [string]$UpdateMode = "adaptive",

    [Parameter()]
    [ValidateSet("off", "strict")]
    [string]$ApplySafetyMode = "strict",

    [Parameter()]
    [bool]$BenchmarkMode = $false,

    [Parameter()]
    [bool]$AdaptiveFastReplaceNonHighConfidence = $false,

    [Parameter()]
    [int]$TailBytes = 0,

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword,

    [Parameter()]
    [switch]$KeepShadowAndLink
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($ConfigPath) {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "ConfigPath not found: $ConfigPath"
    }
    $configRaw = Get-Content -LiteralPath $ConfigPath -Raw
    $config = if ([string]::IsNullOrWhiteSpace($configRaw)) { $null } else { $configRaw | ConvertFrom-Json }
    if ($null -ne $config) {
        $configMap = @{
            SourceDrive          = "source_drive"
            SnapshotDataPath     = "snapshot_data_path"
            LdfName              = "ldf_name"
            CopiedLdfPath        = "copied_ldf_path"
            LdfReadMode          = "ldf_read_mode"
            LiveServerInstance   = "live_server_instance"
            LiveDatabase         = "live_database"
            LogReaderFunction    = "log_reader_function"
            MetadataServerInstance = "metadata_server_instance"
            MetadataDatabase     = "metadata_database"
            MetadataSnapshotPath = "metadata_snapshot_path"
            Tables               = "tables"
            Operations           = "operations"
            Spids                = "spids"
            Users                = "users"
            ExcludeUsers         = "exclude_users"
            WindowMinutes        = "window_minutes"
            StartLsn             = "start_lsn"
            StatePath            = "state_path"
            LockFilePath         = "lock_file_path"
            MetricsPath          = "metrics_path"
            ManifestPath         = "manifest_path"
            HybridMatchesPath    = "hybrid_matches_path"
            HybridTrnPath        = "hybrid_trn_path"
            HybridUnresolvedTrnPath = "hybrid_unresolved_trn_path"
            HybridQuarantineTrnPath = "hybrid_quarantine_trn_path"
            UndoTrnPath          = "undo_trn_path"
            BeforeAfterJsonPath  = "before_after_json_path"
            OutputSuccessfulOnly = "output_successful_only"
            GenerateUndo         = "generate_undo"
            ExportBeforeAfter    = "export_before_after"
            ApplyToTarget        = "apply_to_target"
            ApplyTargetServerInstance = "apply_target_server_instance"
            ApplyTargetDatabase  = "apply_target_database"
            ApplyTargetSqlUser   = "apply_target_sql_user"
            ApplyTargetSqlPassword = "apply_target_sql_password"
            ApplyResultPath      = "apply_result_path"
            ApplyStopOnError     = "apply_stop_on_error"
            ApplyWrapInTransaction = "apply_wrap_in_transaction"
            TargetTable          = "target_table"
            UpdateMode           = "update_mode"
            ApplySafetyMode      = "apply_safety_mode"
            BenchmarkMode        = "benchmark_mode"
            AdaptiveFastReplaceNonHighConfidence = "adaptive_fast_replace_non_high_confidence"
            TailBytes            = "tail_bytes"
            SqlUser              = "sql_user"
            SqlPassword          = "sql_password"
        }

        foreach ($paramName in $configMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) { continue }
            $prop = $configMap[$paramName]
            if ($config.PSObject.Properties.Name -contains $prop) {
                Set-Variable -Name $paramName -Value $config.$prop -Scope Script
            }
        }
    }
}

if ($WindowMinutes -lt 1) {
    throw "WindowMinutes must be > 0."
}

if ($StartLsn -and ($StartLsn -notmatch "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")) {
    throw "StartLsn format is invalid. Expected 00000025:0000F6C0:0006"
}

if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}
if ($ApplyTargetSqlUser -and -not $ApplyTargetSqlPassword) {
    throw "ApplyTargetSqlPassword is required when ApplyTargetSqlUser is provided."
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Is-ValidLsn {
    param([AllowNull()][string]$Lsn)
    return (-not [string]::IsNullOrWhiteSpace($Lsn)) -and ($Lsn -match "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$")
}

function Get-TablesKey {
    param([string[]]$InputTables)
    if (-not $InputTables) { return "" }
    $normalized = @($InputTables | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Sort-Object -Unique)
    return ($normalized -join "|")
}

function Get-FiltersKey {
    param(
        [string[]]$InputOperations,
        [int[]]$InputSpids,
        [string[]]$InputUsers,
        [string[]]$InputExcludeUsers
    )

    $ops = if ($InputOperations) { @($InputOperations | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Sort-Object -Unique) } else { @() }
    $spids = if ($InputSpids) { @($InputSpids | ForEach-Object { [int]$_ } | Sort-Object -Unique) } else { @() }
    $users = if ($InputUsers) { @($InputUsers | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) } else { @() }
    $excludeUsers = if ($InputExcludeUsers) { @($InputExcludeUsers | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) } else { @() }

    return ("ops={0};spids={1};users={2};exclude={3}" -f ($ops -join ","), ($spids -join ","), ($users -join ","), ($excludeUsers -join ","))
}

function Load-State {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-Warning ("State file could not be parsed and will be ignored: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Save-State {
    param(
        [string]$Path,
        [psobject]$State
    )
    Ensure-ParentDirectory -Path $Path
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
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
    param([string]$Sql)

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

function Compare-Lsn {
    param(
        [string]$A,
        [string]$B
    )

    if (-not (Is-ValidLsn -Lsn $A) -or -not (Is-ValidLsn -Lsn $B)) {
        throw "Compare-Lsn requires valid LSN inputs."
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

function Get-JsonIntValue {
    param(
        [psobject]$Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) { return 0 }
    if (-not ($Object.PSObject.Properties.Name -contains $PropertyName)) { return 0 }
    $v = $Object.$PropertyName
    if ($null -eq $v -or $v -is [System.DBNull]) { return 0 }
    return [int]$v
}

function Get-MaxManifestLsn {
    param([object[]]$ManifestRecords)
    if (-not $ManifestRecords) { return $null }
    $lsns = @($ManifestRecords | ForEach-Object { [string]$_.current_lsn } | Where-Object { Is-ValidLsn -Lsn $_ } | Sort-Object)
    if ($lsns.Count -eq 0) { return $null }
    return $lsns[-1]
}

function Remove-LinkPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        if ($item.PSIsContainer) {
            cmd.exe /c "rmdir `"$Path`"" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to remove symbolic link $Path"
            }
        } else {
            Remove-Item -LiteralPath $Path -Force
        }
        return
    }

    if ($item.PSIsContainer) {
        $children = Get-ChildItem -LiteralPath $Path -Force
        if ($children.Count -gt 0) {
            throw "Path $Path exists and is not an empty symbolic link. Refusing to delete."
        }
    }

    Remove-Item -LiteralPath $Path -Force
}

function Resolve-ShadowCopyDetails {
    param([string[]]$CreateShadowOutput)
    $shadowIdMatch = ($CreateShadowOutput | Select-String -Pattern "Shadow Copy ID:\s*(\{[0-9a-fA-F-]+\})").Matches
    $shadowVolMatch = ($CreateShadowOutput | Select-String -Pattern "Shadow Copy Volume Name:\s*(\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy\d+)").Matches
    if ($shadowIdMatch.Count -eq 0 -or $shadowVolMatch.Count -eq 0) {
        throw ("Could not parse shadow copy details. Output:`n{0}" -f ($CreateShadowOutput -join [Environment]::NewLine))
    }

    return [pscustomobject]@{
        ShadowId = $shadowIdMatch[0].Groups[1].Value
        ShadowVolume = $shadowVolMatch[0].Groups[1].Value + "\"
    }
}

$shadowId = $null
$lockStream = $null
$tablesKey = Get-TablesKey -InputTables $Tables
$filtersKey = Get-FiltersKey -InputOperations $Operations -InputSpids $Spids -InputUsers $Users -InputExcludeUsers $ExcludeUsers
$sourceSignatureBase = ("{0}|{1}|{2}" -f $SourceDrive.ToUpperInvariant(), $SnapshotDataPath.ToUpperInvariant(), $LdfName.ToUpperInvariant())
$sourceSignature = ("{0}|{1}" -f $sourceSignatureBase, $LdfReadMode.ToUpperInvariant())
$effectiveStartLsn = $StartLsn
$effectiveStartLsnPreReset = $effectiveStartLsn
$latestLiveLsn = $null
$lsnResetDetected = $false
$effectiveApplyToTarget = $ApplyToTarget
$effectiveGenerateUndo = $GenerateUndo
$effectiveExportBeforeAfter = $ExportBeforeAfter
$effectiveApplySafetyMode = $ApplySafetyMode

$manifestRecordCount = 0
$manifestTransactionCount = 0
$hybridMatchedCount = 0
$hybridUnmatchedCount = 0
$trnStatementCount = 0
$trnUnresolvedStatementCount = 0
$trnQuarantineStatementCount = 0
$undoStatementCount = 0
$beforeAfterRecordCount = 0
$applyBatchCount = 0
$applyFailedBatchCount = 0
$savedLastLsn = $null
$convertPhaseTimingPath = [System.IO.Path]::ChangeExtension($HybridTrnPath, ".phase_timings.json")
$convertPhaseTimings = $null
$noOpShortCircuit = $false

$runStartUtc = (Get-Date).ToUniversalTime()
$runWatch = [System.Diagnostics.Stopwatch]::StartNew()
$runSucceeded = $false
$runError = $null
$stageShadowMs = 0
$stageCopyMs = 0
$stageManifestMs = 0
$stageHybridMs = 0
$stageConvertMs = 0
$stageApplyMs = 0
$ldfPathForProcessing = $null

if ($BenchmarkMode) {
    # Hard isolation mode for performance testing only.
    $effectiveApplyToTarget = $false
    $effectiveGenerateUndo = $false
    $effectiveExportBeforeAfter = $false
    $effectiveApplySafetyMode = "off"
    Write-Host "BenchmarkMode active: apply/undo/before_after disabled and apply_safety=off."
}

if (-not $effectiveStartLsn) {
    $state = Load-State -Path $StatePath
    if ($state) {
        $stateServer = [string]$state.live_server_instance
        $stateDb = [string]$state.live_database
        $stateTablesKey = [string]$state.tables_key
        $stateFiltersKey = $null
        if ($state.PSObject.Properties.Name -contains "filters_key") {
            $stateFiltersKey = [string]$state.filters_key
        }
        $stateSource = [string]$state.source_signature
        $stateLsn = [string]$state.last_lsn
        $sourceCompatible = $false
        if ($stateSource.Equals($sourceSignature, [System.StringComparison]::OrdinalIgnoreCase)) {
            $sourceCompatible = $true
        } elseif ($stateSource.Equals($sourceSignatureBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            # Backward compatibility with pre-mode signatures.
            $sourceCompatible = $true
        } elseif ($stateSource.StartsWith($sourceSignatureBase + "|", [System.StringComparison]::OrdinalIgnoreCase)) {
            # Allow copy/direct mode switch without forcing historical backfill.
            $sourceCompatible = $true
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
            Write-Host "Using incremental StartLSN from hybrid state: $effectiveStartLsn"
        } else {
            Write-Host "Hybrid state file found but not reusable for current scope; running window-based manifest scan."
        }
    } else {
        Write-Host "Hybrid state file not found; running window-based manifest scan."
    }
}
$effectiveStartLsnPreReset = $effectiveStartLsn

if ($effectiveStartLsn) {
    try {
        $latestLiveCandidate = Invoke-LiveScalar -Sql @"
SET NOCOUNT ON;
SELECT TOP (1) [Current LSN]
FROM $LogReaderFunction(NULL, NULL)
ORDER BY [Current LSN] DESC;
"@
        if ($latestLiveCandidate -and $latestLiveCandidate -isnot [System.DBNull]) {
            $latestLiveLsn = [string]$latestLiveCandidate
        }
    } catch {
        Write-Warning ("Could not pre-check current live LSN: {0}" -f $_.Exception.Message)
    }

    if ((Is-ValidLsn -Lsn $effectiveStartLsn) -and (Is-ValidLsn -Lsn $latestLiveLsn)) {
        $lsnCmp = Compare-Lsn -A $latestLiveLsn -B $effectiveStartLsn
        if ($lsnCmp -lt 0) {
            $lsnResetDetected = $true
            Write-Warning ("Saved StartLSN {0} is ahead of current live LSN {1}; likely log truncation/reset. Falling back to window scan." -f $effectiveStartLsn, $latestLiveLsn)
            $effectiveStartLsn = $null
        } elseif ($lsnCmp -eq 0) {
            $noOpShortCircuit = $true
            Write-Host ("No-op short-circuit: latest_live_lsn equals start_lsn ({0}). Skipping shadow copy and offline processing." -f $latestLiveLsn)
        }
    }
}

if ($noOpShortCircuit) {
    $savedLastLsn = $effectiveStartLsn
    $runSucceeded = $true
    $runWatch.Stop()
    try {
        $metricsNoOp = [pscustomobject]@{
            version                 = 1
            run_started_utc         = $runStartUtc.ToString("o")
            run_finished_utc        = (Get-Date).ToUniversalTime().ToString("o")
            duration_ms             = [int]$runWatch.ElapsedMilliseconds
            success                 = $true
            error                   = $null
            no_op_short_circuit     = $true
            source_drive            = $SourceDrive
            snapshot_data_path      = $SnapshotDataPath
            ldf_name                = $LdfName
            ldf_read_mode           = $LdfReadMode
            config_path             = $ConfigPath
            live_server_instance    = $LiveServerInstance
            live_database           = $LiveDatabase
            log_reader_function     = $LogReaderFunction
            tables                  = $Tables
            tables_key              = $tablesKey
            operations              = $Operations
            spids                   = $Spids
            users                   = $Users
            exclude_users           = $ExcludeUsers
            filters_key             = $filtersKey
            source_signature        = $sourceSignature
            state_path              = $StatePath
            start_lsn_input         = $StartLsn
            start_lsn_selected      = $effectiveStartLsnPreReset
            start_lsn_used          = $effectiveStartLsn
            latest_live_lsn         = $latestLiveLsn
            lsn_reset_detected      = $lsnResetDetected
            saved_last_lsn          = $savedLastLsn
            apply_to_target         = $effectiveApplyToTarget
            apply_safety_mode       = $effectiveApplySafetyMode
            benchmark_mode          = $BenchmarkMode
            generate_undo           = $effectiveGenerateUndo
            export_before_after     = $effectiveExportBeforeAfter
            note                    = "No new transactions since saved last_lsn; skipped shadow copy and offline processing."
            timings_ms              = [pscustomobject]@{
                shadow_create = 0
                ldf_copy      = 0
                manifest      = 0
                hybrid_match  = 0
                convert_trn   = 0
                apply_target  = 0
            }
        }
        Ensure-ParentDirectory -Path $MetricsPath
        $metricsNoOp | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MetricsPath -Encoding UTF8
        Write-Host ("Metrics written: {0}" -f (Resolve-Path -LiteralPath $MetricsPath))
    } catch {
        Write-Warning ("No-op metrics write failed: {0}" -f $_.Exception.Message)
    }
    return
}

Ensure-ParentDirectory -Path $LockFilePath
try {
    $lockStream = New-Object System.IO.FileStream($LockFilePath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $lockText = [Text.Encoding]::UTF8.GetBytes((@{
        pid = $PID
        started_at_utc = $runStartUtc.ToString("o")
        script = "Run-HybridLdfCopyFromShadow.ps1"
    } | ConvertTo-Json -Compress))
    $lockStream.SetLength(0)
    $lockStream.Write($lockText, 0, $lockText.Length)
    $lockStream.Flush()
} catch [System.IO.IOException] {
    throw "Hybrid flow lock is already present. Another run may still be active: $LockFilePath"
}

try {
    Write-Host "Step 1/5: Create shadow copy for $SourceDrive"
    $swShadow = [System.Diagnostics.Stopwatch]::StartNew()
    $createOut = & vssadmin create shadow "/for=$SourceDrive" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("Failed to create shadow copy. Output:`n{0}" -f ($createOut -join [Environment]::NewLine))
    }
    $shadow = Resolve-ShadowCopyDetails -CreateShadowOutput $createOut
    $shadowId = $shadow.ShadowId
    $swShadow.Stop()
    $stageShadowMs = [int]$swShadow.ElapsedMilliseconds

    $sourceRoot = Join-Path -Path $shadow.ShadowVolume -ChildPath $SnapshotDataPath
    $sourceLdfPath = Join-Path -Path $sourceRoot -ChildPath $LdfName
    if (-not (Test-Path -LiteralPath $sourceLdfPath)) {
        throw "Source LDF not found in shadow copy: $sourceLdfPath"
    }

    if ($LdfReadMode -eq "direct") {
        Write-Host "Step 2/5: Use shadow LDF directly (no copy)"
        $ldfPathForProcessing = $sourceLdfPath
        $stageCopyMs = 0
    } else {
        Write-Host "Step 2/5: Copy LDF to writable location $CopiedLdfPath"
        $swCopy = [System.Diagnostics.Stopwatch]::StartNew()
        Ensure-ParentDirectory -Path $CopiedLdfPath
        Copy-Item -LiteralPath $sourceLdfPath -Destination $CopiedLdfPath -Force
        $swCopy.Stop()
        $stageCopyMs = [int]$swCopy.ElapsedMilliseconds
        $ldfPathForProcessing = $CopiedLdfPath
    }

    Write-Host "Step 3/5: Build live committed DML manifest from $LiveServerInstance/$LiveDatabase"
    $swManifest = [System.Diagnostics.Stopwatch]::StartNew()
    $manifestScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-LiveCommittedDmlManifest.ps1"
    if (-not (Test-Path -LiteralPath $manifestScript)) {
        throw "Manifest script not found: $manifestScript"
    }
    $manifestParams = @{
        ServerInstance = $LiveServerInstance
        Database = $LiveDatabase
        LogReaderFunction = $LogReaderFunction
        Tables = $Tables
        Operations = $Operations
        WindowMinutes = $WindowMinutes
        OutputPath = $ManifestPath
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
    & $manifestScript @manifestParams

    $manifestObj = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $manifestRecordCount = Get-JsonIntValue -Object $manifestObj -PropertyName "record_count"
    $manifestTransactionCount = Get-JsonIntValue -Object $manifestObj -PropertyName "transaction_count"
    $scanEndLsn = $null
    if ($manifestObj.PSObject.Properties.Name -contains "scan_end_lsn") {
        $scanEndLsn = [string]$manifestObj.scan_end_lsn
    }
    $maxManifestLsn = Get-MaxManifestLsn -ManifestRecords @($manifestObj.records)
    $nextLsn = if (Is-ValidLsn -Lsn $scanEndLsn) { $scanEndLsn } elseif (Is-ValidLsn -Lsn $maxManifestLsn) { $maxManifestLsn } else { $effectiveStartLsn }
    $savedLastLsn = $nextLsn
    $newState = [pscustomobject]@{
        version                    = 1
        updated_at_utc             = (Get-Date).ToUniversalTime().ToString("o")
        live_server_instance       = $LiveServerInstance
        live_database              = $LiveDatabase
        log_reader_function        = $LogReaderFunction
        tables_key                 = $tablesKey
        filters_key                = $filtersKey
        source_signature           = $sourceSignature
        last_lsn                   = $nextLsn
        lsn_reset_detected         = $lsnResetDetected
        effective_start_lsn        = $effectiveStartLsn
        start_lsn_before_reset     = $effectiveStartLsnPreReset
        latest_live_lsn            = $latestLiveLsn
        operations                 = if ($Operations) { ,@($Operations) } else { ,@() }
        spids                      = if ($Spids) { ,@($Spids) } else { ,@() }
        users                      = if ($Users) { ,@($Users) } else { ,@() }
        exclude_users              = if ($ExcludeUsers) { ,@($ExcludeUsers) } else { ,@() }
        last_manifest_collected_at = [string]$manifestObj.collected_at_utc
        last_manifest_record_count = [int]$manifestObj.record_count
        last_scan_end_lsn          = $scanEndLsn
    }
    Save-State -Path $StatePath -State $newState
    if ($nextLsn) {
        Write-Host "Saved hybrid state with last_lsn=$nextLsn"
    } else {
        Write-Host "Saved hybrid state; no last_lsn was available from this run."
    }
    $swManifest.Stop()
    $stageManifestMs = [int]$swManifest.ElapsedMilliseconds

    Write-Host "Step 4/5: Match offline LDF against live manifest"
    $swHybrid = [System.Diagnostics.Stopwatch]::StartNew()
    $hybridScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-RawLdfHybridMatches.ps1"
    if (-not (Test-Path -LiteralPath $hybridScript)) {
        throw "Hybrid script not found: $hybridScript"
    }
    & $hybridScript -LdfPath $ldfPathForProcessing -ManifestPath $ManifestPath -OutputPath $HybridMatchesPath -TailBytes $TailBytes
    $hybridObj = Get-Content -LiteralPath $HybridMatchesPath -Raw | ConvertFrom-Json
    $hybridMatchedCount = Get-JsonIntValue -Object $hybridObj -PropertyName "matched_record_count"
    if ($hybridMatchedCount -eq 0) {
        $hybridMatchedCount = Get-JsonIntValue -Object $hybridObj -PropertyName "matched_count"
    }
    $hybridUnmatchedCount = Get-JsonIntValue -Object $hybridObj -PropertyName "unmatched_record_count"
    if ($hybridUnmatchedCount -eq 0) {
        $hybridUnmatchedCount = Get-JsonIntValue -Object $hybridObj -PropertyName "unmatched_count"
    }
    $swHybrid.Stop()
    $stageHybridMs = [int]$swHybrid.ElapsedMilliseconds

    Write-Host ("Step 5/5: Generate hybrid.trn (successful-only={0})" -f $OutputSuccessfulOnly)
    $swConvert = [System.Diagnostics.Stopwatch]::StartNew()
    $convertScript = Join-Path -Path $PSScriptRoot -ChildPath "Convert-HybridToTrn.ps1"
    if (-not (Test-Path -LiteralPath $convertScript)) {
        throw "Converter script not found: $convertScript"
    }
    $convertParams = @{
        ManifestPath  = $ManifestPath
        HybridPath    = $HybridMatchesPath
        OutputPath    = $HybridTrnPath
        OutputSuccessfulOnly = $OutputSuccessfulOnly
        UnresolvedOutputPath = $HybridUnresolvedTrnPath
        QuarantineOutputPath = $HybridQuarantineTrnPath
        GenerateUndo  = $effectiveGenerateUndo
        UndoOutputPath = $UndoTrnPath
        ExportBeforeAfter = $effectiveExportBeforeAfter
        BeforeAfterJsonPath = $BeforeAfterJsonPath
        TargetTable   = $TargetTable
        UpdateMode    = $UpdateMode
        ApplySafetyMode = $effectiveApplySafetyMode
        PhaseTimingOutputPath = $convertPhaseTimingPath
        AdaptiveFastReplaceNonHighConfidence = $AdaptiveFastReplaceNonHighConfidence
        ServerInstance = $LiveServerInstance
        Database      = $LiveDatabase
        MetadataServerInstance = $MetadataServerInstance
        MetadataDatabase = $MetadataDatabase
        MetadataSnapshotPath = $MetadataSnapshotPath
    }
    if ($SqlUser) {
        $convertParams["SqlUser"] = $SqlUser
        $convertParams["SqlPassword"] = $SqlPassword
    }
    & $convertScript @convertParams
    $swConvert.Stop()
    $stageConvertMs = [int]$swConvert.ElapsedMilliseconds
    if (Test-Path -LiteralPath $convertPhaseTimingPath) {
        try {
            $phasePayload = Get-Content -LiteralPath $convertPhaseTimingPath -Raw | ConvertFrom-Json
            if ($phasePayload.PSObject.Properties.Name -contains "timings_ms") {
                $convertPhaseTimings = $phasePayload.timings_ms
            }
        } catch {
            $convertPhaseTimings = $null
        }
    }

    if (Test-Path -LiteralPath $HybridTrnPath) {
        $firstLine = Get-Content -LiteralPath $HybridTrnPath -TotalCount 1
        if ($firstLine -match "total=(\d+)") {
            $trnStatementCount = [int]$Matches[1]
        } else {
            $trnStatementCount = (Select-String -Path $HybridTrnPath -Pattern '^--(INSERT|UPDATE|DELETE) \(').Count
        }
    }
    if (Test-Path -LiteralPath $HybridUnresolvedTrnPath) {
        $firstUnresolved = Get-Content -LiteralPath $HybridUnresolvedTrnPath -TotalCount 1
        if ($firstUnresolved -match "total=(\d+)") {
            $trnUnresolvedStatementCount = [int]$Matches[1]
        } else {
            $trnUnresolvedStatementCount = (Select-String -Path $HybridUnresolvedTrnPath -Pattern '^--(INSERT|UPDATE|DELETE) \(').Count
        }
    }
    if (Test-Path -LiteralPath $HybridQuarantineTrnPath) {
        $firstQuarantine = Get-Content -LiteralPath $HybridQuarantineTrnPath -TotalCount 1
        if ($firstQuarantine -match "total=(\d+)") {
            $trnQuarantineStatementCount = [int]$Matches[1]
        } else {
            $trnQuarantineStatementCount = (Select-String -Path $HybridQuarantineTrnPath -Pattern '^--(INSERT|UPDATE|DELETE) \(').Count
        }
    }
    if ($effectiveGenerateUndo -and (Test-Path -LiteralPath $UndoTrnPath)) {
        $firstUndo = Get-Content -LiteralPath $UndoTrnPath -TotalCount 1
        if ($firstUndo -match "total=(\d+)") {
            $undoStatementCount = [int]$Matches[1]
        } else {
            $undoStatementCount = (Select-String -Path $UndoTrnPath -Pattern '^--UNDO-(INSERT|UPDATE|DELETE) \(').Count
        }
    }
    if ($effectiveExportBeforeAfter -and (Test-Path -LiteralPath $BeforeAfterJsonPath)) {
        try {
            $beforeAfterObj = Get-Content -LiteralPath $BeforeAfterJsonPath -Raw | ConvertFrom-Json
            $beforeAfterRecordCount = Get-JsonIntValue -Object $beforeAfterObj -PropertyName "record_count"
        } catch {
            $beforeAfterRecordCount = 0
        }
    }

    if ($effectiveApplyToTarget) {
        Write-Host ("Step 6/6: Apply reconstructed TRN to target {0}/{1}" -f $ApplyTargetServerInstance, $ApplyTargetDatabase)
        $swApply = [System.Diagnostics.Stopwatch]::StartNew()
        $applyScript = Join-Path -Path $PSScriptRoot -ChildPath "Apply-TrnToTarget.ps1"
        if (-not (Test-Path -LiteralPath $applyScript)) {
            throw "Apply script not found: $applyScript"
        }
        $applyParams = @{
            TrnPath = $HybridTrnPath
            ServerInstance = $ApplyTargetServerInstance
            Database = $ApplyTargetDatabase
            OutputPath = $ApplyResultPath
            StopOnError = $ApplyStopOnError
            WrapInTransaction = $ApplyWrapInTransaction
        }
        if ($ApplyTargetSqlUser) {
            $applyParams["SqlUser"] = $ApplyTargetSqlUser
            $applyParams["SqlPassword"] = $ApplyTargetSqlPassword
        }
        & $applyScript @applyParams
        $swApply.Stop()
        $stageApplyMs = [int]$swApply.ElapsedMilliseconds

        if (Test-Path -LiteralPath $ApplyResultPath) {
            try {
                $applyObj = Get-Content -LiteralPath $ApplyResultPath -Raw | ConvertFrom-Json
                $applyBatchCount = Get-JsonIntValue -Object $applyObj -PropertyName "applied_batches"
                $applyFailedBatchCount = Get-JsonIntValue -Object $applyObj -PropertyName "failed_batches"
            } catch {
                $applyBatchCount = 0
                $applyFailedBatchCount = 0
            }
        }
    }

    Write-Host ("Completed. LDF source processed: {0}" -f (Resolve-Path -LiteralPath $ldfPathForProcessing))
    $runSucceeded = $true
}
catch {
    $runError = $_.Exception.Message
    throw
}
finally {
    $runWatch.Stop()

    if (-not $KeepShadowAndLink) {
        if ($shadowId) {
            try {
                & vssadmin delete shadows "/Shadow=`"$shadowId`"" /Quiet | Out-Null
            } catch {
                Write-Warning ("Cleanup shadow deletion failed: {0}" -f $_.Exception.Message)
            }
        }
    } else {
        Write-Host "KeepShadowAndLink specified: preserving shadow copy."
    }

    if ($lockStream) {
        try {
            $lockStream.Dispose()
        } catch {}
        try {
            Remove-Item -LiteralPath $LockFilePath -Force
        } catch {
            Write-Warning ("Cleanup lock removal failed: {0}" -f $_.Exception.Message)
        }
    }

    try {
        $metrics = [pscustomobject]@{
            version                 = 1
            run_started_utc         = $runStartUtc.ToString("o")
            run_finished_utc        = (Get-Date).ToUniversalTime().ToString("o")
            duration_ms             = [int]$runWatch.ElapsedMilliseconds
            success                 = $runSucceeded
            error                   = $runError
            no_op_short_circuit     = $false
            source_drive            = $SourceDrive
            snapshot_data_path      = $SnapshotDataPath
            ldf_name                = $LdfName
            ldf_read_mode           = $LdfReadMode
            copied_ldf_path         = $CopiedLdfPath
            processed_ldf_path      = $ldfPathForProcessing
            config_path             = $ConfigPath
            live_server_instance    = $LiveServerInstance
            live_database           = $LiveDatabase
            log_reader_function     = $LogReaderFunction
            metadata_server_instance = $MetadataServerInstance
            metadata_database        = $MetadataDatabase
            metadata_snapshot_path   = $MetadataSnapshotPath
            tables                  = $Tables
            tables_key              = $tablesKey
            operations              = $Operations
            spids                   = $Spids
            users                   = $Users
            exclude_users           = $ExcludeUsers
            filters_key             = $filtersKey
            source_signature        = $sourceSignature
            state_path              = $StatePath
            lock_file_path          = $LockFilePath
            start_lsn_input         = $StartLsn
            start_lsn_selected      = $effectiveStartLsnPreReset
            start_lsn_used          = $effectiveStartLsn
            latest_live_lsn         = $latestLiveLsn
            lsn_reset_detected      = $lsnResetDetected
            saved_last_lsn          = $savedLastLsn
            manifest_path           = $ManifestPath
            hybrid_matches_path     = $HybridMatchesPath
            trn_output_path         = $HybridTrnPath
            trn_unresolved_path     = $HybridUnresolvedTrnPath
            trn_quarantine_path     = $HybridQuarantineTrnPath
            convert_phase_timing_path = $convertPhaseTimingPath
            undo_output_path        = $UndoTrnPath
            before_after_json_path  = $BeforeAfterJsonPath
            apply_to_target         = $effectiveApplyToTarget
            apply_target_server_instance = $ApplyTargetServerInstance
            apply_target_database   = $ApplyTargetDatabase
            apply_result_path       = $ApplyResultPath
            apply_stop_on_error     = $ApplyStopOnError
            apply_wrap_in_transaction = $ApplyWrapInTransaction
            trn_success_only        = $OutputSuccessfulOnly
            apply_safety_mode       = $effectiveApplySafetyMode
            benchmark_mode          = $BenchmarkMode
            generate_undo           = $effectiveGenerateUndo
            export_before_after     = $effectiveExportBeforeAfter
            manifest_record_count   = $manifestRecordCount
            manifest_transaction_count = $manifestTransactionCount
            hybrid_matched_count    = $hybridMatchedCount
            hybrid_unmatched_count  = $hybridUnmatchedCount
            trn_statement_count     = $trnStatementCount
            trn_unresolved_count    = $trnUnresolvedStatementCount
            trn_quarantine_count    = $trnQuarantineStatementCount
            undo_statement_count    = $undoStatementCount
            before_after_record_count = $beforeAfterRecordCount
            apply_batch_count       = $applyBatchCount
            apply_failed_batch_count = $applyFailedBatchCount
            convert_phase_timings_ms = $convertPhaseTimings
            timings_ms              = [pscustomobject]@{
                shadow_create = $stageShadowMs
                ldf_copy      = $stageCopyMs
                manifest      = $stageManifestMs
                hybrid_match  = $stageHybridMs
                convert_trn   = $stageConvertMs
                apply_target  = $stageApplyMs
            }
        }
        Ensure-ParentDirectory -Path $MetricsPath
        $metrics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $MetricsPath -Encoding UTF8
    } catch {
        Write-Warning ("Metrics write failed: {0}" -f $_.Exception.Message)
    }
}
