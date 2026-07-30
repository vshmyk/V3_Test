[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$OrgName,

    [string]$ServerInstance = ".\ERPLINK",
    [string]$TemplateDatabaseName = "MACSII_V2",
    [string]$RawDatabaseName,
    [string]$TargetDatabaseName,
    [string]$BackupDirectory = "$env:TEMP\parspec-bootstrap",
    [switch]$RetargetModuleReferences
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RawDatabaseName)) {
    $RawDatabaseName = "OASIS_$OrgName"
}

if ([string]::IsNullOrWhiteSpace($TargetDatabaseName)) {
    $TargetDatabaseName = "PARSPEC_$OrgName"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$retargetSqlPath = Join-Path $scriptRoot "Retarget-ParspecClientDatabase.sql"

function New-ConnectionString {
    param(
        [string]$Server,
        [string]$Database = "master"
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

function Assert-DatabaseExists {
    param(
        [string]$ConnectionString,
        [string]$DatabaseName
    )

    $result = Invoke-SqlQuery -ConnectionString $ConnectionString -Sql @"
SELECT name
FROM sys.databases
WHERE name = @DatabaseName;
"@ -Parameters @{ DatabaseName = $DatabaseName }

    if ($result.Rows.Count -eq 0) {
        throw "Database [$DatabaseName] was not found on [$ServerInstance]."
    }
}

function Get-TemplateFileLayout {
    param(
        [string]$ConnectionString,
        [string]$DatabaseName
    )

    return Invoke-SqlQuery -ConnectionString $ConnectionString -Sql @"
SELECT
    file_id,
    name AS LogicalName,
    type_desc,
    physical_name
FROM sys.master_files
WHERE database_id = DB_ID(@DatabaseName)
ORDER BY file_id;
"@ -Parameters @{ DatabaseName = $DatabaseName }
}

function Get-ModuleDefinitionsToRetarget {
    param(
        [string]$ConnectionString,
        [string]$TemplateName
    )

    return Invoke-SqlQuery -ConnectionString $ConnectionString -Sql @"
SELECT
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    m.definition AS ModuleDefinition
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE LOWER(m.definition) LIKE '%oasis_macsii%'
   OR LOWER(m.definition) LIKE '%' + LOWER(@TemplateName) + '%'
ORDER BY s.name, o.type_desc, o.name;
"@ -Parameters @{ TemplateName = $TemplateName }
}

function Convert-CreateToAlter {
    param(
        [string]$SqlDefinition,
        [string]$ObjectType
    )

    $rewritten = $SqlDefinition

    switch ($ObjectType) {
        "SQL_STORED_PROCEDURE" {
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+PROCEDURE', 'ALTER PROCEDURE', 'IgnoreCase')
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+PROC', 'ALTER PROC', 'IgnoreCase')
        }
        "VIEW" {
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+VIEW', 'ALTER VIEW', 'IgnoreCase')
        }
        "SQL_SCALAR_FUNCTION" {
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+FUNCTION', 'ALTER FUNCTION', 'IgnoreCase')
        }
        "SQL_INLINE_TABLE_VALUED_FUNCTION" {
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+FUNCTION', 'ALTER FUNCTION', 'IgnoreCase')
        }
        "SQL_TABLE_VALUED_FUNCTION" {
            $rewritten = [regex]::Replace($rewritten, '^\s*CREATE\s+FUNCTION', 'ALTER FUNCTION', 'IgnoreCase')
        }
        default {
            throw "Unsupported module type for retargeting: [$ObjectType]."
        }
    }

    return $rewritten
}

function Retarget-ModuleText {
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

$masterConnectionString = New-ConnectionString -Server $ServerInstance -Database "master"

Assert-DatabaseExists -ConnectionString $masterConnectionString -DatabaseName $TemplateDatabaseName
Assert-DatabaseExists -ConnectionString $masterConnectionString -DatabaseName $RawDatabaseName

$targetExists = (Invoke-SqlQuery -ConnectionString $masterConnectionString -Sql @"
SELECT name
FROM sys.databases
WHERE name = @DatabaseName;
"@ -Parameters @{ DatabaseName = $TargetDatabaseName }).Rows.Count -gt 0

if (-not $targetExists) {
    $layout = Get-TemplateFileLayout -ConnectionString $masterConnectionString -DatabaseName $TemplateDatabaseName
    if ($layout.Rows.Count -eq 0) {
        throw "Could not resolve file layout for template database [$TemplateDatabaseName]."
    }

    New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
    $backupPath = Join-Path $BackupDirectory "$TargetDatabaseName.bootstrap.bak"

    $dataDirectory = Split-Path -Parent $layout.Rows[0]["physical_name"]
    $moveClauses = @()
    foreach ($row in $layout.Rows) {
        $logicalName = [string]$row["LogicalName"]
        $typeDesc = [string]$row["type_desc"]
        $extension = if ($typeDesc -eq "LOG") { "ldf" } else { "mdf" }
        $suffix = if ($typeDesc -eq "LOG") { "log" } else { "data" }
        $newPath = Join-Path $dataDirectory "$TargetDatabaseName.$suffix.$extension"
        $moveClauses += "MOVE N'$logicalName' TO N'$newPath'"
    }

    $cloneSql = @"
BACKUP DATABASE [$TemplateDatabaseName]
TO DISK = N'$backupPath'
WITH COPY_ONLY, INIT, COMPRESSION, STATS = 10;

RESTORE DATABASE [$TargetDatabaseName]
FROM DISK = N'$backupPath'
WITH REPLACE,
$(($moveClauses -join ",`r`n")),
RECOVERY,
STATS = 10;
"@

    if ($PSCmdlet.ShouldProcess($TargetDatabaseName, "Clone [$TemplateDatabaseName] into [$TargetDatabaseName]")) {
        Invoke-SqlNonQuery -ConnectionString $masterConnectionString -Sql $cloneSql
    }
}

$targetExists = (Invoke-SqlQuery -ConnectionString $masterConnectionString -Sql @"
SELECT name
FROM sys.databases
WHERE name = @DatabaseName;
"@ -Parameters @{ DatabaseName = $TargetDatabaseName }).Rows.Count -gt 0

if (-not $targetExists) {
    Write-Host "Target database [$TargetDatabaseName] does not exist after planning/execution. This is expected during -WhatIf runs."
    return
}

$targetConnectionString = New-ConnectionString -Server $ServerInstance -Database $TargetDatabaseName

$retargetTemplate = Get-Content $retargetSqlPath -Raw
$bootstrapSql = $retargetTemplate.Replace('$(TargetDatabaseName)', $TargetDatabaseName).
    Replace('$(TemplateDatabaseName)', $TemplateDatabaseName).
    Replace('$(RawDatabaseName)', $RawDatabaseName).
    Replace('$(OrgName)', $OrgName)

if ($PSCmdlet.ShouldProcess($TargetDatabaseName, "Register bootstrap metadata and module inventory")) {
    Invoke-SqlNonQuery -ConnectionString $targetConnectionString -Sql $bootstrapSql
}

if ($RetargetModuleReferences) {
    $modules = Get-ModuleDefinitionsToRetarget -ConnectionString $targetConnectionString -TemplateName $TemplateDatabaseName
    foreach ($row in $modules.Rows) {
        $schemaName = [string]$row["SchemaName"]
        $objectName = [string]$row["ObjectName"]
        $objectType = [string]$row["ObjectType"]
        $definition = [string]$row["ModuleDefinition"]

        $rewritten = Retarget-ModuleText -Definition $definition -TemplateName $TemplateDatabaseName -TargetName $TargetDatabaseName -RawName $RawDatabaseName
        $rewritten = Convert-CreateToAlter -SqlDefinition $rewritten -ObjectType $objectType

        if ($PSCmdlet.ShouldProcess("$schemaName.$objectName", "Retarget database references inside [$TargetDatabaseName]")) {
            Invoke-SqlNonQuery -ConnectionString $targetConnectionString -Sql $rewritten
        }
    }
}

$summary = Invoke-SqlQuery -ConnectionString $targetConnectionString -Sql @"
SELECT
    OrgName,
    TemplateDatabaseName,
    RawDatabaseName,
    TargetDatabaseName,
    BootstrapedAtUtc,
    BootstrapMode
FROM dbo.ParspecBootstrapConfig;

SELECT
    COUNT(*) AS ReferencingModules
FROM dbo.ParspecModuleReferenceInventory;
"@

$summary | Format-Table -AutoSize
