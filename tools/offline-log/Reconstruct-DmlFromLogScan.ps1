param(
    [Parameter(Mandatory = $true)]
    [string]$ScanPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludePfs,

    [Parameter(Mandatory = $false)]
    [switch]$NoTxCollapse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RequiredPath {
    param([string]$PathValue)
    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
    return $resolved.Path
}

function Get-SafeString {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return [string]$Value
}

function Get-ActionFromOperation {
    param([string]$OperationName)
    switch ($OperationName) {
        "LOP_INSERT_ROWS" { return "INSERT" }
        "LOP_DELETE_ROWS" { return "DELETE" }
        "LOP_MODIFY_ROW" { return "UPDATE" }
        "LOP_MODIFY_COLUMNS" { return "UPDATE" }
        default { return "UNKNOWN" }
    }
}

function Normalize-Template {
    param(
        [string]$Template,
        [string]$SchemaName,
        [string]$TableName,
        [string]$Action
    )

    if (-not [string]::IsNullOrWhiteSpace($Template)) {
        return $Template.Trim()
    }

    $target = if (-not [string]::IsNullOrWhiteSpace($SchemaName)) {
        ("[{0}].[{1}]" -f $SchemaName, $TableName)
    } else {
        ("[{0}]" -f $TableName)
    }

    switch ($Action) {
        "INSERT" { return ("INSERT INTO {0} (/* columns */) VALUES (/* decode rowlog */);" -f $target) }
        "DELETE" { return ("DELETE FROM {0} WHERE /* decode key from rowlog */;" -f $target) }
        default  { return ("UPDATE {0} SET /* decode changed columns */ WHERE /* decode key */;" -f $target) }
    }
}

$scanResolved = Resolve-RequiredPath -PathValue $ScanPath
$scanDoc = Get-Content -LiteralPath $scanResolved -Raw | ConvertFrom-Json
$records = @($scanDoc.records)

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outDir = Split-Path -Parent $scanResolved
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($scanResolved)
    $OutputPath = Join-Path $outDir ("{0}.reconstructed.sql" -f $baseName)
}

$filtered = @(
    $records |
        Where-Object {
            $op = Get-SafeString -Value $_.operation_name
            if ($op -notin @("LOP_INSERT_ROWS", "LOP_DELETE_ROWS", "LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS")) { return $false }
            if ($IncludePfs.IsPresent) { return $true }
            (Get-SafeString -Value $_.context_name) -ne "LCX_PFS"
        }
)

$sqlLines = New-Object System.Collections.Generic.List[string]
$sqlLines.Add("-- Reconstructed best-effort DML templates from fn_dblog scan output")
$sqlLines.Add(("-- Generated UTC: {0}" -f (Get-Date).ToUniversalTime().ToString("o")))
$sqlLines.Add(("-- Source scan: {0}" -f $scanResolved))
$sqlLines.Add(("-- Total scan rows: {0}" -f $records.Count))
$sqlLines.Add(("-- Eligible rows after filter: {0}" -f $filtered.Count))
$sqlLines.Add(("-- Tx collapse: {0}" -f (-not $NoTxCollapse.IsPresent)))
$sqlLines.Add(("-- Include LCX_PFS rows: {0}" -f $IncludePfs.IsPresent))
$sqlLines.Add("-- NOTE: templates are approximations and may require row-log decode for exact predicates/values.")
$sqlLines.Add("")

$statementCount = 0

