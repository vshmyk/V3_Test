using System.Diagnostics;
using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

var argMap = ParseArgs(args);
if (!argMap.TryGetValue("config", out var configPath) || string.IsNullOrWhiteSpace(configPath))
{
    Console.Error.WriteLine("Required: --config <production.service.config.json> [--once]");
    return 2;
}

configPath = Path.GetFullPath(configPath, Environment.CurrentDirectory);
if (!File.Exists(configPath))
{
    Console.Error.WriteLine($"Config not found: {configPath}");
    return 2;
}

var json = File.ReadAllText(configPath);
var cfg = JsonSerializer.Deserialize<Config>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
    ?? throw new InvalidOperationException($"Failed to parse config: {configPath}");
var runtime = Runtime.From(cfg, configPath, argMap.ContainsKey("once"));

Directory.CreateDirectory(runtime.Paths.OutputDir);
Directory.CreateDirectory(Path.GetDirectoryName(runtime.Paths.StatePath)!);
Directory.CreateDirectory(Path.GetDirectoryName(runtime.Paths.LockFilePath)!);
Directory.CreateDirectory(Path.GetDirectoryName(runtime.Paths.HealthFilePath)!);
Directory.CreateDirectory(runtime.Paths.LogDir);
Directory.CreateDirectory(runtime.Paths.ArchiveDir);

if (!runtime.Pipeline.RawMatchMode.Equals("skip", StringComparison.OrdinalIgnoreCase))
    throw new NotSupportedException("The .NET runner currently supports raw_match_mode=skip only.");
if (!runtime.Pipeline.UseCompiledConverter)
    throw new NotSupportedException("The .NET runner currently requires use_compiled_converter=true.");
if (!File.Exists(runtime.Pipeline.CompiledConverterPath))
    throw new FileNotFoundException("Compiled converter not found", runtime.Pipeline.CompiledConverterPath);
if (!File.Exists(runtime.Paths.MetadataSnapshotPath))
    throw new FileNotFoundException("Metadata snapshot not found", runtime.Paths.MetadataSnapshotPath);
if (runtime.Pipeline.Tables.Count == 0 && !IsRawOfflineExploration(runtime))
    throw new InvalidOperationException("pipeline.tables is empty in config.");

var logPath = Path.Combine(runtime.Paths.LogDir, $"{runtime.Service.Name}_{DateTime.UtcNow:yyyyMMdd}.log");
await using var lockStream = TryAcquireLock(runtime.Paths.LockFilePath, logPath);
if (lockStream is null)
    return 10;

while (true)
{
    var sessionName = $"prod_{DateTime.UtcNow:yyyyMMdd_HHmmss}";
    var summaryPath = Path.Combine(runtime.Paths.OutputDir, $"session.{sessionName}.summary.json");
    var health = new Dictionary<string, object?>
    {
        ["service_name"] = runtime.Service.Name,
        ["session"] = sessionName,
        ["started_utc"] = DateTime.UtcNow.ToString("O"),
        ["summary_path"] = summaryPath,
        ["config_path"] = runtime.ConfigPath
    };
    Log(logPath, $"Cycle start: session={sessionName}");
    try
    {
        var summary = await RunCycleAsync(runtime, logPath, sessionName, summaryPath);
        health["success"] = true;
        health["ended_utc"] = DateTime.UtcNow.ToString("O");
        await WriteJsonAsync(runtime.Paths.HealthFilePath, health);
        Log(logPath, $"Cycle success: session={sessionName}");
    }
    catch (Exception ex)
    {
        health["success"] = false;
        health["error"] = ex.Message;
        health["ended_utc"] = DateTime.UtcNow.ToString("O");
        await WriteJsonAsync(runtime.Paths.HealthFilePath, health);
        Log(logPath, $"Cycle failed: session={sessionName}; error={ex.Message}");
        throw;
    }

    Archive(runtime, logPath);
    if (!runtime.Service.Loop)
        break;
    await Task.Delay(TimeSpan.FromMinutes(runtime.Service.IntervalMinutes));
}
return 0;

static async Task<object> RunCycleAsync(Runtime runtime, string logPath, string sessionName, string summaryPath)
{
    var timeout = TimeSpan.FromMinutes(runtime.Service.MaxCycleMinutes);
    var startupSw = Stopwatch.StartNew();
    var tablesKey = string.Join("|", runtime.Pipeline.Tables.Select(t => t.Trim().ToUpperInvariant()).Distinct().OrderBy(t => t));
    var filtersKey = $"ops=DMLALL;spids={string.Join(',', runtime.Pipeline.Spids.OrderBy(x => x))};users={string.Join(',', runtime.Pipeline.Users.Select(u => u.Trim().ToUpperInvariant()).Distinct().OrderBy(x => x))};exclude={string.Join(',', runtime.Pipeline.ExcludeUsers.Select(u => u.Trim().ToUpperInvariant()).Distinct().OrderBy(x => x))}";
    var sourceSignature = $"{runtime.Pipeline.SourceDrive.Trim().ToUpperInvariant()}|{NormalizePath(runtime.Pipeline.SnapshotDataPath)}|{runtime.Pipeline.LdfName.Trim().ToUpperInvariant()}";

    var stateLoadSw = Stopwatch.StartNew();
    var state = LoadState(runtime.Paths.StatePath);
    stateLoadSw.Stop();
    var startupStateLoadMs = (int)stateLoadSw.ElapsedMilliseconds;
    var startupShadowReconcileMs = 0;
    var startupLsnPrecheckMs = 0;
    var startupBootstrapMs = 0;
    var bootstrapPerformed = false;
    var lsnResetDetected = false;

    if (state is not null && string.IsNullOrWhiteSpace(runtime.Pipeline.ReuseShadowDevice))
    {
        var reconcileSw = Stopwatch.StartNew();
        if (!string.IsNullOrWhiteSpace(state.active_shadow_id) && TestShadowActive(state.active_shadow_id))
        {
            Log(logPath, $"Found active shadow from prior run in state: {state.active_shadow_id}. Deleting before new session.");
            DeleteShadow(state.active_shadow_id);
        }
        state.active_shadow_id = null;
        state.active_shadow_device = null;
        state.active_shadow_session = null;
        state.active_shadow_active = false;
        SaveState(runtime.Paths.StatePath, state);
        reconcileSw.Stop();
        startupShadowReconcileMs = (int)reconcileSw.ElapsedMilliseconds;
    }

    var effectiveStartLsn = runtime.Pipeline.StartLsn;
    var effectiveStartLsnPreReset = effectiveStartLsn;
    if (string.IsNullOrWhiteSpace(effectiveStartLsn) && state is not null &&
        string.Equals(state.live_server_instance, runtime.Pipeline.LiveServerInstance, StringComparison.OrdinalIgnoreCase) &&
        string.Equals(state.live_database, runtime.Pipeline.LiveDatabase, StringComparison.OrdinalIgnoreCase) &&
        string.Equals(state.tables_key, tablesKey, StringComparison.OrdinalIgnoreCase) &&
        string.Equals(state.filters_key, filtersKey, StringComparison.OrdinalIgnoreCase) &&
        (string.IsNullOrWhiteSpace(state.source_signature) || string.Equals(state.source_signature, sourceSignature, StringComparison.OrdinalIgnoreCase)) &&
        IsValidLsn(state.last_lsn))
    {
        effectiveStartLsn = state.last_lsn;
    }

    string? latestLiveLsn = null;
    if (!UsesOfflineRead(runtime) && !runtime.Pipeline.SkipLsnHeadPrecheck)
    {
        var lsnSw = Stopwatch.StartNew();
        latestLiveLsn = await GetLiveHeadLsnAsync(runtime);
        lsnSw.Stop();
        startupLsnPrecheckMs = (int)lsnSw.ElapsedMilliseconds;
        if (IsValidLsn(effectiveStartLsn) && IsValidLsn(latestLiveLsn) && CompareLsn(latestLiveLsn!, effectiveStartLsn!) < 0)
        {
            effectiveStartLsn = null;
            lsnResetDetected = true;
        }
    }

    if (!UsesOfflineRead(runtime) && string.IsNullOrWhiteSpace(effectiveStartLsn) && runtime.Pipeline.BootstrapFirstRun)
    {
        var bootstrapSw = Stopwatch.StartNew();
        latestLiveLsn ??= await GetLiveHeadLsnAsync(runtime);
        var bootstrapState = state ?? new RunnerState();
        bootstrapState.version = 1;
        bootstrapState.updated_at_utc = DateTime.UtcNow.ToString("O");
        bootstrapState.bootstrap_only = true;
        bootstrapState.live_server_instance = runtime.Pipeline.LiveServerInstance;
        bootstrapState.live_database = runtime.Pipeline.LiveDatabase;
        bootstrapState.tables_key = tablesKey;
        bootstrapState.filters_key = filtersKey;
        bootstrapState.source_signature = sourceSignature;
        bootstrapState.last_lsn = latestLiveLsn;
        SaveState(runtime.Paths.StatePath, bootstrapState);
        bootstrapSw.Stop();
        startupBootstrapMs = (int)bootstrapSw.ElapsedMilliseconds;
        bootstrapPerformed = true;
        var bootstrapSummary = new Dictionary<string, object?>
        {
            ["generated_utc"] = DateTime.UtcNow.ToString("O"),
            ["session_name"] = sessionName,
            ["bootstrap_only"] = true,
            ["start_lsn"] = latestLiveLsn,
            ["note"] = "First run bootstrap captured live head LSN and exited without processing historical transactions."
        };
        await WriteJsonAsync(summaryPath, bootstrapSummary);
        return bootstrapSummary;
    }

    startupSw.Stop();
    var startupPreStep0Ms = (int)startupSw.ElapsedMilliseconds;

    var step1Sw = Stopwatch.StartNew();
    string? shadowId = null;
    string shadowDevice;
    string ldfPath = string.Empty;
    if (!string.IsNullOrWhiteSpace(runtime.Pipeline.DirectLdfPath))
    {
        shadowDevice = "<direct-ldf>";
        ldfPath = runtime.Pipeline.DirectLdfPath;
        Log(logPath, $"Step 1/4: Use direct LDF path {ldfPath}");
    }
    else if (!string.IsNullOrWhiteSpace(runtime.Pipeline.ReuseShadowDevice))
    {
        shadowDevice = runtime.Pipeline.ReuseShadowDevice.Trim().TrimEnd('\\');
        Log(logPath, $"Step 1/4: Reuse existing shadow device {shadowDevice}");
    }
    else
    {
        Log(logPath, $"Step 1/4: Create one shadow copy for {runtime.Pipeline.SourceDrive}");
        var create = await RunProcessAsync("vssadmin", new[] { "create", "shadow", $"/for={runtime.Pipeline.SourceDrive}" }, timeout);
        shadowId = ParseMatch(Regexes.ShadowId, create.StdOut + Environment.NewLine + create.StdErr) ?? throw new InvalidOperationException("Could not parse shadow copy ID from vssadmin output.");
        shadowDevice = ParseMatch(Regexes.ShadowDevice, create.StdOut + Environment.NewLine + create.StdErr) ?? throw new InvalidOperationException("Could not parse shadow copy device from vssadmin output.");
        UpdateShadowTracking(runtime.Paths.StatePath, shadowId, shadowDevice, true, sessionName);
    }
    if (string.IsNullOrWhiteSpace(runtime.Pipeline.DirectLdfPath))
        ldfPath = Path.Combine(shadowDevice, runtime.Pipeline.SnapshotDataPath.Replace('/', '\\').TrimStart('\\'), runtime.Pipeline.LdfName);
    if (!File.Exists(ldfPath)) throw new FileNotFoundException("LDF file not found in shadow copy", ldfPath);
    runtime.Pipeline.CurrentLdfPath = ldfPath;
    step1Sw.Stop();
    var step1Ms = (int)step1Sw.ElapsedMilliseconds;
    Log(logPath, $"Step 1 timing: {step1Ms} ms");
    var manifestPath = Path.Combine(runtime.Paths.OutputDir, $"live-dml-manifest.{sessionName}.json");
    var step2Sw = Stopwatch.StartNew();
    Log(logPath, UsesOfflineRead(runtime) ? "Step 2/4: Build one offline manifest from shadow-copy LDF" : "Step 2/4: Build one live manifest for all tables");
    var manifest = await BuildManifestAsync(runtime, logPath, manifestPath, effectiveStartLsn);
    step2Sw.Stop();
    var step2Ms = (int)step2Sw.ElapsedMilliseconds;
    Log(logPath, $"Step 2 timing: {step2Ms} ms");

    var hybridPath = Path.Combine(runtime.Paths.OutputDir, $"raw-ldf-hybrid-matches.{sessionName}.json");
    var step3Sw = Stopwatch.StartNew();
    Log(logPath, "Step 3/4: Skip offline raw-LDF match (raw_match_mode=skip)");
    await WriteJsonAsync(hybridPath, new Dictionary<string, object?>
    {
        ["collected_at_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["manifest_path"] = manifestPath,
        ["tail_bytes"] = 0,
        ["manifest_record_count"] = manifest.RecordCount,
        ["manifest_unique_keys"] = manifest.RecordCount,
        ["matched_record_count"] = 0,
        ["matched_unique_keys"] = 0,
        ["unmatched_record_count"] = manifest.RecordCount,
        ["parser_diagnostics"] = new Dictionary<string, object?> { ["raw_match_mode"] = manifest.RecordCount == 0 ? "skip_no_manifest_rows" : "skip" },
        ["note"] = manifest.RecordCount == 0 ? "Raw LDF matching skipped because manifest_record_count=0." : "Raw LDF matching skipped by runner mode.",
        ["records"] = Array.Empty<object>()
    });
    step3Sw.Stop();
    var step3Ms = (int)step3Sw.ElapsedMilliseconds;
    Log(logPath, $"Step 3 timing: {step3Ms} ms");

    var step4Sw = Stopwatch.StartNew();
    Log(logPath, IsRawOfflineExploration(runtime) ? "Step 4/4: Skip conversion for raw offline exploration mode" : "Step 4/4: Convert/apply per table");
    var tableResults = new List<Dictionary<string, object?>>();
    if (!IsRawOfflineExploration(runtime))
    {
        foreach (var table in runtime.Pipeline.Tables)
        {
            tableResults.Add(await RunConvertAsync(runtime, table, manifestPath, sessionName, timeout));
        }
    }
    var aggregateTrnPath = ResolveAggregateTrnPath(runtime, sessionName);
    if (!string.IsNullOrWhiteSpace(aggregateTrnPath))
    {
        Log(logPath, $"Step 4 aggregation: combine per-table TRN parts into {aggregateTrnPath}");
        CombineTrnOutputs(tableResults, aggregateTrnPath);
        foreach (var result in tableResults)
            result["aggregate_trn_path"] = aggregateTrnPath;
    }
    step4Sw.Stop();
    var step4Ms = (int)step4Sw.ElapsedMilliseconds;
    Log(logPath, $"Step 4 timing: {step4Ms} ms");

    var newState = state ?? new RunnerState();
    newState.version = 1;
    newState.updated_at_utc = DateTime.UtcNow.ToString("O");
    newState.bootstrap_only = false;
    newState.live_server_instance = runtime.Pipeline.LiveServerInstance;
    newState.live_database = runtime.Pipeline.LiveDatabase;
    newState.tables_key = tablesKey;
    newState.filters_key = filtersKey;
    newState.source_signature = sourceSignature;
    newState.last_lsn = manifest.ScanEndLsn ?? effectiveStartLsn;
    newState.active_shadow_id = runtime.Pipeline.SkipShadowCleanup ? shadowId : null;
    newState.active_shadow_device = runtime.Pipeline.SkipShadowCleanup ? shadowDevice : null;
    newState.active_shadow_session = runtime.Pipeline.SkipShadowCleanup ? sessionName : null;
    newState.active_shadow_active = runtime.Pipeline.SkipShadowCleanup && !string.IsNullOrWhiteSpace(shadowId);
    SaveState(runtime.Paths.StatePath, newState);

    if (!runtime.Pipeline.SkipShadowCleanup && !string.IsNullOrWhiteSpace(shadowId))
    {
        Log(logPath, $"Cleanup: deleting shadow copy {shadowId}");
        try
        {
            DeleteShadow(shadowId);
            UpdateShadowTracking(runtime.Paths.StatePath, null, null, false, null);
        }
        catch (Exception ex)
        {
            Log(logPath, $"Cleanup failed for shadow copy {shadowId}: {ex.Message}");
        }
    }

    var summary = new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["session_name"] = sessionName,
        ["mode"] = "dotnet_runner",
        ["startup"] = new Dictionary<string, object?>
        {
            ["startup_pre_step0_ms"] = startupPreStep0Ms,
            ["startup_state_load_ms"] = startupStateLoadMs,
            ["startup_shadow_reconcile_ms"] = startupShadowReconcileMs,
            ["startup_lsn_precheck_ms"] = startupLsnPrecheckMs,
            ["startup_bootstrap_ms"] = startupBootstrapMs,
            ["bootstrap_performed"] = bootstrapPerformed
        },
        ["timings_ms"] = new Dictionary<string, object?>
        {
            ["step1_shadow_ms"] = step1Ms,
            ["step2_manifest_ms"] = step2Ms,
            ["step3_raw_ldf_ms"] = step3Ms,
            ["step4_convert_apply_ms"] = step4Ms,
            ["wrapper_total_ms"] = startupPreStep0Ms + step1Ms + step2Ms + step3Ms + step4Ms
        },
        ["start_lsn"] = new Dictionary<string, object?>
        {
            ["requested"] = runtime.Pipeline.StartLsn,
            ["effective_start_lsn"] = effectiveStartLsn,
            ["effective_start_lsn_pre_reset"] = effectiveStartLsnPreReset,
            ["latest_live_lsn"] = latestLiveLsn,
            ["lsn_reset_detected"] = lsnResetDetected
        },
        ["state"] = new Dictionary<string, object?>
        {
            ["path"] = runtime.Paths.StatePath,
            ["saved_last_lsn"] = newState.last_lsn
        },
        ["manifest"] = new Dictionary<string, object?>
        {
            ["path"] = manifestPath,
            ["record_count"] = manifest.RecordCount,
            ["transaction_count"] = manifest.TransactionCount,
            ["scan_end_lsn"] = manifest.ScanEndLsn,
            ["log_reader_function"] = runtime.Pipeline.LogReaderFunction
        },
        ["raw_match"] = new Dictionary<string, object?>
        {
            ["mode"] = runtime.Pipeline.RawMatchMode,
            ["path"] = hybridPath
        },
        ["trn_output"] = new Dictionary<string, object?>
        {
            ["mode"] = string.IsNullOrWhiteSpace(aggregateTrnPath) ? "per_table" : "single_file",
            ["path"] = aggregateTrnPath
        },
        ["tables"] = tableResults
    };
    await WriteJsonAsync(summaryPath, summary);
    return summary;
}

