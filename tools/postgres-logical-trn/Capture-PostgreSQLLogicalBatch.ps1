param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "aotransact-postgresql.config.json"),
    [string]$SftpExecutable = ''
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security

$credentialEntropy = [Text.Encoding]::UTF8.GetBytes('AOtransactPostgreSQL|Credential|v1')

function Get-PostgresPassword {
    param([string]$Path)

    $lines = @(Get-Content -LiteralPath $Path)
    $protectedLine = $lines | Where-Object { $_ -like 'DPAPI_LOCAL_MACHINE=*' } | Select-Object -First 1
    if ($protectedLine) {
        $protectedBytes = $null
        $plainBytes = $null
        try {
            $protectedBytes = [Convert]::FromBase64String($protectedLine.Substring('DPAPI_LOCAL_MACHINE='.Length))
            $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
                $protectedBytes,
                $script:credentialEntropy,
                [Security.Cryptography.DataProtectionScope]::LocalMachine)
            return [Text.Encoding]::UTF8.GetString($plainBytes)
        }
        catch {
            throw "Credential file could not be decrypted on this computer: $Path. $($_.Exception.Message)"
        }
        finally {
            if ($null -ne $plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
            if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
        }
    }

    $passwordLine = $lines | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if ($passwordLine) {
        return $passwordLine.Substring('Password='.Length)
    }

    throw "Encrypted or legacy password entry not found in $Path"
}

function Resolve-PsqlExecutable {
    param([string]$ConfiguredPath)

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath) -and $ConfiguredPath -ne 'auto' -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    $candidates = @()
    $postgresRoot = 'C:\Program Files\PostgreSQL'
    if (Test-Path -LiteralPath $postgresRoot) {
        foreach ($versionDirectory in Get-ChildItem -LiteralPath $postgresRoot -Directory) {
            foreach ($relativePath in @('bin\psql.exe', 'pgsql\bin\psql.exe')) {
                $candidate = Join-Path $versionDirectory.FullName $relativePath
                if (Test-Path -LiteralPath $candidate) {
                    $candidates += Get-Item -LiteralPath $candidate
                }
            }
        }
    }
    $selected = $candidates | Sort-Object { if ($_.FullName -match '\\PostgreSQL\\(?<version>\d+)\\') { [int]$matches['version'] } else { 0 } } -Descending | Select-Object -First 1
    if (-not $selected) {
        throw "PostgreSQL psql.exe was not found. Configure postgres.psql_path explicitly."
    }
    return $selected.FullName
}

function Invoke-PsqlCsv {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string]$Sql
    )

    $tmp = Join-Path $env:TEMP ("aotransact-pg-" + [guid]::NewGuid().ToString("N") + ".sql")
    try {
        Set-Content -LiteralPath $tmp -Value $Sql -Encoding ASCII
        $output = & $Psql -h $HostName -p $PortNumber -U $UserName -d $DatabaseName -v ON_ERROR_STOP=1 -f $tmp
        if ($null -eq $output -or @($output).Count -eq 0) {
            return @()
        }

        $rows = @($output | ConvertFrom-Csv)
        return $rows
    }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
}

function Invoke-PsqlScalar {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string]$Sql
    )

    $result = & $Psql -h $HostName -p $PortNumber -U $UserName -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c $Sql
    if ($null -eq $result) {
        return ""
    }

    return ($result | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1).Trim()
}

function Normalize-TableName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Configured table name cannot be blank."
    }

    $parts = $Value.Trim().Split('.', 2)
    if ($parts.Count -ne 2) {
        throw "Configured table '$Value' must use schema.table format."
    }

    return ($parts[0].Trim() + "." + $parts[1].Trim())
}

function Convert-RelationToSqlServer {
    param([string]$Relation)

    $parts = $Relation.Split('.', 2)
    $schemaName = $parts[0]
    $tableName = $parts[1].Trim('"').Replace('""', '"')
    return "[" + $schemaName.Replace("]", "]]") + "].[" + $tableName.Replace("]", "]]") + "]"
}

function Normalize-ToSqlServerSql {
    param([string]$Sql)

    $result = $Sql
    $result = [regex]::Replace($result, '([A-Za-z_][A-Za-z0-9_]*)\."([^"]+)"', { param($m) "[" + $m.Groups[1].Value + "].[" + $m.Groups[2].Value.Replace("]", "]]") + "]" })
    $result = [regex]::Replace($result, '"([^"]+)"', { param($m) "[" + $m.Groups[1].Value.Replace("]", "]]") + "]" })
    $result = [regex]::Replace($result, '\[([^\]]+)\]\s+IS\s+NOT\s+DISTINCT\s+FROM\s+(.+?)(?=(\s+AND\s+)|;|$)', {
        param($m)
        $col = "[" + $m.Groups[1].Value + "]"
        $val = $m.Groups[2].Value.Trim()
        if ($val -eq 'NULL') {
            return "$col IS NULL"
        }
        return "(($col = $val) OR ($col IS NULL AND $val IS NULL))"
    })
    return $result
}

