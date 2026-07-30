using System.Data;
using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using System.Text.RegularExpressions;
using System.Diagnostics;

record ColumnMeta(string Name, string DataType, int ColumnId, bool IsPk, int PkOrdinal);
record GenericRowCandidate(string StringConcat, HashSet<long> NumericValues, object?[] Row);
record Key(string Dbid, long QuoteId, long? LineNumber, long? Key4 = null)
{
    public override string ToString()
    {
        if (Key4.HasValue)
            return $"{Dbid}|{QuoteId}|{LineNumber.GetValueOrDefault()}|{Key4.Value}";
        if (LineNumber.HasValue)
            return $"{Dbid}|{QuoteId}|{LineNumber.Value}";
        return $"{Dbid}|{QuoteId}";
    }
}
record PartialKey(long QuoteId, long LineNumber)
{
    public override string ToString() => $"{QuoteId}|{LineNumber}";
}

record ManifestRec(
    string Action,
    string CurrentLsn,
    string TxId,
    string TableName,
    string SchemaName,
    string? TransactionName,
    string? OperationName,
    string? ContextName,
    string? AllocUnitName,
    string? PageId,
    int? SlotId,
    string? RowLog0Hex,
    string? RowLog1Hex,
    string? RowLog2Hex,
    string? RowLog3Hex,
    string? RowLog4Hex,
    string? RowLog5Hex,
    string? CommitTime
);

record RunConfig(
    string? Server,
    string? Database,
    string? UserId,
    string? Password,
    JsonElement? Tables
);

static class Program
{
    static HashSet<string> KnownDbids = new(StringComparer.OrdinalIgnoreCase);
    static string TargetSchema = "";
    static string TargetTable = "";
    static string KeyCol1 = "";
    static string KeyCol2 = "";
    static string? KeyCol3 = null;
    static string? KeyCol4 = null;
    static long CallsFetchPk = 0;
    static long CallsFetchKnownDbids = 0;
    static long CallsFetchKnownKeyPairs = 0;
    static long CallsFetchKnownSingleKeys = 0;
    static long CallsFetchKnownKeyTriples = 0;
    static long CallsFetchRows = 0;
    static long CallsFetchRowsByPhysLoc = 0;
    static long CallsResolveByPartial = 0;
    static long CallsResolveInsertCandidates = 0;
    static long CallsResolveInsertByPhysLoc = 0;
    static bool EnableDebugEmitTokenLog = false;
    static bool EnablePartialResolve = false;
    // Default off for performance; enable via --physloc-lookup true as fallback mode.
    static bool EnablePhysLocLookup = false;
    // Default on for 2-key tables: reject bogus decoded IDs not present in current keyspace.
    static bool EnforceKnownPairFilter = true;
    static bool EnableInsertCandidateResolve = false;
    static bool EnableInsertPhysLocResolve = false;
    static bool EmitCompact = false;
    static string UpdateEmitMode = "hybrid"; // hybrid|full|replace
    static bool OfflineLogOnlyMode = false;
    static string? TrustDiagnosticsPath = null;
    static int TrustDiagnosticsSampleLimit = 200;
    static bool HasThirdKey => !string.IsNullOrWhiteSpace(KeyCol3);
    static bool HasFourthKey => !string.IsNullOrWhiteSpace(KeyCol4);
    static HashSet<string> KnownTwoKeyPairs = new(StringComparer.OrdinalIgnoreCase);
    static HashSet<string> KnownSingleKeys = new(StringComparer.OrdinalIgnoreCase);
    static HashSet<string> KnownThreeKeyTriples = new(StringComparer.OrdinalIgnoreCase);
    static HashSet<string> KnownFourKeyQuads = new(StringComparer.OrdinalIgnoreCase);

    static int Main(string[] args)
    {
        var runSw = Stopwatch.StartNew();
        var arg = ParseArgs(args);
        ApplyJsonConfigIfProvided(arg);

        if (!arg.TryGetValue("server", out var server) ||
            !arg.TryGetValue("database", out var database))
        {
            Console.Error.WriteLine("Required: --server --database [--tables schema.table,...] [--schema S --table T] [--config params.json]. Optional: --manifest --metadata --output");
            return 2;
        }

        var manifestPath = arg.GetValueOrDefault("manifest");
        if (string.IsNullOrWhiteSpace(manifestPath))
            manifestPath = FindLatestFile(Path.Combine(Environment.CurrentDirectory, "output"), "live-dml-manifest*.json");
        if (string.IsNullOrWhiteSpace(manifestPath) || !File.Exists(manifestPath))
        {
            Console.Error.WriteLine("Manifest not provided and no matching file found in ./output (live-dml-manifest*.json).");
            return 2;
        }

        var metadataPath = arg.GetValueOrDefault("metadata");
        if (string.IsNullOrWhiteSpace(metadataPath))
            metadataPath = FindLatestFile(Path.Combine(Environment.CurrentDirectory, "output"), "*metadata*.snapshot.json");
        if (string.IsNullOrWhiteSpace(metadataPath) || !File.Exists(metadataPath))
        {
            Console.Error.WriteLine("Metadata not provided and no matching file found in ./output (*metadata*.snapshot.json).");
            return 2;
        }

        var outputPath = arg.GetValueOrDefault("output");
        if (string.IsNullOrWhiteSpace(outputPath))
        {
            var outDir = Path.Combine(Environment.CurrentDirectory, "output");
            Directory.CreateDirectory(outDir);
            outputPath = Path.Combine(outDir, $"fast.{DateTime.UtcNow:yyyyMMdd_HHmmss}.trn");
        }
        var vResolvePartial = arg.GetValueOrDefault("resolve-partial");
        if (!string.IsNullOrWhiteSpace(vResolvePartial))
            EnablePartialResolve = string.Equals(vResolvePartial, "true", StringComparison.OrdinalIgnoreCase);

        var vPhysLocLookup = arg.GetValueOrDefault("physloc-lookup");
        if (!string.IsNullOrWhiteSpace(vPhysLocLookup))
            EnablePhysLocLookup = string.Equals(vPhysLocLookup, "true", StringComparison.OrdinalIgnoreCase);

        var vStrictPair = arg.GetValueOrDefault("strict-pair-filter");
        if (!string.IsNullOrWhiteSpace(vStrictPair))
            EnforceKnownPairFilter = string.Equals(vStrictPair, "true", StringComparison.OrdinalIgnoreCase);

        var vResolveInsertCandidates = arg.GetValueOrDefault("resolve-insert-candidates");
        if (!string.IsNullOrWhiteSpace(vResolveInsertCandidates))
            EnableInsertCandidateResolve = string.Equals(vResolveInsertCandidates, "true", StringComparison.OrdinalIgnoreCase);

        var vResolveInsertPhysLoc = arg.GetValueOrDefault("resolve-insert-physloc");
        if (!string.IsNullOrWhiteSpace(vResolveInsertPhysLoc))
            EnableInsertPhysLocResolve = string.Equals(vResolveInsertPhysLoc, "true", StringComparison.OrdinalIgnoreCase);
        var vDebugEmitTokenLog = arg.GetValueOrDefault("debug-emit-token-log");
        if (!string.IsNullOrWhiteSpace(vDebugEmitTokenLog))
            EnableDebugEmitTokenLog = string.Equals(vDebugEmitTokenLog, "true", StringComparison.OrdinalIgnoreCase);
        var vEmitCompact = arg.GetValueOrDefault("emit-compact");
        if (!string.IsNullOrWhiteSpace(vEmitCompact))
            EmitCompact = string.Equals(vEmitCompact, "true", StringComparison.OrdinalIgnoreCase);
        var vOfflineLogOnly = arg.GetValueOrDefault("offline-log-only");
        if (!string.IsNullOrWhiteSpace(vOfflineLogOnly))
            OfflineLogOnlyMode = string.Equals(vOfflineLogOnly, "true", StringComparison.OrdinalIgnoreCase);
        var vTrustDiagnosticsPath = arg.GetValueOrDefault("trust-diagnostics-path");
        if (!string.IsNullOrWhiteSpace(vTrustDiagnosticsPath))
            TrustDiagnosticsPath = Path.GetFullPath(vTrustDiagnosticsPath, Environment.CurrentDirectory);
        var vTrustDiagnosticsSampleLimit = arg.GetValueOrDefault("trust-diagnostics-sample-limit");
        if (int.TryParse(vTrustDiagnosticsSampleLimit, NumberStyles.Integer, CultureInfo.InvariantCulture, out var trustDiagLimit) && trustDiagLimit > 0)
            TrustDiagnosticsSampleLimit = trustDiagLimit;
        var vUpdateEmitMode = arg.GetValueOrDefault("update-emit-mode");
        if (!string.IsNullOrWhiteSpace(vUpdateEmitMode))
        {
            var m = vUpdateEmitMode.Trim().ToLowerInvariant();
            if (m is "hybrid" or "full" or "replace")
                UpdateEmitMode = m;
        }

        List<(string Schema, string Table)> targets;
        try
        {
            targets = ResolveTargets(arg);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 2;
        }

        var manifestReadSw = Stopwatch.StartNew();
        var allManifest = ReadManifest(manifestPath);
        manifestReadSw.Stop();
        var conn = BuildConnString(server, database, arg.GetValueOrDefault("sql-user"), arg.GetValueOrDefault("sql-password"));

        int totalRows = 0, totalOk = 0, totalUnresolved = 0, totalSkipped = 0, totalIns = 0, totalUpd = 0, totalDel = 0;
        var final = new StringBuilder(8 * 1024 * 1024);
        var unresolvedAll = new StringBuilder(2 * 1024 * 1024);
        var trustDiagnostics = new List<Dictionary<string, object?>>();
        var trustDiagnosticCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        if (!EmitCompact)
        {
            final.AppendLine($"-- Fast compiled prototype");
            final.AppendLine($"-- Manifest: {manifestPath}");
            final.AppendLine($"-- Generated UTC: {DateTime.UtcNow:O}");
            final.AppendLine($"-- Targets: {string.Join(", ", targets.Select(t => $"{t.Schema}.{t.Table}"))}");
            final.AppendLine($"-- Emit options: update_emit_mode={UpdateEmitMode}; emit_compact={EmitCompact}");
            final.AppendLine($"-- Offline log only: {OfflineLogOnlyMode}");
            final.AppendLine();
        }

        foreach (var target in targets)
        {
            var tableSw = Stopwatch.StartNew();
            var filterSw = Stopwatch.StartNew();
            TargetSchema = target.Schema;
            TargetTable = target.Table;

            var manifestAll = allManifest
                .Where(r => r.SchemaName.Equals(TargetSchema, StringComparison.OrdinalIgnoreCase)
                         && r.TableName.Equals(TargetTable, StringComparison.OrdinalIgnoreCase)
                         && !IsInternalTransactionName(r.TransactionName)
                         && (r.Action is "UPDATE" or "INSERT" or "DELETE"))
                .OrderBy(r => ParseCommit(r.CommitTime))
                .ThenBy(r => r.CurrentLsn, StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (manifestAll.Count == 0) continue;

            var baseRows = manifestAll.Where(r => IsBaseRowRecord(r, TargetSchema, TargetTable)).ToList();
            var manifest = manifestAll;
            if (baseRows.Count > 0)
            {
                manifest = baseRows;
                var baseInsertCount = baseRows.Count(r => string.Equals(r.Action, "INSERT", StringComparison.OrdinalIgnoreCase));
                var bestInsertLeaf = manifestAll
                    .Where(r => string.Equals(r.Action, "INSERT", StringComparison.OrdinalIgnoreCase)
                             && string.Equals(r.ContextName, "LCX_INDEX_LEAF", StringComparison.OrdinalIgnoreCase)
                             && !string.IsNullOrWhiteSpace(r.AllocUnitName))
                    .GroupBy(r => r.AllocUnitName!, StringComparer.OrdinalIgnoreCase)
                    .OrderByDescending(g => g.Count())
                    .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
                    .FirstOrDefault();
                if (bestInsertLeaf is not null)
                {
                    var bestInsertLeafCount = bestInsertLeaf.Count();
                    if (baseInsertCount == 0 || (baseInsertCount < 10 && bestInsertLeafCount >= 100))
                    {
                        manifest = baseRows
                            .Where(r => !string.Equals(r.Action, "INSERT", StringComparison.OrdinalIgnoreCase))
                            .Concat(bestInsertLeaf)
                            .GroupBy(r => $"{r.Action}|{r.TxId}|{r.CurrentLsn}", StringComparer.OrdinalIgnoreCase)
                            .Select(g => g.First())
                            .OrderBy(r => ParseCommit(r.CommitTime))
                            .ThenBy(r => r.CurrentLsn, StringComparer.OrdinalIgnoreCase)
                            .ToList();
                    }
                }
            }
            var deleteRowsForTable = manifest.Where(r => string.Equals(r.Action, "DELETE", StringComparison.OrdinalIgnoreCase)).ToList();
            var deleteGhostOnlyMode = deleteRowsForTable.Count > 0
                && deleteRowsForTable.All(r => string.Equals(r.ContextName, "LCX_MARK_AS_GHOST", StringComparison.OrdinalIgnoreCase));
            filterSw.Stop();

            var metadataSw = Stopwatch.StartNew();
            var columns = ReadColumns(metadataPath, TargetSchema, TargetTable);
            if (columns.Count == 0)
            {
                unresolvedAll.AppendLine($"-- {TargetSchema}.{TargetTable}: skipped (metadata not found)");
                unresolvedAll.AppendLine();
                continue;
            }

            var pk = columns.Where(c => c.IsPk).OrderBy(c => c.PkOrdinal).Select(c => c.Name).ToList();
            if (pk.Count < 1 && !OfflineLogOnlyMode) pk = FetchPkColumnsFromDb(conn, TargetSchema, TargetTable);
            if (pk.Count < 1)
            {
                unresolvedAll.AppendLine($"-- {TargetSchema}.{TargetTable}: skipped (need >=1 PK columns, found {pk.Count})");
                unresolvedAll.AppendLine();
                continue;
            }
            var keyCols = pk.ToList();
            var columnSqlNames = columns.Select(c => Q(c.Name)).ToArray();
            var normalizedTypes = columns.Select(c => c.DataType.ToLowerInvariant()).ToArray();
            var insertPrefix = $"INSERT INTO {SqlObject(TargetSchema, TargetTable)} ({string.Join(", ", columnSqlNames)}) VALUES (";
            var pkNameSet = new HashSet<string>(keyCols, StringComparer.OrdinalIgnoreCase);
            var keyMeta = keyCols
                .Select(k => columns.FirstOrDefault(c => c.Name.Equals(k, StringComparison.OrdinalIgnoreCase)))
                .ToList();
            var key2NonIntegral = keyMeta.Count >= 2 && keyMeta[1] is not null && !IsIntegralSqlType(keyMeta[1]!.DataType);
            var key3Or4HasNonIntegral = keyMeta.Skip(2).Any(m => m is not null && !IsIntegralSqlType(m!.DataType));
            var useGenericMixedPkResolver = keyCols.Count > 4 || key2NonIntegral || key3Or4HasNonIntegral;
            var key3Meta = keyMeta.Count >= 3 ? keyMeta[2] : null;
            var canUseInsertCandidateResolve = EnableInsertCandidateResolve
                && !useGenericMixedPkResolver
                && (key3Meta is null || IsIntegralSqlType(key3Meta.DataType));

            var singlePkMode = keyCols.Count == 1;
            KeyCol1 = arg.GetValueOrDefault("key1") ?? pk[0];
            KeyCol2 = (pk.Count >= 2) ? (arg.GetValueOrDefault("key2") ?? pk[1]) : "";
            KeyCol3 = (pk.Count >= 3) ? (arg.GetValueOrDefault("key3") ?? pk[2]) : null;
            KeyCol4 = (pk.Count >= 4) ? (arg.GetValueOrDefault("key4") ?? pk[3]) : null;
            KnownSingleKeys = singlePkMode && !OfflineLogOnlyMode
                ? FetchKnownSingleKeys(conn, TargetSchema, TargetTable, KeyCol1)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            KnownDbids = singlePkMode || OfflineLogOnlyMode
                ? new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                : FetchKnownDbids(conn, TargetSchema, TargetTable, KeyCol1);
            KnownTwoKeyPairs = singlePkMode || HasThirdKey || OfflineLogOnlyMode
                ? new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                : FetchKnownTwoKeyPairs(conn, TargetSchema, TargetTable, KeyCol1, KeyCol2);
            KnownThreeKeyTriples = HasThirdKey && !HasFourthKey && !useGenericMixedPkResolver && !OfflineLogOnlyMode
                ? FetchKnownThreeKeyTriples(conn, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3!)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            KnownFourKeyQuads = HasFourthKey && !useGenericMixedPkResolver && !OfflineLogOnlyMode
                ? FetchKnownFourKeyQuads(conn, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3!, KeyCol4!)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            metadataSw.Stop();

            if (singlePkMode)
            {
                var singlePrepSw = Stopwatch.StartNew();
                var txFallbackSingle = BuildTxFallbackSingleKeyMap(manifest, keyCols[0], columns);
                var txResolvedSingle = new Dictionary<string, string>(txFallbackSingle, StringComparer.OrdinalIgnoreCase);
                var uniqueSingleKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var r in manifest)
                {
                    var k = DecodeSingleKeyFromRecord(r, keyCols[0], columns, KnownSingleKeys) ?? txFallbackSingle.GetValueOrDefault(r.TxId);
                    if (!string.IsNullOrWhiteSpace(k)) uniqueSingleKeys.Add(k);
                }
                singlePrepSw.Stop();

                var singleFetchSw = Stopwatch.StartNew();
                var rowBySingleKey = OfflineLogOnlyMode
                    ? new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase)
                    : FetchRowsBySingleKey(conn, columns, uniqueSingleKeys.ToList(), TargetSchema, TargetTable, keyCols[0]);
                singleFetchSw.Stop();

                var singleEmitSw = Stopwatch.StartNew();
                int ok1 = 0, unresolved1 = 0, skipped1 = 0, ins1 = 0, upd1 = 0, del1 = 0;
                var emittedByToken = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                var unresolvedByTxSingle = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                if (!EmitCompact)
                {
                    final.AppendLine($"-- Table: {TargetSchema}.{TargetTable}");
                    final.AppendLine($"-- Keys: {string.Join(",", keyCols)}");
                    final.AppendLine($"-- BaseRowFilter: selected={manifest.Count}; total={manifestAll.Count}");
                    final.AppendLine();
                }

                foreach (var r in manifest)
                {
                    var action = (r.Action ?? "").Trim().ToUpperInvariant();
                    var physLoc = TryBuildPhysLoc(r) ?? "";
                    var singleKey = DecodeSingleKeyFromRecord(r, keyCols[0], columns, KnownSingleKeys);
                    if (string.IsNullOrWhiteSpace(singleKey) && string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(physLoc))
                    {
                        singleKey = ResolveSingleKeyByPhysLoc(conn, physLoc, TargetSchema, TargetTable, keyCols[0]);
                    }
                    if (string.IsNullOrWhiteSpace(singleKey) && !string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase))
                    {
                        singleKey = txResolvedSingle.GetValueOrDefault(r.TxId);
                    }
                    if (string.IsNullOrWhiteSpace(singleKey))
                    {
                        if (!HasAnyRowLog(r))
                        {
                            skipped1++;
                            continue;
                        }
                        var unresolvedTxToken = $"{action}|{r.TxId}";
                        if (unresolvedByTxSingle.Contains(unresolvedTxToken)) continue;
                        unresolvedByTxSingle.Add(unresolvedTxToken);
                        unresolved1++;
                        unresolvedAll.AppendLine($"--{action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                        unresolvedAll.AppendLine("-- unresolved: key decode failed");
                        unresolvedAll.AppendLine("GO");
                        unresolvedAll.AppendLine();
                        continue;
                    }

                    txResolvedSingle[r.TxId] = singleKey;
                    var emitToken = string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase)
                        ? $"{action}|{r.CurrentLsn}|{physLoc}"
                        : string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase)
                            ? $"{action}|{r.TxId}|{singleKey}"
                            : $"{action}|{r.CurrentLsn}";
                    if (!emittedByToken.Add(emitToken)) continue;

                    rowBySingleKey.TryGetValue(singleKey, out var row);
                    if (row is null && !string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase))
                    {
                        if (!OfflineLogOnlyMode && string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(physLoc))
                        {
                            var keyFromPhys = ResolveSingleKeyByPhysLoc(conn, physLoc, TargetSchema, TargetTable, keyCols[0]);
                            if (!string.IsNullOrWhiteSpace(keyFromPhys))
                            {
                                singleKey = keyFromPhys;
                            }
                        }
                        row = OfflineLogOnlyMode
                            ? null
                            : FetchRowBySingleKey(conn, columns, singleKey, TargetSchema, TargetTable, keyCols[0]);
                        if (row is not null) rowBySingleKey[singleKey] = row;
                    }