static async Task<ManifestSummary> BuildManifestAsync(Runtime runtime, string logPath, string outputPath, string? startLsn)
{
    if (IsRawOfflineExploration(runtime))
        return await BuildRawOfflineExplorationAsync(runtime, logPath, outputPath, startLsn);
    if (UsesOfflineRead(runtime))
        return await BuildOfflineManifestAsync(runtime, logPath, outputPath, startLsn);

    static string QuoteSql(string value) => "N'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";
    var logReaderFunction = runtime.Pipeline.LogReaderFunction;
    var targetsSql = string.Join(Environment.NewLine + "UNION ALL" + Environment.NewLine,
        runtime.Pipeline.Tables.Select(table =>
        {
            var parts = table.Split('.', 2);
            return $"SELECT {QuoteSql(parts[0])} AS schema_name, {QuoteSql(parts[1])} AS table_name";
        }));
    var spidSqlList = runtime.Pipeline.Spids.Count > 0 ? string.Join(", ", runtime.Pipeline.Spids.Distinct().OrderBy(x => x)) : "-1";
    var users = runtime.Pipeline.Users.Select(u => u.Trim().ToUpperInvariant()).Where(u => !string.IsNullOrWhiteSpace(u)).Distinct().OrderBy(x => x).ToList();
    var excludeUsers = runtime.Pipeline.ExcludeUsers.Select(u => u.Trim().ToUpperInvariant()).Where(u => !string.IsNullOrWhiteSpace(u)).Distinct().OrderBy(x => x).ToList();
    var usersSqlList = users.Count > 0 ? string.Join(", ", users.Select(QuoteSql)) : "N''";
    var excludeUsersSqlList = excludeUsers.Count > 0 ? string.Join(", ", excludeUsers.Select(QuoteSql)) : "N''";
    var startLsnLiteral = IsValidLsn(startLsn) ? QuoteSql(startLsn!) : "NULL";
    var sql = $@"
DECLARE @WindowMinutes INT = {runtime.Pipeline.WindowMinutes};
DECLARE @StartLsn NVARCHAR(25) = {startLsnLiteral};
DECLARE @HasSpidFilter BIT = {(runtime.Pipeline.Spids.Count > 0 ? 1 : 0)};
DECLARE @HasUsersFilter BIT = {(users.Count > 0 ? 1 : 0)};
DECLARE @HasExcludeUsersFilter BIT = {(excludeUsers.Count > 0 ? 1 : 0)};
SELECT schema_name, table_name INTO #target_tables FROM (
{targetsSql}
) tt;
SELECT TOP (0) [Current LSN] AS current_lsn,[Transaction ID] AS transaction_id,[Operation] AS operation_name,[Context] AS context_name,[AllocUnitName] AS alloc_unit_name,[AllocUnitId] AS alloc_unit_id,[End Time] AS end_time,[Page ID] AS page_id,[Slot ID] AS slot_id,[SPID] AS spid,[Transaction Name] AS transaction_name,[Transaction SID] AS transaction_sid,[RowLog Contents 0] AS rowlog0,[RowLog Contents 1] AS rowlog1,[RowLog Contents 2] AS rowlog2,[RowLog Contents 3] AS rowlog3,[RowLog Contents 4] AS rowlog4,[RowLog Contents 5] AS rowlog5 INTO #log_rows FROM {logReaderFunction}(NULL, NULL);
IF (@StartLsn IS NULL)
BEGIN
INSERT INTO #log_rows SELECT [Current LSN],[Transaction ID],[Operation],[Context],[AllocUnitName],[AllocUnitId],[End Time],[Page ID],[Slot ID],[SPID],[Transaction Name],[Transaction SID],[RowLog Contents 0],[RowLog Contents 1],[RowLog Contents 2],[RowLog Contents 3],[RowLog Contents 4],[RowLog Contents 5]
FROM {logReaderFunction}(NULL, NULL) WHERE [Transaction ID] IS NOT NULL AND [Operation] IN ('LOP_BEGIN_XACT','LOP_COMMIT_XACT','LOP_INSERT_ROWS','LOP_DELETE_ROWS','LOP_MODIFY_ROW','LOP_MODIFY_COLUMNS');
END ELSE BEGIN
INSERT INTO #log_rows SELECT [Current LSN],[Transaction ID],[Operation],[Context],[AllocUnitName],[AllocUnitId],[End Time],[Page ID],[Slot ID],[SPID],[Transaction Name],[Transaction SID],[RowLog Contents 0],[RowLog Contents 1],[RowLog Contents 2],[RowLog Contents 3],[RowLog Contents 4],[RowLog Contents 5]
FROM {logReaderFunction}(@StartLsn, NULL) WHERE [Transaction ID] IS NOT NULL AND [Operation] IN ('LOP_BEGIN_XACT','LOP_COMMIT_XACT','LOP_INSERT_ROWS','LOP_DELETE_ROWS','LOP_MODIFY_ROW','LOP_MODIFY_COLUMNS') AND [Current LSN] > @StartLsn;
END;
WITH commits AS (
SELECT transaction_id,end_time AS commit_time FROM #log_rows WHERE operation_name='LOP_COMMIT_XACT' AND (@StartLsn IS NOT NULL OR end_time >= DATEADD(MINUTE,-@WindowMinutes,SYSDATETIME()))
), begins_raw AS (
SELECT transaction_id,spid,transaction_name,transaction_sid,current_lsn,ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY current_lsn ASC) AS rn FROM #log_rows WHERE operation_name='LOP_BEGIN_XACT'
), begins AS (
SELECT transaction_id,spid AS tx_spid,transaction_name AS tx_transaction_name,SUSER_SNAME(transaction_sid) AS user_name FROM begins_raw WHERE rn=1
), changes AS (
SELECT lr.current_lsn,lr.transaction_id,lr.operation_name,lr.context_name,lr.alloc_unit_name,lr.alloc_unit_id,lr.page_id,lr.slot_id,ISNULL(br.tx_spid,lr.spid) AS tx_spid,ISNULL(NULLIF(br.tx_transaction_name,N''),lr.transaction_name) AS tx_transaction_name,br.user_name,lr.rowlog0,lr.rowlog1,lr.rowlog2,lr.rowlog3,lr.rowlog4,lr.rowlog5,c.commit_time,
CASE WHEN PARSENAME(lr.alloc_unit_name,3) IS NOT NULL THEN PARSENAME(lr.alloc_unit_name,3) ELSE PARSENAME(lr.alloc_unit_name,2) END AS schema_name,
CASE WHEN PARSENAME(lr.alloc_unit_name,3) IS NOT NULL THEN PARSENAME(lr.alloc_unit_name,2) ELSE PARSENAME(lr.alloc_unit_name,1) END AS table_name
FROM #log_rows lr INNER JOIN commits c ON c.transaction_id=lr.transaction_id LEFT JOIN begins br ON br.transaction_id=lr.transaction_id
WHERE lr.operation_name IN ('LOP_INSERT_ROWS','LOP_DELETE_ROWS','LOP_MODIFY_ROW','LOP_MODIFY_COLUMNS') AND lr.alloc_unit_name IS NOT NULL
AND (@HasSpidFilter=0 OR ISNULL(br.tx_spid,lr.spid) IN ({spidSqlList}))
AND (@HasUsersFilter=0 OR UPPER(ISNULL(br.user_name,N'')) IN ({usersSqlList}))
AND (@HasExcludeUsersFilter=0 OR UPPER(ISNULL(br.user_name,N'')) NOT IN ({excludeUsersSqlList}))
)
SELECT ch.current_lsn,ch.transaction_id,ch.operation_name,ch.context_name,ch.schema_name,ch.table_name,ch.alloc_unit_name,TRY_CONVERT(BIGINT,ch.alloc_unit_id) AS alloc_unit_id,TRY_CONVERT(BIGINT,TRY_CONVERT(BIGINT,ch.alloc_unit_id)/65536)%4294967296 AS hobt_token,ch.page_id,ch.slot_id,ch.tx_spid AS spid,ch.tx_transaction_name AS transaction_name,ch.user_name,master.dbo.fn_varbintohexstr(ch.rowlog0) AS rowlog0_hex,master.dbo.fn_varbintohexstr(ch.rowlog1) AS rowlog1_hex,master.dbo.fn_varbintohexstr(ch.rowlog2) AS rowlog2_hex,master.dbo.fn_varbintohexstr(ch.rowlog3) AS rowlog3_hex,master.dbo.fn_varbintohexstr(ch.rowlog4) AS rowlog4_hex,master.dbo.fn_varbintohexstr(ch.rowlog5) AS rowlog5_hex,ch.commit_time
FROM changes ch INNER JOIN #target_tables tt ON tt.schema_name=ch.schema_name AND tt.table_name=ch.table_name ORDER BY ch.commit_time ASC,ch.current_lsn ASC;
SELECT TOP (1) current_lsn AS scan_end_lsn FROM #log_rows ORDER BY current_lsn DESC;
DROP TABLE #log_rows; DROP TABLE #target_tables;";
    await using var conn = new SqlConnection(BuildConnString(runtime.Pipeline.LiveServerInstance, runtime.Pipeline.LiveDatabase, runtime.Security));
    await using var cmd = conn.CreateCommand();
    cmd.CommandTimeout = 0;
    cmd.CommandText = sql;
    await conn.OpenAsync();
    await using var reader = await cmd.ExecuteReaderAsync();
    var rows = new List<Dictionary<string, object?>>();
    while (await reader.ReadAsync())
    {
        var op = reader["operation_name"]?.ToString();
        var action = op switch { "LOP_INSERT_ROWS" => "INSERT", "LOP_DELETE_ROWS" => "DELETE", "LOP_MODIFY_ROW" => "UPDATE", "LOP_MODIFY_COLUMNS" => "UPDATE", _ => null };
        if (action is null) continue;
        var lsn = reader["current_lsn"]?.ToString() ?? string.Empty;
        var txId = reader["transaction_id"]?.ToString() ?? string.Empty;
        rows.Add(new Dictionary<string, object?> { ["manifest_key"] = $"{action}|{txId}|{lsn}".ToUpperInvariant(), ["action"] = action, ["current_lsn"] = lsn, ["tx_id"] = txId, ["operation_name"] = op, ["context_name"] = DbNull(reader["context_name"]), ["schema_name"] = reader["schema_name"]?.ToString(), ["table_name"] = reader["table_name"]?.ToString(), ["alloc_unit_name"] = DbNull(reader["alloc_unit_name"]), ["alloc_unit_id"] = ToLong(reader["alloc_unit_id"]), ["hobt_token"] = ToLong(reader["hobt_token"]), ["page_id"] = DbNull(reader["page_id"]), ["slot_id"] = ToInt(reader["slot_id"]), ["spid"] = ToInt(reader["spid"]), ["transaction_name"] = DbNull(reader["transaction_name"]), ["user_name"] = DbNull(reader["user_name"]), ["rowlog0_hex"] = DbNull(reader["rowlog0_hex"]), ["rowlog1_hex"] = DbNull(reader["rowlog1_hex"]), ["rowlog2_hex"] = DbNull(reader["rowlog2_hex"]), ["rowlog3_hex"] = DbNull(reader["rowlog3_hex"]), ["rowlog4_hex"] = DbNull(reader["rowlog4_hex"]), ["rowlog5_hex"] = DbNull(reader["rowlog5_hex"]), ["commit_time"] = reader["commit_time"] is DBNull ? null : Convert.ToDateTime(reader["commit_time"], CultureInfo.InvariantCulture).ToString("O") });
    }
    string? scanEndLsn = null;
    if (await reader.NextResultAsync() && await reader.ReadAsync()) scanEndLsn = reader["scan_end_lsn"]?.ToString();
    var txCount = rows.Select(r => (string?)r["tx_id"]).Where(s => !string.IsNullOrWhiteSpace(s)).Distinct(StringComparer.OrdinalIgnoreCase).Count();
    await WriteJsonAsync(outputPath, new Dictionary<string, object?> { ["collected_at_utc"] = DateTime.UtcNow.ToString("O"), ["server_instance"] = runtime.Pipeline.LiveServerInstance, ["database"] = runtime.Pipeline.LiveDatabase, ["window_minutes"] = runtime.Pipeline.WindowMinutes, ["start_lsn_used"] = startLsn, ["scan_end_lsn"] = scanEndLsn, ["tables"] = runtime.Pipeline.Tables, ["operations"] = new[] { "DMLALL" }, ["resolved_log_operations"] = new[] { "LOP_INSERT_ROWS", "LOP_DELETE_ROWS", "LOP_MODIFY_ROW", "LOP_MODIFY_COLUMNS" }, ["log_reader_function"] = logReaderFunction, ["spids"] = runtime.Pipeline.Spids, ["users"] = runtime.Pipeline.Users, ["exclude_users"] = runtime.Pipeline.ExcludeUsers, ["record_count"] = rows.Count, ["transaction_count"] = txCount, ["note"] = $"Committed DML manifest from live {logReaderFunction}, intended for offline LDF hybrid matching.", ["records"] = rows });
    Log(logPath, $"Wrote {rows.Count} manifest rows ({txCount} transactions) to {outputPath}");
    return new ManifestSummary(rows.Count, txCount, scanEndLsn);
}
static async Task<ManifestSummary> BuildOfflineManifestAsync(Runtime runtime, string logPath, string outputPath, string? startLsn)
{
    var ldfPath = runtime.Pipeline.CurrentLdfPath ?? throw new InvalidOperationException("Offline read mode requires current shadow-copy LDF path.");
    var captureBytes = Math.Max(96, runtime.Pipeline.OfflineRecordCaptureBytes);
    var tailBytes = runtime.Pipeline.OfflineTailBytes > 0 ? runtime.Pipeline.OfflineTailBytes : 64 * 1024 * 1024;
    long fileLen;
    using (var fs = File.Open(ldfPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
    {
        fileLen = fs.Length;
    }
    var extractionWindowBytes = Math.Min((long)tailBytes, fileLen);
    var requestedProbeTailBytes = runtime.Pipeline.OfflineProbeTailBytes > 0
        ? Math.Min(runtime.Pipeline.OfflineProbeTailBytes, (int)Math.Min(int.MaxValue, extractionWindowBytes))
        : (int)Math.Min(16 * 1024 * 1024L, extractionWindowBytes);

    var windowStarts = BuildOfflineWindowStarts(fileLen, extractionWindowBytes);
    var broadMarkers = new HashSet<byte>(new byte[] { 0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD1, 0xD2, 0xD3 });
    var profiles = runtime.Pipeline.OfflineAutoProbeProfile
        ? BuildOfflineProfiles()
        : new List<OfflineScanProfile> { new("default_base_inrow_b2_b3_b4_b5_c8_c9_ca_cb_d1_d2_d3", true, true, new HashSet<byte>(new byte[] { 0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD1, 0xD2, 0xD3 })) };
    var tokenMapCache = new Dictionary<string, Dictionary<long, (string Schema, string Table)>>(StringComparer.OrdinalIgnoreCase);
    async Task<Dictionary<long, (string Schema, string Table)>> GetMapAsync(OfflineScanProfile profile)
    {
        var key = $"{profile.BaseRowOnly}|{profile.InRowOnly}";
        if (tokenMapCache.TryGetValue(key, out var cached))
            return cached;
        var map = await GetTargetHobtMapAsync(runtime, profile.BaseRowOnly, profile.InRowOnly);
        tokenMapCache[key] = map;
        return map;
    }
    var broadWindowProfile = profiles.FirstOrDefault(p => p.Name.StartsWith("broad_", StringComparison.OrdinalIgnoreCase))
        ?? profiles.First();
    var broadWindowMap = await GetMapAsync(broadWindowProfile);
    var allAcceptedMarkers = new HashSet<byte>(profiles.SelectMany(p => p.AcceptedDbMarkers));
    var windowScoreboard = new List<Dictionary<string, object?>>();
    long selectedWindowStart = windowStarts.FirstOrDefault();
    long bestWindowScore = long.MinValue;
    var effectiveWindowProbeBytes = requestedProbeTailBytes;
    foreach (var probeSize in new[]
    {
        requestedProbeTailBytes,
        (int)Math.Min(Math.Max((long)requestedProbeTailBytes, 64L * 1024 * 1024), extractionWindowBytes),
        (int)Math.Min(Math.Max((long)requestedProbeTailBytes, 128L * 1024 * 1024), extractionWindowBytes)
    }.Distinct())
    {
        effectiveWindowProbeBytes = probeSize;
        windowScoreboard.Clear();
        bestWindowScore = long.MinValue;
        selectedWindowStart = windowStarts.FirstOrDefault();

        foreach (var windowStart in windowStarts)
        {
            var windowLen = Math.Min(extractionWindowBytes, fileLen - windowStart);
            if (windowLen <= 0)
                continue;
            var segmentStarts = BuildOfflineProbeSegmentStarts(windowStart, windowLen, effectiveWindowProbeBytes);
            long totalRaw = 0;
            long totalCommits = 0;
            long totalUserActions = 0;
            long totalTargetMatches = 0;
            long totalTargetManifest = 0;
            foreach (var segmentStart in segmentStarts)
            {
                var probeLen = (int)Math.Min(effectiveWindowProbeBytes, fileLen - segmentStart);
                if (probeLen <= 0)
                    continue;
                var probeBytes = ReadWindowBytes(ldfPath, segmentStart, probeLen);
                var probeScan = RunOfflineScan(probeBytes, segmentStart, CreateEmptyTokenMap(), false, broadMarkers, 96, 0, startLsn);
                totalRaw += probeScan.SeenKeys.Count;
                totalCommits += probeScan.CommitsByTx.Count;
                totalUserActions += probeScan.ActionCounts.TryGetValue("INSERT", out var ai) ? ai : 0;
                totalUserActions += probeScan.ActionCounts.TryGetValue("DELETE", out var ad) ? ad : 0;
                totalUserActions += probeScan.ActionCounts.TryGetValue("UPDATE", out var au) ? au : 0;
                if (broadWindowMap.Count > 0)
                {
                    var targetProbe = RunOfflineScan(probeBytes, segmentStart, broadWindowMap, false, allAcceptedMarkers, 96, 0, startLsn);
                    totalTargetMatches += targetProbe.Candidates.Count;
                    totalTargetManifest += targetProbe.ManifestRecordCount;
                }
            }

            var score =
                (totalTargetManifest * 1_000_000_000L) +
                (totalTargetMatches * 1_000_000L) +
                totalRaw +
                (totalCommits * 10L) +
                totalUserActions;
            windowScoreboard.Add(new Dictionary<string, object?>
            {
                ["window_start"] = windowStart,
                ["window_length"] = windowLen,
                ["probe_segment_count"] = segmentStarts.Count,
                ["probe_tail_bytes"] = effectiveWindowProbeBytes,
                ["raw_candidate_count"] = totalRaw,
                ["commit_count"] = totalCommits,
                ["user_action_count"] = totalUserActions,
                ["target_match_count"] = totalTargetMatches,
                ["target_manifest_count"] = totalTargetManifest,
                ["window_probe_profile"] = broadWindowProfile.Name,
                ["score"] = score
            });
            if (score > bestWindowScore)
            {
                bestWindowScore = score;
                selectedWindowStart = windowStart;
            }
        }

        if (windowScoreboard.Any(w =>
                Convert.ToInt64(w["target_match_count"], CultureInfo.InvariantCulture) > 0
                || Convert.ToInt64(w["target_manifest_count"], CultureInfo.InvariantCulture) > 0))
        {
            break;
        }
    }

    var selectedWindowLength = Math.Min(extractionWindowBytes, fileLen - selectedWindowStart);
    var bytes = ReadWindowBytes(ldfPath, selectedWindowStart, selectedWindowLength);
    var baseOffset = selectedWindowStart;

    var probeResults = new List<Dictionary<string, object?>>();
    OfflineScanProfile? selectedProfile = null;
    Dictionary<long, (string Schema, string Table)>? selectedMap = null;
    long bestScore = long.MinValue;
    var probeTailBytes = Math.Min(requestedProbeTailBytes, bytes.Length);
    foreach (var probeSize in new[]
    {
        probeTailBytes,
        Math.Min(Math.Max(probeTailBytes, 64 * 1024 * 1024), bytes.Length),
        Math.Min(Math.Max(probeTailBytes, 128 * 1024 * 1024), bytes.Length)
    }.Distinct())
    {
        probeTailBytes = probeSize;
        probeResults.Clear();
        selectedProfile = null;
        selectedMap = null;
        bestScore = long.MinValue;
        var probeOffset = bytes.Length - probeTailBytes;

        foreach (var profile in profiles)
        {
            var hobtMap = await GetMapAsync(profile);
            if (hobtMap.Count == 0)
                continue;
            var probeBytes = new byte[probeTailBytes];
            Array.Copy(bytes, probeOffset, probeBytes, 0, probeTailBytes);
            var probeScan = RunOfflineScan(probeBytes, baseOffset + probeOffset, hobtMap, profile.StrictPrimaryTokenOnly, profile.AcceptedDbMarkers, captureBytes, runtime.Pipeline.OfflineDiagSampleLimit, startLsn);
            var raw = probeScan.SeenKeys.Count;
            var matched = probeScan.Candidates.Count;
            var manifestRows = probeScan.ManifestRecordCount;
            var commits = probeScan.CommitsByTx.Count;
            var userActions = probeScan.ActionCounts.TryGetValue("INSERT", out var ai) ? ai : 0;
            userActions += probeScan.ActionCounts.TryGetValue("DELETE", out var ad) ? ad : 0;
            userActions += probeScan.ActionCounts.TryGetValue("UPDATE", out var au) ? au : 0;
            var trustTier =
                manifestRows > 0 && profile.BaseRowOnly && profile.InRowOnly ? 3 :
                manifestRows > 0 && profile.BaseRowOnly ? 2 :
                manifestRows > 0 ? 1 :
                0;
            var score =
                (long)trustTier * 1_000_000_000_000L +
                (long)manifestRows * 1000L +
                (long)matched * 25L +
                (long)commits * 5L +
                userActions +
                (raw > 0 ? 1 : 0);
            probeResults.Add(new Dictionary<string, object?>
            {
                ["name"] = profile.Name,
                ["base_row_only"] = profile.BaseRowOnly,
                ["in_row_only"] = profile.InRowOnly,
                ["accepted_db_markers"] = profile.AcceptedDbMarkers.OrderBy(x => x).Select(x => $"0x{x:X2}").ToList(),
                ["resolved_token_count"] = hobtMap.Count,
                ["raw_candidate_count"] = raw,
                ["commit_count"] = commits,
                ["matched_candidate_count"] = matched,
                ["manifest_record_count"] = manifestRows,
                ["trust_tier"] = trustTier,
                ["score"] = score
            });
            if (score > bestScore)
            {
                bestScore = score;
                selectedProfile = profile;
                selectedMap = hobtMap;
            }
        }

        if (probeResults.Any(r => Convert.ToInt32(r["raw_candidate_count"], CultureInfo.InvariantCulture) > 0))
            break;
    }

    if (selectedProfile is null || selectedMap is null)
        throw new InvalidOperationException("Offline read mode probe could not find a viable scan profile.");

    var fullScan = RunOfflineScan(bytes, baseOffset, selectedMap, selectedProfile.StrictPrimaryTokenOnly, selectedProfile.AcceptedDbMarkers, captureBytes, runtime.Pipeline.OfflineDiagSampleLimit, startLsn);
    var commitsByTx = fullScan.CommitsByTx;
    var candidates = fullScan.Candidates;
    var seenKeys = fullScan.SeenKeys;
    var actionCounts = fullScan.ActionCounts;
    var dbMarkerCounts = fullScan.DbMarkerCounts;
    var tokenCounts = fullScan.TokenCounts;
    var unresolvedSamples = fullScan.UnresolvedSamples;
    var prefilterComboCounts = fullScan.PrefilterComboCounts;

    var rows = candidates
        .Where(r => commitsByTx.ContainsKey((string)r["tx_id"]!))
        .OrderBy(r => commitsByTx[(string)r["tx_id"]!])
        .ThenBy(r => (long)r["offset"]!)
        .Select(r =>
        {
            r["manifest_key"] = $"{r["action"]}|{r["tx_id"]}|{r["current_lsn"]}".ToString()!.ToUpperInvariant();
            r.Remove("offset");
            return r;
        })
        .ToList();

    var txCount = rows.Select(r => (string?)r["tx_id"]).Where(s => !string.IsNullOrWhiteSpace(s)).Distinct(StringComparer.OrdinalIgnoreCase).Count();
    var scanEndLsn =
        fullScan.MaxSeenLsn
        ?? (rows.Count > 0 ? rows.Select(r => (string)r["current_lsn"]!).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).Last() : startLsn);
    await WriteJsonAsync(outputPath, new Dictionary<string, object?>
    {
        ["collected_at_utc"] = DateTime.UtcNow.ToString("O"),
        ["server_instance"] = runtime.Pipeline.LiveServerInstance,
        ["database"] = runtime.Pipeline.LiveDatabase,
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["tables"] = runtime.Pipeline.Tables,
        ["record_count"] = rows.Count,
        ["transaction_count"] = txCount,
        ["note"] = "Best-effort offline manifest from raw LDF scan. Current_lsn and rowlog blobs are heuristic and intended for offline conversion fallback.",
        ["records"] = rows
    });
    var diagPath = Path.Combine(runtime.Paths.OutputDir, $"offline-scan.{Path.GetFileNameWithoutExtension(outputPath)}.diag.json");
    await WriteJsonAsync(diagPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["server_instance"] = runtime.Pipeline.LiveServerInstance,
        ["database"] = runtime.Pipeline.LiveDatabase,
        ["ldf_path"] = ldfPath,
        ["file_length_bytes"] = fileLen,
        ["selected_window_start"] = selectedWindowStart,
        ["selected_window_length"] = selectedWindowLength,
        ["tail_bytes"] = tailBytes,
        ["probe_tail_bytes"] = probeTailBytes,
        ["capture_bytes"] = captureBytes,
        ["target_table_count"] = runtime.Pipeline.Tables.Count,
        ["window_scoreboard"] = windowScoreboard,
        ["selected_profile"] = selectedProfile.Name,
        ["profile_scoreboard"] = probeResults,
        ["resolved_token_count"] = selectedMap.Count,
        ["raw_candidate_count"] = seenKeys.Count,
        ["commit_count"] = commitsByTx.Count,
        ["matched_candidate_count"] = candidates.Count,
        ["manifest_record_count"] = rows.Count,
        ["action_counts"] = actionCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase),
        ["db_marker_counts"] = dbMarkerCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase),
        ["top_prefilter_combos"] = prefilterComboCounts.OrderByDescending(k => k.Value).Take(runtime.Pipeline.OfflineDiagTopTokens).Select(k => new Dictionary<string, object?> { ["combo"] = k.Key, ["count"] = k.Value }).ToList(),
        ["top_tokens"] = tokenCounts.OrderByDescending(k => k.Value).Take(runtime.Pipeline.OfflineDiagTopTokens).Select(k => new Dictionary<string, object?> { ["token"] = k.Key, ["count"] = k.Value, ["mapped_table"] = selectedMap.TryGetValue(k.Key, out var info) ? $"{info.Schema}.{info.Table}" : null }).ToList(),
        ["sample_unresolved_candidates"] = unresolvedSamples
    });
    Log(logPath, $"Wrote offline diagnostic scan to {diagPath}");
    Log(logPath, $"Wrote {rows.Count} offline manifest rows ({txCount} transactions) to {outputPath}");
    return new ManifestSummary(rows.Count, txCount, scanEndLsn);
}