function Assert-SqlServerDmlIsComplete {
    param([string]$Sql)

    if ($Sql -match '=\s*unchanged-toast-datum(?=\s*(?:,|WHERE|;))') {
        throw 'Generated SQL Server DML contains PostgreSQL''s unchanged TOAST sentinel; refusing to upload or advance the logical slot.'
    }

    $insideString = $false
    for ($index = 0; $index -lt $Sql.Length; $index++) {
        if ($Sql[$index] -ne "'") {
            continue
        }
        if ($insideString -and $index + 1 -lt $Sql.Length -and $Sql[$index + 1] -eq "'") {
            $index++
            continue
        }
        $insideString = -not $insideString
    }

    if ($insideString -or -not $Sql.TrimEnd().EndsWith(';')) {
        throw 'Generated SQL Server DML is incomplete or contains an unterminated string literal; refusing to upload or advance the logical slot.'
    }
}

function Get-TableMetadata {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string[]]$TrackedTables
    )

    $rows = Invoke-PsqlCsv -Psql $Psql -HostName $HostName -PortNumber $PortNumber -UserName $UserName -DatabaseName $DatabaseName -Sql @"
COPY (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        a.attnum AS ordinal_position,
        a.attname AS column_name,
        EXISTS (
            SELECT 1
            FROM pg_index i
            WHERE i.indrelid = c.oid
              AND i.indisprimary
              AND a.attnum = ANY(i.indkey)
        ) AS is_primary_key
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid
    WHERE c.relkind = 'r'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY n.nspname, c.relname, a.attnum
) TO STDOUT WITH CSV HEADER;
"@

    $catalog = @{}
    foreach ($row in $rows) {
        $key = "$($row.schema_name).$($row.table_name)"
        if (-not $catalog.ContainsKey($key)) {
            $catalog[$key] = [ordered]@{
                Columns = @()
                PrimaryKeys = @()
            }
        }

        $entry = [ordered]@{
            Name = $row.column_name
            SqlServerQuotedName = "[" + $row.column_name.Replace("]", "]]") + "]"
        }
        $catalog[$key].Columns += $entry
        if ($row.is_primary_key -eq 't') {
            $catalog[$key].PrimaryKeys += $entry
        }
    }

    $metadata = @{}
    $missingTables = @()
    $ambiguousTables = @()
    foreach ($configuredTable in $TrackedTables) {
        $targetRelation = Normalize-TableName -Value $configuredTable
        $sourceRelation = $targetRelation
        if (-not $catalog.ContainsKey($sourceRelation)) {
            $baseName = $targetRelation.Split('.', 2)[1]
            $sameNameRelations = @($catalog.Keys | Where-Object { $_.Split('.', 2)[1] -ieq $baseName })
            if ($sameNameRelations.Count -eq 1) {
                $sourceRelation = $sameNameRelations[0]
            } elseif ($sameNameRelations.Count -gt 1) {
                $ambiguousTables += "$configuredTable ($($sameNameRelations -join ', '))"
                continue
            } else {
                $missingTables += $configuredTable
                continue
            }
        }

        $tableMetadata = $catalog[$sourceRelation]
        $tableMetadata['SourceRelation'] = $sourceRelation
        $tableMetadata['TargetRelation'] = $targetRelation
        $metadata[$sourceRelation] = $tableMetadata
    }

    if ($ambiguousTables.Count -gt 0) {
        throw "Tracked table names are ambiguous across PostgreSQL schemas: $($ambiguousTables -join '; '). Specify the exact PostgreSQL source schema."
    }

    if ($missingTables.Count -gt 0) {
        $availableRelations = @($rows | ForEach-Object { "$($_.schema_name).$($_.table_name)" } | Select-Object -Unique)
        $detail = if ($availableRelations.Count -gt 0) {
            $schemas = @($rows | ForEach-Object { $_.schema_name } | Select-Object -Unique)
            $sample = @($availableRelations | Select-Object -First 15)
            " Available user schemas: $($schemas -join ', '). Sample tables: $($sample -join ', '). Verify the database name and tracked-table list."
        } else {
            " The selected database contains no visible user tables. Verify the database name and the database user's permissions."
        }

        throw "Tracked tables not found in PostgreSQL: $($missingTables -join ', ').$detail"
    }

    $tablesWithoutPk = @($metadata.GetEnumerator() | Where-Object { $_.Value.PrimaryKeys.Count -eq 0 } | ForEach-Object { $_.Value.SourceRelation })
    if ($tablesWithoutPk.Count -gt 0) {
        throw "Tracked tables without primary keys are not supported in no-DDL mode: $($tablesWithoutPk -join ', ')"
    }

    return $metadata
}

