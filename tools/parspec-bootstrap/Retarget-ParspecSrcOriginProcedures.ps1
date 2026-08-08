[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ServerInstance = ".\ERPLINK",
    [string]$TargetDatabaseName = "PARSPEC_MACSII",
    [string]$TemplateDatabaseName = "MACSII_V2",
    [string]$RawDatabaseName = "OASIS_MACSII",
    [string]$OutputDirectory,
    [string[]]$IgnoreProcedures = @(
        "SRC.EmployeeIncentive_Origin",
        "SRC.ProjectContact_Origin"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $OutputDirectory = Join-Path $scriptRoot "output"
}

function New-ConnectionString {
    param(
        [string]$Server,
        [string]$Database
    )

    return "Server=$Server;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False"
}

function Invoke-SqlQuery {
    param(
        [string]$ConnectionString,
        [string]$Sql,
        [hashtable]$Parameters
    )

    $table = New-Object System.Data.DataTable
    $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 0
        $command.CommandText = $Sql

        if ($Parameters) {
            foreach ($key in $Parameters.Keys) {
                $parameter = $command.Parameters.Add("@$key", [System.Data.SqlDbType]::NVarChar, -1)
                $parameter.Value = [string]$Parameters[$key]
            }
        }

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        [void]$adapter.Fill($table)
        return ,$table
    }
    finally {
        $connection.Dispose()
    }
}

function Invoke-SqlNonQuery {
    param(
        [string]$ConnectionString,
        [string]$Sql
    )

    $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 0
        $command.CommandText = $Sql
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $connection.Dispose()
    }
}

function Convert-CreateToAlterProcedure {
    param(
        [string]$SqlDefinition
    )

    $rewritten = [regex]::Replace($SqlDefinition, '\bCREATE\s+PROCEDURE\b', 'ALTER PROCEDURE', 'IgnoreCase')
    $rewritten = [regex]::Replace($rewritten, '\bCREATE\s+PROC\b', 'ALTER PROC', 'IgnoreCase')
    return $rewritten
}

function Retarget-ProcedureText {
    param(
        [string]$Definition,
        [string]$TemplateName,
        [string]$TargetName,
        [string]$RawName
    )

    $rewritten = $Definition
    $rewritten = [regex]::Replace($rewritten, '\bOASIS_MACSII\b', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $RawName }, 'IgnoreCase')
    $rewritten = [regex]::Replace($rewritten, '\b' + [regex]::Escape($TemplateName) + '\b', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $TargetName }, 'IgnoreCase')
    return $rewritten
}

$connectionString = New-ConnectionString -Server $ServerInstance -Database $TargetDatabaseName

$procedures = Invoke-SqlQuery -ConnectionString $connectionString -Sql @"
SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    m.definition AS ModuleDefinition,
    CASE WHEN LOWER(m.definition) LIKE '%oasis_macsii%' THEN 1 ELSE 0 END AS RefOasisMacsii,
    CASE WHEN LOWER(m.definition) LIKE '%' + LOWER(@TemplateDatabaseName) + '%' THEN 1 ELSE 0 END AS RefTemplateDb
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name = 'SRC'
  AND o.type = 'P'
  AND o.name LIKE '%[_]Origin%'
ORDER BY o.name;
"@ -Parameters @{ TemplateDatabaseName = $TemplateDatabaseName }

if ($procedures.Rows.Count -eq 0) {
    Write-Host "No SRC origin procedures found in [$TargetDatabaseName]."
    return
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $OutputDirectory "src-origin-retarget.$timestamp.json"

$results = New-Object System.Collections.Generic.List[object]

foreach ($row in $procedures.Rows) {
    $schemaName = [string]$row["SchemaName"]
    $objectName = [string]$row["ObjectName"]
    $fullName = "$schemaName.$objectName"
    $definition = [string]$row["ModuleDefinition"]
    $refOasis = [int]$row["RefOasisMacsii"] -eq 1
    $refTemplate = [int]$row["RefTemplateDb"] -eq 1

    $rewritten = Retarget-ProcedureText -Definition $definition -TemplateName $TemplateDatabaseName -TargetName $TargetDatabaseName -RawName $RawDatabaseName
    $rewritten = Convert-CreateToAlterProcedure -SqlDefinition $rewritten

    $status = "skipped"
    $errorMessage = $null

    if ($IgnoreProcedures -contains $fullName) {
        $status = "ignored"
    }
    elseif ($refOasis -or $refTemplate) {
        if ($PSCmdlet.ShouldProcess($fullName, "Retarget origin procedure in [$TargetDatabaseName]")) {
            try {
                Invoke-SqlNonQuery -ConnectionString $connectionString -Sql $rewritten
                $status = "updated"
            }
            catch {
                $status = "failed"
                $errorMessage = $_.Exception.Message
            }
        }
        else {
            $status = "planned"
        }
    }

    $results.Add([pscustomobject]@{
        SchemaName = $schemaName
        ObjectName = $objectName
        FullName = $fullName
        ReferencedOasisMacsii = $refOasis
        ReferencedTemplateDb = $refTemplate
        Status = $status
        Error = $errorMessage
    }) | Out-Null
}

$results | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath

$updated = @($results | Where-Object { $_.Status -eq "updated" }).Count
$failed = @($results | Where-Object { $_.Status -eq "failed" }).Count
$planned = @($results | Where-Object { $_.Status -eq "planned" }).Count
$skipped = @($results | Where-Object { $_.Status -eq "skipped" }).Count
$ignored = @($results | Where-Object { $_.Status -eq "ignored" }).Count

Write-Host "SRC origin retarget complete."
Write-Host "Output: $reportPath"
Write-Host "Updated: $updated"
Write-Host "Failed: $failed"
Write-Host "Planned: $planned"
Write-Host "Skipped: $skipped"
Write-Host "Ignored: $ignored"