static async Task<ManifestSummary> BuildRawOfflineExplorationAsync(Runtime runtime, string logPath, string outputPath, string? startLsn)
{
    var ldfPath = runtime.Pipeline.CurrentLdfPath ?? throw new InvalidOperationException("Raw offline exploration mode requires current LDF path.");
    var fileInfo = new FileInfo(ldfPath);
    if (!fileInfo.Exists)
        throw new FileNotFoundException("LDF file not found for raw offline exploration", ldfPath);

    var fileLen = fileInfo.Length;
    var configuredWindowStart = runtime.Pipeline.RawExploreWindowStart;
    var configuredWindowLength = runtime.Pipeline.RawExploreWindowLength;
    var extractionWindowBytes = configuredWindowLength.HasValue && configuredWindowLength.Value > 0
        ? Math.Min(configuredWindowLength.Value, fileLen)
        : Math.Min(Math.Max(runtime.Pipeline.OfflineTailBytes, 64 * 1024 * 1024), fileLen);
    var requestedProbeBytes = Math.Min(Math.Max(runtime.Pipeline.OfflineProbeTailBytes, 16 * 1024 * 1024), extractionWindowBytes);
    var captureBytes = Math.Max(64, runtime.Pipeline.OfflineRecordCaptureBytes);
    var configuredActions = new HashSet<string>(runtime.Pipeline.RawExploreActions, StringComparer.OrdinalIgnoreCase);
    var configuredMarkers = runtime.Pipeline.RawExploreDbMarkers.Count > 0
        ? new HashSet<byte>(runtime.Pipeline.RawExploreDbMarkers)
        : null;
    var profiles = BuildOfflineProfiles();
    if (configuredMarkers is not null)
    {
        profiles = profiles
            .Select(p => new OfflineScanProfile(
                p.Name,
                p.BaseRowOnly,
                p.InRowOnly,
                new HashSet<byte>(p.AcceptedDbMarkers.Where(configuredMarkers.Contains))))
            .Where(p => p.AcceptedDbMarkers.Count > 0)
            .ToList();
    }
    var allMarkers = configuredMarkers ?? new HashSet<byte>(profiles.SelectMany(p => p.AcceptedDbMarkers));
    var broadProfile = new OfflineScanProfile("raw_all_markers", false, false, allMarkers);

    long selectedWindowStart = 0;
    long bestScore = long.MinValue;
    var windowScoreboard = new List<Dictionary<string, object?>>();
    if (configuredWindowStart.HasValue)
    {
        selectedWindowStart = Math.Max(0, Math.Min(configuredWindowStart.Value, Math.Max(0, fileLen - extractionWindowBytes)));
        windowScoreboard.Add(new Dictionary<string, object?>
        {
            ["window_start"] = selectedWindowStart,
            ["window_length"] = extractionWindowBytes,
            ["probe_segment_count"] = 1,
            ["probe_tail_bytes"] = requestedProbeBytes,
            ["raw_candidate_count"] = null,
            ["commit_count"] = null,
            ["user_action_count"] = null,
            ["score"] = null,
            ["forced_window"] = true
        });
    }
    else
    {
        foreach (var probeWindowBytes in new[]
        {
            requestedProbeBytes,
            Math.Min(Math.Max(requestedProbeBytes, 64 * 1024 * 1024), extractionWindowBytes),
            Math.Min(Math.Max(requestedProbeBytes, 128 * 1024 * 1024), extractionWindowBytes)
        }.Distinct())
        {
            windowScoreboard.Clear();
            bestScore = long.MinValue;
            foreach (var windowStart in BuildOfflineWindowStarts(fileLen, extractionWindowBytes))
            {
                var windowLen = Math.Min(extractionWindowBytes, fileLen - windowStart);
                if (windowLen <= 0)
                    continue;

                var segmentStarts = BuildOfflineProbeSegmentStarts(windowStart, windowLen, (int)probeWindowBytes);
                long totalRaw = 0;
                long totalCommits = 0;
                long totalUserActions = 0;
                foreach (var segmentStart in segmentStarts)
                {
                    var probeLen = (int)Math.Min(probeWindowBytes, fileLen - segmentStart);
                    if (probeLen <= 0)
                        continue;
                    var probeBytes = ReadWindowBytes(ldfPath, segmentStart, probeLen);
                    var probeScan = RunOfflineScan(probeBytes, segmentStart, CreateEmptyTokenMap(), false, allMarkers, captureBytes, runtime.Pipeline.OfflineDiagSampleLimit, startLsn);
                    totalRaw += probeScan.SeenKeys.Count;
                    totalCommits += probeScan.CommitsByTx.Count;
                    totalUserActions += probeScan.ActionCounts.TryGetValue("INSERT", out var ai) ? ai : 0;
                    totalUserActions += probeScan.ActionCounts.TryGetValue("DELETE", out var ad) ? ad : 0;
                    totalUserActions += probeScan.ActionCounts.TryGetValue("UPDATE", out var au) ? au : 0;
                }

                var score = totalRaw + (totalCommits * 10L) + totalUserActions;
                windowScoreboard.Add(new Dictionary<string, object?>
                {
                    ["window_start"] = windowStart,
                    ["window_length"] = windowLen,
                    ["probe_segment_count"] = segmentStarts.Count,
                    ["probe_tail_bytes"] = probeWindowBytes,
                    ["raw_candidate_count"] = totalRaw,
                    ["commit_count"] = totalCommits,
                    ["user_action_count"] = totalUserActions,
                    ["score"] = score
                });
                if (score > bestScore)
                {
                    bestScore = score;
                    selectedWindowStart = windowStart;
                }
            }

            if (windowScoreboard.Any(w => Convert.ToInt64(w["raw_candidate_count"], CultureInfo.InvariantCulture) > 0))
                break;
        }
    }

    var selectedWindowLength = Math.Min(extractionWindowBytes, fileLen - selectedWindowStart);
    var bytes = ReadWindowBytes(ldfPath, selectedWindowStart, selectedWindowLength);
    var probeResults = new List<Dictionary<string, object?>>();
    OfflineScanProfile selectedProfile = broadProfile;
    OfflineScanResult? selectedProbe = null;
    var probeTailBytes = Math.Min(requestedProbeBytes, bytes.Length);
    foreach (var probeSize in new[]
    {
        probeTailBytes,
        Math.Min(Math.Max(probeTailBytes, 64 * 1024 * 1024), bytes.Length),
        Math.Min(Math.Max(probeTailBytes, 128 * 1024 * 1024), bytes.Length)
    }.Distinct())
    {
        probeTailBytes = probeSize;
        probeResults.Clear();
        long bestProbeScore = long.MinValue;
        var probeOffset = bytes.Length - probeTailBytes;

        foreach (var profile in profiles)
        {
            var probeBytes = new byte[probeTailBytes];
            Array.Copy(bytes, probeOffset, probeBytes, 0, probeTailBytes);
            var probeScan = RunOfflineScan(probeBytes, selectedWindowStart + probeOffset, CreateEmptyTokenMap(), false, profile.AcceptedDbMarkers, captureBytes, runtime.Pipeline.OfflineDiagSampleLimit, startLsn);
            var raw = probeScan.SeenKeys.Count;
            var commits = probeScan.CommitsByTx.Count;
            var userActions = probeScan.ActionCounts.TryGetValue("INSERT", out var ai) ? ai : 0;
            userActions += probeScan.ActionCounts.TryGetValue("DELETE", out var ad) ? ad : 0;
            userActions += probeScan.ActionCounts.TryGetValue("UPDATE", out var au) ? au : 0;
            var score = raw + (commits * 10L) + userActions;
            probeResults.Add(new Dictionary<string, object?>
            {
                ["name"] = profile.Name,
                ["accepted_db_markers"] = profile.AcceptedDbMarkers.OrderBy(x => x).Select(x => $"0x{x:X2}").ToList(),
                ["raw_candidate_count"] = raw,
                ["commit_count"] = commits,
                ["user_action_count"] = userActions,
                ["score"] = score
            });
            if (score > bestProbeScore)
            {
                bestProbeScore = score;
                selectedProfile = profile;
                selectedProbe = probeScan;
            }
        }

        if (probeResults.Any(r => Convert.ToInt64(r["raw_candidate_count"], CultureInfo.InvariantCulture) > 0))
            break;
    }

    var fullScan = RunOfflineScan(bytes, selectedWindowStart, CreateEmptyTokenMap(), false, selectedProfile.AcceptedDbMarkers, captureBytes, runtime.Pipeline.OfflineDiagSampleLimit, startLsn);
    var rows = fullScan.RawCandidateSamples
        .Where(r => configuredActions.Count == 0 || configuredActions.Contains((string?)r["action"] ?? string.Empty))
        .ToList();
    var extractedRecords = fullScan.ExtractedRecords
        .Where(r => configuredActions.Count == 0 || configuredActions.Contains(r.Action))
        .ToList();
    var transactionBundles = BuildTransactionBundles(extractedRecords);
    var metadataCatalog = LoadMetadataCatalog(runtime.Paths.MetadataSnapshotPath);
    var commandCandidates = BuildCommandCandidates(transactionBundles, extractedRecords, metadataCatalog);
    var commandNeighborhoods = BuildCommandNeighborhoods(commandCandidates);
    var commandBehaviorClusters = BuildCommandBehaviorClusters(commandCandidates);
    var commandCorrelationFocus = BuildCommandCorrelationFocus(commandBehaviorClusters);
    var commandSemanticTimeline = BuildCommandSemanticTimeline(commandCandidates);
    var semanticEvents = BuildSemanticEvents(commandCandidates);
    if (runtime.Pipeline.SemanticEventKinds.Count > 0)
    {
        var semanticEventFilter = new HashSet<string>(runtime.Pipeline.SemanticEventKinds, StringComparer.OrdinalIgnoreCase);
        semanticEvents = semanticEvents
            .Where(evt => semanticEventFilter.Contains(GetStringValue(evt, "event_kind") ?? string.Empty))
            .ToList();
    }
    var semanticRecoveryReport = BuildSemanticRecoveryReport(semanticEvents);
    var businessEventFeed = BuildBusinessEventFeed(semanticEvents);
    var semanticEventKindCounts = semanticRecoveryReport.TryGetValue("event_kind_counts", out var semanticEventKindCountsObj)
        ? semanticEventKindCountsObj
        : new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    var txCount = fullScan.CommitsByTx.Count;
    var scanEndLsn = fullScan.MaxSeenLsn ?? startLsn;
    var filteredActionCounts = configuredActions.Count == 0
        ? fullScan.ActionCounts
        : fullScan.ActionCounts.Where(k => configuredActions.Contains(k.Key)).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase);
    var baseName = Path.GetFileNameWithoutExtension(outputPath);
    var extractedRecordsPath = Path.Combine(runtime.Paths.OutputDir, $"records.{baseName}.json");
    var transactionBundlesPath = Path.Combine(runtime.Paths.OutputDir, $"transactions.{baseName}.json");
    var commandCandidatesPath = Path.Combine(runtime.Paths.OutputDir, $"commands.{baseName}.json");
    var commandNeighborhoodsPath = Path.Combine(runtime.Paths.OutputDir, $"command-neighborhoods.{baseName}.json");
    var commandBehaviorClustersPath = Path.Combine(runtime.Paths.OutputDir, $"command-behavior-clusters.{baseName}.json");
    var commandCorrelationFocusPath = Path.Combine(runtime.Paths.OutputDir, $"command-correlation-focus.{baseName}.json");
    var commandSemanticTimelinePath = Path.Combine(runtime.Paths.OutputDir, $"command-semantic-timeline.{baseName}.json");
    var semanticEventsPath = Path.Combine(runtime.Paths.OutputDir, $"semantic-events.{baseName}.json");
    var semanticRecoveryReportPath = Path.Combine(runtime.Paths.OutputDir, $"semantic-event-recovery.{baseName}.json");
    var businessEventFeedPath = Path.Combine(runtime.Paths.OutputDir, $"business-event-feed.{baseName}.json");
    var businessEventFeedCsvPath = Path.Combine(runtime.Paths.OutputDir, $"business-event-feed.{baseName}.csv");
    var compatibilityRecordPath = Path.Combine(runtime.Paths.OutputDir, $"compatibility-record.{baseName}.json");
    await WriteJsonAsync(outputPath, new Dictionary<string, object?>
    {
        ["collected_at_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["record_count"] = configuredActions.Count == 0 ? fullScan.SeenKeys.Count : filteredActionCounts.Values.Sum(),
        ["transaction_count"] = txCount,
        ["action_filter"] = runtime.Pipeline.RawExploreActions,
        ["db_marker_filter"] = runtime.Pipeline.RawExploreDbMarkers.Select(x => $"0x{x:X2}").ToList(),
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["note"] = "Raw offline exploration mode. Records are unassigned candidate slices from the LDF and are intended for parser analysis only.",
        ["records"] = rows
    });
    await WriteJsonAsync(extractedRecordsPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["record_count"] = extractedRecords.Count,
        ["records"] = extractedRecords
    });
    await WriteJsonAsync(transactionBundlesPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["transaction_count"] = transactionBundles.Count,
        ["transactions"] = transactionBundles
    });
    await WriteJsonAsync(commandCandidatesPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["command_count"] = commandCandidates.Count,
        ["commands"] = commandCandidates
    });
    await WriteJsonAsync(commandNeighborhoodsPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["neighborhood_count"] = commandNeighborhoods.Count,
        ["neighborhoods"] = commandNeighborhoods
    });
    await WriteJsonAsync(commandBehaviorClustersPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["cluster_count"] = commandBehaviorClusters.Count,
        ["clusters"] = commandBehaviorClusters
    });
    await WriteJsonAsync(commandCorrelationFocusPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["focus_count"] = commandCorrelationFocus.Count,
        ["focus_clusters"] = commandCorrelationFocus
    });
    await WriteJsonAsync(commandSemanticTimelinePath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["event_count"] = commandSemanticTimeline.Count,
        ["events"] = commandSemanticTimeline
    });
    await WriteJsonAsync(semanticEventsPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["event_count"] = semanticEvents.Count,
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["events"] = semanticEvents
    });
    await WriteJsonAsync(semanticRecoveryReportPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["report"] = semanticRecoveryReport
    });
    await WriteJsonAsync(businessEventFeedPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["event_count"] = businessEventFeed.Count,
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["events"] = businessEventFeed
    });
    await WriteCsvAsync(
        businessEventFeedCsvPath,
        businessEventFeed,
        [
            "sequence",
            "event_kind",
            "primary_table",
            "identifier",
            "headline",
            "transaction_id",
            "command_id",
            "first_offset"
        ]);
    await WriteJsonAsync(compatibilityRecordPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["session_name"] = baseName.Replace("live-dml-manifest.", string.Empty, StringComparison.OrdinalIgnoreCase),
        ["service_name"] = runtime.Service.Name,
        ["client_id"] = runtime.Pipeline.ClientId,
        ["environment"] = runtime.Pipeline.Environment,
        ["sql_version_hint"] = runtime.Pipeline.SqlVersionHint,
        ["ldf_path"] = ldfPath,
        ["ldf_file_name"] = Path.GetFileName(ldfPath),
        ["read_mode"] = runtime.Pipeline.ReadMode,
        ["live_server_instance"] = runtime.Pipeline.LiveServerInstance,
        ["live_database"] = runtime.Pipeline.LiveDatabase,
        ["selected_profile"] = selectedProfile.Name,
        ["selected_window_start"] = selectedWindowStart,
        ["selected_window_length"] = selectedWindowLength,
        ["start_lsn_used"] = CanUseOfflineStartLsn(startLsn) ? startLsn : null,
        ["scan_end_lsn"] = scanEndLsn,
        ["action_filter"] = runtime.Pipeline.RawExploreActions,
        ["db_marker_filter"] = runtime.Pipeline.RawExploreDbMarkers.Select(x => $"0x{x:X2}").ToList(),
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["counts"] = new Dictionary<string, object?>
        {
            ["raw_candidate_count"] = fullScan.SeenKeys.Count,
            ["commit_count"] = fullScan.CommitsByTx.Count,
            ["manifest_record_count"] = rows.Count,
            ["extracted_record_count"] = extractedRecords.Count,
            ["transaction_bundle_count"] = transactionBundles.Count,
            ["command_candidate_count"] = commandCandidates.Count,
            ["semantic_event_count"] = semanticEvents.Count,
            ["business_event_feed_count"] = businessEventFeed.Count
        },
        ["semantic_event_kind_counts"] = semanticEventKindCounts,
        ["db_marker_counts"] = fullScan.DbMarkerCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase)
    });

    var diagPath = Path.Combine(runtime.Paths.OutputDir, $"offline-scan.{Path.GetFileNameWithoutExtension(outputPath)}.diag.json");
    await WriteJsonAsync(diagPath, new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["ldf_path"] = ldfPath,
        ["file_length_bytes"] = fileLen,
        ["selected_window_start"] = selectedWindowStart,
        ["selected_window_length"] = selectedWindowLength,
        ["tail_bytes"] = extractionWindowBytes,
        ["probe_tail_bytes"] = probeTailBytes,
        ["capture_bytes"] = captureBytes,
        ["window_scoreboard"] = windowScoreboard,
        ["selected_profile"] = selectedProfile.Name,
        ["profile_scoreboard"] = probeResults,
        ["raw_candidate_count"] = fullScan.SeenKeys.Count,
        ["commit_count"] = fullScan.CommitsByTx.Count,
        ["matched_candidate_count"] = 0,
        ["manifest_record_count"] = rows.Count,
        ["action_filter"] = runtime.Pipeline.RawExploreActions,
        ["db_marker_filter"] = runtime.Pipeline.RawExploreDbMarkers.Select(x => $"0x{x:X2}").ToList(),
        ["semantic_event_filter"] = runtime.Pipeline.SemanticEventKinds,
        ["extracted_records_path"] = extractedRecordsPath,
        ["transaction_bundles_path"] = transactionBundlesPath,
        ["command_candidates_path"] = commandCandidatesPath,
        ["command_neighborhoods_path"] = commandNeighborhoodsPath,
        ["command_behavior_clusters_path"] = commandBehaviorClustersPath,
        ["command_correlation_focus_path"] = commandCorrelationFocusPath,
        ["command_semantic_timeline_path"] = commandSemanticTimelinePath,
        ["semantic_events_path"] = semanticEventsPath,
        ["semantic_recovery_report_path"] = semanticRecoveryReportPath,
        ["business_event_feed_path"] = businessEventFeedPath,
        ["business_event_feed_csv_path"] = businessEventFeedCsvPath,
        ["compatibility_record_path"] = compatibilityRecordPath,
        ["extracted_record_count"] = extractedRecords.Count,
        ["transaction_bundle_count"] = transactionBundles.Count,
        ["command_candidate_count"] = commandCandidates.Count,
        ["command_neighborhood_count"] = commandNeighborhoods.Count,
        ["command_behavior_cluster_count"] = commandBehaviorClusters.Count,
        ["command_correlation_focus_count"] = commandCorrelationFocus.Count,
        ["command_semantic_timeline_count"] = commandSemanticTimeline.Count,
        ["semantic_event_count"] = semanticEvents.Count,
        ["business_event_feed_count"] = businessEventFeed.Count,
        ["semantic_event_kind_counts"] = semanticEventKindCounts,
        ["action_counts"] = filteredActionCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase),
        ["db_marker_counts"] = fullScan.DbMarkerCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase),
        ["top_prefilter_combos"] = fullScan.PrefilterComboCounts.OrderByDescending(k => k.Value).Take(runtime.Pipeline.OfflineDiagTopTokens).Select(k => new Dictionary<string, object?> { ["combo"] = k.Key, ["count"] = k.Value }).ToList(),
        ["top_tokens"] = fullScan.TokenCounts.OrderByDescending(k => k.Value).Take(runtime.Pipeline.OfflineDiagTopTokens).Select(k => new Dictionary<string, object?> { ["token"] = k.Key, ["count"] = k.Value }).ToList(),
        ["sample_raw_candidates"] = fullScan.RawCandidateSamples,
        ["sample_unresolved_candidates"] = fullScan.UnresolvedSamples,
        ["probe_sample_raw_candidates"] = selectedProbe?.RawCandidateSamples
    });
    Log(logPath, $"Wrote raw offline diagnostic scan to {diagPath}");
    Log(logPath, $"Wrote raw offline exploration output to {outputPath}");
    Log(logPath, $"Wrote extracted record stream to {extractedRecordsPath}");
    Log(logPath, $"Wrote transaction bundles to {transactionBundlesPath}");
    Log(logPath, $"Wrote command candidates to {commandCandidatesPath}");
    Log(logPath, $"Wrote command neighborhoods to {commandNeighborhoodsPath}");
    Log(logPath, $"Wrote command behavior clusters to {commandBehaviorClustersPath}");
    Log(logPath, $"Wrote command correlation focus to {commandCorrelationFocusPath}");
    Log(logPath, $"Wrote command semantic timeline to {commandSemanticTimelinePath}");
    Log(logPath, $"Wrote semantic events to {semanticEventsPath}");
    Log(logPath, $"Wrote compatibility record to {compatibilityRecordPath}");
    return new ManifestSummary(fullScan.SeenKeys.Count, txCount, scanEndLsn);
}

static async Task<Dictionary<string, object?>> RunConvertAsync(Runtime runtime, string table, string manifestPath, string sessionName, TimeSpan timeout)
{
    var suffix = table.ToLowerInvariant().Replace("oasis.", "", StringComparison.OrdinalIgnoreCase).Replace('.', '_');
    var trnPath = ResolveTrnPath(runtime, sessionName, table, suffix);
    var unresolvedPath = Path.Combine(runtime.Paths.OutputDir, $"hybrid.{sessionName}.{suffix}.unresolved.trn");
    var trustDiagnosticsPath = Path.Combine(runtime.Paths.OutputDir, $"hybrid.{sessionName}.{suffix}.trust_diagnostics.json");
    var applyPath = Path.Combine(runtime.Paths.OutputDir, $"hybrid.{sessionName}.{suffix}.apply.json");
    var phaseTimingPath = Path.Combine(runtime.Paths.OutputDir, $"hybrid.{sessionName}.{suffix}.phase_timings.json");
    var parts = table.Split('.', 2);
    var compiledUpdateMode = runtime.Pipeline.UpdateMode.Equals("replace", StringComparison.OrdinalIgnoreCase) ? "replace" : runtime.Pipeline.UpdateMode.Equals("update", StringComparison.OrdinalIgnoreCase) ? "full" : "hybrid";
    var args = new List<string> { "--server", runtime.Pipeline.LiveServerInstance, "--database", runtime.Pipeline.LiveDatabase, "--schema", parts[0], "--table", parts[1], "--manifest", manifestPath, "--metadata", runtime.Paths.MetadataSnapshotPath, "--output", trnPath, "--update-emit-mode", compiledUpdateMode };
    if (runtime.Security.UseSqlAuth) args.AddRange(new[] { "--sql-user", runtime.Security.SqlUser ?? string.Empty, "--sql-password", runtime.Security.SqlPassword ?? string.Empty });
    if (UsesOfflineRead(runtime) || runtime.Pipeline.OfflineLogOnly)
    {
        args.AddRange(new[] { "--offline-log-only", "true", "--trust-diagnostics-path", trustDiagnosticsPath });
    }
    var proc = await RunProcessAsync(runtime.Pipeline.CompiledConverterPath, args, timeout);
    var summaryLine = ExtractLine(proc.StdOut, "-- Summary:");
    var timingLine = ExtractLine(proc.StdOut, "-- Timing:");
    var callsLine = ExtractLine(proc.StdOut, "-- Live DB Calls:");
    var converterSummary = ParseKeyValues(summaryLine);
    var timings = ParseKeyValues(timingLine);
    var liveCalls = ParseKeyValues(callsLine);
    var phasePayload = new Dictionary<string, object?>
    {
        ["generated_utc"] = DateTime.UtcNow.ToString("O"),
        ["output_path"] = trnPath,
        ["target_table"] = table,
        ["converter"] = "fast-quote-convert",
        ["timings_ms"] = new Dictionary<string, object?> { ["total_ms"] = timings.TryGetValue("total_run_ms", out var totalMs) ? totalMs : null, ["manifest_read_ms"] = timings.TryGetValue("manifest_read_ms", out var manifestMs) ? manifestMs : null, ["total_run_ms"] = timings.TryGetValue("total_run_ms", out var totalRunMs) ? totalRunMs : null },
        ["summary"] = converterSummary,
        ["live_db_calls"] = liveCalls,
        ["trust_diagnostics_path"] = (UsesOfflineRead(runtime) || runtime.Pipeline.OfflineLogOnly) ? trustDiagnosticsPath : null,
        ["converter_stdout"] = new Dictionary<string, object?> { ["summary_line"] = summaryLine, ["timing_line"] = timingLine, ["calls_line"] = callsLine }
    };
    await WriteJsonAsync(phaseTimingPath, phasePayload);
    object? applySummary = null;
    if (runtime.Pipeline.ApplyToTarget) applySummary = await ApplyTrnAsync(runtime, trnPath, applyPath);
    var trnStatements = File.Exists(trnPath) ? File.ReadLines(trnPath).Count(line => Regexes.TrnAction.IsMatch(line)) : 0;
    return new Dictionary<string, object?> { ["table"] = table, ["trn_statements"] = trnStatements, ["trn_path"] = trnPath, ["unresolved_path"] = unresolvedPath, ["trust_diagnostics_path"] = (UsesOfflineRead(runtime) || runtime.Pipeline.OfflineLogOnly) ? trustDiagnosticsPath : null, ["apply_path"] = runtime.Pipeline.ApplyToTarget ? applyPath : null, ["phase_timing_path"] = phaseTimingPath, ["phase_timings_ms"] = phasePayload["timings_ms"], ["live_db_calls"] = liveCalls, ["converter_summary"] = converterSummary, ["apply_summary"] = applySummary };
}

