param(
    [string]$Database = "OASIS_DATABASE",
    [string]$PgHost = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$CredentialsPath = "C:\Users\Public\Downloads\postgresql-credentials.txt",
    [string]$SlotName = "aotransact_postgresql_slot",
    [string]$OutputPath = "C:\ProgramData\AOtransactPostgreSQL\transactions.trn",
    [switch]$ResetState
)

$ErrorActionPreference = "Stop"

function Get-PostgresPassword {
    param([string]$Path)

    $passwordLine = Get-Content -LiteralPath $Path | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if (-not $passwordLine) {
        throw "Password entry not found in $Path"
    }

    return $passwordLine.Substring("Password=".Length)
}

function Get-TableMetadata {
    param(
        [string]$Psql,
        [string]$HostName,
        [int]$PortNumber,
        [string]$UserName,
        [string]$DbName
    )

    $sql = @"
COPY (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        a.attnum AS ordinal_position,
        a.attname AS column_name,
        a.attname AS raw_column_name,
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
      AND n.nspname IN ('dbo', 'oasis')
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY n.nspname, c.relname, a.attnum
) TO STDOUT WITH CSV HEADER;
"@

    $rows = & $Psql -h $HostName -p $PortNumber -U $UserName -d $DbName -v ON_ERROR_STOP=1 -c $sql | ConvertFrom-Csv
    $metadata = @{}

    foreach ($row in $rows) {
        $key = "$($row.schema_name).$($row.table_name)"
        if (-not $metadata.ContainsKey($key)) {
            $metadata[$key] = [ordered]@{
                Columns = @()
                PrimaryKeys = @()
            }
        }

        $entry = [ordered]@{
            Name = $row.column_name
            SqlServerQuotedName = "[" + $row.column_name.Replace("]", "]]") + "]"
        }
        $metadata[$key].Columns += $entry
        if ($row.is_primary_key -eq 't') {
            $metadata[$key].PrimaryKeys += $entry
        }
    }

    return $metadata
}

function Split-SectionTokens {
    param([string]$Text)

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

        $literal = $match.Groups['value'].Value
        if ($literal -ieq 'null') {
            $literal = 'NULL'
        }

        $result[$normalized] = [ordered]@{
            Name = $normalized
            RenderedName = $name
            Literal = $literal
        }
    }

    return $result
}

