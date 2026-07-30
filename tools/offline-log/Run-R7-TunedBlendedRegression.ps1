param(
    [Parameter()]
    [string]$SourceDrive = 'E:',

    [Parameter()]
    [string]$SnapshotDataPath = 'DATA\Oasis',

    [Parameter()]
    [string]$LdfName = 'OASIS_FLUX_log.ldf',

    [Parameter()]
    [string]$SourceServer = 'LOCALHOST\ERPLINK',

    [Parameter()]
    [string]$Database = 'OASIS_FLUX',

    [Parameter()]
    [string]$MetadataSnapshotPath = '.\output\chsc_metadata_flux.snapshot.json',

    [Parameter()]
    [string[]]$Tables = @(
        'oasis.CHSC_PO',
        'oasis.CHSC_POLINE',
        'oasis.CHSC_POLINE_HISTORY',
        'oasis.CHSC_PROJECT',
        'oasis.CHSC_QUOTELINE',
        'oasis.CHSC_QUOTE'
    ),

    [Parameter()]
    [string]$SessionName = ('r7_tuned_blended_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),

    [Parameter()]
    [string]$OutputDir = '.\output',

    [Parameter()]
    [ValidateRange(1,100000)]
    [int]$PerTypeCount = 334,

    [Parameter()]
    [ValidateSet("auto","full","skip")]
    [string]$RawMatchMode = "skip",

    [Parameter()]
    [ValidateRange(1,1440)]
    [int]$WindowMinutes = 10,

    [Parameter()]
    [bool]$EnableAutoTunePhase = $true,

    [Parameter()]
    [string]$TuningProfilePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Ensure-ParentDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function New-ConnString([string]$Server,[string]$Db){
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $b['Data Source'] = $Server
    $b['Initial Catalog'] = $Db
    $b['Integrated Security'] = $true
    $b['TrustServerCertificate'] = $true
    return $b.ConnectionString
}

function Invoke-DataTable([string]$Server,[string]$Db,[string]$Sql){
    $conn = New-Object System.Data.SqlClient.SqlConnection (New-ConnString -Server $Server -Db $Db)
    $cmd = $conn.CreateCommand()
    $cmd.CommandTimeout = 0
    $cmd.CommandText = $Sql
    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    try { [void]$da.Fill($dt) } finally { $da.Dispose(); $conn.Dispose() }
    return ,$dt
}

function Get-PkColumns([string]$Server,[string]$Db,[string]$Schema,[string]$Table){
    $sql = @"
SELECT c.name AS col_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.indexes i ON i.object_id=t.object_id AND i.is_primary_key=1
JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
JOIN sys.columns c ON c.object_id=t.object_id AND c.column_id=ic.column_id
WHERE s.name='$Schema' AND t.name='$Table'
ORDER BY ic.key_ordinal;
"@
    $dt = Invoke-DataTable -Server $Server -Db $Db -Sql $sql
    return @($dt.Rows | ForEach-Object { [string]$_.col_name })
}

function Load-TuningProfiles([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @{} }
    try {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $map = @{}
        if ($obj -and $obj.PSObject.Properties.Name -contains 'profiles') {
            foreach ($p in @($obj.profiles)) {
                if (-not $p) { continue }
                $k = [string]$p.table
                if ([string]::IsNullOrWhiteSpace($k)) { continue }
                $map[$k.ToUpperInvariant()] = [pscustomobject]@{
                    table = $k
                    column = [string]$p.column
                    kind = [string]$p.kind
                    source = 'tuned_store'
                    tuned_at_utc = [string]$p.tuned_at_utc
                }
            }
        }
        return $map
    } catch {
        Write-Warning ("Unable to parse tuning profile file {0}: {1}" -f $Path, $_.Exception.Message)
        return @{}
    }
}

function Save-TuningProfiles([string]$Path, [hashtable]$Profiles) {
    Ensure-ParentDirectory -Path $Path
    $rows = @(
        $Profiles.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    table = $_.Value.table
                    column = $_.Value.column
                    kind = $_.Value.kind
                    tuned_at_utc = if ($_.Value.PSObject.Properties.Name -contains 'tuned_at_utc' -and $_.Value.tuned_at_utc) { [string]$_.Value.tuned_at_utc } else { (Get-Date).ToUniversalTime().ToString('o') }
                }
            }
    )
    $payload = [pscustomobject]@{
        version = 1
        updated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        profiles = $rows
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-AutoTunedProfile([string]$Server,[string]$Db,[string]$Schema,[string]$Table){
    $schemaEsc = $Schema.Replace("'", "''")
    $tableEsc = $Table.Replace("'", "''")
    $sql = @"
SELECT TOP (1)
    c.name AS col_name,
    CASE
        WHEN c.system_type_id IN (40,41,42,43,58,61) THEN 'datetime_tick'
        ELSE 'string_token'
    END AS kind
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
    WHERE i.is_primary_key=1
) pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
WHERE s.name = '$schemaEsc'
  AND t.name = '$tableEsc'
  AND pk.column_id IS NULL
  AND c.is_computed = 0
  AND c.is_identity = 0
  AND c.is_rowguidcol = 0
  AND c.system_type_id IN (35,99,167,175,231,239,40,41,42,43,58,61)
ORDER BY
  CASE
    WHEN c.name IN ('UPDATEUSERID','UPDATEDATE','DESCRIPTION','FREEFORMATT','MFGQUOTE','MANUFACTURERNAME') THEN 0
    ELSE 1
  END,
  CASE WHEN c.system_type_id IN (35,99,167,175,231,239) THEN 0 ELSE 1 END,
  c.max_length DESC,
  c.column_id;
"@
    $dt = Invoke-DataTable -Server $Server -Db $Db -Sql $sql
    if ($dt.Rows.Count -eq 0) { return $null }
    return [pscustomobject]@{
        column = [string]$dt.Rows[0].col_name
        kind = [string]$dt.Rows[0].kind
        source = 'auto_tuned'
        tuned_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-PreferredProfile([string]$SchemaTable){
    switch ($SchemaTable.ToUpperInvariant()) {
        'OASIS.CHSC_PO' {
            return @(
                [pscustomobject]@{ Column='UPDATEUSERID'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_POLINE' {
            return @(
                [pscustomobject]@{ Column='MFGQUOTE'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_POLINE_HISTORY' {
            return @(
                [pscustomobject]@{ Column='MFGQUOTE'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_PROJECT' {
            return @(
                [pscustomobject]@{ Column='UPDATEUSERID'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_QUOTELINE' {
            return @(
                [pscustomobject]@{ Column='MFGQUOTE'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_QUOTE' {
            return @(
                [pscustomobject]@{ Column='UPDATEDATE'; Kind='datetime_tick' }
            )
        }
        'OASIS.CHSC_INVOICELINE' {
            return @(
                [pscustomobject]@{ Column='DESCRIPTION'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_MANUFACTURERS' {
            return @(
                [pscustomobject]@{ Column='MANUFACTURERNAME'; Kind='string_token' }
            )
        }
        'OASIS.CHSC_QUOTEDISTRIBUTOR' {
            return @(
                [pscustomobject]@{ Column='FREEFORMATT'; Kind='string_token' }
            )
        }
        default {
            return @()
        }
    }
}

$userFilter = (whoami)
$statePath = Join-Path $OutputDir ($SessionName + '.state.json')
$runStatePath = Join-Path $OutputDir ($SessionName + '.run.state.json')
$resultPath = Join-Path $OutputDir ($SessionName + '.result.json')
$summaryPath = Join-Path $OutputDir ('session.' + $SessionName + '.summary.json')
$resolvedTuningProfilePath = if ([string]::IsNullOrWhiteSpace($TuningProfilePath)) { Join-Path $OutputDir 'table-tuning-profiles.json' } else { $TuningProfilePath }
$runTag = 'R7' + (Get-Date -Format 'MMddHHmmss')
$tuningProfiles = Load-TuningProfiles -Path $resolvedTuningProfilePath
$tuningPhase = New-Object System.Collections.Generic.List[object]

# 1) Bootstrap the baseline.
& .\tools\offline-log\Run-HybridLdfSingleSnapshotMultiTable.ps1 `
    -SourceDrive $SourceDrive `
    -SnapshotDataPath $SnapshotDataPath `
    -LdfName $LdfName `
    -LiveServerInstance $SourceServer `
    -LiveDatabase $Database `
    -MetadataServerInstance $SourceServer `
    -MetadataDatabase $Database `
    -MetadataSnapshotPath $MetadataSnapshotPath `
    -Tables $Tables `
    -Users @($userFilter) `
    -WindowMinutes $WindowMinutes `
    -StatePath $statePath `
    -BootstrapFirstRun $true `
    -ApplyToTarget $false `
    -GenerateUndo $false `
    -ExportBeforeAfter $false `
    -ExportRowHistory $false `
    -OutputDir $OutputDir `
    -AllowStartLsnRetryWithoutBound $false `
    -RawMatchMode $RawMatchMode `
    -SessionName ($SessionName + '_bootstrap') | Out-Null

# 2) Generate tuned blended mutations.
$generated = New-Object System.Collections.Generic.List[object]
foreach($t in $Tables){
    $schema,$name = $t.Split('.')
    $pkCols = @(Get-PkColumns -Server $SourceServer -Db $Database -Schema $schema -Table $name)
    if ($pkCols.Count -eq 0) {
        $generated.Add([pscustomobject]@{ table=$t; picked=0; upd=0; del=0; ins=0; note='No PK'; status='FAIL' }) | Out-Null
        continue
    }

    $profile = @(Get-PreferredProfile -SchemaTable $t)
    $profileSource = 'built_in'
    if ($profile.Count -eq 0) {
        $existing = $tuningProfiles[$t.ToUpperInvariant()]
        if ($existing) {
            $profile = @([pscustomobject]@{ Column=[string]$existing.column; Kind=[string]$existing.kind })
            $profileSource = 'tuned_store'
        }
    }
    if ($profile.Count -eq 0 -and $EnableAutoTunePhase) {
        $auto = Get-AutoTunedProfile -Server $SourceServer -Db $Database -Schema $schema -Table $name
        if ($auto) {
            $profile = @([pscustomobject]@{ Column=[string]$auto.column; Kind=[string]$auto.kind })
            $profileSource = 'auto_tuned'
            $tuningProfiles[$t.ToUpperInvariant()] = [pscustomobject]@{
                table = $t
                column = [string]$auto.column
                kind = [string]$auto.kind
                tuned_at_utc = [string]$auto.tuned_at_utc
            }
            $tuningPhase.Add([pscustomobject]@{
                table = $t
                column = [string]$auto.column
                kind = [string]$auto.kind
                source = 'auto_tuned'
                status = 'CREATED'
            }) | Out-Null
        }
    }
    if ($profile.Count -eq 0) {
        $generated.Add([pscustomobject]@{ table=$t; picked=0; upd=0; del=0; ins=0; note='No tuned profile'; profile_source='none'; status='FAIL' }) | Out-Null
        continue
    }

    $keyJoin = ($pkCols | ForEach-Object { "b.[$_] = t.[$_]" }) -join ' AND '
    $keyOrder = ($pkCols | ForEach-Object { "t.[$_]" }) -join ', '
    $pickCount = $PerTypeCount * 3
    $updFrom = 1
    $updTo = $PerTypeCount
    $delFrom = $PerTypeCount + 1
    $delTo = $PerTypeCount * 2
    $insFrom = $delFrom
    $insTo = $delTo
    $sql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RunTag NVARCHAR(64) = '$runTag';
DECLARE @objId INT = OBJECT_ID('[$schema].[$name]');
IF @objId IS NULL
BEGIN
  SELECT CAST(0 AS INT) AS picked, CAST(0 AS INT) AS upd, CAST(0 AS INT) AS del, CAST(0 AS INT) AS ins, CAST('Table not found' AS NVARCHAR(200)) AS note, CAST('FAIL' AS NVARCHAR(20)) AS status;
  RETURN;
END

IF OBJECT_ID('tempdb..#bak') IS NOT NULL DROP TABLE #bak;
SELECT TOP ($pickCount) t.*, ROW_NUMBER() OVER (ORDER BY $keyOrder) AS __rn
INTO #bak
FROM [$schema].[$name] t WITH (READPAST)
ORDER BY $keyOrder;

DECLARE @picked INT = (SELECT COUNT(1) FROM #bak);
IF @picked = 0
BEGIN
  SELECT CAST(0 AS INT) AS picked, CAST(0 AS INT) AS upd, CAST(0 AS INT) AS del, CAST(0 AS INT) AS ins, CAST('No rows picked' AS NVARCHAR(200)) AS note, CAST('FAIL' AS NVARCHAR(20)) AS status;
  RETURN;
END

DECLARE @col SYSNAME = NULL, @typeId INT = NULL, @maxLen INT = NULL, @kind NVARCHAR(40) = NULL;
"@

    foreach($pref in $profile){
        $col = $pref.Column.Replace("'", "''")
        $kind = $pref.Kind.Replace("'", "''")
        $sql += @"
IF @col IS NULL AND EXISTS (
    SELECT 1
    FROM sys.columns c
    WHERE c.object_id = @objId
      AND c.name = '$col'
      AND c.is_computed = 0
      AND c.is_identity = 0
)
BEGIN
    SELECT TOP (1)
      @col = c.name,
      @typeId = c.system_type_id,
      @maxLen = c.max_length,
      @kind = '$kind'
    FROM sys.columns c
    WHERE c.object_id = @objId
      AND c.name = '$col';
END

"@
    }

    $sql += @"
IF @col IS NULL
BEGIN
  SELECT CAST(@picked AS INT) AS picked, CAST(0 AS INT) AS upd, CAST(0 AS INT) AS del, CAST(0 AS INT) AS ins, CAST('No tuned mutable column found' AS NVARCHAR(200)) AS note, CAST('FAIL' AS NVARCHAR(20)) AS status;
  RETURN;
END

DECLARE @setList NVARCHAR(MAX) = N'';
IF @kind = N'datetime_tick'
BEGIN
  SET @setList = QUOTENAME(@col) + N' = DATEADD(second, b.__rn, SYSUTCDATETIME())';
END
ELSE
BEGIN
  DECLARE @charLen INT = CASE WHEN @typeId IN (231,239) THEN CASE WHEN @maxLen = -1 THEN -1 ELSE @maxLen / 2 END ELSE @maxLen END;
  IF @charLen IS NULL OR @charLen = 0 SET @charLen = 1;
  IF @charLen = -1
    SET @setList = QUOTENAME(@col) + N' = @RunTag + RIGHT(REPLICATE(N''0'', 6) + CAST(b.__rn AS nvarchar(10)), 6)';
  ELSE
    SET @setList = QUOTENAME(@col) + N' = LEFT(@RunTag + RIGHT(REPLICATE(N''0'', 6) + CAST(b.__rn AS nvarchar(10)), 6), ' + CAST(@charLen AS nvarchar(20)) + N')';
END

DECLARE @upd INT = 0, @del INT = 0, @ins INT = 0;
DECLARE @cols NVARCHAR(MAX) = STUFF((
  SELECT N', ' + QUOTENAME(c.name)
  FROM sys.columns c
  WHERE c.object_id = @objId
    AND c.is_computed = 0
    AND c.is_identity = 0
  ORDER BY c.column_id
  FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, N'');

DECLARE @sqlUpd NVARCHAR(MAX) = N'
UPDATE t
SET ' + @setList + N'
FROM [$schema].[$name] t
JOIN #bak b ON $keyJoin
WHERE b.__rn BETWEEN $updFrom AND $updTo;';
EXEC sp_executesql @sqlUpd, N'@RunTag nvarchar(64)', @RunTag=@RunTag;
SET @upd = @@ROWCOUNT;

DELETE t
FROM [$schema].[$name] t
JOIN #bak b ON $keyJoin
WHERE b.__rn BETWEEN $delFrom AND $delTo;
SET @del = @@ROWCOUNT;

DECLARE @sqlIns NVARCHAR(MAX) = N'
INSERT INTO [$schema].[$name] (' + @cols + N')
SELECT ' + @cols + N' FROM #bak WHERE __rn BETWEEN $insFrom AND $insTo;';
EXEC sp_executesql @sqlIns;
SET @ins = @@ROWCOUNT;

SELECT CAST(@picked AS INT) AS picked,
       CAST(@upd AS INT) AS upd,
       CAST(@del AS INT) AS del,
       CAST(@ins AS INT) AS ins,
       CAST((N'column=' + @col + N';kind=' + @kind) AS NVARCHAR(200)) AS note,
       CAST(@@SPID AS INT) AS spid,
       CAST('OK' AS NVARCHAR(20)) AS status;
"@

    $dt = Invoke-DataTable -Server $SourceServer -Db $Database -Sql $sql
    $row = $dt.Rows[0]
    $generated.Add([pscustomobject]@{
        table = $t
        picked = [int]$row.picked
        upd = [int]$row.upd
        del = [int]$row.del
        ins = [int]$row.ins
        note = [string]$row.note
        profile_source = $profileSource
        spid = if ($row.PSObject.Properties.Name -contains 'spid') { [int]$row.spid } else { 0 }
        status = [string]$row.status
    }) | Out-Null
}

if ($EnableAutoTunePhase) {
    Save-TuningProfiles -Path $resolvedTuningProfilePath -Profiles $tuningProfiles
}

$mutationSpids = @(
    $generated.ToArray() |
        Where-Object { $_.status -eq 'OK' -and $_.spid -gt 0 } |
        Select-Object -ExpandProperty spid -Unique |
        Sort-Object
)

# 3) Run from saved baseline.
& .\tools\offline-log\Run-HybridLdfSingleSnapshotMultiTable.ps1 `
    -SourceDrive $SourceDrive `
    -SnapshotDataPath $SnapshotDataPath `
    -LdfName $LdfName `
    -LiveServerInstance $SourceServer `
    -LiveDatabase $Database `
    -MetadataServerInstance $SourceServer `
    -MetadataDatabase $Database `
    -MetadataSnapshotPath $MetadataSnapshotPath `
    -Tables $Tables `
    -Users @($userFilter) `
    -WindowMinutes $WindowMinutes `
    -StatePath $runStatePath `
    -BootstrapFirstRun $false `
    -Spids $mutationSpids `
    -ApplyToTarget $false `
    -OutputDir $OutputDir `
    -AllowStartLsnRetryWithoutBound $false `
    -RawMatchMode $RawMatchMode `
    -SessionName $SessionName | Out-Null

$summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
$result = [pscustomobject]@{
    session = $SessionName
    token = $runTag
    source = "$SourceServer/$Database"
    user_filter = $userFilter
    generated = @($generated.ToArray())
    tuning_phase = @($tuningPhase.ToArray())
    tuning_profile_path = $resolvedTuningProfilePath
    manifest_record_count = [int]$summary.manifest_record_count
    manifest_transaction_count = [int]$summary.manifest_transaction_count
    results = $summary.results
    summary_path = $summaryPath
    state_path = $statePath
}
$result | ConvertTo-Json -Depth 12 | Set-Content $resultPath -Encoding UTF8
Get-Content $resultPath -Raw