static async Task<object> ApplyTrnAsync(Runtime runtime, string trnPath, string applyPath)
{
    var batches = SplitBatches(await File.ReadAllTextAsync(trnPath));
    var records = new List<Dictionary<string, object?>>();
    await using var conn = new SqlConnection(BuildConnString(runtime.Pipeline.ApplyTargetServerInstance, runtime.Pipeline.ApplyTargetDatabase, runtime.Security));
    await conn.OpenAsync();
    SqlTransaction? tran = null;
    if (runtime.Pipeline.ApplyWrapInTransaction) tran = (SqlTransaction)await conn.BeginTransactionAsync();
    try
    {
        for (var i = 0; i < batches.Count; i++)
        {
            var batch = batches[i];
            var action = GetBatchAction(batch);
            if (action == "OTHER") continue;
            await using var cmd = conn.CreateCommand();
            cmd.Transaction = tran;
            cmd.CommandTimeout = 0;
            cmd.CommandText = batch;
            var sw = Stopwatch.StartNew();
            try
            {
                var rows = await cmd.ExecuteNonQueryAsync();
                sw.Stop();
                records.Add(new Dictionary<string, object?> { ["batch_index"] = i + 1, ["action"] = action, ["success"] = true, ["rows_affected"] = rows, ["elapsed_ms"] = (int)sw.ElapsedMilliseconds, ["error"] = null });
            }
            catch (Exception ex)
            {
                sw.Stop();
                records.Add(new Dictionary<string, object?> { ["batch_index"] = i + 1, ["action"] = action, ["success"] = false, ["rows_affected"] = null, ["elapsed_ms"] = (int)sw.ElapsedMilliseconds, ["error"] = ex.Message });
                if (runtime.Pipeline.ApplyStopOnError) throw;
            }
        }
        if (tran is not null) await tran.CommitAsync();
    }
    catch
    {
        if (tran is not null) await tran.RollbackAsync();
        throw;
    }
    var summary = new Dictionary<string, object?> { ["generated_utc"] = DateTime.UtcNow.ToString("O"), ["trn_path"] = trnPath, ["server_instance"] = runtime.Pipeline.ApplyTargetServerInstance, ["database"] = runtime.Pipeline.ApplyTargetDatabase, ["stop_on_error"] = runtime.Pipeline.ApplyStopOnError, ["wrap_in_transaction"] = runtime.Pipeline.ApplyWrapInTransaction, ["total_batches"] = records.Count, ["applied_batches"] = records.Count(r => r.TryGetValue("success", out var v) && v is bool ok && ok), ["failed_batches"] = records.Count(r => r.TryGetValue("success", out var v) && v is bool ok && !ok), ["records"] = records };
    await WriteJsonAsync(applyPath, summary);
    return summary;
}

static Dictionary<string, string> ParseArgs(string[] args)
{
    var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < args.Length; i++)
    {
        var token = args[i];
        if (!token.StartsWith("--", StringComparison.Ordinal)) continue;
        var key = token[2..];
        if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal)) result[key] = args[++i];
        else result[key] = "true";
    }
    return result;
}

static string BuildConnString(string server, string database, SecurityRuntime security)
{
    var builder = new SqlConnectionStringBuilder { DataSource = server, InitialCatalog = database, TrustServerCertificate = true };
    if (security.UseSqlAuth)
    {
        builder.UserID = security.SqlUser;
        builder.Password = security.SqlPassword;
        builder.IntegratedSecurity = false;
    }
    else builder.IntegratedSecurity = true;
    return builder.ConnectionString;
}

static bool UsesOfflineRead(Runtime runtime) => string.Equals(runtime.Pipeline.ReadMode, "offline_read", StringComparison.OrdinalIgnoreCase);
static bool IsRawOfflineExploration(Runtime runtime) => string.Equals(runtime.Pipeline.ReadMode, "raw_offline_exploration", StringComparison.OrdinalIgnoreCase);
static bool CanUseOfflineStartLsn(string? startLsn) => IsValidLsn(startLsn);

static List<OfflineScanProfile> BuildOfflineProfiles()
{
    static HashSet<byte> Markers(params byte[] values) => new(values);
    return
    [
        new OfflineScanProfile("base_inrow_b2_b3_b4_b5_c8_c9_ca_cb_d2_d3", true, true, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD2, 0xD3)),
        new OfflineScanProfile("base_inrow_b2_b3_b4_b5_c8_c9_ca_cb_d1_d2_d3", true, true, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD1, 0xD2, 0xD3)),
        new OfflineScanProfile("broad_b2_b3_b4_b5_c8_c9_ca_cb_d2_d3", false, false, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD2, 0xD3)),
        new OfflineScanProfile("broad_b2_b3_b4_b5_c8_c9_ca_cb_d1_d2_d3", false, false, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD1, 0xD2, 0xD3)),
        new OfflineScanProfile("base_allalloc_b2_b3_b4_b5_c8_c9_ca_cb_d2_d3", true, false, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD2, 0xD3)),
        new OfflineScanProfile("base_allalloc_b2_b3_b4_b5_c8_c9_ca_cb_d1_d2_d3", true, false, Markers(0x00, 0x7D, 0xB2, 0xB3, 0xB4, 0xB5, 0xC8, 0xC9, 0xCA, 0xCB, 0xD1, 0xD2, 0xD3))
    ];
}

static IReadOnlyDictionary<long, (string Schema, string Table)> CreateEmptyTokenMap() =>
    new Dictionary<long, (string Schema, string Table)>();

static List<long> BuildOfflineWindowStarts(long fileLen, long windowSize)
{
    if (fileLen <= 0 || windowSize <= 0)
        return [0];
    if (windowSize >= fileLen)
        return [0];

    long ClampStart(long center)
    {
        var start = center - (windowSize / 2);
        if (start < 0) start = 0;
        var maxStart = Math.Max(0, fileLen - windowSize);
        if (start > maxStart) start = maxStart;
        return start;
    }

    return new[]
    {
        0L,
        ClampStart(fileLen / 4),
        ClampStart(fileLen / 2),
        ClampStart((fileLen * 3) / 4),
        Math.Max(0, fileLen - windowSize)
    }
    .Distinct()
    .OrderBy(x => x)
    .ToList();
}

static List<long> BuildOfflineProbeSegmentStarts(long windowStart, long windowLen, int probeBytes)
{
    if (windowLen <= 0 || probeBytes <= 0)
        return [windowStart];
    var actualProbe = Math.Min((long)probeBytes, windowLen);
    long Clamp(long offset)
    {
        var maxStart = Math.Max(windowStart, windowStart + windowLen - actualProbe);
        if (offset < windowStart) offset = windowStart;
        if (offset > maxStart) offset = maxStart;
        return offset;
    }
    return new[]
    {
        Clamp(windowStart),
        Clamp(windowStart + (windowLen / 2) - (actualProbe / 2)),
        Clamp(windowStart + windowLen - actualProbe)
    }
    .Distinct()
    .OrderBy(x => x)
    .ToList();
}

static byte[] ReadWindowBytes(string path, long offset, long length)
{
    using var fs = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    fs.Seek(offset, SeekOrigin.Begin);
    var bytes = new byte[length];
    var read = 0;
    while (read < length)
    {
        var n = fs.Read(bytes, read, (int)Math.Min(int.MaxValue, length - read));
        if (n <= 0) break;
        read += n;
    }
    if (read < length)
        Array.Resize(ref bytes, read);
    return bytes;
}

static OfflineScanResult RunOfflineScan(
    byte[] bytes,
    long baseOffset,
    IReadOnlyDictionary<long, (string Schema, string Table)> hobtMap,
    bool strictPrimaryTokenOnly,
    IReadOnlySet<byte> acceptedDbMarkers,
    int captureBytes,
    int diagSampleLimit,
    string? startLsn)
{
    var commitsByTx = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
    var candidates = new List<Dictionary<string, object?>>();
    var extractedRecords = new List<ExtractedRecord>();
    var seenKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    var rawCandidateSamples = new List<Dictionary<string, object?>>();
    var actionCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    var dbMarkerCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    var tokenCounts = new Dictionary<long, int>();
    var unresolvedSamples = new List<Dictionary<string, object?>>();
    var prefilterComboCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    string? maxSeenLsn = null;
    var limit = Math.Max(0, bytes.Length - 48);
    for (var i = 0; i < limit; i++)
    {
        if (bytes[i] != 0x00 || bytes[i + 1] != 0x00 || bytes[i + 3] != 0x00)
            continue;

        var lenMarker = bytes[i + 2];
        var dbMarker = bytes[i + 4];
        var recordType = bytes[i + 14];
        var majorOp = bytes[i + 22];
        IncrementCount(prefilterComboCounts, $"len=0x{lenMarker:X2};db=0x{dbMarker:X2};rt=0x{recordType:X2};op=0x{majorOp:X2}");
        if (lenMarker != 0x3E && lenMarker != 0x4C && lenMarker != 0x50)
            continue;

        if (bytes[i + 15] != 0x00 || (recordType != 0x02 && recordType != 0x22))
            continue;

        if (!acceptedDbMarkers.Contains(dbMarker) && dbMarker != 0x25 && dbMarker != 0x26)
            continue;

        var txIdRaw = BitConverter.ToUInt32(bytes, i + 16);
        if (txIdRaw == 0)
            continue;

        var action = ParseOfflineAction(lenMarker, majorOp);
        if (action is null)
            continue;

        var txText = FormatOfflineTxId(txIdRaw);
        var seqPart = BitConverter.ToUInt32(bytes, i + 8);
        var recPart = BitConverter.ToUInt16(bytes, i + 12);
        var lsn = FormatOfflineLsn(dbMarker, seqPart, recPart);
        if (CanUseOfflineStartLsn(startLsn) && CompareLsn(lsn, startLsn!) <= 0)
            continue;
        if (maxSeenLsn is null || CompareLsn(lsn, maxSeenLsn) > 0)
            maxSeenLsn = lsn;
        var hobtToken = (long)BitConverter.ToUInt32(bytes, i + 32);
        var absoluteOffset = baseOffset + i;
        var dedupeKey = $"{absoluteOffset}|{action}|{txText}|{hobtToken}|{lsn}";
        if (!seenKeys.Add(dedupeKey))
            continue;

        IncrementCount(actionCounts, action);
        IncrementCount(dbMarkerCounts, $"0x{dbMarker:X2}");
        IncrementCount(tokenCounts, hobtToken);
        var sliceLen = Math.Min(captureBytes, bytes.Length - i);
        var slice = new byte[sliceLen];
        Array.Copy(bytes, i, slice, 0, sliceLen);
        var evidenceTags = new List<string>();
        var matchedSchema = (string?)null;
        var matchedTable = (string?)null;
        long? matchedTokenForRecord = null;
        var contextHint = $"rt=0x{recordType:X2}";
        var recordTypeText = $"0x{recordType:X2}";
        var pageIdHint = $"{BitConverter.ToUInt32(bytes, i + 24):X8}";
        var slotIdHint = (int?)BitConverter.ToUInt16(bytes, i + 28);
        var indexIdHint = (int?)BitConverter.ToUInt16(bytes, i + 30);
        if (rawCandidateSamples.Count < diagSampleLimit)
        {
            rawCandidateSamples.Add(new Dictionary<string, object?>
            {
                ["offset"] = absoluteOffset,
                ["action"] = action,
                ["tx_id"] = txText,
                ["current_lsn"] = lsn,
                ["db_marker"] = $"0x{dbMarker:X2}",
                ["len_marker"] = $"0x{lenMarker:X2}",
                ["record_type"] = $"0x{recordType:X2}",
                ["major_op"] = $"0x{majorOp:X2}",
                ["primary_token"] = hobtToken,
                ["primary_token_hit"] = hobtMap.ContainsKey(hobtToken),
                ["slice_hex"] = ToHex(slice)
            });
        }

        if (action == "COMMIT")
        {
            evidenceTags.Add("commit");
            if (hobtMap.ContainsKey(hobtToken))
                evidenceTags.Add("primary_token_match");
            extractedRecords.Add(new ExtractedRecord(
                absoluteOffset,
                sliceLen,
                $"0x{dbMarker:X2}",
                $"0x{lenMarker:X2}",
                recordTypeText,
                $"0x{majorOp:X2}",
                action,
                lsn,
                null,
                txText,
                hobtToken,
                matchedTokenForRecord,
                matchedSchema,
                matchedTable,
                strictPrimaryTokenOnly && hobtMap.ContainsKey(hobtToken),
                contextHint,
                pageIdHint,
                slotIdHint,
                indexIdHint,
                ToHex(slice),
                ToAsciiPreview(slice),
                evidenceTags));
            commitsByTx[txText] = absoluteOffset;
            continue;
        }
        if (action == "BEGIN")
        {
            evidenceTags.Add("begin");
            if (hobtMap.ContainsKey(hobtToken))
                evidenceTags.Add("primary_token_match");
            extractedRecords.Add(new ExtractedRecord(
                absoluteOffset,
                sliceLen,
                $"0x{dbMarker:X2}",
                $"0x{lenMarker:X2}",
                recordTypeText,
                $"0x{majorOp:X2}",
                action,
                lsn,
                null,
                txText,
                hobtToken,
                matchedTokenForRecord,
                matchedSchema,
                matchedTable,
                strictPrimaryTokenOnly && hobtMap.ContainsKey(hobtToken),
                contextHint,
                pageIdHint,
                slotIdHint,
                indexIdHint,
                ToHex(slice),
                ToAsciiPreview(slice),
                evidenceTags));
            continue;
        }
        var tableInfo = ResolveOfflineTableInfo(bytes, i, hobtMap, hobtToken, strictPrimaryTokenOnly, out var matchedToken);
        if (tableInfo is null)
        {
            if (hobtMap.ContainsKey(hobtToken))
                evidenceTags.Add("primary_token_match");
            else
                evidenceTags.Add("unmatched_token");
            extractedRecords.Add(new ExtractedRecord(
                absoluteOffset,
                sliceLen,
                $"0x{dbMarker:X2}",
                $"0x{lenMarker:X2}",
                recordTypeText,
                $"0x{majorOp:X2}",
                action,
                lsn,
                null,
                txText,
                hobtToken,
                null,
                null,
                null,
                false,
                contextHint,
                pageIdHint,
                slotIdHint,
                indexIdHint,
                ToHex(slice),
                ToAsciiPreview(slice),
                evidenceTags));
            if (unresolvedSamples.Count < diagSampleLimit)
            {
                var scanWindow = ScanOfflineTokenWindow(bytes, i, hobtMap);
                unresolvedSamples.Add(new Dictionary<string, object?>
                {
                    ["offset"] = absoluteOffset,
                    ["action"] = action,
                    ["tx_id"] = txText,
                    ["current_lsn"] = lsn,
                    ["db_marker"] = $"0x{dbMarker:X2}",
                    ["primary_token"] = hobtToken,
                    ["primary_token_hit"] = hobtMap.ContainsKey(hobtToken),
                    ["token_window_hits"] = scanWindow
                });
            }
            continue;
        }

        matchedSchema = tableInfo.Value.Schema;
        matchedTable = tableInfo.Value.Table;
        matchedTokenForRecord = matchedToken;
        evidenceTags.Add(matchedToken == hobtToken ? "primary_token_match" : "nearby_token_match");
        if (strictPrimaryTokenOnly && matchedToken == hobtToken)
            evidenceTags.Add("strict_primary_token_match");
        extractedRecords.Add(new ExtractedRecord(
            absoluteOffset,
            sliceLen,
            $"0x{dbMarker:X2}",
            $"0x{lenMarker:X2}",
            recordTypeText,
            $"0x{majorOp:X2}",
            action,
            lsn,
            null,
            txText,
            hobtToken,
            matchedTokenForRecord,
            matchedSchema,
            matchedTable,
            strictPrimaryTokenOnly && matchedToken == hobtToken,
            contextHint,
            pageIdHint,
            slotIdHint,
            indexIdHint,
            ToHex(slice),
            ToAsciiPreview(slice),
            evidenceTags));
        candidates.Add(new Dictionary<string, object?>
        {
            ["action"] = action,
            ["current_lsn"] = lsn,
            ["tx_id"] = txText,
            ["operation_name"] = $"OFFLINE_{action}",
            ["context_name"] = null,
            ["schema_name"] = tableInfo.Value.Schema,
            ["table_name"] = tableInfo.Value.Table,
            ["alloc_unit_name"] = $"{tableInfo.Value.Schema}.{tableInfo.Value.Table}",
            ["alloc_unit_id"] = null,
            ["hobt_token"] = matchedToken,
            ["page_id"] = null,
            ["slot_id"] = null,
            ["spid"] = null,
            ["transaction_name"] = "OFFLINE_LDF",
            ["user_name"] = null,
            ["rowlog0_hex"] = ToHex(slice),
            ["rowlog1_hex"] = null,
            ["rowlog2_hex"] = null,
            ["rowlog3_hex"] = null,
            ["rowlog4_hex"] = null,
            ["rowlog5_hex"] = null,
            ["commit_time"] = null,
            ["offset"] = absoluteOffset
        });
    }

    return new OfflineScanResult
    {
        CommitsByTx = commitsByTx,
        Candidates = candidates,
        ExtractedRecords = extractedRecords,
        SeenKeys = seenKeys,
        RawCandidateSamples = rawCandidateSamples,
        ActionCounts = actionCounts,
        DbMarkerCounts = dbMarkerCounts,
        TokenCounts = tokenCounts,
        UnresolvedSamples = unresolvedSamples,
        PrefilterComboCounts = prefilterComboCounts,
        MaxSeenLsn = maxSeenLsn
    };
}

static string? ParseOfflineAction(byte lenMarker, byte majorOp)
{
    if (lenMarker == 0x50 && majorOp == 0x81) return "COMMIT";
    if (lenMarker == 0x4C) return "BEGIN";
    if (lenMarker != 0x3E) return null;
    return majorOp switch
    {
        0x02 => "INSERT",
        0x03 => "DELETE",
        0x04 => "UPDATE",
        0x05 => "UPDATE",
        0x06 => "UPDATE",
        _ => null
    };
}

static string FormatOfflineTxId(uint txId) => $"0000:{txId:X8}";
static string FormatOfflineLsn(byte dbMarker, uint seqPart, ushort recPart) => $"{dbMarker:X8}:{seqPart:X8}:{recPart:X4}";
static string ToHex(byte[] bytes) => "0x" + Convert.ToHexString(bytes);
static string? ToAsciiPreview(byte[] bytes)
{
    var chars = new char[bytes.Length];
    var seenPrintable = false;
    for (var i = 0; i < bytes.Length; i++)
    {
        var b = bytes[i];
        if (b >= 32 && b <= 126)
        {
            chars[i] = (char)b;
            seenPrintable = true;
        }
        else
        {
            chars[i] = '.';
        }
    }

    if (!seenPrintable)
        return null;

    var text = new string(chars);
    text = Regex.Replace(text, @"\.{4,}", ".", RegexOptions.CultureInvariant);
    return text.Trim('.');
}