function Parse-ChangeLine {
    param([string]$Line)

    $match = [regex]::Match($Line, '^table\s+(?<relation>.+?):\s+(?<operation>INSERT|UPDATE|DELETE):\s*(?<detail>.*)$')
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

    if ($op -eq 'UPDATE' -and $detail -match '^old-key:\s*(?<old>.*?)\s+new-tuple:\s*(?<new>.*)$') {
        $oldValues = Split-SectionTokens -Text $matches['old']
        $newValues = Split-SectionTokens -Text $matches['new']
    } else {
        $newValues = Split-SectionTokens -Text $detail
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
    $result = [regex]::Replace($result, '\(\(\[([^\]]+)\]\s*=\s*(.*?)\)\s+OR\s+\(\[\1\]\s+IS\s+NULL\s+AND\s+\2\s+IS\s+NULL\)\)', { param($m) $m.Value })
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

function Build-WhereClause {
    param(
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$Values
    )

    $parts = @()
    $keyColumns = if ($TableMeta.PrimaryKeys.Count -gt 0) { $TableMeta.PrimaryKeys } else { $TableMeta.Columns }

    foreach ($column in $keyColumns) {
        if (-not $Values.Contains($column.Name)) {
            continue
        }
        $literal = $Values[$column.Name].Literal
        if ($literal -eq 'NULL') {
            $parts += "$($column.SqlServerQuotedName) IS NULL"
        } else {
            $parts += "(($($column.SqlServerQuotedName) = $literal) OR ($($column.SqlServerQuotedName) IS NULL AND $literal IS NULL))"
        }
    }

    if ($parts.Count -eq 0) {
        throw "Could not build WHERE clause because no key values were present."
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

    $sqlServerRelation = Convert-RelationToSqlServer -Relation $Relation
    return "INSERT INTO $sqlServerRelation ($($columns -join ', ')) VALUES ($($literals -join ', '));"
}

function Build-DeleteSql {
    param(
        [string]$Relation,
        [hashtable]$TableMeta,
        [System.Collections.Specialized.OrderedDictionary]$OldValues
    )

    $whereClause = Build-WhereClause -TableMeta $TableMeta -Values $OldValues
    $sqlServerRelation = Convert-RelationToSqlServer -Relation $Relation
    return "DELETE FROM $sqlServerRelation WHERE $whereClause;"
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
        if (-not $NewValues.Contains($column.Name)) {
            continue
        }

        $isPk = $TableMeta.PrimaryKeys.Name -contains $column.Name
        if ($isPk) {
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
            if ($TableMeta.PrimaryKeys.Name -contains $column.Name) {
                continue
            }
            if ($NewValues.Contains($column.Name)) {
                $setParts += "$($column.SqlServerQuotedName) = $($NewValues[$column.Name].Literal)"
            }
        }
    }

    if ($setParts.Count -eq 0) {
        throw "Could not build UPDATE SET clause."
    }

    $whereClause = Build-WhereClause -TableMeta $TableMeta -Values $(if ($OldValues.Count -gt 0) { $OldValues } else { $NewValues })
    $sqlServerRelation = Convert-RelationToSqlServer -Relation $Relation
    return "UPDATE $sqlServerRelation SET $($setParts -join ', ') WHERE $whereClause;"
}

function Convert-ChangeToSql {
    param(
        [pscustomobject]$Change,
        [hashtable]$Metadata
    )

    $metaKey = "$($Change.SchemaName).$($Change.TableName)"
    if (-not $Metadata.ContainsKey($metaKey)) {
        throw "Metadata not found for $metaKey"
    }

    $tableMeta = $Metadata[$metaKey]
    switch ($Change.Operation) {
        'INSERT' { return Build-InsertSql -Relation $Change.Relation -TableMeta $tableMeta -Values $Change.NewValues }
        'DELETE' { return Build-DeleteSql -Relation $Change.Relation -TableMeta $tableMeta -OldValues $Change.OldValues }
        'UPDATE' { return Build-UpdateSql -Relation $Change.Relation -TableMeta $tableMeta -OldValues $Change.OldValues -NewValues $Change.NewValues }
        default { throw "Unsupported operation $($Change.Operation)" }
    }
}

$env:PGPASSWORD = Get-PostgresPassword -Path $CredentialsPath
$psql = "C:\Program Files\PostgreSQL\17\pgsql\bin\psql.exe"

$metadata = Get-TableMetadata -Psql $psql -HostName $PgHost -PortNumber $Port -UserName $User -DbName $Database

$copySql = @"
COPY (
    SELECT lsn::text, xid::text, data
    FROM pg_logical_slot_get_changes('$SlotName', NULL, NULL, 'include-timestamp', 'on')
) TO STDOUT WITH CSV HEADER;
"@
$rows = & $psql -h $PgHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -c $copySql | ConvertFrom-Csv

$pending = @{}
$newEvents = New-Object System.Collections.Generic.List[object]

foreach ($row in $rows) {
    $data = $row.data
    if ($data -match '^BEGIN\s+(?<xid>\d+)$') {
        $pending[$matches['xid']] = New-Object System.Collections.Generic.List[object]
        continue
    }

    if ($data -match '^COMMIT\s+(?<xid>\d+)\s+\(at\s+(?<ts>[^)]+)\)$') {
        $xid = $matches['xid']
        if ($pending.ContainsKey($xid)) {
            $commitTime = [DateTimeOffset]::Parse($matches['ts'], [System.Globalization.CultureInfo]::InvariantCulture)
            foreach ($change in $pending[$xid]) {
                $newEvents.Add([pscustomobject]@{
                    TxId = $xid
                    Operation = $change.Operation
                    Relation = $change.Relation
                    Sql = (Convert-ChangeToSql -Change $change -Metadata $metadata)
                    CommitTime = $commitTime.UtcDateTime.ToString("o")
                })
            }
            $pending.Remove($xid) | Out-Null
        }
        continue
    }

    $change = Parse-ChangeLine -Line $data
    if ($null -ne $change) {
        if (-not $pending.ContainsKey($row.xid)) {
            $pending[$row.xid] = New-Object System.Collections.Generic.List[object]
        }
        $pending[$row.xid].Add($change)
    }
}

$batchEvents = @(
    $newEvents |
    Sort-Object { [DateTimeOffset]::Parse($_.CommitTime) }, TxId, Operation
)

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$seq = 0
foreach ($event in $batchEvents) {
    $seq++
    $lines.Add("--$($event.Operation)-$($event.TxId)-$($seq.ToString('D10'))")
    $lines.Add((Normalize-ToSqlServerSql -Sql $event.Sql))
    $lines.Add("GO")
}

if ($lines.Count -eq 0) {
    [System.IO.File]::WriteAllText($OutputPath, "")
} else {
    [System.IO.File]::WriteAllLines($OutputPath, $lines)
}
Write-Host "Wrote $OutputPath with $($batchEvents.Count) statement(s) consumed since the previous run using slot $SlotName"