function Split-SectionTokens {
    param(
        [string]$Text,
        [bool]$TrimFixedCharacterTrailingSpaces
    )

    $pattern = '(?<name>"(?:""|[^"])*"|[A-Za-z_][A-Za-z0-9_$]*)\[(?<type>[^\]]+)\]:(?<value>NULL|null|''(?:''''|[^''])*''|[^ ]+)'
    $matches = [regex]::Matches($Text, $pattern)
    $result = [ordered]@{}

    foreach ($match in $matches) {
        $name = $match.Groups['name'].Value
        $normalized = if ($name.StartsWith('"') -and $name.EndsWith('"')) {
            $name.Substring(1, $name.Length - 2).Replace('""', '"')
        } else {
            $name
        }

        $typeName = $match.Groups['type'].Value.Trim()
        $literal = $match.Groups['value'].Value
        if ($literal -ceq 'unchanged-toast-datum') {
            # test_decoding uses this unquoted sentinel when an unchanged TOAST value is absent from WAL.
            continue
        }
        if ($literal -ieq 'null') {
            $literal = 'NULL'
        } elseif ($TrimFixedCharacterTrailingSpaces -and
            $typeName -match '^(?i:character|bpchar)(?:\(\d+\))?$' -and
            $literal.Length -ge 2 -and $literal.StartsWith("'") -and $literal.EndsWith("'")) {
            $innerValue = $literal.Substring(1, $literal.Length - 2).TrimEnd(' ')
            $literal = "'$innerValue'"
        }

        $result[$normalized] = [ordered]@{
            Name = $normalized
            Type = $typeName
            Literal = $literal
        }
    }

    return $result
}

function Parse-ChangeLine {
    param(
        [string]$Line,
        [bool]$TrimFixedCharacterTrailingSpaces
    )

    $match = [regex]::Match($Line, '(?s)^table\s+(?<relation>.+?):\s+(?<operation>INSERT|UPDATE|DELETE):\s*(?<detail>.*)$')
    if (-not $match.Success) {
        return $null
    }

    $relation = $match.Groups['relation'].Value
    $relationParts = $relation.Split('.', 2)
    $schemaName = $relationParts[0]
    $tableNameRendered = $relationParts[1]
    $tableName = if ($tableNameRendered.StartsWith('"') -and $tableNameRendered.EndsWith('"')) {
        $tableNameRendered.Substring(1, $tableNameRendered.Length - 2).Replace('""', '"')
    } else {
        $tableNameRendered
    }

    $detail = $match.Groups['detail'].Value
    $op = $match.Groups['operation'].Value
    $oldValues = [ordered]@{}
    $newValues = [ordered]@{}

    if ($op -eq 'UPDATE' -and $detail -match '(?s)^old-key:\s*(?<old>.*?)\s+new-tuple:\s*(?<new>.*)$') {
        $oldValues = Split-SectionTokens -Text $matches['old'] -TrimFixedCharacterTrailingSpaces $TrimFixedCharacterTrailingSpaces
        $newValues = Split-SectionTokens -Text $matches['new'] -TrimFixedCharacterTrailingSpaces $TrimFixedCharacterTrailingSpaces
    } else {
        $newValues = Split-SectionTokens -Text $detail -TrimFixedCharacterTrailingSpaces $TrimFixedCharacterTrailingSpaces
        if ($op -eq 'DELETE') {
            $oldValues = $newValues
            $newValues = [ordered]@{}
        }
    }

    [pscustomobject]@{
        SchemaName = $schemaName
        TableName = $tableName
        Relation = $relation
        Operation = $op
        OldValues = $oldValues
        NewValues = $newValues
    }
}

function Build-WhereClause {
    param(
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$Values
    )

    $parts = @()
    foreach ($column in $TableMeta.PrimaryKeys) {
        if (-not $Values.Contains($column.Name)) {
            throw "Could not build WHERE clause because PK value '$($column.Name)' is missing."
        }

        $literal = $Values[$column.Name].Literal
        if ($literal -eq 'NULL') {
            throw "Could not build WHERE clause because PK value '$($column.Name)' is NULL."
        }

        $parts += "$($column.SqlServerQuotedName) = $literal"
    }

    return ($parts -join ' AND ')
}

function Build-InsertSql {
    param(
        [string]$Relation,
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$Values
    )

    $columns = @()
    $literals = @()
    foreach ($column in $TableMeta.Columns) {
        if (-not $Values.Contains($column.Name)) {
            continue
        }
        $columns += $column.SqlServerQuotedName
        $literals += $Values[$column.Name].Literal
    }

    return "INSERT INTO $(Convert-RelationToSqlServer -Relation $Relation) ($($columns -join ', ')) VALUES ($($literals -join ', '));"
}

function Build-UpdateSql {
    param(
        [string]$Relation,
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$OldValues,
        [System.Collections.Specialized.OrderedDictionary]$NewValues
    )

    $setParts = @()
    foreach ($column in $TableMeta.Columns) {
        if (($TableMeta.PrimaryKeys.Name -contains $column.Name) -or -not $NewValues.Contains($column.Name)) {
            continue
        }

        $oldLiteral = if ($OldValues.Contains($column.Name)) { $OldValues[$column.Name].Literal } else { $null }
        $newLiteral = $NewValues[$column.Name].Literal
        if ($oldLiteral -ne $newLiteral) {
            $setParts += "$($column.SqlServerQuotedName) = $newLiteral"
        }
    }

    if ($setParts.Count -eq 0) {
        foreach ($column in $TableMeta.Columns) {
            if (($TableMeta.PrimaryKeys.Name -contains $column.Name) -or -not $NewValues.Contains($column.Name)) {
                continue
            }
            $setParts += "$($column.SqlServerQuotedName) = $($NewValues[$column.Name].Literal)"
        }
    }

    if ($setParts.Count -eq 0) {
        throw "Could not build UPDATE SET clause for $(Convert-RelationToSqlServer -Relation $Relation)."
    }

    return "UPDATE $(Convert-RelationToSqlServer -Relation $Relation) SET $($setParts -join ', ') WHERE $(Build-WhereClause -TableMeta $TableMeta -Values $(if ($OldValues.Count -gt 0) { $OldValues } else { $NewValues }));"
}

function Build-DeleteSql {
    param(
        [string]$Relation,
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$OldValues
    )

    return "DELETE FROM $(Convert-RelationToSqlServer -Relation $Relation) WHERE $(Build-WhereClause -TableMeta $TableMeta -Values $OldValues);"
}

function Convert-ChangeToSql {
    param(
        [pscustomobject]$Change,
        [hashtable]$Metadata
    )

    $metaKey = "$($Change.SchemaName).$($Change.TableName)"
    if (-not $Metadata.ContainsKey($metaKey)) {
        throw "Metadata not found for tracked table $metaKey"
    }

    $tableMeta = $Metadata[$metaKey]
    $targetRelation = [string]$tableMeta.TargetRelation
    switch ($Change.Operation) {
        'INSERT' { return Build-InsertSql -Relation $targetRelation -TableMeta $tableMeta -Values $Change.NewValues }
        'UPDATE' { return Build-UpdateSql -Relation $targetRelation -TableMeta $tableMeta -OldValues $Change.OldValues -NewValues $Change.NewValues }
        'DELETE' { return Build-DeleteSql -Relation $targetRelation -TableMeta $tableMeta -OldValues $Change.OldValues }
        default { throw "Unsupported operation $($Change.Operation)" }
    }
}

function Load-Checkpoint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return ($raw | ConvertFrom-Json)
}

function Save-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Remove-ExpiredArchiveFiles {
    param(
        [string]$Directory,
        [int]$RetentionDays
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        return 0
    }

    $cutoffUtc = [DateTime]::UtcNow.AddDays(-$RetentionDays)
    $expiredFiles = @(Get-ChildItem -LiteralPath $Directory -Filter '*.trn' -File |
        Where-Object { $_.LastWriteTimeUtc -lt $cutoffUtc })
    foreach ($file in $expiredFiles) {
        Remove-Item -LiteralPath $file.FullName -Force
    }
    return $expiredFiles.Count
}

function Get-SlotState {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string]$SlotName
    )

    $rows = Invoke-PsqlCsv -Psql $Psql -HostName $HostName -PortNumber $PortNumber -UserName $UserName -DatabaseName $DatabaseName -Sql @"
COPY (
    SELECT
        slot_name,
        confirmed_flush_lsn::text AS confirmed_flush_lsn,
        restart_lsn::text AS restart_lsn,
        active::text AS active,
        active_pid::text AS active_pid
    FROM pg_replication_slots
    WHERE slot_name = '$SlotName'
) TO STDOUT WITH CSV HEADER;
"@

    if (@($rows).Count -eq 0) {
        throw "Logical replication slot '$SlotName' was not found."
    }

    return @($rows)[0]
}

function Compare-SlotToCheckpoint {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string]$SlotName,
        [string]$CheckpointLsn
    )

    if ([string]::IsNullOrWhiteSpace($CheckpointLsn)) {
        return "none"
    }

    return Invoke-PsqlScalar -Psql $Psql -HostName $HostName -PortNumber $PortNumber -UserName $UserName -DatabaseName $DatabaseName -Sql @"
SELECT CASE
    WHEN confirmed_flush_lsn IS NULL THEN 'none'
    WHEN confirmed_flush_lsn < '$CheckpointLsn'::pg_lsn THEN 'behind'
    WHEN confirmed_flush_lsn = '$CheckpointLsn'::pg_lsn THEN 'equal'
    ELSE 'ahead'
END
FROM pg_replication_slots
WHERE slot_name = '$SlotName';
"@
}

function Advance-Slot {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DatabaseName,
        [string]$SlotName,
        [string]$TargetLsn
    )

    $rows = Invoke-PsqlCsv -Psql $Psql -HostName $HostName -PortNumber $PortNumber -UserName $UserName -DatabaseName $DatabaseName -Sql @"
COPY (
    SELECT end_lsn::text
    FROM pg_replication_slot_advance('$SlotName', '$TargetLsn')
) TO STDOUT WITH CSV HEADER;
"@

    if (@($rows).Count -eq 0) {
        throw "Failed to advance slot '$SlotName' to $TargetLsn."
    }

    return @($rows)[0].end_lsn
}

function Write-ErrorRecord {
    param(
        [string]$Path,
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$SlotName,
        [string]$ConfigFilePath
    )

    Save-JsonFile -Path $Path -Value ([ordered]@{
        failed_at_utc = [DateTime]::UtcNow.ToString("o")
        slot_name = $SlotName
        config_path = $ConfigFilePath
        message = $ErrorRecord.Exception.Message
        details = $ErrorRecord.ToString()
    })
}

function Send-SftpFile {
    param(
        [pscustomobject]$Settings,
        [string]$LocalPath,
        [string]$RemoteFileName
    )

    if ([string]::IsNullOrWhiteSpace($script:SftpExecutable) -or -not (Test-Path -LiteralPath $script:SftpExecutable)) {
        throw 'Native SFTP requires AOtransactPostgreSQL.exe. Run the EXE or supply -SftpExecutable when invoking the batch script.'
    }
    $resultPath = Join-Path $env:TEMP ("aotransact-sftp-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        & $script:SftpExecutable --sftp-upload --config $script:resolvedConfigPath --local-file $LocalPath --remote-name $RemoteFileName --result-file $resultPath
        if ($LASTEXITCODE -ne 0) {
            throw "Native SFTP upload failed for '$RemoteFileName' with exit code $LASTEXITCODE. The ZIP remains pending and the logical slot is not advanced."
        }
        $receipt = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if ([long]$receipt.Size -ne (Get-Item -LiteralPath $LocalPath).Length) {
            throw 'Native SFTP receipt size does not match the pending ZIP.'
        }
        return $receipt
    }
    finally {
        if (Test-Path -LiteralPath $resultPath) { Remove-Item -LiteralPath $resultPath -Force }
    }
}

function Expand-BatchTemplate {
    param(
        [string]$Template,
        [string]$ClientId,
        [string]$LastLsn,
        [DateTime]$BatchUtc
    )

    if ([string]::IsNullOrWhiteSpace($Template)) {
        throw "Batch filename template cannot be blank."
    }

    $result = $Template.Replace('{client_id}', $ClientId)
    $result = $result.Replace('{last_lsn}', $LastLsn.Replace('/', '_'))
    $result = $result.Replace('{batch_utc}', $BatchUtc.ToString('yyyyMMdd_HHmmssfff'))
    if ([System.IO.Path]::GetFileName($result) -ne $result) {
        throw "Batch filename template must produce a filename without a directory: $result"
    }
    return $result
}

function New-ZipPackage {
    param(
        [string]$TrnPath,
        [string]$ZipPath,
        [string]$EntryName
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $temporaryPath = "$ZipPath.uploading"
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }

    $archive = [System.IO.Compression.ZipFile]::Open($temporaryPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $TrnPath,
            $EntryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        )
    }
    finally {
        $archive.Dispose()
    }

    Move-Item -LiteralPath $temporaryPath -Destination $ZipPath -Force
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$configDirectory = Split-Path -Parent $resolvedConfigPath
if ([string]::IsNullOrWhiteSpace($SftpExecutable)) {
    $SftpExecutable = Join-Path $configDirectory 'AOtransactPostgreSQL.exe'
}
$client = $config.client
$postgres = $config.postgres
$capture = $config.capture
$package = $config.package
$sftp = $config.sftp
$trackedTables = @($config.tables)
if ($trackedTables.Count -eq 0) {
    throw "Config must define at least one tracked table."
}

$clientId = [string]$client.id
if ($clientId -notmatch '^[A-Za-z0-9_-]+$') {
    throw "Client ID must contain only letters, numbers, underscore, or hyphen: '$clientId'"
}

$pgHost = [string]$postgres.host
$port = [int]$postgres.port
$database = [string]$postgres.database
$user = [string]$postgres.user
$credentialsPath = [string]$postgres.credentials_path
$slotName = [string]$capture.slot_name
$outputPath = [string]$capture.output_path
$archiveDirectory = [string]$capture.archive_directory
$checkpointPath = [string]$capture.checkpoint_path
$lastBatchPath = [string]$capture.last_batch_path
$errorPath = [string]$capture.error_path
$archiveBatches = [bool]$capture.archive_batches
$archiveEmptyBatches = [bool]$capture.archive_empty_batches
$archiveRetentionDays = if ($null -ne $capture.PSObject.Properties['archive_retention_days']) {
    [int]$capture.archive_retention_days
} else {
    5
}
if ($archiveRetentionDays -lt 1) {
    throw "capture.archive_retention_days must be at least 1."
}
$resumeFromCheckpoint = [bool]$capture.resume_from_saved_checkpoint
$clearOutputWhenEmpty = [bool]$capture.clear_output_when_empty
$trimFixedCharacterTrailingSpaces = if ($null -ne $capture.PSObject.Properties['trim_fixed_character_trailing_spaces']) {
    [bool]$capture.trim_fixed_character_trailing_spaces
} else {
    $true
}
$maxChangesPerRun = if ($null -ne $capture.PSObject.Properties['max_changes_per_run']) {
    [int]$capture.max_changes_per_run
} else {
    10000
}
if ($maxChangesPerRun -lt 1) {
    throw "capture.max_changes_per_run must be at least 1."
}
$sftpEnabled = [bool]$sftp.enabled
$sftpUploadEmptyFiles = [bool]$sftp.upload_empty_files
$packageEnabled = [bool]$package.enabled
$packageDirectory = [string]$package.directory
$sentDirectory = if ($null -ne $package.PSObject.Properties['sent_directory'] -and
    -not [string]::IsNullOrWhiteSpace([string]$package.sent_directory)) {
    [string]$package.sent_directory
} else {
    Join-Path (Split-Path -Parent $packageDirectory) 'sent'
}

if ($sftpEnabled -and -not $packageEnabled) {
    throw "ZIP packaging must be enabled when SFTP is enabled."
}

$env:PGPASSWORD = Get-PostgresPassword -Path $credentialsPath
$psql = Resolve-PsqlExecutable -ConfiguredPath ([string]$postgres.psql_path)

try {
    $metadata = Get-TableMetadata -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -TrackedTables $trackedTables
    $checkpoint = Load-Checkpoint -Path $checkpointPath
    $slotStateBefore = Get-SlotState -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName
    if ($slotStateBefore.active -in @('t', 'true')) {
        throw "Logical replication slot '$slotName' is already active for PostgreSQL PID $($slotStateBefore.active_pid). Refusing to start a concurrent capture."
    }

    if ($resumeFromCheckpoint -and $null -ne $checkpoint -and -not [string]::IsNullOrWhiteSpace($checkpoint.confirmed_flush_lsn)) {
        $slotVsCheckpoint = Compare-SlotToCheckpoint -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName -CheckpointLsn $checkpoint.confirmed_flush_lsn
        if ($slotVsCheckpoint -eq "behind") {
            [void](Advance-Slot -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName -TargetLsn $checkpoint.confirmed_flush_lsn)
            $slotStateBefore = Get-SlotState -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName
        }
    }

    $rows = Invoke-PsqlCsv -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -Sql @"
COPY (
    SELECT
        lsn::text,
        xid::text,
        replace(encode(convert_to(data, 'UTF8'), 'base64'), E'\n', '') AS data_base64
    FROM pg_logical_slot_peek_changes('$slotName', NULL, $maxChangesPerRun, 'include-timestamp', 'on')
) TO STDOUT WITH CSV HEADER;
"@

    $trackedLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($sourceRelation in $metadata.Keys) {
        [void]$trackedLookup.Add($sourceRelation)
    }

    $pending = @{}
    $batchEvents = New-Object System.Collections.Generic.List[object]
    $decodedTableCounts = [ordered]@{}
    $lastSeenLsn = ""
    $rawRowCount = 0
    $matchedRowCount = 0
    $firstDecodedCommitUtc = $null
    $lastDecodedCommitUtc = $null

    foreach ($row in $rows) {
        $rawRowCount++
        $lastSeenLsn = $row.lsn
        $dataBytes = $null
        try {
            $dataBytes = [Convert]::FromBase64String([string]$row.data_base64)
            $data = [Text.Encoding]::UTF8.GetString($dataBytes)
        }
        finally {
            if ($null -ne $dataBytes) { [Array]::Clear($dataBytes, 0, $dataBytes.Length) }
        }

        if ($data -match '^BEGIN\s+(?<xid>\d+)$') {
            $pending[$matches['xid']] = New-Object System.Collections.Generic.List[object]
            continue
        }

        if ($data -match '^COMMIT\s+(?<xid>\d+)\s+\(at\s+(?<ts>[^)]+)\)$') {
            $xid = $matches['xid']
            $commitTime = [DateTimeOffset]::Parse($matches['ts'], [System.Globalization.CultureInfo]::InvariantCulture)
            $lastDecodedCommitUtc = $commitTime.UtcDateTime.ToString("o")
            if ($null -eq $firstDecodedCommitUtc) { $firstDecodedCommitUtc = $lastDecodedCommitUtc }
            if ($pending.ContainsKey($xid)) {
                foreach ($change in $pending[$xid]) {
                    $normalizedTable = "$($change.SchemaName).$($change.TableName)"
                    if (-not $trackedLookup.Contains($normalizedTable)) {
                        continue
                    }

                    $matchedRowCount++
                    $sql = Normalize-ToSqlServerSql -Sql (Convert-ChangeToSql -Change $change -Metadata $metadata)
                    Assert-SqlServerDmlIsComplete -Sql $sql
                    $batchEvents.Add([pscustomobject]@{
                        TxId = $xid
                        Operation = $change.Operation
                        Relation = $change.Relation
                        TargetRelation = [string]$metadata[$normalizedTable].TargetRelation
                        CommitTime = $commitTime.UtcDateTime.ToString("o")
                        Sql = $sql
                    })
                }

                $pending.Remove($xid) | Out-Null
            }
            continue
        }

        $change = Parse-ChangeLine -Line $data -TrimFixedCharacterTrailingSpaces $trimFixedCharacterTrailingSpaces
        if ($null -ne $change) {
            $decodedRelation = "$($change.SchemaName).$($change.TableName)"
            if (-not $decodedTableCounts.Contains($decodedRelation)) {
                $decodedTableCounts[$decodedRelation] = 0
            }
            $decodedTableCounts[$decodedRelation] = [int]$decodedTableCounts[$decodedRelation] + 1
            if (-not $pending.ContainsKey($row.xid)) {
                $pending[$row.xid] = New-Object System.Collections.Generic.List[object]
            }
            $pending[$row.xid].Add($change)
        }
    }

    if ($pending.Count -gt 0) {
        throw "Logical decoder returned incomplete transactions; refusing to advance slot."
    }

    # test_decoding already emits committed transactions and their row changes in replay order.
    $orderedEvents = @($batchEvents.ToArray())
    $outputLines = New-Object System.Collections.Generic.List[string]
    $seq = 0
    foreach ($event in $orderedEvents) {
        $seq++
        $outputLines.Add("--$($event.Operation)-$($event.TxId)-$($seq.ToString('D10'))")
        $outputLines.Add($event.Sql)
        $outputLines.Add("GO")
    }

    $outDir = Split-Path -Parent $outputPath
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $batchUtc = [DateTime]::UtcNow
    $batchStamp = $batchUtc.ToString("yyyyMMdd_HHmmssfff")
    $batchLsn = if ([string]::IsNullOrWhiteSpace($lastSeenLsn)) { [string]$slotStateBefore.confirmed_flush_lsn } else { $lastSeenLsn }
    $batchLsnToken = $batchLsn.Replace('/', '_')
    $archiveThisBatch = $archiveBatches -and ($outputLines.Count -gt 0 -or $archiveEmptyBatches)
    $archivePath = if ($archiveThisBatch) { Join-Path $archiveDirectory ("${clientId}_${batchStamp}_${batchLsnToken}.trn") } else { "" }

    if ($archiveThisBatch -and -not (Test-Path -LiteralPath $archiveDirectory)) {
        New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
    }

    if ($outputLines.Count -eq 0) {
        if ($clearOutputWhenEmpty) {
            [System.IO.File]::WriteAllText($outputPath, "")
        }
        if ($archiveThisBatch) {
            [System.IO.File]::WriteAllText($archivePath, "")
        }
    } else {
        [System.IO.File]::WriteAllLines($outputPath, $outputLines)
        if ($archiveThisBatch) {
            [System.IO.File]::WriteAllLines($archivePath, $outputLines)
        }
    }

    $zipPath = ""
    $shouldPackage = $packageEnabled -and ($outputLines.Count -gt 0 -or ($sftpEnabled -and $sftpUploadEmptyFiles))
    if ($shouldPackage) {
        if (-not (Test-Path -LiteralPath $packageDirectory)) {
            New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
        }
        $zipFileName = Expand-BatchTemplate -Template ([string]$package.zip_filename_template) -ClientId $clientId -LastLsn $batchLsn -BatchUtc $batchUtc
        $entryFileName = Expand-BatchTemplate -Template ([string]$package.trn_entry_filename_template) -ClientId $clientId -LastLsn $batchLsn -BatchUtc $batchUtc
        $zipPath = Join-Path $packageDirectory $zipFileName
        New-ZipPackage -TrnPath $outputPath -ZipPath $zipPath -EntryName $entryFileName
    }

    $sftpResult = $null
    $sftpResults = @()
    if ($sftpEnabled) {
        New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path $sentDirectory -Force | Out-Null
        $pendingPackages = @(Get-ChildItem -LiteralPath $packageDirectory -Filter '*.zip' -File |
            Sort-Object LastWriteTimeUtc, Name)
        foreach ($pendingPackage in $pendingPackages) {
            $isCurrentPackage = -not [string]::IsNullOrWhiteSpace($zipPath) -and
                [string]::Equals($pendingPackage.FullName, $zipPath, [StringComparison]::OrdinalIgnoreCase)
            $remoteFileName = if ($isCurrentPackage) {
                Expand-BatchTemplate -Template ([string]$sftp.remote_filename_template) -ClientId $clientId -LastLsn $batchLsn -BatchUtc $batchUtc
            } else {
                $pendingPackage.Name
            }

            $uploadResult = Send-SftpFile -Settings $sftp -LocalPath $pendingPackage.FullName -RemoteFileName $remoteFileName
            $sentPath = Join-Path $sentDirectory $pendingPackage.Name
            Move-Item -LiteralPath $pendingPackage.FullName -Destination $sentPath -Force
            $sftpResults += $uploadResult
            if ($isCurrentPackage) {
                $sftpResult = $uploadResult
                $zipPath = $sentPath
            }
        }
    }

    $archiveFilesDeleted = Remove-ExpiredArchiveFiles -Directory $archiveDirectory -RetentionDays $archiveRetentionDays

    $confirmedFlushLsn = $slotStateBefore.confirmed_flush_lsn
    if (-not [string]::IsNullOrWhiteSpace($lastSeenLsn)) {
        $confirmedFlushLsn = Advance-Slot -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName -TargetLsn $lastSeenLsn
    }

    $slotStateAfter = Get-SlotState -Psql $psql -HostName $pgHost -PortNumber $port -UserName $user -DatabaseName $database -SlotName $slotName

    $tableCounts = [ordered]@{}
    foreach ($tableName in $trackedTables) {
        $tableCounts[$tableName] = 0
    }
    foreach ($event in $orderedEvents) {
        $tableCounts[$event.TargetRelation] = [int]$tableCounts[$event.TargetRelation] + 1
    }

    $checkpointValue = [ordered]@{
        slot_name = $slotName
        confirmed_flush_lsn = $confirmedFlushLsn
        restart_lsn = $slotStateAfter.restart_lsn
        saved_at_utc = $batchUtc.ToString("o")
        last_batch_file = if ($archiveThisBatch) { $archivePath } else { $outputPath }
        statement_count = $orderedEvents.Count
    }
    Save-JsonFile -Path $checkpointPath -Value $checkpointValue

    $lastBatchValue = [ordered]@{
        batch_utc = $batchUtc.ToString("o")
        slot_name = $slotName
        slot_confirmed_flush_lsn_before = $slotStateBefore.confirmed_flush_lsn
        slot_confirmed_flush_lsn_after = $slotStateAfter.confirmed_flush_lsn
        last_seen_lsn = $lastSeenLsn
        raw_decoder_rows = $rawRowCount
        max_changes_per_run = $maxChangesPerRun
        batch_limit_reached = $rawRowCount -ge $maxChangesPerRun
        first_decoded_commit_utc = $firstDecodedCommitUtc
        last_decoded_commit_utc = $lastDecodedCommitUtc
        tracked_statement_count = $orderedEvents.Count
        tracked_change_rows = $matchedRowCount
        decoded_table_change_counts = $decodedTableCounts
        output_path = $outputPath
        archive_path = $archivePath
        archive_retention_days = $archiveRetentionDays
        expired_archive_files_deleted = $archiveFilesDeleted
        trim_fixed_character_trailing_spaces = $trimFixedCharacterTrailingSpaces
        client_id = $clientId
        batch_lsn = $batchLsn
        zip_path = $zipPath
        sftp_enabled = $sftpEnabled
        sftp_transport = 'native_dotnet'
        sftp_uploaded = $sftpResults.Count -gt 0
        sftp_uploaded_count = $sftpResults.Count
        sftp_remote_path = if ($null -ne $sftpResult) { $sftpResult.RemotePath } elseif ($sftpResults.Count -gt 0) { $sftpResults[-1].RemotePath } else { "" }
        sftp_uploaded_bytes = if ($sftpResults.Count -gt 0) { [long]($sftpResults | Measure-Object -Property Size -Sum).Sum } else { 0 }
        sftp_current_package_sha256 = if ($null -ne $sftpResult) { [string]$sftpResult.Sha256 } else { '' }
        tables = $trackedTables
        table_statement_counts = $tableCounts
    }
    Save-JsonFile -Path $lastBatchPath -Value $lastBatchValue

    if (Test-Path -LiteralPath $errorPath) {
        Remove-Item -LiteralPath $errorPath -Force
    }

    Write-Host "Wrote $outputPath with $($orderedEvents.Count) statement(s) and advanced slot $slotName to $confirmedFlushLsn"
}
catch {
    Write-ErrorRecord -Path $errorPath -ErrorRecord $_ -SlotName $slotName -ConfigFilePath $ConfigPath
    throw
}