                    var keySql = WhereSingleKeySql(singleKey, keyCols[0], columns);
                    if (row is not null)
                    {
                        if (action == "INSERT")
                        {
                            if (!EmitCompact) final.AppendLine($"--INSERT ({r.CurrentLsn})");
                            final.Append(insertPrefix);
                            for (int i = 0; i < row.Length; i++)
                            {
                                if (i > 0) final.Append(", ");
                                final.Append(ToSqlLiteral(row[i], normalizedTypes[i]));
                            }
                            final.AppendLine(";");
                            final.AppendLine("GO");
                            if (!EmitCompact) final.AppendLine();
                            ok1++; ins1++;
                        }
                        else if (action == "UPDATE")
                        {
                            if (!EmitCompact) final.AppendLine($"--UPDATE ({r.CurrentLsn})");
                            final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {keySql};");
                            final.Append(insertPrefix);
                            for (int i = 0; i < row.Length; i++)
                            {
                                if (i > 0) final.Append(", ");
                                final.Append(ToSqlLiteral(row[i], normalizedTypes[i]));
                            }
                            final.AppendLine(";");
                            final.AppendLine("GO");
                            if (!EmitCompact) final.AppendLine();
                            ok1++; upd1++;
                        }
                        else if (action == "DELETE")
                        {
                            if (!EmitCompact) final.AppendLine($"--DELETE ({r.CurrentLsn})");
                            final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {keySql};");
                            final.AppendLine("GO");
                            if (!EmitCompact) final.AppendLine();
                            ok1++; del1++;
                        }
                    }
                    else
                    {
                        if (action == "DELETE")
                        {
                            if (!EmitCompact) final.AppendLine($"--DELETE ({r.CurrentLsn})");
                            final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {keySql};");
                            final.AppendLine("GO");
                            if (!EmitCompact) final.AppendLine();
                            ok1++; del1++;
                        }
                        else
                        {
                            var unresolvedTxToken = $"{action}|{r.TxId}";
                            if (unresolvedByTxSingle.Contains(unresolvedTxToken)) continue;
                            unresolvedByTxSingle.Add(unresolvedTxToken);
                            unresolved1++;
                            AddTrustDiagnostic(
                                trustDiagnostics,
                                trustDiagnosticCounts,
                                "single_key_row_materialization_unavailable",
                                r,
                                singleKey,
                                TargetSchema,
                                TargetTable,
                                rowFound: false,
                                trusted: false,
                                note: OfflineLogOnlyMode
                                    ? "offline_log_only mode skipped DB row materialization"
                                    : "row not found by single key",
                                sampleLimit: TrustDiagnosticsSampleLimit);
                            unresolvedAll.AppendLine($"--{action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                            unresolvedAll.AppendLine("-- unresolved: row not found by key");
                            unresolvedAll.AppendLine($"-- key: {keySql}");
                            unresolvedAll.AppendLine("GO");
                            unresolvedAll.AppendLine();
                        }
                    }
                }
                singleEmitSw.Stop();