static List<TransactionBundle> BuildTransactionBundles(IEnumerable<ExtractedRecord> records)
{
    var bundles = new List<TransactionBundle>();
    foreach (var group in records
        .GroupBy(r => r.TransactionId, StringComparer.OrdinalIgnoreCase)
        .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase))
    {
        var ordered = group.OrderBy(r => r.Offset).ToList();
        var actionCounts = ordered
            .GroupBy(r => r.Action, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
        var markerCounts = ordered
            .GroupBy(r => r.DbMarker, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
        var tokensSeen = ordered
            .Select(r => r.MatchedToken ?? r.PrimaryToken)
            .Distinct()
            .OrderBy(x => x)
            .ToList();
        var tablesSeen = ordered
            .Where(r => !string.IsNullOrWhiteSpace(r.MatchedSchema) && !string.IsNullOrWhiteSpace(r.MatchedTable))
            .Select(r => $"{r.MatchedSchema}.{r.MatchedTable}")
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var tags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (ordered.Any(r => string.Equals(r.Action, "COMMIT", StringComparison.OrdinalIgnoreCase)))
            tags.Add("commit_seen");
        if (ordered.Any(r => string.Equals(r.Action, "BEGIN", StringComparison.OrdinalIgnoreCase)))
            tags.Add("begin_seen");
        if (tablesSeen.Count > 0)
            tags.Add("matched_table_activity");
        if (ordered.Any(r => r.EvidenceTags.Any(tag => string.Equals(tag, "strict_primary_token_match", StringComparison.OrdinalIgnoreCase))))
            tags.Add("strict_primary_token_match");
        if (ordered.Any(r => r.EvidenceTags.Any(tag => string.Equals(tag, "nearby_token_match", StringComparison.OrdinalIgnoreCase))))
            tags.Add("nearby_token_match");
        if (ordered.Any(r => !string.IsNullOrWhiteSpace(r.AsciiPreview)))
            tags.Add("printable_payload");

        bundles.Add(new TransactionBundle(
            group.Key,
            ordered.FirstOrDefault(r => !string.Equals(r.Action, "BEGIN", StringComparison.OrdinalIgnoreCase))?.CurrentLsn ?? ordered.First().CurrentLsn,
            ordered.Last().CurrentLsn,
            ordered.Count,
            ordered.Any(r => string.Equals(r.Action, "COMMIT", StringComparison.OrdinalIgnoreCase)),
            markerCounts,
            actionCounts,
            tablesSeen,
            tokensSeen,
            ordered.First().Offset,
            ordered.Last().Offset,
            ordered.Take(5).Select(r => new Dictionary<string, object?>
            {
                ["offset"] = r.Offset,
                ["action"] = r.Action,
                ["db_marker"] = r.DbMarker,
                ["primary_token"] = r.PrimaryToken,
                ["matched_token"] = r.MatchedToken,
                ["matched_table"] = string.IsNullOrWhiteSpace(r.MatchedSchema) || string.IsNullOrWhiteSpace(r.MatchedTable) ? null : $"{r.MatchedSchema}.{r.MatchedTable}",
                ["ascii_preview"] = r.AsciiPreview,
                ["evidence_tags"] = r.EvidenceTags
            }).ToList(),
            tags.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList()));
    }

    return bundles;
}

static List<CommandCandidate> BuildCommandCandidates(IEnumerable<TransactionBundle> bundles, IEnumerable<ExtractedRecord> records, MetadataCatalog metadataCatalog)
{
    var byTx = records
        .GroupBy(r => r.TransactionId, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.OrderBy(r => r.Offset).ToList(), StringComparer.OrdinalIgnoreCase);
    var commands = new List<CommandCandidate>();

    foreach (var bundle in bundles.OrderBy(b => b.TransactionId, StringComparer.OrdinalIgnoreCase))
    {
        if (!byTx.TryGetValue(bundle.TransactionId, out var txRecords) || txRecords.Count == 0)
            continue;

        var d2BundleCommands = TryBuildD2BundleCommands(bundle, txRecords);
        if (d2BundleCommands is not null)
        {
            commands.AddRange(d2BundleCommands);
            continue;
        }

        var groups = new List<List<ExtractedRecord>>();
        List<ExtractedRecord>? current = null;
        ExtractedRecord? prev = null;
        foreach (var rec in txRecords)
        {
            var breakGroup =
                current is not null &&
                prev is not null &&
                (
                    !string.Equals(prev.DbMarker, rec.DbMarker, StringComparison.OrdinalIgnoreCase) ||
                    !string.Equals(prev.Action, rec.Action, StringComparison.OrdinalIgnoreCase) ||
                    prev.PrimaryToken != rec.PrimaryToken ||
                    rec.Offset - prev.Offset > 4096
                );
            if (current is null || breakGroup)
            {
                current = new List<ExtractedRecord>();
                groups.Add(current);
            }
            current.Add(rec);
            prev = rec;
        }

        var ordinal = 1;
        foreach (var group in groups)
        {
            var markerCounts = group.GroupBy(r => r.DbMarker, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
            var actionCounts = group.GroupBy(r => r.Action, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
            var tablesSeen = group
                .Where(r => !string.IsNullOrWhiteSpace(r.MatchedSchema) && !string.IsNullOrWhiteSpace(r.MatchedTable))
                .Select(r => $"{r.MatchedSchema}.{r.MatchedTable}")
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
                .ToList();
            var tokensSeen = group.Select(r => r.MatchedToken ?? r.PrimaryToken).Distinct().OrderBy(x => x).ToList();
            var tags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (group.Any(r => !string.IsNullOrWhiteSpace(r.AsciiPreview)))
                tags.Add("printable_payload");
            if (group.Any(r => r.EvidenceTags.Any(tag => string.Equals(tag, "strict_primary_token_match", StringComparison.OrdinalIgnoreCase))))
                tags.Add("strict_primary_token_match");
            if (group.All(r => string.Equals(r.DbMarker, "0xD2", StringComparison.OrdinalIgnoreCase)))
                tags.Add("homogeneous_d2");

            var d2Records = group
                .Select(r => (Record: r, Info: TryAnalyzeD2Record(r)))
                .Where(x => x.Info is not null)
                .ToList();
            var d2Summary = d2Records.Count == 0
                ? null
                : new Dictionary<string, object?>
                {
                    ["record_count"] = d2Records.Count,
                    ["dense_count"] = d2Records.Count(x => !x.Info!.IsControl),
                    ["control_count"] = d2Records.Count(x => x.Info!.IsControl),
                    ["ordinals"] = d2Records.Where(x => !x.Info!.IsControl && x.Info.Ordinal.HasValue).Select(x => x.Info!.Ordinal!.Value).OrderBy(x => x).ToList(),
                    ["marker_families"] = d2Records.Where(x => !string.IsNullOrWhiteSpace(x.Info!.MarkerFamily)).GroupBy(x => x.Info!.MarkerFamily!, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase),
                    ["echo_values"] = d2Records.Where(x => x.Info!.EchoValue.HasValue).Select(x => x.Info!.EchoValue!.Value).Distinct().OrderBy(x => x).ToList()
                };
            if (d2Summary is not null)
                tags.Add("d2_structured");

            commands.Add(new CommandCandidate(
                $"{bundle.TransactionId}#{ordinal:000}",
                bundle.TransactionId,
                InferCommandType(actionCounts),
                group.Count,
                group.First().CurrentLsn,
                group.Last().CurrentLsn,
                group.First().Offset,
                group.Last().Offset,
                markerCounts,
                actionCounts,
                tablesSeen,
                tokensSeen,
                "transaction_cluster_v1",
                ComputeCommandConfidence(group, tablesSeen),
                tags.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
                d2Summary,
                group.Take(8).Select(r => new Dictionary<string, object?>
                {
                    ["offset"] = r.Offset,
                    ["action"] = r.Action,
                    ["db_marker"] = r.DbMarker,
                    ["primary_token"] = r.PrimaryToken,
                    ["matched_table"] = string.IsNullOrWhiteSpace(r.MatchedSchema) || string.IsNullOrWhiteSpace(r.MatchedTable) ? null : $"{r.MatchedSchema}.{r.MatchedTable}",
                    ["ascii_preview"] = r.AsciiPreview,
                    ["evidence_tags"] = r.EvidenceTags
                }).ToList()));
            ordinal++;
        }
    }

    return EnrichCommandCandidates(commands, metadataCatalog);
}

static List<CommandCandidate> EnrichCommandCandidates(List<CommandCandidate> commands, MetadataCatalog metadataCatalog)
{
    var enriched = new List<CommandCandidate>();

    foreach (var txGroup in commands
        .GroupBy(c => c.TransactionId, StringComparer.OrdinalIgnoreCase)
        .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase))
    {
        var ordered = txGroup
            .OrderBy(c => c.FirstOffset)
            .ThenBy(c => c.LastOffset)
            .ThenBy(c => c.CommandId, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var templateMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var templateRepeatCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var templateOrdinal = 1;

        for (var i = 0; i < ordered.Count; i++)
        {
            var command = ordered[i];
            var templateSignature = BuildCommandTemplateSignature(command);
            if (!templateMap.TryGetValue(templateSignature, out var templateId))
            {
                templateId = $"TPL{templateOrdinal:000}";
                templateMap[templateSignature] = templateId;
                templateRepeatCounts[templateId] = 0;
                templateOrdinal++;
            }

            templateRepeatCounts[templateId]++;
            var prev = i > 0 ? ordered[i - 1].CommandId : null;
            var next = i < ordered.Count - 1 ? ordered[i + 1].CommandId : null;
            var printableSignals = ExtractPrintableSignals(command);
            var enrichedCommand = command with
            {
                SequenceNumber = i + 1,
                PreviousCommandId = prev,
                NextCommandId = next,
                TemplateId = templateId,
                TemplateRepeatIndex = templateRepeatCounts[templateId],
                CommandRole = InferCommandRole(command),
                PrintableSignals = printableSignals
            };

            enriched.Add(enrichedCommand with
            {
                Inference = InferCommandTarget(enrichedCommand, metadataCatalog)
            });
        }
    }

    return enriched;
}

static Dictionary<string, object?> InferCommandTarget(CommandCandidate command, MetadataCatalog metadataCatalog)
{
    if (command.TablesSeen.Count > 0)
    {
        return new Dictionary<string, object?>
        {
            ["target_kind"] = "table",
            ["confidence"] = "high",
            ["candidate_tables"] = command.TablesSeen,
            ["matched_terms"] = command.TablesSeen,
            ["rationale"] = "Command records already contain matched schema/table assignments."
        };
    }

    var terms = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var signal in command.PrintableSignals ?? new List<string>())
    {
        foreach (var term in NormalizeInferenceTerms(signal))
            terms.Add(term);
    }

    var candidates = metadataCatalog.Tables
        .Select(t => new
        {
            Table = t.QualifiedTable,
            Matches = t.Terms.Intersect(terms, StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList()
        })
        .Where(x => x.Matches.Count > 0)
        .OrderByDescending(x => x.Matches.Count)
        .ThenBy(x => x.Table, StringComparer.OrdinalIgnoreCase)
        .Take(5)
        .ToList();

    if (candidates.Count > 0)
    {
        var topScore = candidates[0].Matches.Count;
        var confidence = topScore >= 2 ? "medium" : "low";
        return new Dictionary<string, object?>
        {
            ["target_kind"] = "table_hint",
            ["confidence"] = confidence,
            ["candidate_tables"] = candidates.Select(x => x.Table).ToList(),
            ["matched_terms"] = candidates.SelectMany(x => x.Matches).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
            ["rationale"] = "Candidate tables inferred from printable command signals matched against metadata snapshot table/column terms."
        };
    }

    if (command.D2Summary is not null)
    {
        return new Dictionary<string, object?>
        {
            ["target_kind"] = "structured_bundle",
            ["confidence"] = "low",
            ["candidate_tables"] = new List<string>(),
            ["matched_terms"] = terms.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
            ["rationale"] = "Structured D2 bundle with no direct metadata keyword hits; likely requires bundle-level decoding before table attribution."
        };
    }

    return new Dictionary<string, object?>
    {
        ["target_kind"] = "unknown",
        ["confidence"] = "low",
        ["candidate_tables"] = new List<string>(),
        ["matched_terms"] = terms.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
        ["rationale"] = "No direct table match and no metadata keyword hits."
    };
}

static List<Dictionary<string, object?>> BuildCommandNeighborhoods(List<CommandCandidate> commands)
{
    var ordered = commands
        .OrderBy(c => c.FirstOffset)
        .ThenBy(c => c.LastOffset)
        .ThenBy(c => c.CommandId, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var neighborhoods = new List<List<CommandCandidate>>();
    List<CommandCandidate>? current = null;
    CommandCandidate? prev = null;
    foreach (var command in ordered)
    {
        var breakGroup =
            current is not null &&
            prev is not null &&
            command.FirstOffset - prev.LastOffset > 16384;

        if (current is null || breakGroup)
        {
            current = new List<CommandCandidate>();
            neighborhoods.Add(current);
        }

        current.Add(command);
        prev = command;
    }

    var results = new List<Dictionary<string, object?>>();
    var neighborhoodOrdinal = 1;
    foreach (var group in neighborhoods)
    {
        var printableSignals = group
            .SelectMany(c => c.PrintableSignals ?? new List<string>())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .Take(12)
            .ToList();
        var inferredTables = group
            .SelectMany(c => c.Inference is null || !c.Inference.TryGetValue("candidate_tables", out var obj)
                ? (IEnumerable<string>)Array.Empty<string>()
                : ToStringList(obj))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .Take(12)
            .ToList();
        var markerCounts = group
            .SelectMany(c => c.MarkerCounts)
            .GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Value), StringComparer.OrdinalIgnoreCase);
        var groupingModes = group
            .Select(c => c.GroupingMode)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();

        results.Add(new Dictionary<string, object?>
        {
            ["neighborhood_id"] = $"N{neighborhoodOrdinal:000}",
            ["command_count"] = group.Count,
            ["first_offset"] = group.First().FirstOffset,
            ["last_offset"] = group.Last().LastOffset,
            ["span_bytes"] = group.Last().LastOffset - group.First().FirstOffset,
            ["grouping_modes"] = groupingModes,
            ["marker_counts"] = markerCounts,
            ["mixed_markers"] = markerCounts.Count > 1,
            ["transactions"] = group.Select(c => c.TransactionId).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
            ["candidate_tables"] = inferredTables,
            ["printable_signals"] = printableSignals,
            ["commands"] = group.Select(c => new Dictionary<string, object?>
            {
                ["command_id"] = c.CommandId,
                ["transaction_id"] = c.TransactionId,
                ["type"] = c.CommandType,
                ["first_offset"] = c.FirstOffset,
                ["last_offset"] = c.LastOffset,
                ["markers"] = c.MarkerCounts,
                ["role"] = c.CommandRole,
                ["template_id"] = c.TemplateId,
                ["printable_signals"] = c.PrintableSignals,
                ["inference"] = c.Inference
            }).ToList()
        });

        neighborhoodOrdinal++;
    }

    return results;
}

static List<Dictionary<string, object?>> BuildCommandBehaviorClusters(List<CommandCandidate> commands)
{
    var clusters = commands
        .GroupBy(c => BuildBehaviorClusterKey(c), StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(g => g.Count())
        .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var results = new List<Dictionary<string, object?>>();
    var ordinal = 1;
    foreach (var cluster in clusters)
    {
        var ordered = cluster
            .OrderBy(c => c.FirstOffset)
            .ThenBy(c => c.CommandId, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var markerCounts = ordered
            .SelectMany(c => c.MarkerCounts)
            .GroupBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Value), StringComparer.OrdinalIgnoreCase);
        var candidateTables = ordered
            .SelectMany(c => c.Inference is null || !c.Inference.TryGetValue("candidate_tables", out var obj)
                ? (IEnumerable<string>)Array.Empty<string>()
                : ToStringList(obj))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .Take(10)
            .ToList();
        var printableSignals = ordered
            .SelectMany(c => c.PrintableSignals ?? new List<string>())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .Take(12)
            .ToList();
        var themes = ordered
            .Select(c => InferBehaviorTheme(c))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();

        results.Add(new Dictionary<string, object?>
        {
            ["cluster_id"] = $"C{ordinal:000}",
            ["cluster_key"] = cluster.Key,
            ["command_count"] = ordered.Count,
            ["themes"] = themes,
            ["marker_counts"] = markerCounts,
            ["candidate_tables"] = candidateTables,
            ["printable_signals"] = printableSignals,
            ["template_ids"] = ordered.Select(c => c.TemplateId).Where(x => !string.IsNullOrWhiteSpace(x)).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
            ["commands"] = ordered.Take(20).Select(c => new Dictionary<string, object?>
            {
                ["command_id"] = c.CommandId,
                ["transaction_id"] = c.TransactionId,
                ["type"] = c.CommandType,
                ["first_offset"] = c.FirstOffset,
                ["last_offset"] = c.LastOffset,
                ["role"] = c.CommandRole,
                ["template_id"] = c.TemplateId,
                ["printable_signals"] = c.PrintableSignals,
                ["inference"] = c.Inference
            }).ToList()
        });
        ordinal++;
    }

    return results;
}

static List<Dictionary<string, object?>> BuildCommandCorrelationFocus(List<Dictionary<string, object?>> clusters)
{
    var keepThemes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "attachments",
        "invoice",
        "history",
        "commercial_adjustment",
        "status_sync",
        "d2_structured"
    };

    return clusters
        .Where(cluster =>
        {
            if (!cluster.TryGetValue("themes", out var value) || value is null)
                return false;
            var themes = ToStringList(value);
            return themes.Any(theme => keepThemes.Contains(theme));
        })
        .OrderByDescending(cluster => TryGetDictionaryInt(cluster, "command_count") ?? 0)
        .ThenBy(cluster => cluster.TryGetValue("cluster_key", out var key) ? key?.ToString() : string.Empty, StringComparer.OrdinalIgnoreCase)
        .ToList();
}

static List<Dictionary<string, object?>> BuildCommandSemanticTimeline(List<CommandCandidate> commands)
{
    var focusThemes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "attachments",
        "invoice",
        "commercial_adjustment",
        "history",
        "status_sync",
        "d2_structured"
    };

    var focused = commands
        .Select(c => new
        {
            Command = c,
            Theme = InferBehaviorTheme(c)
        })
        .Where(x => focusThemes.Contains(x.Theme))
        .OrderBy(x => x.Command.FirstOffset)
        .ThenBy(x => x.Command.CommandId, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var d2 = focused
        .Where(x => string.Equals(x.Theme, "d2_structured", StringComparison.OrdinalIgnoreCase))
        .ToList();

    var results = new List<Dictionary<string, object?>>();
    for (var i = 0; i < focused.Count; i++)
    {
        var item = focused[i];
        var previousD2 = d2
            .Where(x => x.Command.LastOffset <= item.Command.FirstOffset)
            .OrderByDescending(x => x.Command.LastOffset)
            .FirstOrDefault();
        var nextD2 = d2
            .Where(x => x.Command.FirstOffset >= item.Command.LastOffset)
            .OrderBy(x => x.Command.FirstOffset)
            .FirstOrDefault();

        results.Add(new Dictionary<string, object?>
        {
            ["sequence"] = i + 1,
            ["command_id"] = item.Command.CommandId,
            ["transaction_id"] = item.Command.TransactionId,
            ["theme"] = item.Theme,
            ["type"] = item.Command.CommandType,
            ["first_offset"] = item.Command.FirstOffset,
            ["last_offset"] = item.Command.LastOffset,
            ["template_id"] = item.Command.TemplateId,
            ["role"] = item.Command.CommandRole,
            ["candidate_tables"] = item.Command.Inference is not null && item.Command.Inference.TryGetValue("candidate_tables", out var tablesObj) ? ToStringList(tablesObj) : new List<string>(),
            ["printable_signals"] = item.Command.PrintableSignals ?? new List<string>(),
            ["nearest_previous_d2"] = previousD2 is null
                ? null
                : new Dictionary<string, object?>
                {
                    ["command_id"] = previousD2.Command.CommandId,
                    ["theme"] = previousD2.Theme,
                    ["first_offset"] = previousD2.Command.FirstOffset,
                    ["last_offset"] = previousD2.Command.LastOffset,
                    ["delta_bytes"] = item.Command.FirstOffset - previousD2.Command.LastOffset
                },
            ["nearest_next_d2"] = nextD2 is null
                ? null
                : new Dictionary<string, object?>
                {
                    ["command_id"] = nextD2.Command.CommandId,
                    ["theme"] = nextD2.Theme,
                    ["first_offset"] = nextD2.Command.FirstOffset,
                    ["last_offset"] = nextD2.Command.LastOffset,
                    ["delta_bytes"] = nextD2.Command.FirstOffset - item.Command.LastOffset
                }
        });
    }

    return results;
}

static List<Dictionary<string, object?>> BuildSemanticEvents(List<CommandCandidate> commands)
{
    var events = new List<Dictionary<string, object?>>();
    foreach (var command in commands.OrderBy(c => c.FirstOffset).ThenBy(c => c.CommandId, StringComparer.OrdinalIgnoreCase))
    {
        var theme = InferBehaviorTheme(command);
        if (string.Equals(theme, "commercial_adjustment", StringComparison.OrdinalIgnoreCase))
        {
            var extracted = TryExtractCommercialAdjustmentEvent(command);
            if (extracted is not null)
                events.Add(extracted);
        }
        else if (string.Equals(theme, "attachments", StringComparison.OrdinalIgnoreCase))
        {
            var extracted = TryExtractAttachmentEvent(command);
            if (extracted is not null)
                events.Add(extracted);
        }
        else if (string.Equals(theme, "invoice", StringComparison.OrdinalIgnoreCase))
        {
            var extracted = TryExtractInvoiceEvent(command);
            if (extracted is not null)
                events.Add(extracted);
        }
        else if (string.Equals(theme, "history", StringComparison.OrdinalIgnoreCase))
        {
            var extracted = TryExtractHistoryEvent(command);
            if (extracted is not null)
                events.Add(extracted);
        }
    }

    return events;
}

static Dictionary<string, object?> BuildSemanticRecoveryReport(List<Dictionary<string, object?>> events)
{
    var orderedEvents = events
        .OrderBy(e => TryGetLongValue(e, "first_offset") ?? long.MaxValue)
        .ThenBy(e => GetStringValue(e, "command_id") ?? string.Empty, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var eventKindCounts = orderedEvents
        .GroupBy(e => GetStringValue(e, "event_kind") ?? "unknown", StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(g => g.Count())
        .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

    var candidateTableCounts = orderedEvents
        .SelectMany(e => e.TryGetValue("candidate_tables", out var value) ? ToStringList(value) : new List<string>())
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .GroupBy(x => x, StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(g => g.Count())
        .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

    var recommendedTables = BuildPreferredTableRanking("all", candidateTableCounts);

    var familySummaries = orderedEvents
        .GroupBy(e => GetStringValue(e, "event_kind") ?? "unknown", StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(g => g.Count())
        .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
        .Select(group => BuildSemanticFamilySummary(group.Key, group.ToList()))
        .ToList();

    var notableEvents = orderedEvents
        .Select((evt, index) => new Dictionary<string, object?>
        {
            ["sequence"] = index + 1,
            ["event_kind"] = GetStringValue(evt, "event_kind"),
            ["command_id"] = GetStringValue(evt, "command_id"),
            ["transaction_id"] = GetStringValue(evt, "transaction_id"),
            ["first_offset"] = TryGetLongValue(evt, "first_offset"),
            ["candidate_tables"] = evt.TryGetValue("candidate_tables", out var tables) ? ToStringList(tables) : new List<string>(),
            ["primary_candidate_table"] = ChoosePrimaryCandidateTable(GetStringValue(evt, "event_kind"), evt.TryGetValue("candidate_tables", out var tablesObj) ? ToStringList(tablesObj) : new List<string>()),
            ["headline"] = BuildSemanticEventHeadline(evt)
        })
        .ToList();

    return new Dictionary<string, object?>
    {
        ["event_count"] = orderedEvents.Count,
        ["event_kind_counts"] = eventKindCounts,
        ["candidate_table_counts"] = candidateTableCounts,
        ["recommended_tables"] = recommendedTables,
        ["family_summaries"] = familySummaries,
        ["notable_events"] = notableEvents
    };
}

static List<Dictionary<string, object?>> BuildBusinessEventFeed(List<Dictionary<string, object?>> events)
{
    return events
        .OrderBy(e => TryGetLongValue(e, "first_offset") ?? long.MaxValue)
        .ThenBy(e => GetStringValue(e, "command_id") ?? string.Empty, StringComparer.OrdinalIgnoreCase)
        .Select((evt, index) => new Dictionary<string, object?>
        {
            ["sequence"] = index + 1,
            ["event_kind"] = GetStringValue(evt, "event_kind"),
            ["primary_table"] = ChoosePrimaryCandidateTable(
                GetStringValue(evt, "event_kind"),
                evt.TryGetValue("candidate_tables", out var tableObj) ? ToStringList(tableObj) : new List<string>()),
            ["identifier"] = BuildBusinessEventIdentifier(evt),
            ["headline"] = BuildSemanticEventHeadline(evt),
            ["transaction_id"] = GetStringValue(evt, "transaction_id"),
            ["command_id"] = GetStringValue(evt, "command_id"),
            ["first_offset"] = TryGetLongValue(evt, "first_offset")
        })
        .ToList();
}

static Dictionary<string, object?> BuildSemanticFamilySummary(string eventKind, List<Dictionary<string, object?>> events)
{
    var ordered = events
        .OrderBy(e => TryGetLongValue(e, "first_offset") ?? long.MaxValue)
        .ThenBy(e => GetStringValue(e, "command_id") ?? string.Empty, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var candidateTableCounts = ordered
        .SelectMany(e => e.TryGetValue("candidate_tables", out var value) ? ToStringList(value) : new List<string>())
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .GroupBy(x => x, StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(g => g.Count())
        .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

    var preferredTables = BuildPreferredTableRanking(eventKind, candidateTableCounts);
    var candidateTableCountList = candidateTableCounts
        .Select(g => new Dictionary<string, object?>
        {
            ["table"] = g.Key,
            ["count"] = g.Value
        })
        .ToList();

    var transactionIds = ordered
        .Select(e => GetStringValue(e, "transaction_id"))
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
        .ToList();

    var summary = new Dictionary<string, object?>
    {
        ["event_kind"] = eventKind,
        ["event_count"] = ordered.Count,
        ["transaction_count"] = transactionIds.Count,
        ["candidate_tables"] = candidateTableCountList,
        ["preferred_tables"] = preferredTables,
        ["primary_candidate_table"] = preferredTables.FirstOrDefault() is Dictionary<string, object?> preferred && preferred.TryGetValue("table", out var primaryTableObj) ? primaryTableObj : null,
        ["transaction_ids"] = transactionIds,
        ["headlines"] = ordered.Select(BuildSemanticEventHeadline).Distinct(StringComparer.OrdinalIgnoreCase).Take(12).ToList()
    };

    if (string.Equals(eventKind, "commercial_adjustment", StringComparison.OrdinalIgnoreCase))
    {
        var typeCodes = ordered
            .Select(e => GetStringValue(e, "type_code"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var adjustments = ordered
            .Select(e => new Dictionary<string, object?>
            {
                ["type_code"] = GetStringValue(e, "type_code"),
                ["old_price"] = TryGetDecimalValue(e, "old_price"),
                ["new_price"] = TryGetDecimalValue(e, "new_price"),
                ["price_delta"] = ComputePriceDelta(e),
                ["command_id"] = GetStringValue(e, "command_id")
            })
            .ToList();

        summary["type_codes"] = typeCodes;
        summary["adjustments"] = adjustments;
    }
    else if (string.Equals(eventKind, "attachment_activity", StringComparison.OrdinalIgnoreCase))
    {
        summary["attachment_scopes"] = ordered
            .Select(e => GetStringValue(e, "attachment_scope"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
        summary["status_labels"] = ordered
            .Select(e => GetStringValue(e, "status_label"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
        summary["reference_ids"] = ordered
            .Select(e => GetStringValue(e, "reference_id"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
    else if (string.Equals(eventKind, "invoice_activity", StringComparison.OrdinalIgnoreCase))
    {
        summary["invoice_ids"] = ordered
            .Select(e => GetStringValue(e, "invoice_id"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
        summary["invoice_line_reference_count"] = ordered.Count(e => TryGetBoolValue(e, "has_invoice_line_reference") == true);
        summary["possible_misapplication_count"] = ordered.Count(e => TryGetBoolValue(e, "possible_misapplication") == true);
    }
    else if (string.Equals(eventKind, "history_activity", StringComparison.OrdinalIgnoreCase))
    {
        summary["history_markers"] = ordered
            .Select(e => GetStringValue(e, "history_marker"))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    return summary;
}

static List<Dictionary<string, object?>> BuildPreferredTableRanking(string? eventKind, IReadOnlyDictionary<string, int> candidateTableCounts)
{
    return candidateTableCounts
        .Select(kvp =>
        {
            var affinity = GetSemanticTableAffinity(eventKind, kvp.Key);
            return new
            {
                Table = kvp.Key,
                Count = kvp.Value,
                Affinity = affinity,
                Score = (affinity * 1000) + kvp.Value
            };
        })
        .OrderByDescending(x => x.Score)
        .ThenByDescending(x => x.Count)
        .ThenBy(x => x.Table, StringComparer.OrdinalIgnoreCase)
        .Select(x => new Dictionary<string, object?>
        {
            ["table"] = x.Table,
            ["count"] = x.Count,
            ["affinity"] = x.Affinity,
            ["score"] = x.Score
        })
        .ToList();
}

static string? ChoosePrimaryCandidateTable(string? eventKind, List<string> candidateTables)
{
    if (candidateTables.Count == 0)
        return null;

    return candidateTables
        .Select(table => new
        {
            Table = table,
            Affinity = GetSemanticTableAffinity(eventKind, table)
        })
        .OrderByDescending(x => x.Affinity)
        .ThenBy(x => x.Table, StringComparer.OrdinalIgnoreCase)
        .FirstOrDefault()
        ?.Table;
}

static int GetSemanticTableAffinity(string? eventKind, string table)
{
    if (string.IsNullOrWhiteSpace(table))
        return 0;

    var normalizedEventKind = (eventKind ?? string.Empty).Trim();
    var normalizedTable = table.Trim();

    if (string.Equals(normalizedEventKind, "attachment_activity", StringComparison.OrdinalIgnoreCase))
    {
        if (normalizedTable.Contains("ATTACHMENTS", StringComparison.OrdinalIgnoreCase))
            return 5;
        if (normalizedTable.Contains("QUOTE_ATTACHMENTS", StringComparison.OrdinalIgnoreCase))
            return 6;
        if (normalizedTable.Contains("QUOTE", StringComparison.OrdinalIgnoreCase))
            return 2;
        return 0;
    }

    if (string.Equals(normalizedEventKind, "invoice_activity", StringComparison.OrdinalIgnoreCase))
    {
        if (normalizedTable.Contains("INVOICELINE", StringComparison.OrdinalIgnoreCase))
            return 6;
        if (normalizedTable.Contains("INVOICE", StringComparison.OrdinalIgnoreCase))
            return 5;
        if (normalizedTable.Contains("SHIPMENTLINE", StringComparison.OrdinalIgnoreCase))
            return 2;
        return 0;
    }

    if (string.Equals(normalizedEventKind, "history_activity", StringComparison.OrdinalIgnoreCase))
    {
        if (normalizedTable.Contains("HISTORY", StringComparison.OrdinalIgnoreCase))
            return 6;
        if (normalizedTable.Contains("POLINE", StringComparison.OrdinalIgnoreCase))
            return 3;
        return 0;
    }

    if (string.Equals(normalizedEventKind, "commercial_adjustment", StringComparison.OrdinalIgnoreCase))
    {
        if (normalizedTable.Contains("QUOTELINE", StringComparison.OrdinalIgnoreCase))
            return 6;
        if (normalizedTable.Contains("QUOTE", StringComparison.OrdinalIgnoreCase))
            return 4;
        if (normalizedTable.Contains("INVOICE", StringComparison.OrdinalIgnoreCase))
            return 1;
        return 0;
    }

    if (string.Equals(normalizedEventKind, "all", StringComparison.OrdinalIgnoreCase))
    {
        if (normalizedTable.Contains("INVOICELINE", StringComparison.OrdinalIgnoreCase))
            return 4;
        if (normalizedTable.Contains("INVOICE", StringComparison.OrdinalIgnoreCase))
            return 3;
        if (normalizedTable.Contains("ATTACHMENTS", StringComparison.OrdinalIgnoreCase))
            return 3;
        if (normalizedTable.Contains("QUOTELINE", StringComparison.OrdinalIgnoreCase))
            return 3;
        if (normalizedTable.Contains("HISTORY", StringComparison.OrdinalIgnoreCase))
            return 2;
    }

    return 0;
}

static string BuildSemanticEventHeadline(Dictionary<string, object?> evt)
{
    var eventKind = GetStringValue(evt, "event_kind") ?? "event";
    if (string.Equals(eventKind, "commercial_adjustment", StringComparison.OrdinalIgnoreCase))
    {
        var typeCode = GetStringValue(evt, "type_code");
        var oldPrice = TryGetDecimalValue(evt, "old_price");
        var newPrice = TryGetDecimalValue(evt, "new_price");
        if (!string.IsNullOrWhiteSpace(typeCode) && oldPrice.HasValue && newPrice.HasValue)
            return $"commercial_adjustment {typeCode} ${oldPrice.Value.ToString("0.##", CultureInfo.InvariantCulture)} -> ${newPrice.Value.ToString("0.##", CultureInfo.InvariantCulture)}";
    }
    else if (string.Equals(eventKind, "attachment_activity", StringComparison.OrdinalIgnoreCase))
    {
        var scope = GetStringValue(evt, "attachment_scope");
        var referenceId = GetStringValue(evt, "reference_id");
        var statusLabel = GetStringValue(evt, "status_label");
        var parts = new[] { scope, referenceId, statusLabel }.Where(x => !string.IsNullOrWhiteSpace(x)).ToList();
        if (parts.Count > 0)
            return $"attachment_activity {string.Join(" | ", parts)}";
    }
    else if (string.Equals(eventKind, "invoice_activity", StringComparison.OrdinalIgnoreCase))
    {
        var invoiceId = GetStringValue(evt, "invoice_id");
        var qualifiers = new List<string>();
        if (!string.IsNullOrWhiteSpace(invoiceId))
            qualifiers.Add($"invoice {invoiceId}");
        if (TryGetBoolValue(evt, "has_invoice_line_reference") == true)
            qualifiers.Add("invoice line");
        if (TryGetBoolValue(evt, "possible_misapplication") == true)
            qualifiers.Add("possible misapplication");
        if (qualifiers.Count > 0)
            return $"invoice_activity {string.Join(" | ", qualifiers)}";
    }
    else if (string.Equals(eventKind, "history_activity", StringComparison.OrdinalIgnoreCase))
    {
        var marker = GetStringValue(evt, "history_marker");
        if (!string.IsNullOrWhiteSpace(marker))
            return $"history_activity {marker}";
    }

    return GetStringValue(evt, "message_preview") ?? eventKind;
}

static string? BuildBusinessEventIdentifier(Dictionary<string, object?> evt)
{
    var eventKind = GetStringValue(evt, "event_kind");
    if (string.Equals(eventKind, "commercial_adjustment", StringComparison.OrdinalIgnoreCase))
    {
        var typeCode = GetStringValue(evt, "type_code");
        if (!string.IsNullOrWhiteSpace(typeCode))
            return $"type:{typeCode}";
    }
    else if (string.Equals(eventKind, "attachment_activity", StringComparison.OrdinalIgnoreCase))
    {
        var referenceId = GetStringValue(evt, "reference_id");
        if (!string.IsNullOrWhiteSpace(referenceId))
            return referenceId;
        var scope = GetStringValue(evt, "attachment_scope");
        if (!string.IsNullOrWhiteSpace(scope))
            return scope;
        var attachmentLabel = GetStringValue(evt, "attachment_label");
        if (!string.IsNullOrWhiteSpace(attachmentLabel))
            return attachmentLabel;
    }
    else if (string.Equals(eventKind, "invoice_activity", StringComparison.OrdinalIgnoreCase))
    {
        var invoiceId = GetStringValue(evt, "invoice_id");
        if (!string.IsNullOrWhiteSpace(invoiceId))
            return $"invoice:{invoiceId}";
        if (TryGetBoolValue(evt, "possible_misapplication") == true)
            return "possible_misapplication";
        if (TryGetBoolValue(evt, "has_invoice_line_reference") == true)
            return "invoice_line_reference";
    }
    else if (string.Equals(eventKind, "history_activity", StringComparison.OrdinalIgnoreCase))
    {
        var historyMarker = GetStringValue(evt, "history_marker");
        if (!string.IsNullOrWhiteSpace(historyMarker))
            return historyMarker;
    }

    return GetStringValue(evt, "command_id");
}

static decimal? ComputePriceDelta(Dictionary<string, object?> evt)
{
    var oldPrice = TryGetDecimalValue(evt, "old_price");
    var newPrice = TryGetDecimalValue(evt, "new_price");
    if (!oldPrice.HasValue || !newPrice.HasValue)
        return null;
    return newPrice.Value - oldPrice.Value;
}

static Dictionary<string, object?> BuildSemanticEventBase(string eventKind, CommandCandidate command, string messagePreview)
{
    return new Dictionary<string, object?>
    {
        ["event_kind"] = eventKind,
        ["command_id"] = command.CommandId,
        ["transaction_id"] = command.TransactionId,
        ["command_type"] = command.CommandType,
        ["first_offset"] = command.FirstOffset,
        ["last_offset"] = command.LastOffset,
        ["candidate_tables"] = command.Inference is not null && command.Inference.TryGetValue("candidate_tables", out var obj) ? ToStringList(obj) : new List<string>(),
        ["printable_signals"] = command.PrintableSignals ?? new List<string>(),
        ["message_preview"] = messagePreview
    };
}

static Dictionary<string, object?>? TryExtractCommercialAdjustmentEvent(CommandCandidate command)
{
    var textSources = new List<string>();
    if (command.PrintableSignals is not null)
        textSources.AddRange(command.PrintableSignals.Where(x => !string.IsNullOrWhiteSpace(x)));
    foreach (var sample in command.SampleRecords)
    {
        if (sample.TryGetValue("ascii_preview", out var value) && value is not null)
        {
            var text = value.ToString();
            if (!string.IsNullOrWhiteSpace(text))
                textSources.Add(text!);
        }
    }

    var combined = string.Join(" | ", textSources.Distinct(StringComparer.OrdinalIgnoreCase));
    if (string.IsNullOrWhiteSpace(combined))
        return null;

    string? typeCode = null;
    decimal? oldPrice = null;
    decimal? newPrice = null;

    var changePattern = Regex.Match(combined, @"Changes\s+for\s+type\s+([A-Z0-9]+)\s*:\s*Change[_ ]sell[_ ]price[_ ]from[_ ]\$(\d+(?:\.\d+)?)[_ ]to[_ ]\$(\d+(?:\.\d+)?)", RegexOptions.IgnoreCase);
    if (changePattern.Success)
    {
        typeCode = changePattern.Groups[1].Value;
        oldPrice = decimal.TryParse(changePattern.Groups[2].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var parsedOld) ? parsedOld : null;
        newPrice = decimal.TryParse(changePattern.Groups[3].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var parsedNew) ? parsedNew : null;
    }

    var result = BuildSemanticEventBase("commercial_adjustment", command, combined);
    result["type_code"] = typeCode;
    result["old_price"] = oldPrice;
    result["new_price"] = newPrice;
    return result;
}

static Dictionary<string, object?>? TryExtractAttachmentEvent(CommandCandidate command)
{
    var combined = CombineCommandText(command);
    if (string.IsNullOrWhiteSpace(combined))
        return null;

    string? attachmentScope = null;
    string? statusLabel = null;
    string? referenceId = null;
    string? attachmentLabel = null;

    var scopeMatch = Regex.Match(combined, @"([A-Z_]*ATTACHMENTS(?:-[A-Z0-9\-]+)?)", RegexOptions.IgnoreCase);
    if (scopeMatch.Success)
        attachmentScope = scopeMatch.Groups[1].Value;

    var cloudMatch = Regex.Match(combined, @"CLOUD_STATUS", RegexOptions.IgnoreCase);
    if (cloudMatch.Success)
        statusLabel = "CLOUD_STATUS";

    var sendMatch = Regex.Match(combined, @"Sending", RegexOptions.IgnoreCase);
    if (sendMatch.Success && string.IsNullOrWhiteSpace(statusLabel))
        statusLabel = "Sending";

    var refMatch = Regex.Match(combined, @"MH-DEN08-[0-9]+(?:-[0-9]+)?", RegexOptions.IgnoreCase);
    if (refMatch.Success)
        referenceId = refMatch.Value;

    var labelTokens = new List<string>();
    foreach (Match match in Regex.Matches(combined, @"[A-Za-z][A-Za-z0-9_]{3,}", RegexOptions.IgnoreCase))
    {
        var token = match.Value;
        if (token.Contains("ATTACH", StringComparison.OrdinalIgnoreCase) ||
            token.Contains("SERVIC", StringComparison.OrdinalIgnoreCase) ||
            token.Contains("CLOUD", StringComparison.OrdinalIgnoreCase) ||
            token.Contains("SEND", StringComparison.OrdinalIgnoreCase))
        {
            labelTokens.Add(token);
        }
    }
    attachmentLabel = labelTokens
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
        .Take(3)
        .DefaultIfEmpty()
        .Aggregate((string?)null, (current, next) => string.IsNullOrWhiteSpace(current) ? next : $"{current}+{next}");

    var result = BuildSemanticEventBase("attachment_activity", command, combined);
    result["attachment_scope"] = attachmentScope;
    result["status_label"] = statusLabel;
    result["reference_id"] = referenceId;
    result["attachment_label"] = attachmentLabel;
    return result;
}

static Dictionary<string, object?>? TryExtractInvoiceEvent(CommandCandidate command)
{
    var combined = CombineCommandText(command);
    if (string.IsNullOrWhiteSpace(combined))
        return null;

    string? invoiceId = null;
    bool? hasInvoiceLine = null;
    bool? possibleMisapplication = null;

    var invoiceQuoted = Regex.Match(combined, @"Invoice\s+is\s+'?([0-9]+)'?", RegexOptions.IgnoreCase);
    if (invoiceQuoted.Success)
        invoiceId = invoiceQuoted.Groups[1].Value;
    else
    {
        var invoiceInline = Regex.Match(combined, @"INVOICE[-_]?([0-9]+)", RegexOptions.IgnoreCase);
        if (invoiceInline.Success)
            invoiceId = invoiceInline.Groups[1].Value;
    }

    if (Regex.IsMatch(combined, @"invoice\s+line", RegexOptions.IgnoreCase))
        hasInvoiceLine = true;
    if (Regex.IsMatch(combined, @"misapplication", RegexOptions.IgnoreCase))
        possibleMisapplication = true;

    var result = BuildSemanticEventBase("invoice_activity", command, combined);
    result["invoice_id"] = invoiceId;
    result["has_invoice_line_reference"] = hasInvoiceLine;
    result["possible_misapplication"] = possibleMisapplication;
    return result;
}

static Dictionary<string, object?>? TryExtractHistoryEvent(CommandCandidate command)
{
    var combined = CombineCommandText(command);
    if (string.IsNullOrWhiteSpace(combined))
        return null;

    var result = BuildSemanticEventBase("history_activity", command, combined);
    result["history_marker"] = Regex.IsMatch(combined, @"CS_SYNC_HISTORY", RegexOptions.IgnoreCase) ? "CS_SYNC_HISTORY" : null;
    return result;
}

static string CombineCommandText(CommandCandidate command)
{
    var textSources = new List<string>();
    if (command.PrintableSignals is not null)
        textSources.AddRange(command.PrintableSignals.Where(x => !string.IsNullOrWhiteSpace(x)));
    foreach (var sample in command.SampleRecords)
    {
        if (sample.TryGetValue("ascii_preview", out var value) && value is not null)
        {
            var text = value.ToString();
            if (!string.IsNullOrWhiteSpace(text))
                textSources.Add(text!);
        }
    }

    return string.Join(" | ", textSources.Distinct(StringComparer.OrdinalIgnoreCase));
}

static string? GetStringValue(Dictionary<string, object?> source, string key)
{
    if (!source.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is string s)
        return string.IsNullOrWhiteSpace(s) ? null : s;
    if (value is JsonElement el)
    {
        if (el.ValueKind == JsonValueKind.String)
        {
            var str = el.GetString();
            return string.IsNullOrWhiteSpace(str) ? null : str;
        }
        return el.ToString();
    }

    var text = value.ToString();
    return string.IsNullOrWhiteSpace(text) ? null : text;
}

static long? TryGetLongValue(Dictionary<string, object?> source, string key)
{
    if (!source.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is long l)
        return l;
    if (value is int i)
        return i;
    if (value is decimal d && d is <= long.MaxValue and >= long.MinValue)
        return (long)d;
    if (value is JsonElement el)
    {
        if (el.ValueKind == JsonValueKind.Number && el.TryGetInt64(out var parsedLong))
            return parsedLong;
        if (el.ValueKind == JsonValueKind.String && long.TryParse(el.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsedStringLong))
            return parsedStringLong;
    }
    return long.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
}

static decimal? TryGetDecimalValue(Dictionary<string, object?> source, string key)
{
    if (!source.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is decimal d)
        return d;
    if (value is double dbl)
        return (decimal)dbl;
    if (value is float f)
        return (decimal)f;
    if (value is int i)
        return i;
    if (value is long l)
        return l;
    if (value is JsonElement el)
    {
        if (el.ValueKind == JsonValueKind.Number && el.TryGetDecimal(out var parsedDecimal))
            return parsedDecimal;
        if (el.ValueKind == JsonValueKind.String && decimal.TryParse(el.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsedStringDecimal))
            return parsedStringDecimal;
    }
    return decimal.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
}

static bool? TryGetBoolValue(Dictionary<string, object?> source, string key)
{
    if (!source.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is bool b)
        return b;
    if (value is JsonElement el)
    {
        if (el.ValueKind == JsonValueKind.True)
            return true;
        if (el.ValueKind == JsonValueKind.False)
            return false;
        if (el.ValueKind == JsonValueKind.String && bool.TryParse(el.GetString(), out var parsedBool))
            return parsedBool;
    }
    return bool.TryParse(value.ToString(), out var parsed) ? parsed : null;
}

static int? TryGetDictionaryInt(Dictionary<string, object?> source, string key)
{
    if (!source.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is int i)
        return i;
    if (value is long l && l is >= int.MinValue and <= int.MaxValue)
        return (int)l;
    if (value is JsonElement el && el.ValueKind == JsonValueKind.Number && el.TryGetInt32(out var parsed))
        return parsed;
    return null;
}

static string BuildBehaviorClusterKey(CommandCandidate command)
{
    var family = command.D2Summary is not null ? "D2" : string.Join(",", command.MarkerCounts.Keys.OrderBy(x => x, StringComparer.OrdinalIgnoreCase));
    var theme = InferBehaviorTheme(command);
    var template = command.TemplateId ?? "no-template";
    var role = command.CommandRole ?? "no-role";
    return $"{family}|{theme}|{role}|{template}";
}

static string InferBehaviorTheme(CommandCandidate command)
{
    var terms = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var signal in command.PrintableSignals ?? new List<string>())
    {
        foreach (var term in NormalizeInferenceTerms(signal))
            terms.Add(term);
    }

    if (command.D2Summary is not null)
        return "d2_structured";
    if (terms.Contains("ATTACH") || terms.Contains("ATTACHMENT") || terms.Contains("ATTACHMENTS"))
        return "attachments";
    if (terms.Contains("INVOICE") || terms.Contains("INVOICES"))
        return "invoice";
    if (terms.Contains("HISTORY"))
        return "history";
    if (terms.Contains("SEND") || terms.Contains("SENDING") || terms.Contains("STATUS") || terms.Contains("STATU"))
        return "status_sync";
    if (terms.Contains("ERROR") || terms.Contains("NULLPOINTEREXCEPTION") || terms.Contains("DIAGNOSTIC") || terms.Contains("REPORT"))
        return "diagnostic";
    if (terms.Contains("RELEASE"))
        return "release";
    if (terms.Contains("SELL") || terms.Contains("OVERAGE") || terms.Contains("SPLIT"))
        return "commercial_adjustment";
    return "generic";
}

static List<string> ToStringList(object? value)
{
    if (value is null)
        return new List<string>();
    if (value is IEnumerable<string> strings)
        return strings.Where(x => !string.IsNullOrWhiteSpace(x)).ToList();
    if (value is JsonElement el && el.ValueKind == JsonValueKind.Array)
        return el.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString() ?? string.Empty).Where(x => !string.IsNullOrWhiteSpace(x)).ToList();
    return new List<string>();
}

static List<string> NormalizeInferenceTerms(string? text)
{
    if (string.IsNullOrWhiteSpace(text))
        return new List<string>();

    var results = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (Match match in Regex.Matches(text.ToUpperInvariant(), @"[A-Z0-9]+"))
    {
        var token = match.Value;
        if (token.Length >= 3 && !string.Equals(token, "CHSC", StringComparison.OrdinalIgnoreCase))
            results.Add(token);
        foreach (var derived in ExpandDomainTerms(token))
            results.Add(derived);
    }

    return results.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList();
}

static IEnumerable<string> ExpandDomainTerms(string token)
{
    if (string.IsNullOrWhiteSpace(token))
        yield break;

    var normalized = token.ToUpperInvariant();

    if (normalized.EndsWith("S", StringComparison.OrdinalIgnoreCase) && normalized.Length > 4)
        yield return normalized[..^1];

    string[] domainTerms =
    {
        "ATTACH", "ATTACHMENT", "ATTACHMENTS",
        "CARRIER",
        "CONTACT", "CONTACTS",
        "CLOUD",
        "DISTRIBUTOR", "DISTRIBUTORS",
        "HISTORY",
        "INVOICE", "INVOICES",
        "LINE", "LINES",
        "MANUFACTURER", "MANUFACTURERS",
        "MATERIAL",
        "OVERAGE",
        "POLINE",
        "PROJECT",
        "QUOTE", "QUOTES",
        "REPORT",
        "RELEASE",
        "SELL",
        "SEND", "SENDING",
        "SERVICE", "SERVICES",
        "SHIPMENT",
        "SPLIT",
        "STATUS"
    };

    foreach (var term in domainTerms)
    {
        if (normalized.Length > term.Length && normalized.Contains(term, StringComparison.OrdinalIgnoreCase))
            yield return term;
    }
}

static MetadataCatalog LoadMetadataCatalog(string path)
{
    if (!File.Exists(path))
        return new MetadataCatalog(new List<MetadataCatalogEntry>());

    using var doc = JsonDocument.Parse(File.ReadAllText(path));
    if (!doc.RootElement.TryGetProperty("tables", out var tablesEl) || tablesEl.ValueKind != JsonValueKind.Array)
        return new MetadataCatalog(new List<MetadataCatalogEntry>());

    var entries = new List<MetadataCatalogEntry>();
    foreach (var tableEl in tablesEl.EnumerateArray())
    {
        var schema = tableEl.TryGetProperty("schema_name", out var schemaEl) ? schemaEl.GetString() : null;
        var table = tableEl.TryGetProperty("table_name", out var tableElName) ? tableElName.GetString() : null;
        if (string.IsNullOrWhiteSpace(schema) || string.IsNullOrWhiteSpace(table))
            continue;

        var terms = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var term in NormalizeInferenceTerms(table))
            terms.Add(term);

        if (tableEl.TryGetProperty("columns", out var columnsEl) && columnsEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var colEl in columnsEl.EnumerateArray())
            {
                var colName = colEl.TryGetProperty("column_name", out var colNameEl) ? colNameEl.GetString() : null;
                foreach (var term in NormalizeInferenceTerms(colName))
                    terms.Add(term);
            }
        }

        entries.Add(new MetadataCatalogEntry($"{schema}.{table}", terms));
    }

    return new MetadataCatalog(entries);
}

static string BuildCommandTemplateSignature(CommandCandidate command)
{
    var tokens = string.Join(",", command.TokensSeen.OrderBy(x => x));
    var tables = string.Join(",", command.TablesSeen.OrderBy(x => x, StringComparer.OrdinalIgnoreCase));
    var markerCounts = string.Join(",", command.MarkerCounts.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase).Select(x => $"{x.Key}:{x.Value}"));
    var tagCore = string.Join(",", command.Tags.Where(x => !string.Equals(x, "printable_payload", StringComparison.OrdinalIgnoreCase)).OrderBy(x => x, StringComparer.OrdinalIgnoreCase));

    var d2Ordinals = string.Empty;
    var d2MarkerFamilies = string.Empty;
    if (command.D2Summary is not null)
    {
        if (command.D2Summary.TryGetValue("ordinals", out var ordinalsObj) && ordinalsObj is JsonElement ordinalsEl && ordinalsEl.ValueKind == JsonValueKind.Array)
            d2Ordinals = string.Join(",", ordinalsEl.EnumerateArray().Select(x => x.GetInt32()));
        if (command.D2Summary.TryGetValue("marker_families", out var familiesObj) && familiesObj is JsonElement familiesEl && familiesEl.ValueKind == JsonValueKind.Object)
            d2MarkerFamilies = string.Join(",", familiesEl.EnumerateObject().Select(x => $"{x.Name}:{x.Value.GetInt32()}").OrderBy(x => x, StringComparer.OrdinalIgnoreCase));
    }

    return string.Join("|", new[]
    {
        command.GroupingMode,
        command.CommandType,
        tokens,
        tables,
        markerCounts,
        d2Ordinals,
        d2MarkerFamilies,
        tagCore
    });
}

static string InferCommandRole(CommandCandidate command)
{
    if (command.D2Summary is not null)
    {
        var dense = TryReadSummaryInt(command.D2Summary, "dense_count") ?? 0;
        var control = TryReadSummaryInt(command.D2Summary, "control_count") ?? 0;
        var ordinals = TryReadSummaryIntList(command.D2Summary, "ordinals");

        if (dense == 2 && control == 2 && ordinals.Count == 2)
            return "d2_wrapper_pair";
        if (dense >= 8 && control >= 4)
            return "d2_large_bundle";
        if (dense >= 4 && control >= 1)
            return "d2_bundle_with_wrappers";
        if (dense >= 2 && control == 0)
            return "d2_dense_run";
        return "d2_fragment_bundle";
    }

    if (command.Tags.Any(x => string.Equals(x, "printable_payload", StringComparison.OrdinalIgnoreCase)))
        return "payload_cluster";

    return "cluster";
}

static int? TryReadSummaryInt(Dictionary<string, object?> summary, string key)
{
    if (!summary.TryGetValue(key, out var value) || value is null)
        return null;
    if (value is int i)
        return i;
    if (value is long l && l is >= int.MinValue and <= int.MaxValue)
        return (int)l;
    if (value is JsonElement el)
    {
        if (el.ValueKind == JsonValueKind.Number && el.TryGetInt32(out var intVal))
            return intVal;
        if (el.ValueKind == JsonValueKind.String && int.TryParse(el.GetString(), out var parsed))
            return parsed;
    }
    return null;
}

static List<int> TryReadSummaryIntList(Dictionary<string, object?> summary, string key)
{
    if (!summary.TryGetValue(key, out var value) || value is null)
        return new List<int>();
    if (value is IEnumerable<int> ints)
        return ints.ToList();
    if (value is JsonElement el && el.ValueKind == JsonValueKind.Array)
        return el.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.Number && x.TryGetInt32(out _)).Select(x => x.GetInt32()).ToList();
    return new List<int>();
}

static List<string> ExtractPrintableSignals(CommandCandidate command)
{
    var signals = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var sample in command.SampleRecords)
    {
        if (!sample.TryGetValue("ascii_preview", out var value) || value is null)
            continue;
        var preview = value.ToString();
        if (string.IsNullOrWhiteSpace(preview))
            continue;
        foreach (Match match in Regex.Matches(preview, @"[A-Za-z0-9][A-Za-z0-9\-_]{3,}"))
        {
            signals.Add(match.Value);
            if (signals.Count >= 8)
                break;
        }
        if (signals.Count >= 8)
            break;
    }

    return signals.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList();
}

static List<CommandCandidate>? TryBuildD2BundleCommands(TransactionBundle bundle, List<ExtractedRecord> txRecords)
{
    if (txRecords.Count == 0)
        return null;
    if (!txRecords.All(r => string.Equals(r.DbMarker, "0xD2", StringComparison.OrdinalIgnoreCase)))
        return null;
    if (txRecords.Select(r => r.PrimaryToken).Distinct().Count() != 1)
        return null;

    var enriched = txRecords
        .Select(r => (Record: r, Info: TryAnalyzeD2Record(r)))
        .Where(x => x.Info is not null)
        .Select(x => (x.Record, Info: x.Info!))
        .OrderBy(x => x.Record.Offset)
        .ToList();
    if (enriched.Count != txRecords.Count)
        return null;

    var dense = enriched
        .Where(x => !x.Info.IsControl && x.Info.Ordinal.HasValue)
        .OrderBy(x => x.Record.Offset)
        .ToList();
    if (dense.Count == 0)
        return null;

    var denseGroups = new List<List<(ExtractedRecord Record, D2RecordInfo Info)>>();
    List<(ExtractedRecord Record, D2RecordInfo Info)>? current = null;
    (ExtractedRecord Record, D2RecordInfo Info)? prev = null;
    foreach (var item in dense)
    {
        var breakGroup =
            current is not null &&
            prev is not null &&
                (
                    item.Record.Offset - prev.Value.Record.Offset > 3000 ||
                    item.Info.Ordinal!.Value <= prev.Value.Info.Ordinal!.Value ||
                    item.Info.Ordinal!.Value - prev.Value.Info.Ordinal!.Value >= 10
                );
        if (current is null || breakGroup)
        {
            current = new List<(ExtractedRecord Record, D2RecordInfo Info)>();
            denseGroups.Add(current);
        }
        current.Add(item);
        prev = item;
    }

    var results = new List<CommandCandidate>();
    var commandOrdinal = 1;
    foreach (var group in denseGroups)
    {
        var firstDenseOffset = group.First().Record.Offset;
        var lastDenseOffset = group.Last().Record.Offset;
        var cluster = enriched
            .Where(x => x.Record.Offset >= firstDenseOffset - 300 && x.Record.Offset <= lastDenseOffset + 300)
            .ToList();
        if (cluster.Count == 0)
            continue;

        var clusterRecords = cluster.Select(x => x.Record).ToList();
        var markerCounts = clusterRecords.GroupBy(r => r.DbMarker, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
        var actionCounts = clusterRecords.GroupBy(r => r.Action, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
        var tablesSeen = clusterRecords
            .Where(r => !string.IsNullOrWhiteSpace(r.MatchedSchema) && !string.IsNullOrWhiteSpace(r.MatchedTable))
            .Select(r => $"{r.MatchedSchema}.{r.MatchedTable}")
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var tokensSeen = clusterRecords.Select(r => r.MatchedToken ?? r.PrimaryToken).Distinct().OrderBy(x => x).ToList();
        var tags = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "d2_bundle_v1",
            "d2_structured",
            "homogeneous_d2"
        };
        if (clusterRecords.Any(r => !string.IsNullOrWhiteSpace(r.AsciiPreview)))
            tags.Add("printable_payload");

        var d2Summary = new Dictionary<string, object?>
        {
            ["record_count"] = cluster.Count,
            ["dense_count"] = cluster.Count(x => !x.Info.IsControl),
            ["control_count"] = cluster.Count(x => x.Info.IsControl),
            ["ordinals"] = group.Select(x => x.Info.Ordinal!.Value).OrderBy(x => x).ToList(),
            ["ordinal_range"] = new[] { group.First().Info.Ordinal!.Value, group.Last().Info.Ordinal!.Value },
            ["marker_families"] = cluster.Where(x => !string.IsNullOrWhiteSpace(x.Info.MarkerFamily)).GroupBy(x => x.Info.MarkerFamily!, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase),
            ["echo_values"] = cluster.Where(x => x.Info.EchoValue.HasValue).Select(x => x.Info.EchoValue!.Value).Distinct().OrderBy(x => x).ToList()
        };

        results.Add(new CommandCandidate(
            $"{bundle.TransactionId}#D2B{commandOrdinal:000}",
            bundle.TransactionId,
            InferCommandType(actionCounts),
            cluster.Count,
            clusterRecords.First().CurrentLsn,
            clusterRecords.Last().CurrentLsn,
            clusterRecords.First().Offset,
            clusterRecords.Last().Offset,
            markerCounts,
            actionCounts,
            tablesSeen,
            tokensSeen,
            "d2_bundle_v1",
            "medium",
            tags.OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
            d2Summary,
            clusterRecords.Take(8).Select(r => new Dictionary<string, object?>
            {
                ["offset"] = r.Offset,
                ["action"] = r.Action,
                ["db_marker"] = r.DbMarker,
                ["primary_token"] = r.PrimaryToken,
                ["matched_table"] = string.IsNullOrWhiteSpace(r.MatchedSchema) || string.IsNullOrWhiteSpace(r.MatchedTable) ? null : $"{r.MatchedSchema}.{r.MatchedTable}",
                ["ascii_preview"] = r.AsciiPreview,
                ["evidence_tags"] = r.EvidenceTags
            }).ToList()));
        commandOrdinal++;
    }

    return results.Count == 0 ? null : results;
}

static string InferCommandType(IReadOnlyDictionary<string, int> actionCounts)
{
    if (actionCounts.Count == 1)
        return actionCounts.Keys.First();
    if (actionCounts.ContainsKey("UPDATE"))
        return "UPDATE";
    if (actionCounts.ContainsKey("INSERT"))
        return "INSERT";
    if (actionCounts.ContainsKey("DELETE"))
        return "DELETE";
    return "UNKNOWN";
}

static string ComputeCommandConfidence(List<ExtractedRecord> records, List<string> tablesSeen)
{
    if (tablesSeen.Count > 0 && records.All(r => r.StrictPrimaryTokenMatch || r.MatchedToken == r.PrimaryToken))
        return "high";
    if (tablesSeen.Count > 0)
        return "medium";
    if (records.All(r => string.Equals(r.DbMarker, records[0].DbMarker, StringComparison.OrdinalIgnoreCase) && r.PrimaryToken == records[0].PrimaryToken))
        return "medium";
    return "low";
}

static D2RecordInfo? TryAnalyzeD2Record(ExtractedRecord record)
{
    if (!string.Equals(record.DbMarker, "0xD2", StringComparison.OrdinalIgnoreCase))
        return null;
    if (!TryParseHex(record.CaptureHex, out var bytes) || bytes.Length < 148)
        return null;

    var ordinal = (int)BitConverter.ToUInt16(bytes, 112);
    var markerFamily = Convert.ToHexString(bytes, 88, 4).ToLowerInvariant();
    var echo = (int)BitConverter.ToUInt32(bytes, 144);
    return new D2RecordInfo(ordinal == 0, ordinal == 0 ? null : ordinal, markerFamily, echo);
}

static bool TryParseHex(string? hex, out byte[] bytes)
{
    bytes = Array.Empty<byte>();
    if (string.IsNullOrWhiteSpace(hex))
        return false;
    var trimmed = hex.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? hex[2..] : hex;
    if ((trimmed.Length & 1) != 0)
        return false;
    try
    {
        bytes = Convert.FromHexString(trimmed);
        return true;
    }
    catch
    {
        return false;
    }
}

static (string Schema, string Table)? ResolveOfflineTableInfo(
    byte[] bytes,
    int recordOffset,
    IReadOnlyDictionary<long, (string Schema, string Table)> tokenMap,
    long primaryToken,
    bool strictPrimaryTokenOnly,
    out long matchedToken)
{
    if (tokenMap.TryGetValue(primaryToken, out var primaryMatch))
    {
        matchedToken = primaryToken;
        return primaryMatch;
    }

    if (strictPrimaryTokenOnly)
    {
        matchedToken = primaryToken;
        return null;
    }

    var matches = new Dictionary<string, (string Schema, string Table, long Token)>(StringComparer.OrdinalIgnoreCase);
    var maxOffset = Math.Min(bytes.Length - 4, recordOffset + 96);
    for (var pos = recordOffset + 20; pos <= maxOffset; pos += 4)
    {
        var token = (long)BitConverter.ToUInt32(bytes, pos);
        if (!tokenMap.TryGetValue(token, out var info))
            continue;

        var key = $"{info.Schema}.{info.Table}";
        matches[key] = (info.Schema, info.Table, token);
    }

    if (matches.Count == 1)
    {
        var hit = matches.Values.First();
        matchedToken = hit.Token;
        return (hit.Schema, hit.Table);
    }

    matchedToken = primaryToken;
    return null;
}

static List<Dictionary<string, object?>> ScanOfflineTokenWindow(
    byte[] bytes,
    int recordOffset,
    IReadOnlyDictionary<long, (string Schema, string Table)> tokenMap)
{
    var hits = new List<Dictionary<string, object?>>();
    var maxOffset = Math.Min(bytes.Length - 4, recordOffset + 96);
    for (var pos = recordOffset + 20; pos <= maxOffset; pos += 4)
    {
        var token = (long)BitConverter.ToUInt32(bytes, pos);
        if (!tokenMap.TryGetValue(token, out var info))
            continue;

        hits.Add(new Dictionary<string, object?>
        {
            ["relative_offset"] = pos - recordOffset,
            ["token"] = token,
            ["table"] = $"{info.Schema}.{info.Table}"
        });
    }
    return hits;
}

static void IncrementCount<TKey>(IDictionary<TKey, int> counts, TKey key) where TKey : notnull
{
    if (counts.TryGetValue(key, out var value))
        counts[key] = value + 1;
    else
        counts[key] = 1;
}

static async Task<Dictionary<long, (string Schema, string Table)>> GetTargetHobtMapAsync(Runtime runtime, bool baseRowOnly, bool inRowOnly)
{
    static string QuoteSql(string value) => "N'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";
    var targetsSql = string.Join(Environment.NewLine + "UNION ALL" + Environment.NewLine,
        runtime.Pipeline.Tables.Select(table =>
        {
            var parts = table.Split('.', 2);
            return $"SELECT {QuoteSql(parts[0])} AS schema_name, {QuoteSql(parts[1])} AS table_name";
        }));

    var tokenCandidatesSql =
        baseRowOnly && inRowOnly
            ? @"
    SELECT schema_name, table_name, CONVERT(BIGINT, (CONVERT(BIGINT, allocation_unit_id) / 65536) % 4294967296) AS hobt_token
    FROM selected_allocs"
            : @"
    SELECT schema_name, table_name, CONVERT(BIGINT, hobt_id % 4294967296) AS hobt_token
    FROM selected_partitions
    UNION ALL
    SELECT schema_name, table_name, CONVERT(BIGINT, (CONVERT(BIGINT, hobt_id) / 65536) % 4294967296) AS hobt_token
    FROM selected_partitions
    UNION ALL
    SELECT schema_name, table_name, CONVERT(BIGINT, allocation_unit_id % 4294967296) AS hobt_token
    FROM selected_allocs
    UNION ALL
    SELECT schema_name, table_name, CONVERT(BIGINT, (CONVERT(BIGINT, allocation_unit_id) / 65536) % 4294967296) AS hobt_token
    FROM selected_allocs";

    var sql = $@"
WITH target_tables AS (
{targetsSql}
),
base_partitions AS (
    SELECT
        tt.schema_name,
        tt.table_name,
        p.index_id,
        p.partition_id,
        p.hobt_id
    FROM target_tables tt
    JOIN sys.schemas s ON s.name = tt.schema_name
    JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = tt.table_name
    JOIN sys.partitions p ON p.object_id = t.object_id
    WHERE p.hobt_id IS NOT NULL
),
base_row_partitions AS (
    SELECT *
    FROM base_partitions
    WHERE index_id IN (0, 1)
),
selected_partitions AS (
    SELECT *
    FROM {(baseRowOnly ? "base_row_partitions" : "base_partitions")}
),
selected_allocs AS (
    SELECT
        bp.schema_name,
        bp.table_name,
        au.allocation_unit_id
    FROM selected_partitions bp
    JOIN sys.allocation_units au
      ON au.container_id = bp.hobt_id
      OR au.container_id = bp.partition_id
    {(inRowOnly ? "WHERE au.type_desc = 'IN_ROW_DATA'" : "")}
),
token_candidates AS (
{tokenCandidatesSql}
)
SELECT schema_name, table_name, hobt_token
FROM token_candidates
WHERE hobt_token IS NOT NULL AND hobt_token <> 0;";

    await using var conn = new SqlConnection(BuildConnString(runtime.Pipeline.LiveServerInstance, runtime.Pipeline.LiveDatabase, runtime.Security));
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = sql;
    cmd.CommandTimeout = 0;
    await conn.OpenAsync();
    await using var reader = await cmd.ExecuteReaderAsync();
    var candidates = new Dictionary<long, HashSet<string>>();
    while (await reader.ReadAsync())
    {
        var token = Convert.ToInt64(reader["hobt_token"], CultureInfo.InvariantCulture);
        var schema = reader["schema_name"]?.ToString() ?? "";
        var table = reader["table_name"]?.ToString() ?? "";
        if (token == 0 || string.IsNullOrWhiteSpace(schema) || string.IsNullOrWhiteSpace(table))
            continue;
        var fq = $"{schema}.{table}";
        if (!candidates.TryGetValue(token, out var tables))
        {
            tables = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            candidates[token] = tables;
        }
        tables.Add(fq);
    }
    var map = new Dictionary<long, (string Schema, string Table)>();
    foreach (var pair in candidates)
    {
        if (pair.Value.Count != 1)
            continue;
        var fq = pair.Value.First();
        var parts = fq.Split('.', 2);
        map[pair.Key] = (parts[0], parts[1]);
    }
    return map;
}

static object? DbNull(object value) => value is DBNull ? null : value;
static long? ToLong(object value) => value is DBNull ? null : Convert.ToInt64(value, CultureInfo.InvariantCulture);
static int? ToInt(object value) => value is DBNull ? null : Convert.ToInt32(value, CultureInfo.InvariantCulture);
static string NormalizePath(string path) => path.Replace('/', '\\').Trim('\\').ToUpperInvariant();
static bool IsValidLsn(string? value) => !string.IsNullOrWhiteSpace(value) && Regex.IsMatch(value, "^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}:[0-9A-Fa-f]{4}$");
static int CompareLsn(string a, string b)
{
    var aParts = a.Split(':');
    var bParts = b.Split(':');
    for (var i = 0; i < 3; i++)
    {
        var av = Convert.ToInt64(aParts[i], 16);
        var bv = Convert.ToInt64(bParts[i], 16);
        if (av < bv) return -1;
        if (av > bv) return 1;
    }
    return 0;
}

static RunnerState? LoadState(string path)
{
    if (!File.Exists(path)) return null;
    try { return JsonSerializer.Deserialize<RunnerState>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }); }
    catch { return null; }
}
static void SaveState(string path, RunnerState state)
{
    Directory.CreateDirectory(Path.GetDirectoryName(path)!);
    File.WriteAllText(path, JsonSerializer.Serialize(state, JsonOpts.Options));
}
static void UpdateShadowTracking(string path, string? id, string? device, bool active, string? session)
{
    var state = LoadState(path) ?? new RunnerState { version = 1 };
    state.updated_at_utc = DateTime.UtcNow.ToString("O");
    state.active_shadow_id = id;
    state.active_shadow_device = device;
    state.active_shadow_session = session;
    state.active_shadow_active = active;
    state.active_shadow_updated_utc = DateTime.UtcNow.ToString("O");
    SaveState(path, state);
}
static bool TestShadowActive(string shadowId)
{
    using var p = Process.Start(new ProcessStartInfo { FileName = "vssadmin", Arguments = $"list shadows /Shadow={shadowId}", UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true });
    if (p is null) return false;
    p.WaitForExit();
    if (p.ExitCode != 0) return false;
    var output = p.StandardOutput.ReadToEnd();
    return output.IndexOf(shadowId.Trim().Trim('{', '}'), StringComparison.OrdinalIgnoreCase) >= 0;
}
static void DeleteShadow(string shadowId)
{
    using var p = Process.Start(new ProcessStartInfo { FileName = "vssadmin", Arguments = $"delete shadows /Shadow={shadowId} /Quiet", UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true });
    if (p is null) throw new InvalidOperationException($"Failed to start vssadmin for shadow cleanup: {shadowId}");
    p.WaitForExit();
    if (p.ExitCode != 0) throw new InvalidOperationException(p.StandardError.ReadToEnd());
}
static async Task<string?> GetLiveHeadLsnAsync(Runtime runtime)
{
    await using var conn = new SqlConnection(BuildConnString(runtime.Pipeline.LiveServerInstance, runtime.Pipeline.LiveDatabase, runtime.Security));
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = $"SET NOCOUNT ON; SELECT TOP (1) [Current LSN] FROM {runtime.Pipeline.LogReaderFunction}(NULL, NULL) ORDER BY [Current LSN] DESC;";
    cmd.CommandTimeout = 0;
    await conn.OpenAsync();
    return (await cmd.ExecuteScalarAsync())?.ToString();
}

static async Task<ProcResult> RunProcessAsync(string fileName, IReadOnlyList<string> args, TimeSpan timeout)
{
    using var p = new Process { StartInfo = new ProcessStartInfo { FileName = fileName, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true } };
    foreach (var arg in args) p.StartInfo.ArgumentList.Add(arg);
    p.Start();
    var so = p.StandardOutput.ReadToEndAsync();
    var se = p.StandardError.ReadToEndAsync();
    using var cts = new CancellationTokenSource(timeout);
    await p.WaitForExitAsync(cts.Token);
    var stdout = await so; var stderr = await se;
    if (p.ExitCode != 0) throw new InvalidOperationException($"{fileName} failed (exit {p.ExitCode}): {stderr}{Environment.NewLine}{stdout}".Trim());
    return new ProcResult(stdout, stderr);
}
static FileStream? TryAcquireLock(string path, string logPath)
{
    try { return File.Open(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
    catch { Log(logPath, "Another instance is running; exiting."); return null; }
}
static void Archive(Runtime runtime, string logPath)
{
    if (runtime.Paths.ArchiveAfterHours <= 0 || !Directory.Exists(runtime.Paths.OutputDir)) return;
    var thresholdUtc = DateTime.UtcNow.AddHours(-runtime.Paths.ArchiveAfterHours);
    var files = Directory.EnumerateFiles(runtime.Paths.OutputDir, "*", SearchOption.TopDirectoryOnly).Select(p => new FileInfo(p)).Where(f => f.LastWriteTimeUtc < thresholdUtc && (f.Extension.Equals(".trn", StringComparison.OrdinalIgnoreCase) || f.Extension.Equals(".json", StringComparison.OrdinalIgnoreCase) || f.Extension.Equals(".log", StringComparison.OrdinalIgnoreCase))).ToList();
    if (files.Count == 0) return;
    var zipPath = Path.Combine(runtime.Paths.ArchiveDir, $"archive_{DateTime.UtcNow:yyyyMMdd_HHmmss}.zip");
    using (var archive = ZipFile.Open(zipPath, ZipArchiveMode.Create)) foreach (var file in files) archive.CreateEntryFromFile(file.FullName, file.Name, CompressionLevel.Optimal);
    Log(logPath, $"Archived {files.Count} files to {zipPath}");
    if (!runtime.Paths.DeleteOriginalAfterArchive) return;
    foreach (var file in files) try { file.Delete(); } catch { }
    Log(logPath, $"Deleted archived originals: {files.Count}");
}
static async Task WriteJsonAsync(string path, object payload)
{
    Directory.CreateDirectory(Path.GetDirectoryName(path)!);
    await File.WriteAllTextAsync(path, JsonSerializer.Serialize(payload, JsonOpts.Options));
}
static async Task WriteCsvAsync(string path, List<Dictionary<string, object?>> rows, IReadOnlyList<string> columns)
{
    Directory.CreateDirectory(Path.GetDirectoryName(path)!);
    var sb = new StringBuilder();
    sb.AppendLine(string.Join(",", columns.Select(EscapeCsv)));

    foreach (var row in rows)
    {
        var values = columns.Select(column =>
        {
            row.TryGetValue(column, out var value);
            return EscapeCsv(FormatCsvValue(value));
        });
        sb.AppendLine(string.Join(",", values));
    }

    await File.WriteAllTextAsync(path, sb.ToString());
}
static string FormatCsvValue(object? value)
{
    if (value is null)
        return string.Empty;
    if (value is JsonElement element)
    {
        return element.ValueKind switch
        {
            JsonValueKind.String => element.GetString() ?? string.Empty,
            JsonValueKind.Number => element.ToString(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            JsonValueKind.Null => string.Empty,
            _ => element.ToString()
        };
    }
    return value switch
    {
        DateTime dt => dt.ToString("O", CultureInfo.InvariantCulture),
        DateTimeOffset dto => dto.ToString("O", CultureInfo.InvariantCulture),
        IFormattable formattable => formattable.ToString(null, CultureInfo.InvariantCulture) ?? string.Empty,
        _ => value.ToString() ?? string.Empty
    };
}
static string EscapeCsv(string value)
{
    if (value.Contains('"'))
        value = value.Replace("\"", "\"\"");
    if (value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r'))
        return $"\"{value}\"";
    return value;
}
static string? ParseMatch(Regex regex, string text) { var m = regex.Match(text); return m.Success ? m.Groups[1].Value.Trim() : null; }
static string? ExtractLine(string text, string prefix) => text.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None).FirstOrDefault(l => l.StartsWith(prefix, StringComparison.Ordinal));
static Dictionary<string, int> ParseKeyValues(string? line)
{
    var result = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase); if (string.IsNullOrWhiteSpace(line)) return result; foreach (Match m in Regexes.KeyValue.Matches(line)) result[m.Groups[1].Value] = int.Parse(m.Groups[2].Value, CultureInfo.InvariantCulture); return result;
}
static List<string> SplitBatches(string script)
{
    var batches = new List<string>(); var cur = new List<string>();
    foreach (var line in script.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None)) { if (line.Trim().Equals("GO", StringComparison.OrdinalIgnoreCase)) { var txt = string.Join(Environment.NewLine, cur).Trim(); if (!string.IsNullOrWhiteSpace(txt)) batches.Add(txt); cur.Clear(); } else cur.Add(line); }
    var tail = string.Join(Environment.NewLine, cur).Trim(); if (!string.IsNullOrWhiteSpace(tail)) batches.Add(tail); return batches;
}
static string GetBatchAction(string batch)
{
    foreach (var line in batch.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None)) { var t = line.Trim(); if (string.IsNullOrWhiteSpace(t) || t.StartsWith("--", StringComparison.Ordinal) || t.StartsWith("/*", StringComparison.Ordinal)) continue; if (t.StartsWith("INSERT", StringComparison.OrdinalIgnoreCase)) return "INSERT"; if (t.StartsWith("UPDATE", StringComparison.OrdinalIgnoreCase)) return "UPDATE"; if (t.StartsWith("DELETE", StringComparison.OrdinalIgnoreCase)) return "DELETE"; return "OTHER"; } return "OTHER";
}
static void Log(string path, string message)
{
    var line = $"{DateTime.UtcNow:O} {message}"; Directory.CreateDirectory(Path.GetDirectoryName(path)!); File.AppendAllText(path, line + Environment.NewLine);
}

static void CombineTrnOutputs(IEnumerable<Dictionary<string, object?>> tableResults, string aggregateTrnPath)
{
    var dir = Path.GetDirectoryName(aggregateTrnPath);
    if (!string.IsNullOrWhiteSpace(dir))
        Directory.CreateDirectory(dir);

    using var writer = new StreamWriter(aggregateTrnPath, false);
    var wroteAny = false;
    foreach (var result in tableResults)
    {
        if (!result.TryGetValue("trn_path", out var trnPathObj) || trnPathObj is not string trnPath || !File.Exists(trnPath))
            continue;

        if (wroteAny)
            writer.WriteLine();

        foreach (var line in File.ReadLines(trnPath))
            writer.WriteLine(line);

        wroteAny = true;
    }
}

static bool UsesAggregateTrnPath(Runtime runtime)
{
    if (string.IsNullOrWhiteSpace(runtime.Pipeline.TrnOutputPathTemplate))
        return false;

    var template = runtime.Pipeline.TrnOutputPathTemplate;
    return template.IndexOf("{table}", StringComparison.OrdinalIgnoreCase) < 0
        && template.IndexOf("{schema}", StringComparison.OrdinalIgnoreCase) < 0
        && template.IndexOf("{table_full}", StringComparison.OrdinalIgnoreCase) < 0;
}

static string? ResolveAggregateTrnPath(Runtime runtime, string sessionName)
{
    if (!UsesAggregateTrnPath(runtime))
        return null;

    var resolved = runtime.Pipeline.TrnOutputPathTemplate!
        .Replace("{session}", sessionName, StringComparison.OrdinalIgnoreCase);
    var dir = Path.GetDirectoryName(resolved);
    if (!string.IsNullOrWhiteSpace(dir))
        Directory.CreateDirectory(dir);
    return resolved;
}

static string ResolveTrnPath(Runtime runtime, string sessionName, string table, string suffix)
{
    if (string.IsNullOrWhiteSpace(runtime.Pipeline.TrnOutputPathTemplate))
        return Path.Combine(runtime.Paths.OutputDir, $"hybrid.{sessionName}.{suffix}.trn");

    if (UsesAggregateTrnPath(runtime))
    {
        var partsDir = Path.Combine(runtime.Paths.OutputDir, "aggregate_parts", sessionName);
        Directory.CreateDirectory(partsDir);
        return Path.Combine(partsDir, $"hybrid.{sessionName}.{suffix}.trn");
    }

    var parts = table.Split('.', 2);
    var schema = parts[0].ToLowerInvariant();
    var tableName = parts[1].ToLowerInvariant();
    var resolved = runtime.Pipeline.TrnOutputPathTemplate
        .Replace("{session}", sessionName, StringComparison.OrdinalIgnoreCase)
        .Replace("{table}", tableName, StringComparison.OrdinalIgnoreCase)
        .Replace("{schema}", schema, StringComparison.OrdinalIgnoreCase)
        .Replace("{table_full}", $"{schema}.{tableName}", StringComparison.OrdinalIgnoreCase);
    var dir = Path.GetDirectoryName(resolved);
    if (!string.IsNullOrWhiteSpace(dir)) Directory.CreateDirectory(dir);
    return resolved;
}
sealed record ProcResult(string StdOut, string StdErr);
sealed record ManifestSummary(int RecordCount, int TransactionCount, string? ScanEndLsn);
sealed record OfflineScanProfile(string Name, bool BaseRowOnly, bool InRowOnly, HashSet<byte> AcceptedDbMarkers)
{
    public bool StrictPrimaryTokenOnly => BaseRowOnly;
}
sealed record ExtractedRecord(
    long Offset,
    int Length,
    string DbMarker,
    string LenMarker,
    string RecordType,
    string MajorOp,
    string Action,
    string CurrentLsn,
    string? PreviousLsn,
    string TransactionId,
    long PrimaryToken,
    long? MatchedToken,
    string? MatchedSchema,
    string? MatchedTable,
    bool StrictPrimaryTokenMatch,
    string? ContextHint,
    string? PageIdHint,
    int? SlotIdHint,
    int? IndexIdHint,
    string CaptureHex,
    string? AsciiPreview,
    List<string> EvidenceTags);
sealed record TransactionBundle(
    string TransactionId,
    string BeginLsn,
    string EndLsn,
    int RecordCount,
    bool CommitSeen,
    Dictionary<string, int> MarkerCounts,
    Dictionary<string, int> ActionCounts,
    List<string> TablesSeen,
    List<long> TokensSeen,
    long FirstOffset,
    long LastOffset,
    List<Dictionary<string, object?>> SampleRecords,
    List<string> BundleTags);
sealed record CommandCandidate(
    string CommandId,
    string TransactionId,
    string CommandType,
    int RecordCount,
    string BeginLsn,
    string EndLsn,
    long FirstOffset,
    long LastOffset,
    Dictionary<string, int> MarkerCounts,
    Dictionary<string, int> ActionCounts,
    List<string> TablesSeen,
    List<long> TokensSeen,
    string GroupingMode,
    string Confidence,
    List<string> Tags,
    Dictionary<string, object?>? D2Summary,
    List<Dictionary<string, object?>> SampleRecords,
    int SequenceNumber = 0,
    string? PreviousCommandId = null,
    string? NextCommandId = null,
    string? TemplateId = null,
    int TemplateRepeatIndex = 0,
    string? CommandRole = null,
    List<string>? PrintableSignals = null,
    Dictionary<string, object?>? Inference = null);
sealed record MetadataCatalogEntry(string QualifiedTable, HashSet<string> Terms);
sealed record MetadataCatalog(List<MetadataCatalogEntry> Tables);
sealed record D2RecordInfo(bool IsControl, int? Ordinal, string? MarkerFamily, int? EchoValue);
sealed class OfflineScanResult
{
    public required Dictionary<string, long> CommitsByTx { get; init; }
    public required List<Dictionary<string, object?>> Candidates { get; init; }
    public required List<ExtractedRecord> ExtractedRecords { get; init; }
    public required HashSet<string> SeenKeys { get; init; }
    public required List<Dictionary<string, object?>> RawCandidateSamples { get; init; }
    public required Dictionary<string, int> ActionCounts { get; init; }
    public required Dictionary<string, int> DbMarkerCounts { get; init; }
    public required Dictionary<long, int> TokenCounts { get; init; }
    public required List<Dictionary<string, object?>> UnresolvedSamples { get; init; }
    public required Dictionary<string, int> PrefilterComboCounts { get; init; }
    public string? MaxSeenLsn { get; init; }
    public int ManifestRecordCount => Candidates.Count(r => CommitsByTx.ContainsKey((string)r["tx_id"]!));
}
static class Regexes
{
    public static readonly Regex ShadowId = new(@"Shadow Copy ID:\s*(\{[^}]+\})", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    public static readonly Regex ShadowDevice = new(@"Shadow Copy Volume Name:\s*(\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    public static readonly Regex KeyValue = new(@"([A-Za-z_]+)=([0-9]+)", RegexOptions.Compiled);
    public static readonly Regex TrnAction = new(@"^--(INSERT|UPDATE|DELETE) \(", RegexOptions.Compiled);
}


static class JsonOpts
{
    public static readonly JsonSerializerOptions Options = new() { WriteIndented = true };
}
sealed class Config { public ServiceConfig service { get; set; } = new(); public PathConfig paths { get; set; } = new(); public PipelineConfig pipeline { get; set; } = new(); public SecurityConfig security { get; set; } = new(); }
sealed class ServiceConfig { public string name { get; set; } = "AOTransact"; public int interval_minutes { get; set; } = 15; public bool loop { get; set; } public int max_cycle_minutes { get; set; } = 12; }
sealed class PathConfig { public string output_dir { get; set; } = ".\\output"; public string state_path { get; set; } = ".\\output\\service\\last-offset.json"; public string metadata_snapshot_path { get; set; } = ".\\output\\chsc_metadata_flux.snapshot.json"; public string lock_file_path { get; set; } = ".\\output\\service\\aotransact.lock"; public string health_file_path { get; set; } = ".\\output\\service\\last-run.json"; public string log_dir { get; set; } = ".\\output\\service\\logs"; public string archive_dir { get; set; } = ".\\output\\service\\archive"; public int archive_after_hours { get; set; } = 24; public bool delete_original_after_archive { get; set; } }
sealed class PipelineConfig { public string source_drive { get; set; } = "E:"; public string snapshot_data_path { get; set; } = "AOexpress"; public string ldf_name { get; set; } = "OASIS_FLUX_log.ldf"; public string? direct_ldf_path { get; set; } public string live_server_instance { get; set; } = @"LOCALHOST\SQLEXPRESS"; public string live_database { get; set; } = "OASIS_FLUX"; public string log_reader_function { get; set; } = "fn_dblog"; public string? client_id { get; set; } public string? environment { get; set; } public string? sql_version_hint { get; set; } public List<string> tables { get; set; } = new(); public List<string> users { get; set; } = new(); public List<string> exclude_users { get; set; } = new(); public List<int> spids { get; set; } = new(); public int window_minutes { get; set; } = 15; public bool bootstrap_first_run { get; set; } = true; public string raw_match_mode { get; set; } = "skip"; public string read_mode { get; set; } = "live_manifest"; public int offline_tail_bytes { get; set; } = 67108864; public int offline_probe_tail_bytes { get; set; } = 16777216; public bool offline_auto_probe_profile { get; set; } = true; public int offline_record_capture_bytes { get; set; } = 192; public int offline_diag_top_tokens { get; set; } = 50; public int offline_diag_sample_limit { get; set; } = 25; public bool offline_log_only { get; set; } public long? raw_explore_window_start { get; set; } public long? raw_explore_window_length { get; set; } public List<string> raw_explore_actions { get; set; } = new(); public List<string> raw_explore_db_markers { get; set; } = new(); public List<string> semantic_event_kinds { get; set; } = new(); public bool apply_to_target { get; set; } public bool use_compiled_converter { get; set; } = true; public string? reuse_shadow_device { get; set; } public bool skip_shadow_cleanup { get; set; } public bool skip_lsn_head_precheck { get; set; } public string? start_lsn { get; set; } public string update_mode { get; set; } = "adaptive"; public string apply_target_server_instance { get; set; } = @"LOCALHOST\SQLEXPRESS"; public string apply_target_database { get; set; } = "OASIS_FLUX"; public bool apply_stop_on_error { get; set; } = true; public bool apply_wrap_in_transaction { get; set; } public string? compiled_converter_path { get; set; } public string? trn_output_path_template { get; set; } }
sealed class SecurityConfig { public bool use_sql_auth { get; set; } public string? sql_user { get; set; } public string? sql_password { get; set; } }
sealed class Runtime
{
    public required string ConfigPath { get; init; }
    public required ServiceRuntime Service { get; init; }
    public required PathRuntime Paths { get; init; }
    public required PipelineRuntime Pipeline { get; init; }
    public required SecurityRuntime Security { get; init; }

    public static Runtime From(Config cfg, string configPath, bool once)
    {
        var baseDir = Path.GetDirectoryName(configPath) ?? Environment.CurrentDirectory;
        string Resolve(string path) => Path.IsPathRooted(path) ? path : Path.GetFullPath(Path.Combine(baseDir, path));
        static byte? ParseMarker(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return null;
            var text = value.Trim();
            if (text.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
                text = text[2..];
            return byte.TryParse(text, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var parsed)
                ? parsed
                : null;
        }
        static string ParseLogReaderFunction(string? configuredValue)
        {
            if (string.IsNullOrWhiteSpace(configuredValue))
                return "fn_dblog";

            var canonical = configuredValue.Trim().ToLowerInvariant();
            return canonical switch
            {
                "fn_dblog" or "sys.fn_dblog" or "master.sys.fn_dblog" => "fn_dblog",
                "fn_full_dblog" or "sys.fn_full_dblog" or "master.sys.fn_full_dblog" => "fn_full_dblog",
                _ => throw new InvalidOperationException($"Unsupported pipeline.log_reader_function '{configuredValue}'. Allowed values: fn_dblog, fn_full_dblog.")
            };
        }

        return new Runtime
        {
            ConfigPath = configPath,
            Service = new ServiceRuntime
            {
                Name = string.IsNullOrWhiteSpace(cfg.service.name) ? "AOTransact" : cfg.service.name,
                IntervalMinutes = Math.Max(1, cfg.service.interval_minutes),
                Loop = once ? false : cfg.service.loop,
                MaxCycleMinutes = Math.Max(1, cfg.service.max_cycle_minutes)
            },
            Paths = new PathRuntime
            {
                OutputDir = Resolve(cfg.paths.output_dir),
                StatePath = Resolve(cfg.paths.state_path),
                MetadataSnapshotPath = Resolve(cfg.paths.metadata_snapshot_path),
                LockFilePath = Resolve(cfg.paths.lock_file_path),
                HealthFilePath = Resolve(cfg.paths.health_file_path),
                LogDir = Resolve(cfg.paths.log_dir),
                ArchiveDir = Resolve(cfg.paths.archive_dir),
                ArchiveAfterHours = Math.Max(0, cfg.paths.archive_after_hours),
                DeleteOriginalAfterArchive = cfg.paths.delete_original_after_archive
            },
            Pipeline = new PipelineRuntime
            {
                SourceDrive = cfg.pipeline.source_drive,
                SnapshotDataPath = cfg.pipeline.snapshot_data_path,
                LdfName = cfg.pipeline.ldf_name,
                DirectLdfPath = string.IsNullOrWhiteSpace(cfg.pipeline.direct_ldf_path) ? null : Resolve(cfg.pipeline.direct_ldf_path),
                LiveServerInstance = cfg.pipeline.live_server_instance,
                LiveDatabase = cfg.pipeline.live_database,
                LogReaderFunction = ParseLogReaderFunction(cfg.pipeline.log_reader_function),
                ClientId = string.IsNullOrWhiteSpace(cfg.pipeline.client_id) ? null : cfg.pipeline.client_id.Trim(),
                Environment = string.IsNullOrWhiteSpace(cfg.pipeline.environment) ? null : cfg.pipeline.environment.Trim(),
                SqlVersionHint = string.IsNullOrWhiteSpace(cfg.pipeline.sql_version_hint) ? null : cfg.pipeline.sql_version_hint.Trim(),
                Tables = cfg.pipeline.tables ?? new(),
                Users = cfg.pipeline.users ?? new(),
                ExcludeUsers = cfg.pipeline.exclude_users ?? new(),
                Spids = cfg.pipeline.spids ?? new(),
                WindowMinutes = Math.Max(1, cfg.pipeline.window_minutes),
                BootstrapFirstRun = cfg.pipeline.bootstrap_first_run,
                RawMatchMode = string.IsNullOrWhiteSpace(cfg.pipeline.raw_match_mode) ? "skip" : cfg.pipeline.raw_match_mode,
                ReadMode = string.IsNullOrWhiteSpace(cfg.pipeline.read_mode) ? "live_manifest" : cfg.pipeline.read_mode,
                OfflineTailBytes = cfg.pipeline.offline_tail_bytes <= 0 ? 67108864 : cfg.pipeline.offline_tail_bytes,
                OfflineProbeTailBytes = cfg.pipeline.offline_probe_tail_bytes <= 0 ? 16777216 : cfg.pipeline.offline_probe_tail_bytes,
                OfflineAutoProbeProfile = cfg.pipeline.offline_auto_probe_profile,
                OfflineRecordCaptureBytes = cfg.pipeline.offline_record_capture_bytes <= 0 ? 192 : cfg.pipeline.offline_record_capture_bytes,
                OfflineDiagTopTokens = cfg.pipeline.offline_diag_top_tokens <= 0 ? 50 : cfg.pipeline.offline_diag_top_tokens,
                OfflineDiagSampleLimit = cfg.pipeline.offline_diag_sample_limit <= 0 ? 25 : cfg.pipeline.offline_diag_sample_limit,
                OfflineLogOnly = cfg.pipeline.offline_log_only,
                RawExploreWindowStart = cfg.pipeline.raw_explore_window_start,
                RawExploreWindowLength = cfg.pipeline.raw_explore_window_length,
                RawExploreActions = (cfg.pipeline.raw_explore_actions ?? new()).Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim().ToUpperInvariant()).Distinct().ToList(),
                RawExploreDbMarkers = (cfg.pipeline.raw_explore_db_markers ?? new()).Where(x => !string.IsNullOrWhiteSpace(x)).Select(ParseMarker).Where(x => x.HasValue).Select(x => x!.Value).Distinct().ToList(),
                SemanticEventKinds = (cfg.pipeline.semantic_event_kinds ?? new()).Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).ToList(),
                ApplyToTarget = cfg.pipeline.apply_to_target,
                UseCompiledConverter = cfg.pipeline.use_compiled_converter,
                ReuseShadowDevice = cfg.pipeline.reuse_shadow_device,
                SkipShadowCleanup = cfg.pipeline.skip_shadow_cleanup,
                SkipLsnHeadPrecheck = cfg.pipeline.skip_lsn_head_precheck,
                StartLsn = cfg.pipeline.start_lsn,
                UpdateMode = string.IsNullOrWhiteSpace(cfg.pipeline.update_mode) ? "adaptive" : cfg.pipeline.update_mode,
                ApplyTargetServerInstance = string.IsNullOrWhiteSpace(cfg.pipeline.apply_target_server_instance) ? cfg.pipeline.live_server_instance : cfg.pipeline.apply_target_server_instance,
                ApplyTargetDatabase = string.IsNullOrWhiteSpace(cfg.pipeline.apply_target_database) ? cfg.pipeline.live_database : cfg.pipeline.apply_target_database,
                ApplyStopOnError = cfg.pipeline.apply_stop_on_error,
                ApplyWrapInTransaction = cfg.pipeline.apply_wrap_in_transaction,
                CompiledConverterPath = Resolve(string.IsNullOrWhiteSpace(cfg.pipeline.compiled_converter_path) ? ".\\tools\\offline-log\\fast-quote-convert\\bin\\Release\\net8.0\\fast-quote-convert.exe" : cfg.pipeline.compiled_converter_path),
                TrnOutputPathTemplate = string.IsNullOrWhiteSpace(cfg.pipeline.trn_output_path_template) ? null : Resolve(cfg.pipeline.trn_output_path_template)
            },
            Security = new SecurityRuntime
            {
                UseSqlAuth = cfg.security.use_sql_auth,
                SqlUser = cfg.security.sql_user,
                SqlPassword = cfg.security.sql_password
            }
        };
    }
}
sealed class ServiceRuntime { public required string Name { get; init; } public required int IntervalMinutes { get; init; } public required bool Loop { get; init; } public required int MaxCycleMinutes { get; init; } }
sealed class PathRuntime { public required string OutputDir { get; init; } public required string StatePath { get; init; } public required string MetadataSnapshotPath { get; init; } public required string LockFilePath { get; init; } public required string HealthFilePath { get; init; } public required string LogDir { get; init; } public required string ArchiveDir { get; init; } public required int ArchiveAfterHours { get; init; } public required bool DeleteOriginalAfterArchive { get; init; } }
sealed class PipelineRuntime { public required string SourceDrive { get; init; } public required string SnapshotDataPath { get; init; } public required string LdfName { get; init; } public required string? DirectLdfPath { get; init; } public required string LiveServerInstance { get; init; } public required string LiveDatabase { get; init; } public required string LogReaderFunction { get; init; } public required string? ClientId { get; init; } public required string? Environment { get; init; } public required string? SqlVersionHint { get; init; } public required List<string> Tables { get; init; } public required List<string> Users { get; init; } public required List<string> ExcludeUsers { get; init; } public required List<int> Spids { get; init; } public required int WindowMinutes { get; init; } public required bool BootstrapFirstRun { get; init; } public required string RawMatchMode { get; init; } public required string ReadMode { get; init; } public required int OfflineTailBytes { get; init; } public required int OfflineProbeTailBytes { get; init; } public required bool OfflineAutoProbeProfile { get; init; } public required int OfflineRecordCaptureBytes { get; init; } public required int OfflineDiagTopTokens { get; init; } public required int OfflineDiagSampleLimit { get; init; } public required bool OfflineLogOnly { get; init; } public required long? RawExploreWindowStart { get; init; } public required long? RawExploreWindowLength { get; init; } public required List<string> RawExploreActions { get; init; } public required List<byte> RawExploreDbMarkers { get; init; } public required List<string> SemanticEventKinds { get; init; } public required bool ApplyToTarget { get; init; } public required bool UseCompiledConverter { get; init; } public required string? ReuseShadowDevice { get; init; } public required bool SkipShadowCleanup { get; init; } public required bool SkipLsnHeadPrecheck { get; init; } public required string? StartLsn { get; init; } public required string UpdateMode { get; init; } public required string ApplyTargetServerInstance { get; init; } public required string ApplyTargetDatabase { get; init; } public required bool ApplyStopOnError { get; init; } public required bool ApplyWrapInTransaction { get; init; } public required string CompiledConverterPath { get; init; } public string? TrnOutputPathTemplate { get; init; } public string? CurrentLdfPath { get; set; } }
sealed class SecurityRuntime { public required bool UseSqlAuth { get; init; } public required string? SqlUser { get; init; } public required string? SqlPassword { get; init; } }
sealed class RunnerState { public int version { get; set; } public string? updated_at_utc { get; set; } public bool bootstrap_only { get; set; } public string? live_server_instance { get; set; } public string? live_database { get; set; } public string? tables_key { get; set; } public string? filters_key { get; set; } public string? source_signature { get; set; } public string? last_lsn { get; set; } public string? active_shadow_id { get; set; } public string? active_shadow_device { get; set; } public string? active_shadow_session { get; set; } public bool active_shadow_active { get; set; } public string? active_shadow_updated_utc { get; set; } }

