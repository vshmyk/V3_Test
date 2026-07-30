param(
    [Parameter()]
    [string]$TrnPath = ".\output\mh.trn",

    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$Database = "OASIS_MH",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword,

    [Parameter()]
    [string]$OutputPath = ".\output\mh.apply.json",

    [Parameter()]
    [bool]$StopOnError = $true,

    [Parameter()]
    [bool]$WrapInTransaction = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TrnPath)) {
    throw "TrnPath not found: $TrnPath"
}
if ($SqlUser -and -not $SqlPassword) {
    throw "SqlPassword is required when SqlUser is provided."
}

function New-ConnectionString {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $ServerInstance
    $builder["Initial Catalog"] = $Database
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

function Split-Batches {
    param([string]$ScriptText)

    $lines = $ScriptText -split "`r?`n"
    $batches = New-Object System.Collections.Generic.List[string]
    $cur = New-Object System.Collections.Generic.List[string]

    foreach ($ln in $lines) {
        if ($ln.Trim().ToUpperInvariant() -eq "GO") {
            $txt = ($cur -join [Environment]::NewLine).Trim()
            if (-not [string]::IsNullOrWhiteSpace($txt)) {
                $batches.Add($txt)
            }
            $cur.Clear()
            continue
        }
        $cur.Add($ln)
    }

    $tail = ($cur -join [Environment]::NewLine).Trim()
    if (-not [string]::IsNullOrWhiteSpace($tail)) {
        $batches.Add($tail)
    }

    return @($batches.ToArray())
}

function Get-BatchAction {
    param([string]$BatchText)

    foreach ($ln in ($BatchText -split "`r?`n")) {
        $t = $ln.Trim()
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        if ($t.StartsWith("--")) { continue }
        if ($t.StartsWith("/*")) { continue }
        if ($t -match "^(INSERT|UPDATE|DELETE)\b") {
            return $Matches[1].ToUpperInvariant()
        }
        return "OTHER"
    }
    return "OTHER"
}

function Get-BatchLsn {
    param([string]$BatchText)
    $m = [regex]::Match($BatchText, "--\s*(INSERT|UPDATE|DELETE)\s*\(([^)]+)\)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        return [string]$m.Groups[2].Value
    }
    return $null
}

$raw = Get-Content -LiteralPath $TrnPath -Raw
$batches = @(Split-Batches -ScriptText $raw)

$records = New-Object System.Collections.Generic.List[object]
$conn = New-Object System.Data.SqlClient.SqlConnection (New-ConnectionString)
$tran = $null
$hasError = $false
$errMsg = $null

try {
    $conn.Open()
    if ($WrapInTransaction) {
        $tran = $conn.BeginTransaction()
    }

    for ($i = 0; $i -lt $batches.Count; $i++) {
        $batch = [string]$batches[$i]
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }

        $action = Get-BatchAction -BatchText $batch
        $lsn = Get-BatchLsn -BatchText $batch
        if ($action -eq "OTHER") {
            continue
        }
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $batch
        $cmd.CommandTimeout = 0
        if ($tran) { $cmd.Transaction = $tran }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = $false
        $rows = $null
        $errorText = $null
        try {
            $rows = $cmd.ExecuteNonQuery()
            $ok = $true
        } catch {
            $ok = $false
            $errorText = $_.Exception.Message
            $hasError = $true
            if ($StopOnError) {
                $errMsg = $errorText
            }
        } finally {
            $sw.Stop()
        }

        $records.Add([pscustomobject]@{
            batch_index    = $i + 1
            action         = $action
            lsn            = $lsn
            success        = $ok
            rows_affected  = $rows
            elapsed_ms     = [int]$sw.ElapsedMilliseconds
            error          = $errorText
        })

        if ($hasError -and $StopOnError) {
            break
        }
    }

    if ($tran) {
        if ($hasError -and $StopOnError) {
            $tran.Rollback()
        } else {
            $tran.Commit()
        }
    }
} finally {
    if ($conn) { $conn.Dispose() }
}

$recordArray = @($records.ToArray())
if ($null -eq $recordArray) {
    $recordArray = @()
}
$applied = @($recordArray | Where-Object { $_.success })
if ($applied -isnot [array]) { $applied = @($applied) }
$failed = @($recordArray | Where-Object { -not $_.success })
if ($failed -isnot [array]) { $failed = @($failed) }
$appliedInsertCount = ($applied | Where-Object { $_.action -eq "INSERT" } | Measure-Object).Count
$appliedUpdateCount = ($applied | Where-Object { $_.action -eq "UPDATE" } | Measure-Object).Count
$appliedDeleteCount = ($applied | Where-Object { $_.action -eq "DELETE" } | Measure-Object).Count
$summary = [ordered]@{
    generated_utc        = (Get-Date).ToUniversalTime().ToString("o")
    trn_path             = $TrnPath
    server_instance      = $ServerInstance
    database             = $Database
    stop_on_error        = $StopOnError
    wrap_in_transaction  = $WrapInTransaction
    total_batches        = $recordArray.Count
    applied_batches      = $applied.Count
    failed_batches       = $failed.Count
    applied_insert       = [int]$appliedInsertCount
    applied_update       = [int]$appliedUpdateCount
    applied_delete       = [int]$appliedDeleteCount
    records              = $recordArray
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host ("Applied TRN batches: total={0}, applied={1}, failed={2}. Output: {3}" -f $summary.total_batches, $summary.applied_batches, $summary.failed_batches, (Resolve-Path -LiteralPath $OutputPath))

if ($hasError -and $StopOnError) {
    throw ("TRN apply failed. First error: {0}" -f $errMsg)
}