                totalRows += manifest.Count;
                totalOk += ok1;
                totalUnresolved += unresolved1;
                totalSkipped += skipped1;
                totalIns += ins1;
                totalUpd += upd1;
                totalDel += del1;
                if (!EmitCompact)
                {
                    final.AppendLine($"-- Table Summary: total={manifest.Count}; ok={ok1}; unresolved={unresolved1}; skipped_internal={skipped1}; insert={ins1}; update={upd1}; delete={del1}");
                    final.AppendLine();
                }
                final.AppendLine($"-- Timing: filter_ms={filterSw.ElapsedMilliseconds}; metadata_ms={metadataSw.ElapsedMilliseconds}; prep_ms={singlePrepSw.ElapsedMilliseconds}; fetch_ms={singleFetchSw.ElapsedMilliseconds}; emit_ms={singleEmitSw.ElapsedMilliseconds}; total_ms={tableSw.ElapsedMilliseconds}");
                if (!EmitCompact) final.AppendLine();
                continue;
            }

            var prepSw = Stopwatch.StartNew();
            var txFallback = useGenericMixedPkResolver
                ? new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase)
                : BuildTxFallbackKeyMap(manifest);
            var txResolved = new Dictionary<string, Key>(txFallback, StringComparer.OrdinalIgnoreCase);
            var uniqueKeys = new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase);
            if (!useGenericMixedPkResolver)
            {
                foreach (var r in manifest)
                {
                    var k = DecodeKeyFromRecord(r) ?? txFallback.GetValueOrDefault(r.TxId);
                    if (k is null) continue;
                    uniqueKeys[k.ToString()] = k;
                }
            }
            prepSw.Stop();

            var fetchSw = Stopwatch.StartNew();
            var rowByKey = useGenericMixedPkResolver
                ? new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase)
                : OfflineLogOnlyMode
                    ? new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase)
                    : FetchRows(conn, columns, uniqueKeys.Values.ToList(), TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
            var physLocToKey = new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase);
            var rowByPhysLoc = new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase);
            List<GenericRowCandidate>? genericCandidates = null;
            var physLocs = manifest
                .Where(r => !string.IsNullOrWhiteSpace(r.PageId) && r.SlotId.HasValue)
                .Select(TryBuildPhysLoc)
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (useGenericMixedPkResolver)
            {
                genericCandidates = OfflineLogOnlyMode
                    ? null
                    : FetchGenericRowCandidates(conn, columns, keyCols, TargetSchema, TargetTable);
            }
            // Bulk physloc preloading is expensive on large tables.
            // Keep it only for 4-key tables where we need full PK reconstruction;
            // 2/3-key tables should use targeted physloc lookup on unresolved rows.
            var usePhysLocForTable = EnablePhysLocLookup && HasFourthKey && !OfflineLogOnlyMode;
            if (usePhysLocForTable && physLocs.Count > 0)
            {
                FetchRowsByPhysLoc(conn, columns, physLocs!, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4, rowByPhysLoc, physLocToKey);
            }
            fetchSw.Stop();

            var emitSw = Stopwatch.StartNew();
            var partialKeyCache = new Dictionary<string, Key?>(StringComparer.OrdinalIgnoreCase);
            var insertCandidateCache = new Dictionary<string, Key?>(StringComparer.OrdinalIgnoreCase);
            SqlConnection? tableConn = null;
            if (!OfflineLogOnlyMode)
            {
                tableConn = new SqlConnection(conn);
                tableConn.Open();
            }

            int ok = 0, unresolved = 0, skipped = 0, ins = 0, upd = 0, del = 0;
            int dbgSeenInsert = 0, dbgInsertKeyNull = 0, dbgInsertKeyResolved = 0;
            var emittedByTxKey = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var unresolvedByTx = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (!EmitCompact)
            {
                final.AppendLine($"-- Table: {TargetSchema}.{TargetTable}");
                final.AppendLine($"-- Keys: {string.Join(",", keyCols)}");
                final.AppendLine($"-- BaseRowFilter: selected={manifest.Count}; total={manifestAll.Count}");
                final.AppendLine();
            }

            foreach (var r in manifest)
            {
                var action = (r.Action ?? "").Trim().ToUpperInvariant();
                object?[]? genericResolvedRow = null;
                var genericResolved = false;
                if (action == "INSERT") dbgSeenInsert++;
                var physLoc = TryBuildPhysLoc(r);
                var key = DecodeKeyFromRecord(r);
                if (key is null && (
                    string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(action, "UPDATE", StringComparison.OrdinalIgnoreCase) ||
                    (string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase) && deleteGhostOnlyMode)))
                {
                    // Relax known-keyspace filtering for active-row operations where current-table snapshots
                    // can legitimately miss historical keys (e.g. insert+delete within the same window).
                    key = DecodeKeyFromRecord(r, relaxKnownFilter: true);
                }
                if (useGenericMixedPkResolver)
                {
                    key = null;
                }
                // INSERT must remain row-granular. Tx-level fallback can collapse many inserted rows
                // in a single statement into one key, which drops valid rows.
                if (!useGenericMixedPkResolver && key is null && !string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase))
                {
                    key = txResolved.GetValueOrDefault(r.TxId);
                }
                // For INSERT, physloc mapping is the most deterministic row locator for this snapshot.
                // Prefer it over heuristic key decode when available.
                if (string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase)
                    && !string.IsNullOrWhiteSpace(physLoc)
                    && physLocToKey.TryGetValue(physLoc!, out var keyFromPhysPreferred))
                {
                    key = keyFromPhysPreferred;
                }
                if (key is null)
                {
                    if (!string.IsNullOrWhiteSpace(physLoc) && physLocToKey.TryGetValue(physLoc!, out var keyFromPhys))
                    {
                        key = keyFromPhys;
                    }
                }
                if (key is null)
                {
                    if (action == "INSERT") dbgInsertKeyNull++;
                    if (action == "INSERT")
                    {
                        if (!useGenericMixedPkResolver && usePhysLocForTable && EnableInsertPhysLocResolve && key is null && string.Equals(r.ContextName, "LCX_CLUSTERED", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(physLoc))
                        {
                            key = tableConn is null ? null : ResolveKeyByPhysLoc(tableConn, physLoc!, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                        }
                        if (canUseInsertCandidateResolve && tableConn is not null)
                        {
                            key = ResolveInsertByCandidates(
                                tableConn,
                                r,
                                insertCandidateCache,
                                TargetSchema,
                                TargetTable,
                                KeyCol1,
                                KeyCol2,
                                KeyCol3
                            );
                        }
                        if (key is not null)
                        {
                            txResolved[r.TxId] = key;
                            if (!OfflineLogOnlyMode && !rowByKey.ContainsKey(key.ToString()))
                            {
                                var rows = FetchRows(conn, columns, new List<Key> { key }, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                                if (rows.TryGetValue(key.ToString(), out var rr))
                                {
                                    rowByKey[key.ToString()] = rr;
                                }
                            }
                        }
                    }
                }
                else if (action == "INSERT")
                {
                    dbgInsertKeyResolved++;
                }

                if (key is null)
                {
                    if (!useGenericMixedPkResolver && !string.IsNullOrWhiteSpace(physLoc)
                        && (action == "UPDATE" || (action == "DELETE" && !string.Equals(r.ContextName, "LCX_TEXT_MIX", StringComparison.OrdinalIgnoreCase))))
                    {
                        key = tableConn is null ? null : ResolveKeyByPhysLoc(tableConn, physLoc!, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                    }
                    if (!useGenericMixedPkResolver && action == "DELETE" && !deleteGhostOnlyMode && (
                        string.Equals(r.ContextName, "LCX_TEXT_MIX", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(r.ContextName, "LCX_MARK_AS_GHOST", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(r.ContextName, "LCX_INDEX_LEAF", StringComparison.OrdinalIgnoreCase)))
                    {
                        if (EnableDebugEmitTokenLog)
                        {
                            unresolvedAll.AppendLine($"--DEBUG SKIP DELETE ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                            unresolvedAll.AppendLine($"-- tx={r.TxId}; page={r.PageId}; slot={r.SlotId}; context={r.ContextName}; alloc={r.AllocUnitName}");
                            unresolvedAll.AppendLine($"-- rowlog0={r.RowLog0Hex}");
                            unresolvedAll.AppendLine($"-- rowlog1={r.RowLog1Hex}");
                            unresolvedAll.AppendLine($"-- rowlog2={r.RowLog2Hex}");
                            unresolvedAll.AppendLine("GO");
                            unresolvedAll.AppendLine();
                        }
                        skipped++;
                        continue;
                    }
                    if (action == "INSERT" && !useGenericMixedPkResolver)
                    {
                        // Keep internal/transient INSERT fragments skipped, but do not silently drop
                        // user INSERTs that carry rowlog evidence.
                        if (!HasAnyRowLog(r) || !HasDbidEvidence(r))
                        {
                            skipped++;
                            continue;
                        }
                        var unresolvedTxToken = $"{action}|{r.TxId}";
                        if (unresolvedByTx.Contains(unresolvedTxToken))
                        {
                            continue;
                        }
                        unresolvedByTx.Add(unresolvedTxToken);
                        unresolved++;
                        AddTrustDiagnostic(
                            trustDiagnostics,
                            trustDiagnosticCounts,
                            "key_decode_failed",
                            r,
                            null,
                            TargetSchema,
                            TargetTable,
                            rowFound: false,
                            trusted: false,
                            note: "decoded key remained null after fallback passes",
                            sampleLimit: TrustDiagnosticsSampleLimit);
                        unresolvedAll.AppendLine($"--{action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                        unresolvedAll.AppendLine("-- unresolved: key decode failed");
                        unresolvedAll.AppendLine("GO");
                        unresolvedAll.AppendLine();
                        continue;
                    }
                    var partial = DecodePartialFromRecord(r);
                    if (EnablePartialResolve && !string.IsNullOrWhiteSpace(KeyCol3) && partial is not null)
                    {
                        key = OfflineLogOnlyMode ? null : ResolveKeyByPartial(conn, partial, partialKeyCache, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3);
                    }
                }
                if (key is null)
                {
                    if (useGenericMixedPkResolver && genericCandidates is not null)
                    {
                        genericResolvedRow = ResolveGenericRowFromRecord(r, columns, keyCols, genericCandidates);
                        if (genericResolvedRow is not null)
                        {
                            genericResolved = true;
                            key = BuildSyntheticKeyFromRow(genericResolvedRow, columns, keyCols);
                        }
                    }
                }
                if (key is null && useGenericMixedPkResolver && string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase))
                {
                    var mixedWhere = TryBuildMixedDeleteWhereSqlFromRecord(r, columns, keyCols);
                    if (!string.IsNullOrWhiteSpace(mixedWhere))
                    {
                        var deleteEmitToken = $"{action}|{r.TxId}|{mixedWhere}";
                        if (!emittedByTxKey.Contains(deleteEmitToken))
                        {
                            emittedByTxKey.Add(deleteEmitToken);
                            final.AppendLine($"--DELETE ({r.CurrentLsn})");
                            final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {mixedWhere};");
                            final.AppendLine("GO");
                            final.AppendLine();
                            ok++; del++;
                        }
                        continue;
                    }
                }
                if (key is null)
                {
                    if (!HasAnyRowLog(r) || !HasDbidEvidence(r))
                    {
                        if (EnableDebugEmitTokenLog)
                        {
                            unresolvedAll.AppendLine($"--DEBUG SKIP {action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                            unresolvedAll.AppendLine($"-- reason=no_rowlog_or_dbid");
                            unresolvedAll.AppendLine($"-- tx={r.TxId}; page={r.PageId}; slot={r.SlotId}; context={r.ContextName}; alloc={r.AllocUnitName}");
                            unresolvedAll.AppendLine($"-- rowlog0={r.RowLog0Hex}");
                            unresolvedAll.AppendLine($"-- rowlog1={r.RowLog1Hex}");
                            unresolvedAll.AppendLine($"-- rowlog2={r.RowLog2Hex}");
                            unresolvedAll.AppendLine("GO");
                            unresolvedAll.AppendLine();
                        }
                        skipped++;
                        continue;
                    }
                    var unresolvedTxToken = $"{action}|{r.TxId}";
                    if (unresolvedByTx.Contains(unresolvedTxToken))
                    {
                        continue;
                    }
                    unresolvedByTx.Add(unresolvedTxToken);
                    unresolved++;
                    AddTrustDiagnostic(
                        trustDiagnostics,
                        trustDiagnosticCounts,
                        "key_decode_failed",
                        r,
                        null,
                        TargetSchema,
                        TargetTable,
                        rowFound: false,
                        trusted: false,
                        note: "no usable key survived decode or fallback",
                        sampleLimit: TrustDiagnosticsSampleLimit);
                    unresolvedAll.AppendLine($"--{action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                    unresolvedAll.AppendLine("-- unresolved: key decode failed");
                    unresolvedAll.AppendLine("GO");
                    unresolvedAll.AppendLine();
                    continue;
                }

                string emitToken;
                if (string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase))
                {
                    // INSERT can contain many rows in one transaction. Deduplicate by physical/log identity,
                    // not by tx+key, to avoid collapsing valid multi-row inserts.
                    var phys = TryBuildPhysLoc(r) ?? "";
                    emitToken = $"{action}|{r.CurrentLsn}|{phys}";
                }
                else if (string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase))
                {
                    if (deleteGhostOnlyMode)
                    {
                        // When the selected delete set is ghost-only, there is no clustered companion to collapse
                        // against. In that case physical row identity is safer than tx+decoded-key.
                        var phys = TryBuildPhysLoc(r) ?? "";
                        emitToken = $"{action}|{r.CurrentLsn}|{phys}";
                    }
                    else
                    {
                        // DELETE often produces clustered + ghost companions for the same row.
                        // Deduplicate by transaction + resolved key to keep one user delete per row.
                        emitToken = $"{action}|{r.TxId}|{key}";
                    }
                }
                else
                {
                    // Keep non-INSERT row-granular too; tx+key can collapse valid rows on wide-PK/history tables.
                    emitToken = $"{action}|{r.CurrentLsn}";
                }
                if (emittedByTxKey.Contains(emitToken))
                {
                    if (EnableDebugEmitTokenLog && string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase))
                    {
                        unresolvedAll.AppendLine($"--DEBUG DUP DELETE ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                        unresolvedAll.AppendLine($"-- emit_token={emitToken}");
                        unresolvedAll.AppendLine($"-- tx={r.TxId}; page={r.PageId}; slot={r.SlotId}; context={r.ContextName}; alloc={r.AllocUnitName}");
                        unresolvedAll.AppendLine($"-- rowlog0={r.RowLog0Hex}");
                        unresolvedAll.AppendLine($"-- rowlog1={r.RowLog1Hex}");
                        unresolvedAll.AppendLine($"-- rowlog2={r.RowLog2Hex}");
                        unresolvedAll.AppendLine("GO");
                        unresolvedAll.AppendLine();
                    }
                    continue;
                }
                emittedByTxKey.Add(emitToken);

                object?[]? row = null;
                if (genericResolvedRow is not null)
                {
                    row = genericResolvedRow;
                }
                if (row is null && !string.IsNullOrWhiteSpace(physLoc))
                {
                    rowByPhysLoc.TryGetValue(physLoc!, out row);
                }
                if (row is null)
                {
                    rowByKey.TryGetValue(key.ToString(), out row);
                }
                // Edge case: key decode can produce a syntactically valid but wrong key for some rowlog shapes.
                // If enabled, recover key by physical locator for UPDATE/DELETE when key lookup misses.
                if (row is null
                    && EnablePhysLocLookup
                    && !string.IsNullOrWhiteSpace(physLoc)
                    && (string.Equals(action, "UPDATE", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(action, "DELETE", StringComparison.OrdinalIgnoreCase)))
                {
                    var keyFromPhys = tableConn is null ? null : ResolveKeyByPhysLoc(tableConn, physLoc!, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                    if (keyFromPhys is not null)
                    {
                        key = keyFromPhys;
                        rowByKey.TryGetValue(key.ToString(), out row);
                    }
                }
                if (row is null && string.Equals(action, "UPDATE", StringComparison.OrdinalIgnoreCase))
                {
                    if (!OfflineLogOnlyMode)
                    {
                        var singleFetch = FetchRows(conn, columns, new List<Key> { key }, TargetSchema, TargetTable, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                        if (singleFetch.TryGetValue(key.ToString(), out var fetchedRow))
                        {
                            row = fetchedRow;
                            rowByKey[key.ToString()] = fetchedRow;
                        }
                    }
                }
                if (row is null
                    && string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase)
                    && key is not null
                    && HasThirdKey
                    && !HasFourthKey
                    && tableConn is not null)
                {
                    var resolvedByLeading = ResolveRowByLeadingKeysFromRecord(
                        tableConn,
                        r,
                        columns,
                        TargetSchema,
                        TargetTable,
                        KeyCol1,
                        KeyCol2,
                        KeyCol3!,
                        key.Dbid,
                        key.QuoteId);
                    if (resolvedByLeading.Row is not null && resolvedByLeading.Key is not null)
                    {
                        row = resolvedByLeading.Row;
                        key = resolvedByLeading.Key;
                        rowByKey[key.ToString()] = row;
                    }
                }

                var trustReason = ExplainTrustDecision(key, row is not null);
                var trustedKey = IsTrustedResolvedKey(key, row is not null);
                if (!trustedKey)
                {
                    var unresolvedTxToken = $"{action}|{r.TxId}|UNTRUSTED";
                    if (string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase) && unresolvedByTx.Contains(unresolvedTxToken))
                    {
                        continue;
                    }
                    unresolvedByTx.Add(unresolvedTxToken);
                    unresolved++;
                    AddTrustDiagnostic(
                        trustDiagnostics,
                        trustDiagnosticCounts,
                        trustReason,
                        r,
                        key?.ToString(),
                        TargetSchema,
                        TargetTable,
                        rowFound: row is not null,
                        trusted: false,
                        note: "resolved key failed trust gate",
                        sampleLimit: TrustDiagnosticsSampleLimit);
                    unresolvedAll.AppendLine($"--{action} ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                    unresolvedAll.AppendLine("-- unresolved: decoded PK is incomplete or untrusted");
                    unresolvedAll.AppendLine("GO");
                    unresolvedAll.AppendLine();

                    if (string.Equals(action, "INSERT", StringComparison.OrdinalIgnoreCase))
                    {
                        final.AppendLine($"--INSERT ({r.CurrentLsn})");
                        final.AppendLine("-- unresolved: decoded PK is incomplete or untrusted");
                        final.AppendLine("GO");
                        final.AppendLine();
                    }
                    continue;
                }

                var keySql = WhereKeySql(key, KeyCol1, KeyCol2, KeyCol3, KeyCol4);
                if (row is not null)
                {
                    var fullPkSql = WhereKeySqlFromRow(row, columns, keyCols);
                    if (!string.IsNullOrWhiteSpace(fullPkSql))
                    {
                        keySql = fullPkSql!;
                    }
                }

                switch (action)
                {
                    case "UPDATE":
                        upd++;
                        if (row is null)
                        {
                        if (!HasAnyRowLog(r) || !HasDbidEvidence(r))
                        {
                            skipped++;
                            break;
                        }
                        unresolved++;
                        AddTrustDiagnostic(
                            trustDiagnostics,
                            trustDiagnosticCounts,
                            OfflineLogOnlyMode ? "update_row_materialization_unavailable" : "row_not_found_by_key",
                            r,
                            keySql,
                            TargetSchema,
                            TargetTable,
                            rowFound: false,
                            trusted: true,
                            note: OfflineLogOnlyMode
                                ? "offline_log_only mode does not fetch source rows for update emission"
                                : "trusted key resolved but no row was fetched",
                            sampleLimit: TrustDiagnosticsSampleLimit);
                        unresolvedAll.AppendLine($"--UPDATE ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                        unresolvedAll.AppendLine("-- unresolved: row not found by key");
                        unresolvedAll.AppendLine($"UPDATE {SqlObject(TargetSchema, TargetTable)} SET /* unresolved */ WHERE {keySql};");
                            unresolvedAll.AppendLine("GO");
                            unresolvedAll.AppendLine();
                            break;
                        }
                        if (!EmitCompact) final.AppendLine($"--UPDATE ({r.CurrentLsn})");
                        var emitAsFull = UpdateEmitMode == "full"
                            || (UpdateEmitMode == "hybrid" && (genericResolved || CanEmitHighConfidenceUpdate(r, row, key, physLoc, physLocToKey, keySql)));
                        if (emitAsFull)
                        {
                            if (!EmitCompact) final.AppendLine("-- mode=update_fullrow; confidence=100%");
                            final.AppendLine(BuildUpdateFullRowSql(columns, row, pkNameSet, keySql, normalizedTypes, TargetSchema, TargetTable));
                        }
                        else
                        {
                            if (!EmitCompact) final.AppendLine("-- mode=delete_insert; confidence=not_fullrow_update_safe");
                            final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {keySql};");
                            final.AppendLine(BuildInsertSql(row, insertPrefix, normalizedTypes));
                        }
                        final.AppendLine("GO");
                        if (!EmitCompact) final.AppendLine();
                        ok++;
                        break;
                    case "INSERT":
                        ins++;
                        if (row is null)
                        {
                            // Do not silently skip user INSERTs with decoded key; emit unresolved marker.
                            unresolved++;
                            AddTrustDiagnostic(
                                trustDiagnostics,
                                trustDiagnosticCounts,
                                OfflineLogOnlyMode ? "insert_row_materialization_unavailable" : "row_not_found_by_key",
                                r,
                                keySql,
                                TargetSchema,
                                TargetTable,
                                rowFound: false,
                                trusted: true,
                                note: OfflineLogOnlyMode
                                    ? "offline_log_only mode resolved a key but has no compatible source row to materialize"
                                    : "trusted key resolved but no row was fetched",
                                sampleLimit: TrustDiagnosticsSampleLimit);
                            unresolvedAll.AppendLine($"--INSERT ({r.CurrentLsn}) [{TargetSchema}.{TargetTable}]");
                            unresolvedAll.AppendLine("-- unresolved: row not found by key");
                            unresolvedAll.AppendLine($"-- key: {keySql}");
                            unresolvedAll.AppendLine("GO");
                            unresolvedAll.AppendLine();

                            final.AppendLine($"--INSERT ({r.CurrentLsn})");
                            final.AppendLine($"-- unresolved: row not found by key");
                            final.AppendLine($"-- key: {keySql}");
                            final.AppendLine("GO");
                            final.AppendLine();
                            break;
                        }
                        if (!EmitCompact) final.AppendLine($"--INSERT ({r.CurrentLsn})");
                        final.AppendLine(BuildInsertSql(row, insertPrefix, normalizedTypes));
                        final.AppendLine("GO");
                        if (!EmitCompact) final.AppendLine();
                        ok++;
                        break;
                    case "DELETE":
                        del++;
                        if (!EmitCompact) final.AppendLine($"--DELETE ({r.CurrentLsn})");
                        final.AppendLine($"DELETE FROM {SqlObject(TargetSchema, TargetTable)} WHERE {keySql};");
                        final.AppendLine("GO");
                        if (!EmitCompact) final.AppendLine();
                        ok++;
                        break;
                }
            }

            totalRows += manifest.Count;
            totalOk += ok;
            totalUnresolved += unresolved;
            totalSkipped += skipped;
            totalIns += ins;
            totalUpd += upd;
            totalDel += del;
            emitSw.Stop();
            tableSw.Stop();
            if (!EmitCompact)
            {
                final.AppendLine($"-- Table Summary: total={manifest.Count}; ok={ok}; unresolved={unresolved}; skipped_internal={skipped}; insert={ins}; update={upd}; delete={del}");
                final.AppendLine($"-- Debug: seen_insert={dbgSeenInsert}; insert_key_null={dbgInsertKeyNull}; insert_key_resolved={dbgInsertKeyResolved}");
                final.AppendLine();
            }
            final.AppendLine($"-- Timing: filter_ms={filterSw.ElapsedMilliseconds}; metadata_ms={metadataSw.ElapsedMilliseconds}; prep_ms={prepSw.ElapsedMilliseconds}; fetch_ms={fetchSw.ElapsedMilliseconds}; emit_ms={emitSw.ElapsedMilliseconds}; total_ms={tableSw.ElapsedMilliseconds}");
            if (!EmitCompact) final.AppendLine();
        }

        runSw.Stop();
        var summary = $"-- Summary: total={totalRows}; ok={totalOk}; unresolved={totalUnresolved}; skipped_internal={totalSkipped}; insert={totalIns}; update={totalUpd}; delete={totalDel}";
        var callsSummary = $"-- Live DB Calls: total={CallsFetchPk + CallsFetchKnownDbids + CallsFetchKnownSingleKeys + CallsFetchKnownKeyPairs + CallsFetchKnownKeyTriples + CallsFetchRows + CallsFetchRowsByPhysLoc + CallsResolveByPartial + CallsResolveInsertCandidates + CallsResolveInsertByPhysLoc}; fetch_pk={CallsFetchPk}; fetch_dbid={CallsFetchKnownDbids}; fetch_single_keys={CallsFetchKnownSingleKeys}; fetch_pairs={CallsFetchKnownKeyPairs}; fetch_triples={CallsFetchKnownKeyTriples}; fetch_rows={CallsFetchRows}; fetch_physloc={CallsFetchRowsByPhysLoc}; resolve_partial={CallsResolveByPartial}; resolve_insert_candidates={CallsResolveInsertCandidates}; resolve_insert_physloc={CallsResolveInsertByPhysLoc}";
        var timingSummary = $"-- Timing: manifest_read_ms={manifestReadSw.ElapsedMilliseconds}; total_run_ms={runSw.ElapsedMilliseconds}";
        var header = timingSummary + Environment.NewLine + callsSummary + Environment.NewLine + summary + Environment.NewLine;
        File.WriteAllText(outputPath, header + final.ToString(), Encoding.UTF8);

        var unresolvedPath = Path.ChangeExtension(outputPath, ".unresolved.trn");
        File.WriteAllText(unresolvedPath, unresolvedAll.ToString(), Encoding.UTF8);
        if (!string.IsNullOrWhiteSpace(TrustDiagnosticsPath))
        {
            var trustPayload = new Dictionary<string, object?>
            {
                ["generated_utc"] = DateTime.UtcNow.ToString("O"),
                ["offline_log_only"] = OfflineLogOnlyMode,
                ["manifest_path"] = manifestPath,
                ["metadata_path"] = metadataPath,
                ["output_path"] = outputPath,
                ["summary"] = new Dictionary<string, object?>
                {
                    ["total_rows"] = totalRows,
                    ["ok"] = totalOk,
                    ["unresolved"] = totalUnresolved,
                    ["skipped_internal"] = totalSkipped,
                    ["insert"] = totalIns,
                    ["update"] = totalUpd,
                    ["delete"] = totalDel
                },
                ["diagnostic_reason_counts"] = trustDiagnosticCounts.OrderBy(k => k.Key).ToDictionary(k => k.Key, v => v.Value, StringComparer.OrdinalIgnoreCase),
                ["samples"] = trustDiagnostics
            };
            var trustDir = Path.GetDirectoryName(TrustDiagnosticsPath);
            if (!string.IsNullOrWhiteSpace(trustDir))
                Directory.CreateDirectory(trustDir);
            File.WriteAllText(TrustDiagnosticsPath, JsonSerializer.Serialize(trustPayload, new JsonSerializerOptions { WriteIndented = true }), Encoding.UTF8);
        }

        Console.WriteLine(summary);
        Console.WriteLine(callsSummary);
        Console.WriteLine(timingSummary);
        Console.WriteLine($"Wrote {outputPath}");
        Console.WriteLine($"Wrote {unresolvedPath}");
        if (!string.IsNullOrWhiteSpace(TrustDiagnosticsPath))
            Console.WriteLine($"Wrote {TrustDiagnosticsPath}");
        return 0;
    }

    static DateTime ParseCommit(string? s)
    {
        if (string.IsNullOrWhiteSpace(s)) return DateTime.MinValue;
        if (DateTime.TryParseExact(s, "yyyy/MM/dd HH:mm:ss:fff", CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var d)) return d;
        if (DateTime.TryParse(s, out var x)) return x;
        return DateTime.MinValue;
    }

    static Dictionary<string, string> ParseArgs(string[] args)
    {
        var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < args.Length; i++)
        {
            if (!args[i].StartsWith("--")) continue;
            var k = args[i][2..];
            var v = (i + 1 < args.Length && !args[i + 1].StartsWith("--")) ? args[++i] : "true";
            d[k] = v;
        }
        return d;
    }

    static List<(string Schema, string Table)> ResolveTargets(Dictionary<string, string> arg)
    {
        var list = new List<(string Schema, string Table)>();
        if (arg.TryGetValue("tables", out var tablesCsv) && !string.IsNullOrWhiteSpace(tablesCsv))
        {
            foreach (var t in tablesCsv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var parts = t.Split('.', 2, StringSplitOptions.TrimEntries);
                list.Add(parts.Length == 2 ? (parts[0], parts[1]) : ("dbo", parts[0]));
            }
            if (list.Count == 0)
                throw new InvalidOperationException("Parameter --tables was provided but no table names were parsed.");
            return list;
        }

        if (arg.TryGetValue("schema", out var schema) && arg.TryGetValue("table", out var table) &&
            !string.IsNullOrWhiteSpace(schema) && !string.IsNullOrWhiteSpace(table))
        {
            return new List<(string Schema, string Table)> { (schema, table) };
        }

        throw new InvalidOperationException("Provide either --tables schema.table,... or --schema plus --table.");
    }

    static void ApplyJsonConfigIfProvided(Dictionary<string, string> arg)
    {
        if (!arg.TryGetValue("config", out var path) || string.IsNullOrWhiteSpace(path)) return;
        if (!File.Exists(path)) throw new InvalidOperationException($"Config file not found: {path}");
        var json = File.ReadAllText(path);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        if (root.TryGetProperty("server", out var server) && server.ValueKind == JsonValueKind.String)
            arg["server"] = server.GetString() ?? "";
        if (root.TryGetProperty("database", out var database) && database.ValueKind == JsonValueKind.String)
            arg["database"] = database.GetString() ?? "";
        if (root.TryGetProperty("userId", out var userId))
        {
            if (userId.ValueKind == JsonValueKind.String) arg["sql-user"] = userId.GetString() ?? "";
            else if (userId.ValueKind == JsonValueKind.Null) arg.Remove("sql-user");
        }
        if (root.TryGetProperty("password", out var password))
        {
            if (password.ValueKind == JsonValueKind.String) arg["sql-password"] = password.GetString() ?? "";
            else if (password.ValueKind == JsonValueKind.Null) arg.Remove("sql-password");
        }
        if (root.TryGetProperty("tables", out var tables))
        {
            if (tables.ValueKind == JsonValueKind.Array)
            {
                var arr = new List<string>();
                foreach (var item in tables.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String)
                    {
                        var v = item.GetString();
                        if (!string.IsNullOrWhiteSpace(v)) arr.Add(v!);
                    }
                }
                if (arr.Count > 0) arg["tables"] = string.Join(",", arr);
            }
            else if (tables.ValueKind == JsonValueKind.String)
            {
                arg["tables"] = tables.GetString() ?? "";
            }
        }
    }

    static string? FindLatestFile(string dir, string pattern)
    {
        if (!Directory.Exists(dir)) return null;
        return Directory.GetFiles(dir, pattern)
            .Select(p => new FileInfo(p))
            .OrderByDescending(fi => fi.LastWriteTimeUtc)
            .Select(fi => fi.FullName)
            .FirstOrDefault();
    }

    static string BuildConnString(string server, string database, string? user, string? pass)
    {
        var b = new SqlConnectionStringBuilder
        {
            DataSource = server,
            InitialCatalog = database,
            TrustServerCertificate = true,
            ConnectTimeout = 0
        };
        if (!string.IsNullOrWhiteSpace(user))
        {
            b.UserID = user;
            b.Password = pass ?? "";
            b.IntegratedSecurity = false;
        }
        else
        {
            b.IntegratedSecurity = true;
        }
        return b.ConnectionString;
    }

    static List<ManifestRec> ReadManifest(string path)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var list = new List<ManifestRec>();
        foreach (var r in doc.RootElement.GetProperty("records").EnumerateArray())
        {
            list.Add(new ManifestRec(
                r.GetProperty("action").GetString() ?? "",
                r.GetProperty("current_lsn").GetString() ?? "",
                r.GetProperty("tx_id").GetString() ?? "",
                r.GetProperty("table_name").GetString() ?? "",
                r.GetProperty("schema_name").GetString() ?? "",
                r.TryGetProperty("transaction_name", out var tn) ? tn.GetString() : null,
                r.TryGetProperty("operation_name", out var op) ? op.GetString() : null,
                r.TryGetProperty("context_name", out var ctx) ? ctx.GetString() : null,
                r.TryGetProperty("alloc_unit_name", out var au) ? au.GetString() : null,
                r.TryGetProperty("page_id", out var pg) ? pg.GetString() : null,
                r.TryGetProperty("slot_id", out var sl) && sl.ValueKind is JsonValueKind.Number ? sl.GetInt32() : null,
                r.TryGetProperty("rowlog0_hex", out var rl0) ? rl0.GetString() : null,
                r.TryGetProperty("rowlog1_hex", out var rl1) ? rl1.GetString() : null,
                r.TryGetProperty("rowlog2_hex", out var rl2) ? rl2.GetString() : null,
                r.TryGetProperty("rowlog3_hex", out var rl3) ? rl3.GetString() : null,
                r.TryGetProperty("rowlog4_hex", out var rl4) ? rl4.GetString() : null,
                r.TryGetProperty("rowlog5_hex", out var rl5) ? rl5.GetString() : null,
                r.TryGetProperty("commit_time", out var ct) ? ct.GetString() : null
            ));
        }
        return list;
    }

    static bool IsInternalTransactionName(string? txName)
    {
        if (string.IsNullOrWhiteSpace(txName)) return false;
        var t = txName.Trim();
        if (t.Equals("user_transaction", StringComparison.OrdinalIgnoreCase)) return false;
        return t.Equals("SplitPage", StringComparison.OrdinalIgnoreCase)
            || t.Equals("Deallocate Extent", StringComparison.OrdinalIgnoreCase)
            || t.Equals("GhostCleanupTask", StringComparison.OrdinalIgnoreCase)
            || t.Equals("SORT temporary run storage", StringComparison.OrdinalIgnoreCase)
            || t.Equals("DROPOBJ", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsBaseRowRecord(ManifestRec r, string schema, string table)
    {
        var context = r.ContextName ?? "";
        var op = r.OperationName ?? "";
        var contextUpper = context.ToUpperInvariant();
        var opUpper = op.ToUpperInvariant();

        // INSERT/UPDATE: keep only true base-row contexts.
        if (opUpper == "LOP_INSERT_ROWS" || opUpper == "LOP_MODIFY_ROW" || opUpper == "LOP_MODIFY_COLUMNS")
        {
            return contextUpper == "LCX_CLUSTERED" || contextUpper == "LCX_HEAP";
        }

        // DELETE: keep base-row delete + ghost companion rows.
        // LCX_TEXT_MIX fragments are plentiful on wide-row deletes and usually do not represent
        // distinct user DML, but they do add substantial decode cost.
        if (opUpper == "LOP_DELETE_ROWS")
        {
            return contextUpper == "LCX_CLUSTERED"
                || contextUpper == "LCX_HEAP"
                || contextUpper == "LCX_MARK_AS_GHOST";
        }

        return contextUpper == "LCX_CLUSTERED" || contextUpper == "LCX_HEAP";
    }

    static List<ColumnMeta> ReadColumns(string metadataPath, string schema, string table)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(metadataPath));
        var result = new List<ColumnMeta>();
        foreach (var t in doc.RootElement.GetProperty("tables").EnumerateArray())
        {
            var s = t.GetProperty("schema_name").GetString();
            var n = t.GetProperty("table_name").GetString();
            if (!string.Equals(s, schema, StringComparison.OrdinalIgnoreCase) || !string.Equals(n, table, StringComparison.OrdinalIgnoreCase))
                continue;
            foreach (var c in t.GetProperty("columns").EnumerateArray())
            {
                result.Add(new ColumnMeta(
                    c.GetProperty("column_name").GetString() ?? "",
                    c.GetProperty("data_type").GetString() ?? "",
                    c.GetProperty("column_id").GetInt32(),
                    c.TryGetProperty("is_pk", out var isPk) && isPk.GetBoolean(),
                    c.TryGetProperty("pk_ordinal", out var pkOrd) ? pkOrd.GetInt32() : 0
                ));
            }
            break;
        }
        result.Sort((a,b) => a.ColumnId.CompareTo(b.ColumnId));
        return result;
    }

    static Dictionary<string, Key> BuildTxFallbackKeyMap(List<ManifestRec> rows)
    {
        var txMap = new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase);
        foreach (var g in rows.GroupBy(x => x.TxId, StringComparer.OrdinalIgnoreCase))
        {
            var distinct = new Dictionary<string, Key>(StringComparer.OrdinalIgnoreCase);
            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var r in g)
            {
                var k = DecodeKeyFromRecord(r);
                if (k is null) continue;
                var sk = k.ToString();
                distinct[sk] = k;
                counts[sk] = counts.TryGetValue(sk, out var c) ? c + 1 : 1;
            }
            if (distinct.Count == 1)
            {
                txMap[g.Key] = distinct.Values.First();
                continue;
            }

            if (distinct.Count > 1)
            {
                // For index-heavy records in a single tx, key decode may be noisy.
                // Pick dominant decoded key when it is clearly the majority.
                var best = counts.OrderByDescending(kv => kv.Value).First();
                var decodedTotal = counts.Values.Sum();
                if (best.Value >= 2 && best.Value * 2 > decodedTotal && distinct.TryGetValue(best.Key, out var kbest))
                {
                    txMap[g.Key] = kbest;
                }
            }
        }
        return txMap;
    }

    static Key? DecodeKeyFromRecord(ManifestRec r, bool relaxKnownFilter = false)
    {
        if (IsQuoteLineTarget() && HasThirdKey && !HasFourthKey && KnownThreeKeyTriples.Count > 0)
        {
            var special = DecodeQuoteLineKnownTripleFromRecord(r, relaxKnownFilter);
            if (special is not null) return ValidateDecodedKey(special, relaxKnownFilter);
        }

        var full = DecodeKeyFromHexCandidate(r.RowLog2Hex, relaxKnownFilter)
            ?? DecodeKeyFromHexCandidate(r.RowLog0Hex, relaxKnownFilter)
            ?? DecodeKeyFromHexCandidate(r.RowLog1Hex, relaxKnownFilter)
            ?? DecodeKeyFromHexCandidate(r.RowLog3Hex, relaxKnownFilter)
            ?? DecodeKeyFromHexCandidate(r.RowLog4Hex, relaxKnownFilter)
            ?? DecodeKeyFromHexCandidate(r.RowLog5Hex, relaxKnownFilter);
        if (full is not null) return ValidateDecodedKey(full, relaxKnownFilter);

        // 2-key fallback: QUOTEID can be present in one rowlog fragment while DBID token is present in another.
        if (!HasThirdKey)
        {
            var quoteId = DecodeQuoteIdFromHexCandidate(r.RowLog2Hex)
                ?? DecodeQuoteIdFromHexCandidate(r.RowLog0Hex)
                ?? DecodeQuoteIdFromHexCandidate(r.RowLog1Hex)
                ?? DecodeQuoteIdFromHexCandidate(r.RowLog3Hex)
                ?? DecodeQuoteIdFromHexCandidate(r.RowLog4Hex)
                ?? DecodeQuoteIdFromHexCandidate(r.RowLog5Hex);
            var dbid = ExtractDbidFromRecord(r);
            if (quoteId.HasValue && !string.IsNullOrWhiteSpace(dbid))
            {
                if (!relaxKnownFilter && EnforceKnownPairFilter && KnownTwoKeyPairs.Count > 0 && !KnownTwoKeyPairs.Contains($"{dbid}|{quoteId.Value}"))
                {
                    return null;
                }
                return ValidateDecodedKey(new Key(dbid!, quoteId.Value, null), relaxKnownFilter);
            }
        }

        return null;
    }

    static bool HasAnyRowLog(ManifestRec r)
        => !(string.IsNullOrWhiteSpace(r.RowLog0Hex)
          && string.IsNullOrWhiteSpace(r.RowLog1Hex)
          && string.IsNullOrWhiteSpace(r.RowLog2Hex)
          && string.IsNullOrWhiteSpace(r.RowLog3Hex)
          && string.IsNullOrWhiteSpace(r.RowLog4Hex)
          && string.IsNullOrWhiteSpace(r.RowLog5Hex));

    static bool HasDbidEvidence(ManifestRec r)
    {
        return HasDbidToken(r.RowLog0Hex)
            || HasDbidToken(r.RowLog1Hex)
            || HasDbidToken(r.RowLog2Hex)
            || HasDbidToken(r.RowLog3Hex)
            || HasDbidToken(r.RowLog4Hex)
            || HasDbidToken(r.RowLog5Hex);
    }

    static bool HasDbidToken(string? rowlogHex)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return false;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 2) return false;
        int prefixChars = Math.Min(hex.Length, 1024);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 2) return false;
        try
        {
            var bytes = Convert.FromHexString(hex[..prefixChars]);
            return !string.IsNullOrWhiteSpace(ExtractBestDbidToken(bytes));
        }
        catch
        {
            return false;
        }
    }

    static PartialKey? DecodePartialFromRecord(ManifestRec r)
        => DecodePartialFromHexCandidate(r.RowLog2Hex)
        ?? DecodePartialFromHexCandidate(r.RowLog0Hex)
        ?? DecodePartialFromHexCandidate(r.RowLog1Hex)
        ?? DecodePartialFromHexCandidate(r.RowLog3Hex)
        ?? DecodePartialFromHexCandidate(r.RowLog4Hex)
        ?? DecodePartialFromHexCandidate(r.RowLog5Hex);

    static bool IsQuoteLineTarget()
        => TargetSchema.Equals("oasis", StringComparison.OrdinalIgnoreCase)
        && TargetTable.Equals("CHSC_QUOTELINE", StringComparison.OrdinalIgnoreCase);

    static Key? DecodeQuoteLineKnownTripleFromRecord(ManifestRec r, bool relaxKnownFilter)
    {
        foreach (var h in new[] { r.RowLog2Hex, r.RowLog0Hex, r.RowLog1Hex, r.RowLog3Hex, r.RowLog4Hex, r.RowLog5Hex })
        {
            var k = DecodeQuoteLineKnownTripleFromHexCandidate(h, relaxKnownFilter);
            if (k is not null) return k;
        }
        return null;
    }

    static Key? DecodeQuoteLineKnownTripleFromHexCandidate(string? rowlogHex, bool relaxKnownFilter)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return null;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 18) return null;
        int prefixChars = Math.Min(hex.Length, 4096);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 18) return null;

        byte[] bytes;
        try { bytes = Convert.FromHexString(hex[..prefixChars]); }
        catch { return null; }
        if (bytes.Length < 32) return null;

        var dbid = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
        if ((string.IsNullOrWhiteSpace(dbid) || (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid))) && KnownDbids.Count > 0)
        {
            dbid = NormalizeDbid(FindKnownDbidInBytes(bytes));
        }
        if (string.IsNullOrWhiteSpace(dbid)) return null;
        if (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid)) return null;

        const int bodyStart = 64;
        var qFreq = ExtractUInt32Frequency(bytes, bodyStart, 1_000, 100_000_000);
        var lFreq = ExtractUInt16Frequency(bytes, bodyStart, 0, 100_000);

        if (qFreq.Count == 0 || lFreq.Count == 0) return null;

        var best = default(Key);
        var bestScore = int.MinValue;
        var secondBestScore = int.MinValue;
        var bestQFreq = 0;
        var bestLFreq = 0;
        var found = 0;

        foreach (var q in qFreq.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key).Take(64))
        {
            foreach (var l in lFreq.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key).Take(64))
            {
                var triple = $"{dbid}|{q.Key}|{l.Key}";
                if (!KnownThreeKeyTriples.Contains(triple)) continue;

                var score = (q.Value * 1000) + (l.Value * 100);
                if (q.Key >= 10000) score += 20;
                if (l.Key > 0 && l.Key <= 10000) score += 20;
                if (l.Key <= 5000) score += 10;
                if (score > bestScore)
                {
                    secondBestScore = bestScore;
                    bestScore = score;
                    bestQFreq = q.Value;
                    bestLFreq = l.Value;
                    best = new Key(dbid, q.Key, l.Key);
                }
                else if (score > secondBestScore)
                {
                    secondBestScore = score;
                }
                found++;
            }
        }

        if (found == 0) return null;
        if (!relaxKnownFilter && found > 1)
        {
            if (bestScore <= 0) return null;
            if (bestScore - secondBestScore < 250) return null;
            if (bestQFreq < 2 && bestLFreq < 2) return null;
        }
        return best;
    }

    static Key? DecodeKeyFromHexCandidate(string? rowlogHex, bool relaxKnownFilter = false)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return null;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 18) return null;
        int prefixChars = Math.Min(hex.Length, 4096);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 18) return null;

        byte[] bytes;
        try { bytes = Convert.FromHexString(hex[..prefixChars]); }
        catch { return null; }
        if (bytes.Length < 5) return null;

        Key? best = null;
        int bestTokenLen = int.MaxValue;
        var offsets = new[] { 1, 0, 2, 3, 4 };
        foreach (var off in offsets)
        {
            if (off + 4 >= bytes.Length) continue;
            uint quoteId = BitConverter.ToUInt32(bytes, off);
            if (quoteId == 0 || quoteId > 100_000_000) continue;

            long? lineVal = null;
            long? key4Val = null;
            if (HasThirdKey)
            {
                if (off + 8 >= bytes.Length) continue;
                uint line = BitConverter.ToUInt32(bytes, off + 4);
                if (line > 1_000_000) continue;
                lineVal = line;
            }
            if (HasFourthKey)
            {
                if (off + 12 >= bytes.Length) continue;
                uint extra = BitConverter.ToUInt32(bytes, off + 8);
                if (extra > 10_000_000) continue;
                key4Val = extra;
            }

            var dbid = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
            if ((string.IsNullOrWhiteSpace(dbid) || (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid))) && KnownDbids.Count > 0)
            {
                dbid = NormalizeDbid(FindKnownDbidInBytes(bytes));
            }
            if (string.IsNullOrWhiteSpace(dbid)) continue;
            if (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid)) continue;
            if (!relaxKnownFilter && EnforceKnownPairFilter && !HasThirdKey && KnownTwoKeyPairs.Count > 0 && !KnownTwoKeyPairs.Contains($"{dbid}|{quoteId}")) continue;
            if (!relaxKnownFilter && EnforceKnownPairFilter && HasFourthKey && lineVal.HasValue && key4Val.HasValue && KnownFourKeyQuads.Count > 0 && !KnownFourKeyQuads.Contains($"{dbid}|{quoteId}|{lineVal.Value}|{key4Val.Value}")) continue;
            if (!relaxKnownFilter && EnforceKnownPairFilter && HasThirdKey && !HasFourthKey && lineVal.HasValue && KnownThreeKeyTriples.Count > 0 && !KnownThreeKeyTriples.Contains($"{dbid}|{quoteId}|{lineVal.Value}")) continue;
            if (dbid.Length < bestTokenLen)
            {
                bestTokenLen = dbid.Length;
                best = new Key(dbid, quoteId, lineVal, key4Val);
            }
        }

        if (!HasThirdKey && best is null)
        {
            var dbid = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
            if ((string.IsNullOrWhiteSpace(dbid) || (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid))) && KnownDbids.Count > 0)
            {
                dbid = NormalizeDbid(FindKnownDbidInBytes(bytes));
            }
            if (!string.IsNullOrWhiteSpace(dbid) && (KnownDbids.Count == 0 || KnownDbids.Contains(dbid)))
            {
                foreach (var cand in ExtractNumericCandidates(bytes, 100_000_000))
                {
                    if (cand <= 0 || cand > 100_000_000) continue;
                    if (!relaxKnownFilter && EnforceKnownPairFilter && KnownTwoKeyPairs.Count > 0 && !KnownTwoKeyPairs.Contains($"{dbid}|{cand}")) continue;
                    best = new Key(dbid, cand, null);
                    break;
                }
            }
        }
        if (HasFourthKey && best is null)
        {
            var dbid = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
            if ((string.IsNullOrWhiteSpace(dbid) || (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid))) && KnownDbids.Count > 0)
            {
                dbid = NormalizeDbid(FindKnownDbidInBytes(bytes));
            }
            if (!string.IsNullOrWhiteSpace(dbid) && (KnownDbids.Count == 0 || KnownDbids.Contains(dbid)))
            {
                int limit = Math.Max(0, bytes.Length - 12);
                for (int off = 0; off <= limit; off++)
                {
                    long k2 = BitConverter.ToUInt32(bytes, off);
                    long k3 = BitConverter.ToUInt32(bytes, off + 4);
                    long k4 = BitConverter.ToUInt32(bytes, off + 8);
                    if (k2 <= 0 || k2 > 100_000_000) continue;
                    if (k3 < 0 || k3 > 1_000_000) continue;
                    if (k4 < 0 || k4 > 10_000_000) continue;
                    if (!relaxKnownFilter && EnforceKnownPairFilter && KnownFourKeyQuads.Count > 0 && !KnownFourKeyQuads.Contains($"{dbid}|{k2}|{k3}|{k4}")) continue;
                    best = new Key(dbid, k2, k3, k4);
                    break;
                }
            }
        }
        if (HasThirdKey && !HasFourthKey && best is null)
        {
            var dbid = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
            if ((string.IsNullOrWhiteSpace(dbid) || (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid))) && KnownDbids.Count > 0)
            {
                dbid = NormalizeDbid(FindKnownDbidInBytes(bytes));
            }
            if (!string.IsNullOrWhiteSpace(dbid) && (KnownDbids.Count == 0 || KnownDbids.Contains(dbid)))
            {
                long? bestQ = null;
                long? bestL = null;
                int bestScore = int.MinValue;
                int limit = Math.Max(0, bytes.Length - 8);
                for (int off = 0; off <= limit; off++)
                {
                    long q = BitConverter.ToUInt32(bytes, off);
                    long l = BitConverter.ToUInt32(bytes, off + 4);
                    if (q <= 0 || q > 100_000_000) continue;
                    if (l < 0 || l > 1_000_000) continue;
                    int score = 0;
                    if (q >= 1000) score += 8;
                    if (l <= 100000) score += 5;
                    if (q > l) score += 3;
                    if (q >= 10000) score += 2;
                    if (score > bestScore)
                    {
                        bestScore = score;
                        bestQ = q;
                        bestL = l;
                    }
                }
                if (bestQ.HasValue && bestL.HasValue)
                {
                    if (!relaxKnownFilter && EnforceKnownPairFilter && KnownThreeKeyTriples.Count > 0 && !KnownThreeKeyTriples.Contains($"{dbid}|{bestQ.Value}|{bestL.Value}"))
                    {
                        // keep unresolved here; caller may use other fallback strategies
                    }
                    else
                    {
                    best = new Key(dbid, bestQ.Value, bestL.Value);
                    }
                }
            }
        }
        return best;
    }

    static PartialKey? DecodePartialFromHexCandidate(string? rowlogHex)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return null;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 18) return null;
        int prefixChars = Math.Min(hex.Length, 4096);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 18) return null;

        byte[] bytes;
        try { bytes = Convert.FromHexString(hex[..prefixChars]); }
        catch { return null; }
        if (bytes.Length < 9) return null;

        var offsets = new[] { 1, 0, 2, 3, 4 };
        foreach (var off in offsets)
        {
            if (off + 8 >= bytes.Length) continue;
            uint quoteId = BitConverter.ToUInt32(bytes, off);
            uint line = BitConverter.ToUInt32(bytes, off + 4);
            if (quoteId == 0 || quoteId > 100_000_000 || line > 1_000_000) continue;
            return new PartialKey(quoteId, line);
        }
        return null;
    }

    static long? DecodeQuoteIdFromHexCandidate(string? rowlogHex)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return null;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 10) return null;
        int prefixChars = Math.Min(hex.Length, 256);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 10) return null;

        byte[] bytes;
        try { bytes = Convert.FromHexString(hex[..prefixChars]); }
        catch { return null; }
        if (bytes.Length < 5) return null;

        foreach (var off in new[] { 1, 0, 2, 3, 4 })
        {
            if (off + 4 >= bytes.Length) continue;
            uint quoteId = BitConverter.ToUInt32(bytes, off);
            if (quoteId == 0 || quoteId > 100_000_000) continue;
            return quoteId;
        }
        return null;
    }

    static string? ExtractDbidFromRecord(ManifestRec r)
    {
        return ExtractDbidFromHexCandidate(r.RowLog0Hex)
            ?? ExtractDbidFromHexCandidate(r.RowLog1Hex)
            ?? ExtractDbidFromHexCandidate(r.RowLog2Hex)
            ?? ExtractDbidFromHexCandidate(r.RowLog3Hex)
            ?? ExtractDbidFromHexCandidate(r.RowLog4Hex)
            ?? ExtractDbidFromHexCandidate(r.RowLog5Hex);
    }

    static string? ExtractDbidFromHexCandidate(string? rowlogHex)
    {
        if (string.IsNullOrWhiteSpace(rowlogHex)) return null;
        var hex = rowlogHex!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? rowlogHex[2..] : rowlogHex;
        if (hex.Length < 2) return null;
        int prefixChars = Math.Min(hex.Length, 1024);
        if ((prefixChars & 1) == 1) prefixChars--;
        if (prefixChars < 2) return null;
        try
        {
            var bytes = Convert.FromHexString(hex[..prefixChars]);
            var tok = NormalizeDbid(ExtractBestDbidTokenAnyEncoding(bytes));
            if (!string.IsNullOrWhiteSpace(tok))
            {
                if (KnownDbids.Count == 0 || KnownDbids.Contains(tok)) return tok;
            }
            if (KnownDbids.Count > 0)
            {
                var known = NormalizeDbid(FindKnownDbidInBytes(bytes));
                if (!string.IsNullOrWhiteSpace(known)) return known;
            }
            return null;
        }
        catch
        {
            return null;
        }
    }

    static string? FindKnownDbidInBytes(byte[] bytes)
    {
        if (KnownDbids.Count == 0 || bytes.Length == 0) return null;
        var ascii = Encoding.ASCII.GetString(bytes);
        foreach (var d in KnownDbids)
        {
            if (ascii.IndexOf(d, StringComparison.OrdinalIgnoreCase) >= 0) return d;
        }
        var compact = bytes.Where(b => b != 0x00).ToArray();
        if (compact.Length > 0 && compact.Length != bytes.Length)
        {
            var compactAscii = Encoding.ASCII.GetString(compact);
            foreach (var d in KnownDbids)
            {
                if (compactAscii.IndexOf(d, StringComparison.OrdinalIgnoreCase) >= 0) return d;
            }
        }
        return null;
    }

    static string? NormalizeDbid(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var trimmed = value.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
    }

    static bool IsTrustedResolvedKey(Key? key, bool validatedByRow)
    {
        if (key is null) return false;
        if (string.IsNullOrWhiteSpace(NormalizeDbid(key.Dbid))) return false;
        if (key.QuoteId <= 0) return false;

        if (OfflineLogOnlyMode)
        {
            if (!HasThirdKey && !HasFourthKey) return true;
            if (HasThirdKey && !HasFourthKey) return key.LineNumber.HasValue;
            if (HasFourthKey) return key.LineNumber.HasValue && key.Key4.HasValue;
        }

        if (!HasThirdKey && !HasFourthKey)
        {
            return validatedByRow
                || !EnforceKnownPairFilter
                || KnownTwoKeyPairs.Count == 0
                || KnownTwoKeyPairs.Contains(key.ToString());
        }

        if (HasThirdKey && !HasFourthKey)
        {
            if (!key.LineNumber.HasValue) return false;
            if (key.LineNumber.Value <= 0) return false;
            return validatedByRow
                || KnownThreeKeyTriples.Count == 0
                || KnownThreeKeyTriples.Contains(key.ToString());
        }

        if (HasFourthKey)
        {
            if (!key.LineNumber.HasValue || !key.Key4.HasValue) return false;
            if (key.LineNumber.Value <= 0 || key.Key4.Value <= 0) return false;
            return validatedByRow
                || KnownFourKeyQuads.Count == 0
                || KnownFourKeyQuads.Contains(key.ToString());
        }

        return true;
    }

    static string ExplainTrustDecision(Key? key, bool validatedByRow)
    {
        if (key is null) return "key_null";
        if (string.IsNullOrWhiteSpace(NormalizeDbid(key.Dbid))) return "dbid_missing";
        if (key.QuoteId <= 0) return "quoteid_nonpositive";

        if (OfflineLogOnlyMode)
        {
            if (!HasThirdKey && !HasFourthKey) return "offline_log_only_complete_two_key";
            if (HasThirdKey && !HasFourthKey) return key.LineNumber.HasValue ? "offline_log_only_complete_three_key" : "line_missing";
            if (HasFourthKey) return key.LineNumber.HasValue && key.Key4.HasValue ? "offline_log_only_complete_four_key" : "line_or_key4_missing";
        }

        if (!HasThirdKey && !HasFourthKey)
        {
            if (validatedByRow) return "validated_by_row";
            if (!EnforceKnownPairFilter) return "known_pair_filter_disabled";
            if (KnownTwoKeyPairs.Count == 0) return "known_pair_set_empty";
            return KnownTwoKeyPairs.Contains(key.ToString()) ? "known_pair_match" : "known_pair_miss";
        }

        if (HasThirdKey && !HasFourthKey)
        {
            if (!key.LineNumber.HasValue) return "line_missing";
            if (key.LineNumber.Value <= 0) return "line_nonpositive";
            if (validatedByRow) return "validated_by_row";
            if (KnownThreeKeyTriples.Count == 0) return "known_triple_set_empty";
            return KnownThreeKeyTriples.Contains(key.ToString()) ? "known_triple_match" : "known_triple_miss";
        }

        if (HasFourthKey)
        {
            if (!key.LineNumber.HasValue || !key.Key4.HasValue) return "line_or_key4_missing";
            if (key.LineNumber.Value <= 0 || key.Key4.Value <= 0) return "line_or_key4_nonpositive";
            if (validatedByRow) return "validated_by_row";
            if (KnownFourKeyQuads.Count == 0) return "known_quad_set_empty";
            return KnownFourKeyQuads.Contains(key.ToString()) ? "known_quad_match" : "known_quad_miss";
        }

        return "unknown";
    }

    static void AddTrustDiagnostic(
        List<Dictionary<string, object?>> sink,
        Dictionary<string, int> counts,
        string reason,
        ManifestRec r,
        string? keyText,
        string schema,
        string table,
        bool rowFound,
        bool trusted,
        string? note,
        int sampleLimit)
    {
        counts[reason] = counts.TryGetValue(reason, out var current) ? current + 1 : 1;
        if (sink.Count >= sampleLimit) return;

        sink.Add(new Dictionary<string, object?>
        {
            ["reason"] = reason,
            ["note"] = note,
            ["action"] = r.Action,
            ["current_lsn"] = r.CurrentLsn,
            ["tx_id"] = r.TxId,
            ["schema"] = schema,
            ["table"] = table,
            ["key"] = keyText,
            ["row_found"] = rowFound,
            ["trusted"] = trusted,
            ["offline_log_only"] = OfflineLogOnlyMode,
            ["context_name"] = r.ContextName,
            ["alloc_unit_name"] = r.AllocUnitName,
            ["page_id"] = r.PageId,
            ["slot_id"] = r.SlotId,
            ["has_rowlog"] = HasAnyRowLog(r),
            ["has_dbid_evidence"] = HasDbidEvidence(r)
        });
    }

    static Key? ValidateDecodedKey(Key? key, bool relaxKnownFilter = false)
    {
        if (key is null) return null;

        if (HasThirdKey && !HasFourthKey)
        {
            var line = key.LineNumber.GetValueOrDefault();
            if (line == 0)
            {
                if (KnownThreeKeyTriples.Count > 0)
                {
                    if (!KnownThreeKeyTriples.Contains(key.ToString()))
                        return null;
                }
                else if (!relaxKnownFilter)
                {
                    return null;
                }
            }
        }

        if (HasFourthKey)
        {
            var line = key.LineNumber.GetValueOrDefault();
            var key4 = key.Key4.GetValueOrDefault();
            if ((line == 0 || key4 == 0) && KnownFourKeyQuads.Count > 0)
            {
                if (!KnownFourKeyQuads.Contains(key.ToString()))
                    return null;
            }
        }

        return key;
    }

    static Key? ResolveKeyByPartial(string connStr, PartialKey partial, Dictionary<string, Key?> cache, string schema, string table, string key1, string key2, string? key3)
    {
        if (string.IsNullOrWhiteSpace(key3)) return null;
        var ck = partial.ToString();
        if (cache.TryGetValue(ck, out var cached)) return cached;

        using var conn = new SqlConnection(connStr);
        conn.Open();
        var sql = $@"
SELECT TOP (2) {Q(key1)},{Q(key2)},{Q(key3)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE {Q(key2)}=@q AND {Q(key3)}=@l;";
        using var cmd = new SqlCommand(sql, conn);
        CallsResolveByPartial++;
        cmd.CommandTimeout = 0;
        cmd.Parameters.Add(new SqlParameter("@q", SqlDbType.BigInt) { Value = partial.QuoteId });
        cmd.Parameters.Add(new SqlParameter("@l", SqlDbType.BigInt) { Value = partial.LineNumber });
        using var rd = cmd.ExecuteReader();
        Key? found = null;
        int cnt = 0;
        while (rd.Read())
        {
            cnt++;
            if (cnt == 1)
            {
                found = new Key(
                    rd.IsDBNull(0) ? "" : rd.GetString(0),
                    rd.IsDBNull(1) ? 0 : Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture),
                    rd.IsDBNull(2) ? 0 : Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture)
                );
            }
        }
        if (cnt != 1) found = null;
        cache[ck] = found;
        return found;
    }

    static Dictionary<string, string> BuildTxFallbackSingleKeyMap(List<ManifestRec> manifest, string keyCol, List<ColumnMeta> columns)
    {
        var txMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var g in manifest.GroupBy(r => r.TxId, StringComparer.OrdinalIgnoreCase))
        {
            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var r in g)
            {
                var k = DecodeSingleKeyFromRecord(r, keyCol, columns, KnownSingleKeys);
                if (string.IsNullOrWhiteSpace(k)) continue;
                counts[k] = counts.TryGetValue(k, out var c) ? c + 1 : 1;
            }
            if (counts.Count == 0) continue;
            var best = counts.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key, StringComparer.OrdinalIgnoreCase).First();
            txMap[g.Key] = best.Key;
        }
        return txMap;
    }

    static string? DecodeSingleKeyFromRecord(ManifestRec r, string keyCol, List<ColumnMeta> columns, HashSet<string> knownKeys)
    {
        var keyMeta = columns.FirstOrDefault(c => c.Name.Equals(keyCol, StringComparison.OrdinalIgnoreCase));
        if (keyMeta is null) return null;
        var maxLen = 64;

        if (knownKeys.Count > 0)
        {
            var knownHit = ExtractKnownSingleKeyHitsFromRecord(r, knownKeys)
                .OrderByDescending(kv => kv.Value)
                .ThenBy(kv => kv.Key.Length)
                .Select(kv => kv.Key)
                .FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(knownHit))
            {
                return knownHit;
            }
        }

        var freq = ExtractTextTokenFrequencyFromRecord(r, maxLen);
        if (freq.Count == 0) return null;

        string? best = null;
        int bestScore = int.MinValue;
        foreach (var kv in freq)
        {
            var token = kv.Key;
            if (token.Length > maxLen) continue;
            if (token.Length < 2) continue;
            if (Regex.IsMatch(token, @"^\d+$")) continue;

            int score = kv.Value * 100;
            if (knownKeys.Contains(token)) score += 1000;
            if (Regex.IsMatch(token, @"^[A-Za-z0-9_\-]+$")) score += 25;
            if (Regex.IsMatch(token, @"[A-Za-z]") && Regex.IsMatch(token, @"\d")) score += 20;
            if (token.Length is >= 4 and <= 24) score += 10;
            if (score > bestScore)
            {
                best = token;
                bestScore = score;
            }
        }
        return best;
    }

    static Dictionary<string, int> ExtractKnownSingleKeyHitsFromRecord(ManifestRec r, HashSet<string> knownKeys)
    {
        var freq = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var payload in ExtractAsciiPayloadsFromRecord(r))
        {
            foreach (Match m in Regex.Matches(payload, @"[A-Za-z0-9_\-]{2,96}"))
            {
                var token = m.Value;
                if (string.IsNullOrWhiteSpace(token)) continue;

                if (knownKeys.Contains(token))
                {
                    freq[token] = freq.TryGetValue(token, out var c1) ? c1 + 1 : 1;
                }

                foreach (Match sm in Regex.Matches(token, @"[A-Za-z]{2,}[0-9]{2,}"))
                {
                    var sub = sm.Value;
                    if (string.IsNullOrWhiteSpace(sub)) continue;
                    if (!knownKeys.Contains(sub)) continue;
                    freq[sub] = freq.TryGetValue(sub, out var c2) ? c2 + 1 : 1;
                }
            }
        }
        return freq;
    }

    static Dictionary<string, int> ExtractTextTokenFrequencyFromRecord(ManifestRec r, int maxLen)
    {
        var freq = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var payload in ExtractAsciiPayloadsFromRecord(r))
        {
            foreach (Match m in Regex.Matches(payload, @"[A-Za-z0-9_\-]{2,64}"))
            {
                var token = m.Value;
                if (string.IsNullOrWhiteSpace(token)) continue;
                if (token.Length > maxLen) continue;
                freq[token] = freq.TryGetValue(token, out var c) ? c + 1 : 1;
            }
        }
        return freq;
    }

    static Key? ResolveInsertByCandidates(
        SqlConnection conn,
        ManifestRec r,
        Dictionary<string, Key?> cache,
        string schema,
        string table,
        string key1,
        string key2,
        string? key3)
    {
        var dbid = ExtractDbidFromRecord(r);
        if (string.IsNullOrWhiteSpace(dbid)) return null;
        if (KnownDbids.Count > 0 && !KnownDbids.Contains(dbid)) return null;

        var qFreq = ExtractNumericFrequencyFromRecord(r, 100, 100_000_000);
        var qCands = qFreq.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key).Select(kv => kv.Key).Take(40).ToList();
        if (qCands.Count == 0) return null;

        var lFreq = string.IsNullOrWhiteSpace(key3)
            ? new Dictionary<long, int>()
            : ExtractNumericFrequencyFromRecord(r, 0, 100_000);
        var lCands = string.IsNullOrWhiteSpace(key3)
            ? new List<long>()
            : lFreq.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key).Select(kv => kv.Key).Take(40).ToList();
        if (!string.IsNullOrWhiteSpace(key3) && lCands.Count == 0) return null;

        var cacheKey = string.IsNullOrWhiteSpace(key3)
            ? $"{dbid}|Q:{string.Join(",", qCands)}"
            : $"{dbid}|Q:{string.Join(",", qCands)}|L:{string.Join(",", lCands)}";
        if (cache.TryGetValue(cacheKey, out var cached)) return cached;

        List<Key> rows = QueryInsertCandidateRows(conn, dbid, schema, table, key1, key2, key3, qCands, lCands, 8, 8, 5);
        if (rows.Count != 1)
        {
            rows = QueryInsertCandidateRows(conn, dbid, schema, table, key1, key2, key3, qCands, lCands, 24, 24, 8);
        }
        Key? found = null;
        if (rows.Count == 1)
        {
            found = rows[0];
        }
        else if (rows.Count > 1)
        {
            var ranked = rows
                .Select(k =>
                {
                    var qScore = qFreq.TryGetValue(k.QuoteId, out var qv) ? qv : 0;
                    var lScore = string.IsNullOrWhiteSpace(key3)
                        ? 0
                        : (lFreq.TryGetValue(k.LineNumber ?? -1, out var lv) ? lv : 0);
                    var score = (qScore * 1000) + (lScore * 100) + (int)Math.Min(k.QuoteId, int.MaxValue);
                    return new { Key = k, Score = score };
                })
                .OrderByDescending(x => x.Score)
                .ToList();
            if (ranked.Count > 0)
            {
                if (ranked.Count == 1 || ranked[0].Score > ranked[1].Score)
                {
                    found = ranked[0].Key;
                }
            }
        }
        cache[cacheKey] = found;
        return found;
    }

    static List<Key> QueryInsertCandidateRows(
        SqlConnection conn,
        string dbid,
        string schema,
        string table,
        string key1,
        string key2,
        string? key3,
        List<long> qCands,
        List<long> lCands,
        int qTake,
        int lTake,
        int timeoutSec)
    {
        var qList = string.Join(",", qCands.Take(qTake).Select(v => v.ToString(CultureInfo.InvariantCulture)));
        var sql = string.IsNullOrWhiteSpace(key3)
            ? $@"
SELECT TOP (50) {Q(key1)},{Q(key2)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE {Q(key1)}=@d AND {Q(key2)} IN ({qList});"
            : $@"
SELECT TOP (50) {Q(key1)},{Q(key2)},{Q(key3)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE {Q(key1)}=@d AND {Q(key2)} IN ({qList}) AND {Q(key3)} IN ({string.Join(",", lCands.Take(lTake).Select(v => v.ToString(CultureInfo.InvariantCulture)))});";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = timeoutSec };
        CallsResolveInsertCandidates++;
        cmd.Parameters.Add(new SqlParameter("@d", SqlDbType.NVarChar, 128) { Value = dbid });
        using var rd = cmd.ExecuteReader();
        var rows = new List<Key>();
        while (rd.Read())
        {
            rows.Add(string.IsNullOrWhiteSpace(key3)
                ? new Key(
                    rd.IsDBNull(0) ? "" : Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture) ?? "",
                    rd.IsDBNull(1) ? 0 : Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture),
                    null)
                : new Key(
                    rd.IsDBNull(0) ? "" : Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture) ?? "",
                    rd.IsDBNull(1) ? 0 : Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture),
                    rd.IsDBNull(2) ? 0 : Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture)
                ));
        }
        return rows;
    }

    static (Key? Key, object?[]? Row) ResolveRowByLeadingKeysFromRecord(
        SqlConnection conn,
        ManifestRec r,
        List<ColumnMeta> columns,
        string schema,
        string table,
        string key1,
        string key2,
        string key3,
        string dbid,
        long quoteId)
    {
        var rows = FetchRowsByLeadingKeys(conn, columns, schema, table, key1, key2, dbid, quoteId, 256);
        if (rows.Count == 0) return (null, null);
        if (rows.Count == 1)
        {
            var only = rows[0];
            var onlyKey = BuildKeyFromResolvedRow(only, columns, key1, key2, key3, null);
            return (IsTrustedResolvedKey(onlyKey, validatedByRow: true) ? onlyKey : null, IsTrustedResolvedKey(onlyKey, validatedByRow: true) ? only : null);
        }

        var payloads = ExtractAsciiPayloadsFromRecord(r);
        var numericSet = new HashSet<long>(ExtractNumericCandidatesFromRecord(r, 0, 100_000_000, 512));
        var numericFreq = ExtractNumericFrequencyFromRecord(r, 0, 100_000_000);
        object?[]? bestRow = null;
        int bestScore = int.MinValue;
        int secondScore = int.MinValue;

        foreach (var row in rows)
        {
            var rowKey = BuildKeyFromResolvedRow(row, columns, key1, key2, key3, null);
            if (rowKey is null) continue;
            if (HasThirdKey && !HasFourthKey)
            {
                var line = rowKey.LineNumber.GetValueOrDefault();
                if (line <= 0) continue;
                if (!numericFreq.TryGetValue(line, out var lineHits) || lineHits <= 0) continue;
            }

            var score = ScoreRowAgainstRecord(r, row, columns, payloads, numericSet);
            if (score > bestScore)
            {
                secondScore = bestScore;
                bestScore = score;
                bestRow = row;
            }
            else if (score > secondScore)
            {
                secondScore = score;
            }
        }

        if (bestRow is null) return (null, null);
        if (bestScore <= 0) return (null, null);
        if (rows.Count > 1 && bestScore - secondScore < 80) return (null, null);

        var bestKey = BuildKeyFromResolvedRow(bestRow, columns, key1, key2, key3, null);
        if (!IsTrustedResolvedKey(bestKey, validatedByRow: true)) return (null, null);
        return (bestKey, bestRow);
    }

    static List<object?[]> FetchRowsByLeadingKeys(
        SqlConnection conn,
        List<ColumnMeta> columns,
        string schema,
        string table,
        string key1,
        string key2,
        string dbid,
        long quoteId,
        int topN)
    {
        var rows = new List<object?[]>();
        var sql = $@"
SELECT TOP ({topN}) {string.Join(", ", columns.Select(c => $"t.{Q(c.Name)}"))}
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
WHERE t.{Q(key1)}=@d AND t.{Q(key2)}=@q;";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 15 };
        CallsFetchRows++;
        cmd.Parameters.Add(new SqlParameter("@d", SqlDbType.NVarChar, 128) { Value = dbid });
        cmd.Parameters.Add(new SqlParameter("@q", SqlDbType.BigInt) { Value = quoteId });
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            var row = new object?[columns.Count];
            for (int i = 0; i < columns.Count; i++) row[i] = rd.IsDBNull(i) ? null : rd.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }

    static Key? BuildKeyFromResolvedRow(
        object?[] row,
        List<ColumnMeta> columns,
        string key1,
        string key2,
        string? key3,
        string? key4)
    {
        var idx1 = columns.FindIndex(c => c.Name.Equals(key1, StringComparison.OrdinalIgnoreCase));
        var idx2 = columns.FindIndex(c => c.Name.Equals(key2, StringComparison.OrdinalIgnoreCase));
        if (idx1 < 0 || idx2 < 0) return null;

        var k1 = NormalizeDbid(Convert.ToString(row[idx1], CultureInfo.InvariantCulture)) ?? "";
        if (string.IsNullOrWhiteSpace(k1)) return null;

        long k2;
        try { k2 = Convert.ToInt64(row[idx2], CultureInfo.InvariantCulture); }
        catch { return null; }

        long? k3 = null;
        long? k4 = null;
        if (!string.IsNullOrWhiteSpace(key3))
        {
            var idx3 = columns.FindIndex(c => c.Name.Equals(key3, StringComparison.OrdinalIgnoreCase));
            if (idx3 < 0) return null;
            try { k3 = Convert.ToInt64(row[idx3], CultureInfo.InvariantCulture); }
            catch { return null; }
        }
        if (!string.IsNullOrWhiteSpace(key4))
        {
            var idx4 = columns.FindIndex(c => c.Name.Equals(key4, StringComparison.OrdinalIgnoreCase));
            if (idx4 < 0) return null;
            try { k4 = Convert.ToInt64(row[idx4], CultureInfo.InvariantCulture); }
            catch { return null; }
        }
        return new Key(k1, k2, k3, k4);
    }

    static int ScoreRowAgainstRecord(
        ManifestRec r,
        object?[] row,
        List<ColumnMeta> columns,
        List<string> payloads,
        HashSet<long> numericSet)
    {
        int score = 0;
        for (int i = 0; i < columns.Count && i < row.Length; i++)
        {
            var val = row[i];
            if (val is null || val is DBNull) continue;
            var col = columns[i];
            if (IsIntegralSqlType(col.DataType))
            {
                long n;
                try { n = Convert.ToInt64(val, CultureInfo.InvariantCulture); }
                catch { continue; }
                if (!numericSet.Contains(n)) continue;
                score += col.IsPk ? 50 : 12;
                if (col.Name.Equals(KeyCol3, StringComparison.OrdinalIgnoreCase))
                {
                    if (n > 0) score += 100;
                    if (n is > 0 and <= 10000) score += 40;
                }
            }
            else
            {
                var s = NormalizeDbid(Convert.ToString(val, CultureInfo.InvariantCulture));
                if (string.IsNullOrWhiteSpace(s) || s.Length < 3) continue;
                var hit = payloads.Any(p => p.IndexOf(s, StringComparison.OrdinalIgnoreCase) >= 0);
                if (!hit) continue;
                score += Math.Min(40, s.Length * 2);
                if (col.IsPk) score += 20;
            }
        }
        return score;
    }

    static Key? ResolveKeyByPhysLoc(
        SqlConnection conn,
        string physLoc,
        string schema,
        string table,
        string key1,
        string key2,
        string? key3,
        string? key4)
    {
        var sql = string.IsNullOrWhiteSpace(key3)
            ? $@"
SELECT TOP (1) {Q(key1)},{Q(key2)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%)=@p;"
            : !string.IsNullOrWhiteSpace(key4)
            ? $@"
SELECT TOP (1) {Q(key1)},{Q(key2)},{Q(key3!)},{Q(key4!)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%)=@p;"
            : $@"
SELECT TOP (1) {Q(key1)},{Q(key2)},{Q(key3)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%)=@p;";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 15 };
        CallsResolveInsertByPhysLoc++;
        cmd.Parameters.Add(new SqlParameter("@p", SqlDbType.NVarChar, 64) { Value = physLoc });
        using var rd = cmd.ExecuteReader();
        if (!rd.Read()) return null;
        var k1 = rd.IsDBNull(0) ? "" : Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture) ?? "";
        var k2 = rd.IsDBNull(1) ? 0 : Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture);
        long? k3 = null;
        long? k4 = null;
        if (!string.IsNullOrWhiteSpace(key3))
        {
            k3 = rd.IsDBNull(2) ? 0 : Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture);
        }
        if (!string.IsNullOrWhiteSpace(key4))
        {
            k4 = rd.IsDBNull(3) ? 0 : Convert.ToInt64(rd.GetValue(3), CultureInfo.InvariantCulture);
        }
        return new Key(
            rd.IsDBNull(0) ? "" : Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture) ?? "",
            k2,
            k3,
            k4
        );
    }

    static string? ResolveSingleKeyByPhysLoc(
        string connStr,
        string physLoc,
        string schema,
        string table,
        string key1)
    {
        using var conn = new SqlConnection(connStr);
        conn.Open();
        var sql = $@"
SELECT TOP (1) {Q(key1)}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%)=@p;";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 15 };
        CallsResolveInsertByPhysLoc++;
        cmd.Parameters.Add(new SqlParameter("@p", SqlDbType.NVarChar, 64) { Value = physLoc });
        var v = cmd.ExecuteScalar();
        if (v is null || v is DBNull) return null;
        var s = Convert.ToString(v, CultureInfo.InvariantCulture);
        return string.IsNullOrWhiteSpace(s) ? null : s;
    }

    static List<long> ExtractNumericCandidatesFromRecord(ManifestRec r, long minValue, long maxValue, int maxCount)
    {
        var seen = new HashSet<long>();
        var outVals = new List<long>(maxCount);
        foreach (var h in new[] { r.RowLog2Hex, r.RowLog0Hex, r.RowLog1Hex, r.RowLog3Hex, r.RowLog4Hex, r.RowLog5Hex })
        {
            if (string.IsNullOrWhiteSpace(h)) continue;
            var hex = h!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? h[2..] : h;
            int prefixChars = Math.Min(hex.Length, 4096);
            if ((prefixChars & 1) == 1) prefixChars--;
            if (prefixChars < 8) continue;
            byte[] bytes;
            try { bytes = Convert.FromHexString(hex[..prefixChars]); } catch { continue; }
            foreach (var v in ExtractNumericCandidates(bytes, maxValue))
            {
                if (v < minValue || v > maxValue) continue;
                if (!seen.Add(v)) continue;
                outVals.Add(v);
                if (outVals.Count >= maxCount) return outVals;
            }
        }
        return outVals;
    }

    static Dictionary<long, int> ExtractNumericFrequencyFromRecord(ManifestRec r, long minValue, long maxValue)
    {
        var freq = new Dictionary<long, int>();
        foreach (var h in new[] { r.RowLog2Hex, r.RowLog0Hex, r.RowLog1Hex, r.RowLog3Hex, r.RowLog4Hex, r.RowLog5Hex })
        {
            if (string.IsNullOrWhiteSpace(h)) continue;
            var hex = h!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? h[2..] : h;
            int prefixChars = Math.Min(hex.Length, 4096);
            if ((prefixChars & 1) == 1) prefixChars--;
            if (prefixChars < 8) continue;
            byte[] bytes;
            try { bytes = Convert.FromHexString(hex[..prefixChars]); } catch { continue; }
            int limit = Math.Max(0, bytes.Length - 4);
            for (int off = 0; off <= limit; off++)
            {
                long v = BitConverter.ToUInt32(bytes, off);
                if (v < minValue || v > maxValue) continue;
                freq[v] = freq.TryGetValue(v, out var c) ? c + 1 : 1;
            }
        }
        return freq;
    }

    static Dictionary<long, int> ExtractUInt32Frequency(byte[] bytes, int startOffset, long minValue, long maxValue)
    {
        var freq = new Dictionary<long, int>();
        var from = Math.Max(0, Math.Min(startOffset, bytes.Length));
        var limit = Math.Max(from, bytes.Length - 4);
        for (int off = from; off <= limit; off++)
        {
            long v = BitConverter.ToUInt32(bytes, off);
            if (v < minValue || v > maxValue) continue;
            freq[v] = freq.TryGetValue(v, out var c) ? c + 1 : 1;
        }
        return freq;
    }

    static Dictionary<long, int> ExtractUInt16Frequency(byte[] bytes, int startOffset, long minValue, long maxValue)
    {
        var freq = new Dictionary<long, int>();
        var from = Math.Max(0, Math.Min(startOffset, bytes.Length));
        var limit = Math.Max(from, bytes.Length - 2);
        for (int off = from; off <= limit; off++)
        {
            long v = BitConverter.ToUInt16(bytes, off);
            if (v < minValue || v > maxValue) continue;
            freq[v] = freq.TryGetValue(v, out var c) ? c + 1 : 1;
        }
        return freq;
    }

    static string? ExtractBestDbidToken(byte[] bytes)
    {
        string? dbid = null;
        int bestScore = int.MinValue;
        int bestLen = int.MaxValue;
        int runStart = -1;
        for (int i = 0; i < bytes.Length; i++)
        {
            byte b = bytes[i];
            bool ok = IsKeyTextByte(b);
            if (ok)
            {
                if (runStart < 0) runStart = i;
            }
            else if (runStart >= 0)
            {
                int len = i - runStart;
                if (len >= 6)
                {
                    var t = Encoding.ASCII.GetString(bytes, runStart, len);
                    var s = ScoreDbidToken(t);
                    if (s > bestScore || (s == bestScore && t.Length < bestLen))
                    {
                        bestScore = s;
                        bestLen = t.Length;
                        dbid = t;
                    }
                }
                runStart = -1;
            }
        }
        if (runStart >= 0)
        {
            int len = bytes.Length - runStart;
            if (len >= 6)
            {
                var t = Encoding.ASCII.GetString(bytes, runStart, len);
                var s = ScoreDbidToken(t);
                if (s > bestScore || (s == bestScore && t.Length < bestLen))
                {
                    bestScore = s;
                    bestLen = t.Length;
                    dbid = t;
                }
            }
        }

        return dbid;
    }

    static string? ExtractBestDbidTokenAnyEncoding(byte[] bytes)
    {
        var direct = ExtractBestDbidToken(bytes);
        if (!string.IsNullOrWhiteSpace(direct)) return direct;

        // Some rowlog fragments carry UTF-16LE text; strip NUL bytes and retry token extraction.
        var compact = bytes.Where(b => b != 0x00).ToArray();
        if (compact.Length == 0 || compact.Length == bytes.Length) return direct;
        return ExtractBestDbidToken(compact);
    }

    static bool IsKeyTextByte(byte b)
    {
        // Allow common printable chars seen in key text values (spaces, punctuation, mixed case).
        if (b >= (byte)'0' && b <= (byte)'9') return true;
        if (b >= (byte)'A' && b <= (byte)'Z') return true;
        if (b >= (byte)'a' && b <= (byte)'z') return true;
        return b is (byte)'_' or (byte)' ' or (byte)'+' or (byte)'-' or (byte)'.' or (byte)'&' or (byte)'/' or (byte)'(' or (byte)')' or (byte)'#' or (byte)',' or (byte)':' or (byte)';' or (byte)'@';
    }

    static int ScoreDbidToken(string t)
    {
        if (string.IsNullOrWhiteSpace(t)) return int.MinValue / 2;
        int score = 0;
        if (KnownDbids.Count > 0 && KnownDbids.Contains(t)) score += 1000;
        if (Regex.IsMatch(t, "^[A-Z0-9_]+$")) score += 5;
        if (t.Length is >= 8 and <= 10) score += 10;
        if (Regex.IsMatch(t, @"\d{3}$")) score += 20;
        if (Regex.IsMatch(t, "^[A-Z]{3,}")) score += 5;
        if (t.Contains('_')) score -= 1;
        if (t.Length > 20) score -= 10;
        return score;
    }

    static HashSet<string> FetchKnownDbids(string connStr, string schema, string table, string dbidColumn)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var conn = new SqlConnection(connStr);
        conn.Open();
        using var cmd = new SqlCommand($"SELECT DISTINCT {Q(dbidColumn)} FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED) WHERE {Q(dbidColumn)} IS NOT NULL;", conn)
        {
            CommandTimeout = 0
        };
        CallsFetchKnownDbids++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            if (!rd.IsDBNull(0))
            {
                var v = NormalizeDbid(rd.GetString(0));
                if (!string.IsNullOrWhiteSpace(v)) set.Add(v);
            }
        }
        return set;
    }

    static HashSet<string> FetchKnownTwoKeyPairs(string connStr, string schema, string table, string key1, string key2)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var conn = new SqlConnection(connStr);
        conn.Open();
        using var cmd = new SqlCommand($"SELECT {Q(key1)}, {Q(key2)} FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED);", conn)
        {
            CommandTimeout = 0
        };
        CallsFetchKnownKeyPairs++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            if (rd.IsDBNull(0) || rd.IsDBNull(1)) continue;
            var k1 = NormalizeDbid(Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture)) ?? "";
            if (string.IsNullOrWhiteSpace(k1)) continue;
            var k2 = Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture);
            set.Add($"{k1}|{k2}");
        }
        return set;
    }

    static HashSet<string> FetchKnownSingleKeys(string connStr, string schema, string table, string key1)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var conn = new SqlConnection(connStr);
        conn.Open();
        using var cmd = new SqlCommand($"SELECT DISTINCT {Q(key1)} FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED) WHERE {Q(key1)} IS NOT NULL;", conn)
        {
            CommandTimeout = 0
        };
        CallsFetchKnownSingleKeys++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            if (rd.IsDBNull(0)) continue;
            var k1 = NormalizeDbid(Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture));
            if (string.IsNullOrWhiteSpace(k1)) continue;
            set.Add(k1);
        }
        return set;
    }

    static HashSet<string> FetchKnownThreeKeyTriples(string connStr, string schema, string table, string key1, string key2, string key3)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var conn = new SqlConnection(connStr);
        conn.Open();
        using var cmd = new SqlCommand($"SELECT {Q(key1)}, {Q(key2)}, {Q(key3)} FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED);", conn)
        {
            CommandTimeout = 0
        };
        CallsFetchKnownKeyTriples++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            if (rd.IsDBNull(0) || rd.IsDBNull(1) || rd.IsDBNull(2)) continue;
            var k1 = NormalizeDbid(Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture)) ?? "";
            if (string.IsNullOrWhiteSpace(k1)) continue;
            var k2 = Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture);
            var k3 = Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture);
            set.Add($"{k1}|{k2}|{k3}");
        }
        return set;
    }

    static HashSet<string> FetchKnownFourKeyQuads(string connStr, string schema, string table, string key1, string key2, string key3, string key4)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var conn = new SqlConnection(connStr);
        conn.Open();
        using var cmd = new SqlCommand($"SELECT {Q(key1)}, {Q(key2)}, {Q(key3)}, {Q(key4)} FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED);", conn)
        {
            CommandTimeout = 0
        };
        CallsFetchKnownKeyTriples++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            if (rd.IsDBNull(0) || rd.IsDBNull(1) || rd.IsDBNull(2) || rd.IsDBNull(3)) continue;
            var k1 = NormalizeDbid(Convert.ToString(rd.GetValue(0), CultureInfo.InvariantCulture)) ?? "";
            if (string.IsNullOrWhiteSpace(k1)) continue;
            var k2 = Convert.ToInt64(rd.GetValue(1), CultureInfo.InvariantCulture);
            var k3 = Convert.ToInt64(rd.GetValue(2), CultureInfo.InvariantCulture);
            var k4 = Convert.ToInt64(rd.GetValue(3), CultureInfo.InvariantCulture);
            set.Add($"{k1}|{k2}|{k3}|{k4}");
        }
        return set;
    }

    static List<GenericRowCandidate> FetchGenericRowCandidates(string connStr, List<ColumnMeta> columns, List<string> keyCols, string schema, string table)
    {
        var list = new List<GenericRowCandidate>();
        using var conn = new SqlConnection(connStr);
        conn.Open();
        var sql = $"SELECT {string.Join(", ", columns.Select(c => $"t.[{c.Name}]"))} FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED);";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 0 };
        CallsFetchRows++;
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            var row = new object?[columns.Count];
            for (int c = 0; c < columns.Count; c++) row[c] = rd.IsDBNull(c) ? null : rd.GetValue(c);
            var sb = new StringBuilder();
            var nums = new HashSet<long>();
            foreach (var keyCol in keyCols)
            {
                var idx = columns.FindIndex(c => c.Name.Equals(keyCol, StringComparison.OrdinalIgnoreCase));
                if (idx < 0 || idx >= row.Length) continue;
                var meta = columns[idx];
                var val = row[idx];
                if (val is null || val is DBNull) continue;
                if (IsIntegralSqlType(meta.DataType))
                {
                    nums.Add(Convert.ToInt64(val, CultureInfo.InvariantCulture));
                }
                else
                {
                    sb.Append(Convert.ToString(val, CultureInfo.InvariantCulture));
                }
            }
            list.Add(new GenericRowCandidate(sb.ToString(), nums, row));
        }
        return list;
    }

    static object?[]? ResolveGenericRowFromRecord(ManifestRec r, List<ColumnMeta> columns, List<string> keyCols, List<GenericRowCandidate> candidates)
    {
        var payloads = ExtractAsciiPayloadsFromRecord(r);
        var numericSet = new HashSet<long>(ExtractNumericCandidatesFromRecord(r, 0, 100_000_000, 256));
        var matches = new List<GenericRowCandidate>();
        foreach (var cand in candidates)
        {
            if (cand.NumericValues.Count > 0 && !cand.NumericValues.All(numericSet.Contains))
                continue;
            if (!string.IsNullOrWhiteSpace(cand.StringConcat))
            {
                var stringMatched = payloads.Any(p => p.IndexOf(cand.StringConcat, StringComparison.OrdinalIgnoreCase) >= 0);
                if (!stringMatched) continue;
            }
            matches.Add(cand);
            if (matches.Count > 1)
            {
                // keep collecting; we only accept a unique row
            }
        }
        if (matches.Count == 1)
            return matches[0].Row;
        return null;
    }

    static Key? BuildSyntheticKeyFromRow(object?[] row, List<ColumnMeta> columns, List<string> keyCols)
    {
        if (keyCols.Count < 2) return null;
        var idx1 = columns.FindIndex(c => c.Name.Equals(keyCols[0], StringComparison.OrdinalIgnoreCase));
        var idx2 = columns.FindIndex(c => c.Name.Equals(keyCols[1], StringComparison.OrdinalIgnoreCase));
        if (idx1 < 0 || idx2 < 0) return null;
        var k1 = Convert.ToString(row[idx1], CultureInfo.InvariantCulture) ?? "";
        if (string.IsNullOrWhiteSpace(k1)) return null;
        long k2;
        try { k2 = Convert.ToInt64(row[idx2], CultureInfo.InvariantCulture); }
        catch { k2 = 0; }
        return new Key(k1, k2, null, null);
    }

    static bool IsIntegralSqlType(string dataType)
        => dataType.Equals("tinyint", StringComparison.OrdinalIgnoreCase)
        || dataType.Equals("smallint", StringComparison.OrdinalIgnoreCase)
        || dataType.Equals("int", StringComparison.OrdinalIgnoreCase)
        || dataType.Equals("bigint", StringComparison.OrdinalIgnoreCase);

    static List<string> ExtractAsciiPayloadsFromRecord(ManifestRec r)
    {
        var payloads = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var h in new[] { r.RowLog2Hex, r.RowLog0Hex, r.RowLog1Hex, r.RowLog3Hex, r.RowLog4Hex, r.RowLog5Hex })
        {
            if (string.IsNullOrWhiteSpace(h)) continue;
            var hex = h!.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? h[2..] : h;
            int prefixChars = Math.Min(hex.Length, 4096);
            if ((prefixChars & 1) == 1) prefixChars--;
            if (prefixChars < 2) continue;
            byte[] bytes;
            try { bytes = Convert.FromHexString(hex[..prefixChars]); } catch { continue; }

            var direct = Encoding.ASCII.GetString(bytes);
            if (!string.IsNullOrWhiteSpace(direct)) payloads.Add(direct);

            var compact = bytes.Where(b => b != 0x00).ToArray();
            if (compact.Length > 0)
            {
                var compactAscii = Encoding.ASCII.GetString(compact);
                if (!string.IsNullOrWhiteSpace(compactAscii)) payloads.Add(compactAscii);
            }
        }
        return payloads.ToList();
    }

    static IEnumerable<long> ExtractNumericCandidates(byte[] bytes, long maxValue)
    {
        var seen = new HashSet<long>();
        int limit = Math.Max(0, bytes.Length - 4);
        for (int off = 0; off <= limit; off++)
        {
            long v = BitConverter.ToUInt32(bytes, off);
            if (v <= 0 || v > maxValue) continue;
            if (seen.Add(v)) yield return v;
        }
    }

    static List<string> FetchPkColumnsFromDb(string connStr, string schema, string table)
    {
        var list = new List<(int Ordinal, string Name)>();
        using var conn = new SqlConnection(connStr);
        conn.Open();
        var sql = @"
SELECT ic.key_ordinal, c.name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
WHERE s.name = @schema AND t.name = @table
ORDER BY ic.key_ordinal;";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 0 };
        CallsFetchPk++;
        cmd.Parameters.Add(new SqlParameter("@schema", SqlDbType.NVarChar, 128) { Value = schema });
        cmd.Parameters.Add(new SqlParameter("@table", SqlDbType.NVarChar, 128) { Value = table });
        using var rd = cmd.ExecuteReader();
        while (rd.Read())
        {
            var ord = rd.IsDBNull(0) ? 0 : Convert.ToInt32(rd.GetValue(0), CultureInfo.InvariantCulture);
            var name = rd.IsDBNull(1) ? "" : rd.GetString(1);
            if (!string.IsNullOrWhiteSpace(name))
            {
                list.Add((ord, name));
            }
        }
        return list.OrderBy(x => x.Ordinal).Select(x => x.Name).ToList();
    }

    static Dictionary<string, object?[]> FetchRows(string connStr, List<ColumnMeta> columns, List<Key> keys, string schema, string table, string key1, string key2, string? key3, string? key4)
    {
        var map = new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase);
        if (keys.Count == 0) return map;
        var keyIdx1 = columns.FindIndex(c => c.Name.Equals(key1, StringComparison.OrdinalIgnoreCase));
        var keyIdx2 = columns.FindIndex(c => c.Name.Equals(key2, StringComparison.OrdinalIgnoreCase));
        var keyIdx3 = string.IsNullOrWhiteSpace(key3) ? -1 : columns.FindIndex(c => c.Name.Equals(key3, StringComparison.OrdinalIgnoreCase));
        var keyIdx4 = string.IsNullOrWhiteSpace(key4) ? -1 : columns.FindIndex(c => c.Name.Equals(key4, StringComparison.OrdinalIgnoreCase));

        var colSql = string.Join(", ", columns.Select(c => $"t.[{c.Name}]"));
        using var conn = new SqlConnection(connStr);
        conn.Open();

        const int chunk = 1000;
        for (int i = 0; i < keys.Count; i += chunk)
        {
            var take = Math.Min(chunk, keys.Count - i);
            var vals = new StringBuilder();
            for (int j = 0; j < take; j++)
            {
                var k = keys[i + j];
                if (j > 0) vals.Append(',');
                vals.Append("('").Append(k.Dbid.Replace("'", "''")).Append("',")
                    .Append(k.QuoteId.ToString(CultureInfo.InvariantCulture));
                if (!string.IsNullOrWhiteSpace(key3))
                {
                    vals.Append(',').Append((k.LineNumber ?? 0).ToString(CultureInfo.InvariantCulture));
                }
                if (!string.IsNullOrWhiteSpace(key4))
                {
                    vals.Append(',').Append((k.Key4 ?? 0).ToString(CultureInfo.InvariantCulture));
                }
                vals.Append(')');
            }

            var sql = string.IsNullOrWhiteSpace(key3)
                ? $@"
SELECT {colSql}
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
JOIN (VALUES {vals}) v({Q(key1)},{Q(key2)})
  ON t.{Q(key1)}=v.{Q(key1)} AND t.{Q(key2)}=v.{Q(key2)};"
                : !string.IsNullOrWhiteSpace(key4)
                ? $@"
SELECT {colSql}
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
JOIN (VALUES {vals}) v({Q(key1)},{Q(key2)},{Q(key3!)},{Q(key4)})
  ON t.{Q(key1)}=v.{Q(key1)} AND t.{Q(key2)}=v.{Q(key2)} AND t.{Q(key3!)}=v.{Q(key3!)} AND t.{Q(key4)}=v.{Q(key4)};"
                : $@"
SELECT {colSql}
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
JOIN (VALUES {vals}) v({Q(key1)},{Q(key2)},{Q(key3)})
  ON t.{Q(key1)}=v.{Q(key1)} AND t.{Q(key2)}=v.{Q(key2)} AND t.{Q(key3)}=v.{Q(key3)};";

            using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 0 };
            CallsFetchRows++;
            using var rd = cmd.ExecuteReader();
            while (rd.Read())
            {
                var row = new object?[columns.Count];
                for (int c = 0; c < columns.Count; c++) row[c] = rd.IsDBNull(c) ? null : rd.GetValue(c);
                var key = BuildKeyFromRow(columns, row, key1, key2, key3, key4, keyIdx1, keyIdx2, keyIdx3, keyIdx4);
                if (key is not null) map[key.ToString()] = row;
            }
        }
        return map;
    }

    static Dictionary<string, object?[]> FetchRowsBySingleKey(string connStr, List<ColumnMeta> columns, List<string> keys, string schema, string table, string key1)
    {
        var map = new Dictionary<string, object?[]>(StringComparer.OrdinalIgnoreCase);
        if (keys.Count == 0) return map;
        var keyIdx = columns.FindIndex(c => c.Name.Equals(key1, StringComparison.OrdinalIgnoreCase));
        if (keyIdx < 0) return map;

        var colSql = string.Join(", ", columns.Select(c => $"t.[{c.Name}]"));
        using var conn = new SqlConnection(connStr);
        conn.Open();

        const int chunk = 600;
        for (int i = 0; i < keys.Count; i += chunk)
        {
            var part = keys.Skip(i).Take(chunk).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            if (part.Count == 0) continue;
            var vals = string.Join(",", part.Select(v => $"('{v.Replace("'", "''")}')"));
            var sql = $@"
SELECT {colSql}
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
JOIN (VALUES {vals}) v({Q(key1)})
  ON t.{Q(key1)}=v.{Q(key1)};";
            using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 0 };
            CallsFetchRows++;
            using var rd = cmd.ExecuteReader();
            while (rd.Read())
            {
                var row = new object?[columns.Count];
                for (int c = 0; c < columns.Count; c++) row[c] = rd.IsDBNull(c) ? null : rd.GetValue(c);
                var k = Convert.ToString(row[keyIdx], CultureInfo.InvariantCulture);
                if (string.IsNullOrWhiteSpace(k)) continue;
                map[k] = row;
            }
        }
        return map;
    }

    static object?[]? FetchRowBySingleKey(string connStr, List<ColumnMeta> columns, string keyValue, string schema, string table, string key1)
    {
        var colSql = string.Join(", ", columns.Select(c => $"[{c.Name}]"));
        using var conn = new SqlConnection(connStr);
        conn.Open();
        var sql = $@"
SELECT TOP (1) {colSql}
FROM {SqlObject(schema, table)} WITH (READUNCOMMITTED)
WHERE {Q(key1)} = @k;";
        using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 15 };
        CallsFetchRows++;
        cmd.Parameters.Add(new SqlParameter("@k", SqlDbType.NVarChar, 256) { Value = keyValue });
        using var rd = cmd.ExecuteReader();
        if (!rd.Read()) return null;
        var row = new object?[columns.Count];
        for (int c = 0; c < columns.Count; c++) row[c] = rd.IsDBNull(c) ? null : rd.GetValue(c);
        return row;
    }

    static void FetchRowsByPhysLoc(
        string connStr,
        List<ColumnMeta> columns,
        List<string> physLocs,
        string schema,
        string table,
        string key1,
        string key2,
        string? key3,
        string? key4,
        Dictionary<string, object?[]> rowByPhysLoc,
        Dictionary<string, Key> keyByPhysLoc)
    {
        if (physLocs.Count == 0) return;
        var colSql = string.Join(", ", columns.Select(c => $"t.[{c.Name}]"));
        using var conn = new SqlConnection(connStr);
        conn.Open();

        var keyIdx1 = columns.FindIndex(c => c.Name.Equals(key1, StringComparison.OrdinalIgnoreCase));
        var keyIdx2 = columns.FindIndex(c => c.Name.Equals(key2, StringComparison.OrdinalIgnoreCase));
        var keyIdx3 = string.IsNullOrWhiteSpace(key3) ? -1 : columns.FindIndex(c => c.Name.Equals(key3, StringComparison.OrdinalIgnoreCase));
        var keyIdx4 = string.IsNullOrWhiteSpace(key4) ? -1 : columns.FindIndex(c => c.Name.Equals(key4, StringComparison.OrdinalIgnoreCase));

        const int chunk = 400;
        for (int i = 0; i < physLocs.Count; i += chunk)
        {
            var take = Math.Min(chunk, physLocs.Count - i);
            var vals = new StringBuilder();
            for (int j = 0; j < take; j++)
            {
                if (j > 0) vals.Append(',');
                vals.Append('\'').Append(physLocs[i + j].Replace("'", "''")).Append('\'');
            }

            var sql = $@"
SELECT {colSql}, sys.fn_PhysLocFormatter(%%physloc%%) AS _physloc
FROM {SqlObject(schema, table)} t WITH (READUNCOMMITTED)
WHERE sys.fn_PhysLocFormatter(%%physloc%%) IN ({vals});";

            try
            {
                using var cmd = new SqlCommand(sql, conn) { CommandTimeout = 0 };
                CallsFetchRowsByPhysLoc++;
                using var rd = cmd.ExecuteReader();
                while (rd.Read())
                {
                    var row = new object?[columns.Count];
                    for (int c = 0; c < columns.Count; c++) row[c] = rd.IsDBNull(c) ? null : rd.GetValue(c);
                    var phys = rd.IsDBNull(columns.Count) ? null : rd.GetString(columns.Count);
                    if (string.IsNullOrWhiteSpace(phys)) continue;

                    var key = BuildKeyFromRow(columns, row, key1, key2, key3, key4, keyIdx1, keyIdx2, keyIdx3, keyIdx4);
                    if (key is null) continue;
                    rowByPhysLoc[phys] = row;
                    keyByPhysLoc[phys] = key;
                }
            }
            catch
            {
                // Non-fatal: continue without physloc fallback on servers that don't expose this function.
                break;
            }
        }
    }

    static Key? BuildKeyFromRow(
        List<ColumnMeta> columns,
        object?[] row,
        string key1,
        string key2,
        string? key3,
        string? key4,
        int keyIdx1,
        int keyIdx2,
        int keyIdx3,
        int keyIdx4)
    {
        if (keyIdx1 < 0 || keyIdx2 < 0) return null;
        if (row.Length <= keyIdx2) return null;
        var k1 = Convert.ToString(row[keyIdx1], CultureInfo.InvariantCulture) ?? "";
        if (string.IsNullOrWhiteSpace(k1)) return null;
        var k2 = Convert.ToInt64(row[keyIdx2] ?? 0, CultureInfo.InvariantCulture);
        long? k3 = null;
        long? k4 = null;
        if (!string.IsNullOrWhiteSpace(key3))
        {
            if (keyIdx3 < 0 || row.Length <= keyIdx3) return null;
            k3 = Convert.ToInt64(row[keyIdx3] ?? 0, CultureInfo.InvariantCulture);
        }
        if (!string.IsNullOrWhiteSpace(key4))
        {
            if (keyIdx4 < 0 || row.Length <= keyIdx4) return null;
            k4 = Convert.ToInt64(row[keyIdx4] ?? 0, CultureInfo.InvariantCulture);
        }
        return new Key(k1, k2, k3, k4);
    }

    static string? TryBuildPhysLoc(ManifestRec r)
    {
        if (string.IsNullOrWhiteSpace(r.PageId) || !r.SlotId.HasValue) return null;
        var parts = r.PageId.Split(':', StringSplitOptions.TrimEntries);
        if (parts.Length != 2) return null;
        if (!int.TryParse(parts[0], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var fileId)) return null;
        if (!int.TryParse(parts[1], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var pageId)) return null;
        return $"({fileId}:{pageId}:{r.SlotId.Value})";
    }

    static string WhereKeySql(Key k, string key1, string key2, string? key3, string? key4)
    {
        var baseSql = $"{Q(key1)} = '{k.Dbid.Replace("'", "''")}' AND {Q(key2)} = {k.QuoteId.ToString(CultureInfo.InvariantCulture)}";
        if (!string.IsNullOrWhiteSpace(key3))
        {
            baseSql += $" AND {Q(key3)} = {(k.LineNumber ?? 0).ToString(CultureInfo.InvariantCulture)}";
        }
        if (!string.IsNullOrWhiteSpace(key4))
        {
            baseSql += $" AND {Q(key4)} = {(k.Key4 ?? 0).ToString(CultureInfo.InvariantCulture)}";
        }
        return baseSql;
    }

    static string WhereSingleKeySql(string keyValue, string keyCol, List<ColumnMeta> columns)
    {
        var meta = columns.FirstOrDefault(c => c.Name.Equals(keyCol, StringComparison.OrdinalIgnoreCase));
        var lit = ToSqlLiteral(keyValue, meta?.DataType?.ToLowerInvariant() ?? "varchar");
        if (string.Equals(lit, "NULL", StringComparison.OrdinalIgnoreCase))
            return $"{Q(keyCol)} IS NULL";
        return $"{Q(keyCol)} = {lit}";
    }

    static string? WhereKeySqlFromRow(object?[] row, List<ColumnMeta> columns, List<string> keyCols)
    {
        if (keyCols.Count == 0) return null;
        var predicates = new List<string>(keyCols.Count);
        foreach (var keyCol in keyCols)
        {
            var idx = columns.FindIndex(c => c.Name.Equals(keyCol, StringComparison.OrdinalIgnoreCase));
            if (idx < 0 || idx >= row.Length) return null;
            var meta = columns[idx];
            var lit = ToSqlLiteral(row[idx], meta.DataType);
            if (string.Equals(lit, "NULL", StringComparison.OrdinalIgnoreCase))
            {
                predicates.Add($"{Q(keyCol)} IS NULL");
            }
            else
            {
                predicates.Add($"{Q(keyCol)} = {lit}");
            }
        }
        return string.Join(" AND ", predicates);
    }

    static string? TryBuildMixedDeleteWhereSqlFromRecord(ManifestRec r, List<ColumnMeta> columns, List<string> keyCols)
    {
        if (keyCols.Count == 0) return null;
        var predicates = new List<string>(keyCols.Count);

        var dbid = ExtractDbidFromRecord(r);
        var quoteId = DecodeQuoteIdFromHexCandidate(r.RowLog2Hex)
            ?? DecodeQuoteIdFromHexCandidate(r.RowLog0Hex)
            ?? DecodeQuoteIdFromHexCandidate(r.RowLog1Hex)
            ?? DecodeQuoteIdFromHexCandidate(r.RowLog3Hex)
            ?? DecodeQuoteIdFromHexCandidate(r.RowLog4Hex)
            ?? DecodeQuoteIdFromHexCandidate(r.RowLog5Hex);

        var stringCandidates = ExtractStringCandidatesFromRecord(r);

        foreach (var keyCol in keyCols)
        {
            var meta = columns.FirstOrDefault(c => c.Name.Equals(keyCol, StringComparison.OrdinalIgnoreCase));
            if (meta is null) return null;
            var dt = meta.DataType.ToLowerInvariant();
            object? value = null;

            if (IsIntegralSqlType(dt))
            {
                value = quoteId;
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(dbid) && keyCol.Equals(keyCols[0], StringComparison.OrdinalIgnoreCase))
                {
                    value = dbid;
                }
                else
                {
                    var cand = stringCandidates
                        .Where(s => !string.IsNullOrWhiteSpace(s))
                        .Where(s => string.IsNullOrWhiteSpace(dbid) || !s.Equals(dbid, StringComparison.OrdinalIgnoreCase))
                        .Where(s => s.Length is >= 3 and <= 32)
                        .Where(s => Regex.IsMatch(s, @"[A-Za-z]") && Regex.IsMatch(s, @"\d"))
                        .OrderByDescending(s => s.Length)
                        .FirstOrDefault();
                    value = cand;
                }
            }

            if (value is null) return null;
            var lit = ToSqlLiteral(value, dt);
            if (string.Equals(lit, "NULL", StringComparison.OrdinalIgnoreCase))
                predicates.Add($"{Q(keyCol)} IS NULL");
            else
                predicates.Add($"{Q(keyCol)} = {lit}");
        }
        return predicates.Count == keyCols.Count ? string.Join(" AND ", predicates) : null;
    }

    static List<string> ExtractStringCandidatesFromRecord(ManifestRec r)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var payload in ExtractAsciiPayloadsFromRecord(r))
        {
            foreach (Match m in Regex.Matches(payload, @"[A-Za-z0-9_\-]{2,96}"))
            {
                var token = m.Value;
                if (string.IsNullOrWhiteSpace(token)) continue;
                set.Add(token);
                foreach (Match sm in Regex.Matches(token, @"[A-Za-z]{2,}[0-9]{2,}"))
                {
                    var sub = sm.Value;
                    if (string.IsNullOrWhiteSpace(sub)) continue;
                    set.Add(sub);
                }
            }
        }
        return set.ToList();
    }

    static string BuildInsertSql(object?[] row, string insertPrefix, string[] normalizedTypes)
    {
        var valSb = new StringBuilder();
        for (int i = 0; i < row.Length; i++)
        {
            if (i > 0) valSb.Append(", ");
            valSb.Append(ToSqlLiteral(row[i], normalizedTypes[i]));
        }
        return insertPrefix + valSb + ");";
    }

    static string BuildUpdateFullRowSql(
        List<ColumnMeta> columns,
        object?[] row,
        HashSet<string> pkNameSet,
        string keySql,
        string[] normalizedTypes,
        string schema,
        string table)
    {
        var setSb = new StringBuilder();
        var wroteAny = false;
        for (int i = 0; i < columns.Count; i++)
        {
            if (pkNameSet.Contains(columns[i].Name)) continue;
            if (wroteAny) setSb.Append(", ");
            setSb.Append(Q(columns[i].Name))
                .Append(" = ")
                .Append(ToSqlLiteral(row[i], normalizedTypes[i]));
            wroteAny = true;
        }
        if (!wroteAny)
        {
            return $"-- no-op: no non-PK columns available for UPDATE WHERE {keySql};";
        }
        return $"UPDATE {SqlObject(schema, table)} SET {setSb} WHERE {keySql};";
    }

    static bool CanEmitHighConfidenceUpdate(
        ManifestRec r,
        object?[] row,
        Key key,
        string? physLoc,
        Dictionary<string, Key> physLocToKey,
        string keySql)
    {
        if (row is null) return false;
        if (string.IsNullOrWhiteSpace(keySql)) return false;

        // High-confidence gate:
        // 1. key decoded directly from rowlog, or
        // 2. physical row locator already mapped to a key in the prefetched row map.
        // Excludes expensive late fallback lookups.
        var directKey = DecodeKeyFromRecord(r);
        if (directKey is not null && directKey.ToString().Equals(key.ToString(), StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
        if (!string.IsNullOrWhiteSpace(physLoc)
            && physLocToKey.TryGetValue(physLoc!, out var physKey)
            && physKey.ToString().Equals(key.ToString(), StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
        return false;
    }

    static string ToSqlLiteral(object? value, string dataType)
    {
        if (value is null || value is DBNull) return "NULL";
        return dataType switch
        {
            "varchar" or "char" or "text" => $"'{value.ToString()!.Replace("'", "''")}'",
            "nvarchar" or "nchar" or "ntext" => $"N'{value.ToString()!.Replace("'", "''")}'",
            "datetime" or "smalldatetime" or "datetime2" => value is DateTime dt
                ? $"'{dt:yyyy-MM-dd HH:mm:ss.fffffff}'"
                : $"'{Convert.ToDateTime(value, CultureInfo.InvariantCulture):yyyy-MM-dd HH:mm:ss.fffffff}'",
            "date" => value is DateTime dd
                ? $"'{dd:yyyy-MM-dd}'"
                : $"'{Convert.ToDateTime(value, CultureInfo.InvariantCulture):yyyy-MM-dd}'",
            "time" => $"'{value}'",
            "bit" => value switch
            {
                bool b => b ? "1" : "0",
                byte b => b == 0 ? "0" : "1",
                short s => s == 0 ? "0" : "1",
                int i => i == 0 ? "0" : "1",
                long l => l == 0 ? "0" : "1",
                _ => (Convert.ToBoolean(value, CultureInfo.InvariantCulture) ? "1" : "0")
            },
            "tinyint" or "smallint" or "int" or "bigint" => value switch
            {
                byte v => v.ToString(CultureInfo.InvariantCulture),
                short v => v.ToString(CultureInfo.InvariantCulture),
                int v => v.ToString(CultureInfo.InvariantCulture),
                long v => v.ToString(CultureInfo.InvariantCulture),
                sbyte v => v.ToString(CultureInfo.InvariantCulture),
                ushort v => v.ToString(CultureInfo.InvariantCulture),
                uint v => v.ToString(CultureInfo.InvariantCulture),
                ulong v => v.ToString(CultureInfo.InvariantCulture),
                _ => Convert.ToInt64(value, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture)
            },
            "decimal" or "numeric" or "money" or "smallmoney" => value switch
            {
                decimal v => v.ToString(CultureInfo.InvariantCulture),
                _ => Convert.ToDecimal(value, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture)
            },
            "float" or "real" => value switch
            {
                float v => v.ToString("R", CultureInfo.InvariantCulture),
                double v => v.ToString("R", CultureInfo.InvariantCulture),
                _ => Convert.ToDouble(value, CultureInfo.InvariantCulture).ToString("R", CultureInfo.InvariantCulture)
            },
            "uniqueidentifier" => $"'{value}'",
            _ => $"'{value.ToString()!.Replace("'", "''")}'"
        };
    }

    static string Q(string name) => "[" + name.Replace("]", "]]") + "]";

    static string SqlObject(string schema, string table) => $"{Q(schema)}.{Q(table)}";
}