if ($NoTxCollapse.IsPresent) {
    $orderedRows = @($filtered | Sort-Object tx_commit_time, transaction_id, current_lsn)
    foreach ($r in $orderedRows) {
        $action = Get-ActionFromOperation -OperationName (Get-SafeString -Value $r.operation_name)
        if ($action -eq "UNKNOWN") { continue }
        $template = Normalize-Template -Template (Get-SafeString -Value $r.reconstructed_sql_template) -SchemaName (Get-SafeString -Value $r.schema_name) -TableName (Get-SafeString -Value $r.table_name) -Action $action
        $sqlLines.Add(("-- tx={0} lsn={1} op={2} ctx={3} alloc={4}" -f (Get-SafeString -Value $r.transaction_id), (Get-SafeString -Value $r.current_lsn), (Get-SafeString -Value $r.operation_name), (Get-SafeString -Value $r.context_name), (Get-SafeString -Value $r.alloc_unit_name)))
        $sqlLines.Add($template)
        $sqlLines.Add("GO")
        $sqlLines.Add("")
        $statementCount++
    }
}
else {
    $txGroups = @($filtered | Group-Object transaction_id)
    $orderedGroups = @(
        $txGroups | Sort-Object {
            $sample = @($_.Group | Sort-Object current_lsn | Select-Object -First 1)
            if ($sample.Count -gt 0) { Get-SafeString -Value $sample[0].current_lsn } else { "" }
        }, Name
    )

    foreach ($g in $orderedGroups) {
        $txRows = @($g.Group | Sort-Object current_lsn)
        if ($txRows.Count -eq 0) { continue }

        $sample = $txRows[0]
        $schemaName = Get-SafeString -Value $sample.schema_name
        $tableName = Get-SafeString -Value $sample.table_name
        $operations = @($txRows | ForEach-Object { Get-SafeString -Value $_.operation_name })
        $contexts = @($txRows | ForEach-Object { Get-SafeString -Value $_.context_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $allocUnits = @($txRows | ForEach-Object { Get-SafeString -Value $_.alloc_unit_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

        $hasInsert = $operations -contains "LOP_INSERT_ROWS"
        $hasDelete = $operations -contains "LOP_DELETE_ROWS"
        $hasModify = ($operations -contains "LOP_MODIFY_ROW") -or ($operations -contains "LOP_MODIFY_COLUMNS")

        $action = "UPDATE"
        if ($hasInsert -and -not $hasDelete -and -not $hasModify) { $action = "INSERT" }
        elseif ($hasDelete -and -not $hasInsert -and -not $hasModify) { $action = "DELETE" }
        elseif ($hasInsert -and $hasDelete) { $action = "UPDATE" }

        $templateSource = $null
        if ($action -eq "INSERT") {
            $templateSource = @($txRows | Where-Object { (Get-SafeString -Value $_.operation_name) -eq "LOP_INSERT_ROWS" } | Select-Object -First 1)
        }
        elseif ($action -eq "DELETE") {
            $templateSource = @($txRows | Where-Object { (Get-SafeString -Value $_.operation_name) -eq "LOP_DELETE_ROWS" } | Select-Object -First 1)
        }
        else {
            $templateSource = @(
                $txRows |
                    Where-Object {
                        (Get-SafeString -Value $_.operation_name) -in @("LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS", "LOP_INSERT_ROWS", "LOP_DELETE_ROWS")
                    } |
                    Select-Object -First 1
            )
        }

        $template = ""
        if ($templateSource.Count -gt 0) {
            $template = Normalize-Template -Template (Get-SafeString -Value $templateSource[0].reconstructed_sql_template) -SchemaName $schemaName -TableName $tableName -Action $action
        } else {
            $template = Normalize-Template -Template "" -SchemaName $schemaName -TableName $tableName -Action $action
        }

        if ($hasInsert -and $hasDelete) {
            $target = if (-not [string]::IsNullOrWhiteSpace($schemaName)) { "[{0}].[{1}]" -f $schemaName, $tableName } else { "[{0}]" -f $tableName }
            $template = ("UPDATE {0} SET /* inferred from insert+delete pattern in same transaction */ WHERE /* decode key */;" -f $target)
        }

        $txId = Get-SafeString -Value $g.Name
        $firstLsn = Get-SafeString -Value $txRows[0].current_lsn
        $commitTime = Get-SafeString -Value $sample.tx_commit_time
        $opSummary = @($operations | Select-Object -Unique) -join ","
        $ctxSummary = $contexts -join ","
        $allocSummary = $allocUnits -join "; "

        $sqlLines.Add(("-- tx={0} commit={1} first_lsn={2} rows={3} ops={4}" -f $txId, $commitTime, $firstLsn, $txRows.Count, $opSummary))
        if (-not [string]::IsNullOrWhiteSpace($ctxSummary)) {
            $sqlLines.Add(("-- contexts={0}" -f $ctxSummary))
        }
        if (-not [string]::IsNullOrWhiteSpace($allocSummary)) {
            $sqlLines.Add(("-- alloc_units={0}" -f $allocSummary))
        }
        $sqlLines.Add($template)
        $sqlLines.Add("GO")
        $sqlLines.Add("")
        $statementCount++
    }
}

$sqlLines.Insert(6, ("-- Output statements: {0}" -f $statementCount))
$sqlText = [string]::Join([Environment]::NewLine, $sqlLines)

$outDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value $sqlText -Encoding UTF8
Write-Host ("Reconstructed SQL written to: {0}" -f (Resolve-Path -LiteralPath $OutputPath).Path)
Write-Host ("Statements written: {0}" -f $statementCount)
