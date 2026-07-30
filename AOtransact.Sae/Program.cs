using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

var argsMap = ParseArgs(args);
if (!argsMap.TryGetValue("config", out var configPath) || string.IsNullOrWhiteSpace(configPath))
{
    Console.Error.WriteLine("Required: --config <sae.config.json> [--input <logfile>] [--manifest-output <file>] [--trn-output <file>]");
    return 2;
}

configPath = Path.GetFullPath(configPath, Environment.CurrentDirectory);
if (!File.Exists(configPath))
{
    Console.Error.WriteLine($"Config not found: {configPath}");
    return 2;
}

var jsonOptions = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    ReadCommentHandling = JsonCommentHandling.Skip,
    AllowTrailingCommas = true,
    WriteIndented = true,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
};

var config = JsonSerializer.Deserialize<ExtractorConfig>(File.ReadAllText(configPath), jsonOptions)
    ?? throw new InvalidOperationException($"Failed to parse config: {configPath}");

var resolvedInputPath = argsMap.TryGetValue("input", out var inputArg)
    ? ResolvePathFromCurrentDirectory(inputArg)
    : ResolvePathFromConfig(config.InputPath, configPath);
if (string.IsNullOrWhiteSpace(resolvedInputPath) || !File.Exists(resolvedInputPath))
{
    throw new FileNotFoundException("Input log file not found.", resolvedInputPath);
}

var manifestOutputPath = (argsMap.TryGetValue("manifest-output", out var manifestArg)
    ? ResolvePathFromCurrentDirectory(manifestArg)
    : ResolvePathFromConfig(config.ManifestOutputPath, configPath))
    ?? throw new InvalidOperationException("Manifest output path is required.");
var trnOutputPath = argsMap.TryGetValue("trn-output", out var trnArg)
    ? ResolvePathFromCurrentDirectory(trnArg)
    : ResolvePathFromConfig(config.TrnOutputPath, configPath);

Directory.CreateDirectory(Path.GetDirectoryName(manifestOutputPath)!);
if (!string.IsNullOrWhiteSpace(trnOutputPath))
{
    Directory.CreateDirectory(Path.GetDirectoryName(trnOutputPath)!);
}

var extractor = new RegexLogExtractor(config);
var result = extractor.Extract(resolvedInputPath);

await File.WriteAllTextAsync(
    manifestOutputPath,
    JsonSerializer.Serialize(result.Manifest, jsonOptions) + Environment.NewLine,
    Encoding.UTF8);

if (!string.IsNullOrWhiteSpace(trnOutputPath))
{
    await File.WriteAllLinesAsync(trnOutputPath, result.TrnLines, Encoding.UTF8);
}

Console.WriteLine($"Input: {resolvedInputPath}");
Console.WriteLine($"Manifest rows: {result.Manifest.RecordCount}");
Console.WriteLine($"Transactions: {result.Manifest.TransactionCount}");
Console.WriteLine($"Manifest output: {manifestOutputPath}");
if (!string.IsNullOrWhiteSpace(trnOutputPath))
{
    Console.WriteLine($"TRN output: {trnOutputPath}");
}
if (result.UnmatchedLineCount > 0)
{
    Console.WriteLine($"Skipped unmatched lines: {result.UnmatchedLineCount}");
}

return 0;

static Dictionary<string, string> ParseArgs(string[] args)
{
    var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < args.Length; i++)
    {
        var raw = args[i];
        if (!raw.StartsWith("--", StringComparison.Ordinal))
        {
            continue;
        }

        var key = raw[2..];
        var value = "true";
        if ((i + 1) < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
        {
            value = args[++i];
        }
        map[key] = value;
    }

    return map;
}

static string? ResolvePathFromCurrentDirectory(string? path)
{
    if (string.IsNullOrWhiteSpace(path))
    {
        return null;
    }

    return Path.IsPathRooted(path)
        ? path
        : Path.GetFullPath(path, Environment.CurrentDirectory);
}

static string? ResolvePathFromConfig(string? path, string configPath)
{
    if (string.IsNullOrWhiteSpace(path))
    {
        return null;
    }

    if (Path.IsPathRooted(path))
    {
        return path;
    }

    var baseDir = Path.GetDirectoryName(configPath) ?? Environment.CurrentDirectory;
    return Path.GetFullPath(Path.Combine(baseDir, path));
}

internal sealed class RegexLogExtractor
{
    private readonly ExtractorConfig _config;
    private readonly CompiledRule[] _rules;
    private readonly HashSet<string> _tableFilter;

    public RegexLogExtractor(ExtractorConfig config)
    {
        _config = config;
        _rules = (config.Rules ?? new List<RegexRule>())
            .Select(r => new CompiledRule(r))
            .ToArray();
        if (_rules.Length == 0)
        {
            throw new InvalidOperationException("At least one regex rule is required.");
        }

        _tableFilter = new HashSet<string>(
            (config.Tables ?? new List<string>())
                .Where(t => !string.IsNullOrWhiteSpace(t))
                .Select(t => t.Trim().ToUpperInvariant()),
            StringComparer.OrdinalIgnoreCase);
    }

    public ExtractionResult Extract(string inputPath)
    {
        var rows = new List<ManifestRecord>();
        var txSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var trnLines = new List<string>
        {
            $"-- AOtransact SAE extraction",
            $"-- Source log: {inputPath}",
            $"-- Generated UTC: {DateTime.UtcNow:O}"
        };

        var unmatched = 0;
        var fallbackLsn = 0L;
        var lineNo = 0;
        foreach (var line in File.ReadLines(inputPath))
        {
            lineNo++;
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var matched = false;
            foreach (var rule in _rules)
            {
                var row = rule.TryParse(line, lineNo, ref fallbackLsn, _config);
                if (row is null)
                {
                    continue;
                }

                var fullTable = BuildFullTableName(row.SchemaName, row.TableName);
                if (_tableFilter.Count > 0 && !_tableFilter.Contains(fullTable))
                {
                    matched = true;
                    break;
                }

                row.ManifestKey = $"{row.Action}|{row.TxId}|{row.CurrentLsn}".ToUpperInvariant();
                rows.Add(row);
                txSet.Add(row.TxId);
                trnLines.Add(RenderTrnLine(row));
                matched = true;
                break;
            }

            if (!matched)
            {
                unmatched++;
            }
        }

        var ordered = rows
            .OrderBy(r => ParseCommitTime(r.CommitTime))
            .ThenBy(r => r.CurrentLsn, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => r.SourceLineNumber)
            .ToList();

        var manifest = new ManifestDocument
        {
            CollectedAtUtc = DateTime.UtcNow.ToString("O"),
            SourceType = "sae_text_log",
            ServerInstance = _config.ServerInstance,
            Database = _config.Database,
            Tables = _config.Tables ?? new List<string>(),
            RecordCount = ordered.Count,
            TransactionCount = txSet.Count,
            Note = "Committed DML manifest extracted from SAE text log via regex rules. Row-log hex fields are not populated in this project scaffold.",
            Records = ordered
        };

        return new ExtractionResult(manifest, trnLines, unmatched);
    }

    private static string BuildFullTableName(string? schema, string? table)
    {
        var safeSchema = string.IsNullOrWhiteSpace(schema) ? "dbo" : schema.Trim();
        var safeTable = string.IsNullOrWhiteSpace(table) ? "UNKNOWN_TABLE" : table.Trim();
        return $"{safeSchema}.{safeTable}".ToUpperInvariant();
    }

    private static DateTimeOffset ParseCommitTime(string? text)
    {
        if (DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var dto))
        {
            return dto;
        }

        return DateTimeOffset.MinValue;
    }

    private static string RenderTrnLine(ManifestRecord row)
    {
        var actionHeader = $"--{row.Action} ({row.CurrentLsn})";
        var metaHeader = $"-- tx={row.TxId}; commit={row.CommitTime}; spid={row.Spid?.ToString(CultureInfo.InvariantCulture) ?? ""}; source_line={row.SourceLineNumber}";
        var sql = !string.IsNullOrWhiteSpace(row.SqlText)
            ? row.SqlText!.TrimEnd().TrimEnd(';') + ";"
            : $"-- unresolved SQL text for {row.Action} on [{row.SchemaName ?? "dbo"}].[{row.TableName ?? "UNKNOWN_TABLE"}]";
        return string.Join(Environment.NewLine, new[] { actionHeader, metaHeader, sql });
    }
}

internal sealed class CompiledRule
{
    private readonly RegexRule _rule;
    private readonly Regex _regex;

    public CompiledRule(RegexRule rule)
    {
        _rule = rule;
        if (string.IsNullOrWhiteSpace(rule.Pattern))
        {
            throw new InvalidOperationException("Regex rule pattern is required.");
        }

        var options = RegexOptions.Compiled | RegexOptions.CultureInvariant;
        if (!rule.CaseSensitive)
        {
            options |= RegexOptions.IgnoreCase;
        }

        _regex = new Regex(rule.Pattern, options, TimeSpan.FromSeconds(2));
    }

    public ManifestRecord? TryParse(string line, int lineNo, ref long fallbackLsn, ExtractorConfig config)
    {
        var match = _regex.Match(line);
        if (!match.Success)
        {
            return null;
        }

        var operation = GetValue(match, _rule.OperationGroup, _rule.DefaultOperation) ?? "UNKNOWN";
        var normalizedAction = NormalizeAction(GetValue(match, _rule.ActionGroup, null), operation, _rule.OperationMap);
        if (normalizedAction is null)
        {
            return null;
        }

        var schema = GetValue(match, _rule.SchemaGroup, _rule.DefaultSchema);
        var table = GetValue(match, _rule.TableGroup, _rule.DefaultTable);
        var txId = GetValue(match, _rule.TxIdGroup, null);
        if (string.IsNullOrWhiteSpace(txId))
        {
            txId = $"LINE:{lineNo:D8}";
        }

        var lsn = GetValue(match, _rule.LsnGroup, null);
        if (string.IsNullOrWhiteSpace(lsn))
        {
            fallbackLsn++;
            lsn = $"TEXT:{fallbackLsn:D12}";
        }

        var commitTime = NormalizeCommitTime(GetValue(match, _rule.CommitTimeGroup, null));
        if (commitTime is null)
        {
            commitTime = File.GetLastWriteTimeUtc(config.InputPath ?? string.Empty).ToString("O");
        }

        return new ManifestRecord
        {
            ManifestKey = string.Empty,
            Action = normalizedAction,
            CurrentLsn = lsn,
            TxId = txId,
            OperationName = operation,
            SchemaName = schema,
            TableName = table,
            Spid = ParseNullableInt(GetValue(match, _rule.SpidGroup, null)),
            TransactionName = GetValue(match, _rule.TransactionNameGroup, null),
            UserName = GetValue(match, _rule.UserGroup, null),
            CommitTime = commitTime,
            SqlText = GetValue(match, _rule.SqlGroup, _rule.DefaultSqlTemplate),
            RawLine = line,
            SourceLineNumber = lineNo
        };
    }

    private static string? GetValue(Match match, string? groupName, string? fallback)
    {
        if (!string.IsNullOrWhiteSpace(groupName))
        {
            var group = match.Groups[groupName];
            if (group.Success && !string.IsNullOrWhiteSpace(group.Value))
            {
                return group.Value.Trim();
            }
        }

        return string.IsNullOrWhiteSpace(fallback) ? null : fallback.Trim();
    }

    private static int? ParseNullableInt(string? value)
    {
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
        {
            return parsed;
        }

        return null;
    }

    private static string? NormalizeAction(string? explicitAction, string operation, Dictionary<string, string>? operationMap)
    {
        var candidate = explicitAction;
        if (string.IsNullOrWhiteSpace(candidate) && operationMap is not null && operationMap.TryGetValue(operation, out var mapped))
        {
            candidate = mapped;
        }
        if (string.IsNullOrWhiteSpace(candidate))
        {
            candidate = operation;
        }

        return candidate.Trim().ToUpperInvariant() switch
        {
            "INSERT" => "INSERT",
            "UPDATE" => "UPDATE",
            "DELETE" => "DELETE",
            _ => null
        };
    }

    private static string? NormalizeCommitTime(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var parsed))
        {
            return parsed.ToUniversalTime().ToString("O");
        }

        return value;
    }
}

internal sealed class ExtractionResult
{
    public ExtractionResult(ManifestDocument manifest, List<string> trnLines, int unmatchedLineCount)
    {
        Manifest = manifest;
        TrnLines = trnLines;
        UnmatchedLineCount = unmatchedLineCount;
    }

    public ManifestDocument Manifest { get; }
    public List<string> TrnLines { get; }
    public int UnmatchedLineCount { get; }
}

internal sealed class ExtractorConfig
{
    [JsonPropertyName("input_path")]
    public string? InputPath { get; set; }

    [JsonPropertyName("manifest_output_path")]
    public string? ManifestOutputPath { get; set; } = ".\\output\\sae.manifest.json";

    [JsonPropertyName("trn_output_path")]
    public string? TrnOutputPath { get; set; } = ".\\output\\sae.trn";

    [JsonPropertyName("server_instance")]
    public string? ServerInstance { get; set; }

    [JsonPropertyName("database")]
    public string? Database { get; set; }

    [JsonPropertyName("tables")]
    public List<string>? Tables { get; set; }

    [JsonPropertyName("rules")]
    public List<RegexRule>? Rules { get; set; }
}

internal sealed class RegexRule
{
    [JsonPropertyName("pattern")]
    public string? Pattern { get; set; }

    [JsonPropertyName("case_sensitive")]
    public bool CaseSensitive { get; set; }

    [JsonPropertyName("action_group")]
    public string? ActionGroup { get; set; }

    [JsonPropertyName("operation_group")]
    public string? OperationGroup { get; set; }

    [JsonPropertyName("lsn_group")]
    public string? LsnGroup { get; set; }

    [JsonPropertyName("tx_id_group")]
    public string? TxIdGroup { get; set; }

    [JsonPropertyName("schema_group")]
    public string? SchemaGroup { get; set; }

    [JsonPropertyName("table_group")]
    public string? TableGroup { get; set; }

    [JsonPropertyName("spid_group")]
    public string? SpidGroup { get; set; }

    [JsonPropertyName("user_group")]
    public string? UserGroup { get; set; }

    [JsonPropertyName("commit_time_group")]
    public string? CommitTimeGroup { get; set; }

    [JsonPropertyName("transaction_name_group")]
    public string? TransactionNameGroup { get; set; }

    [JsonPropertyName("sql_group")]
    public string? SqlGroup { get; set; }

    [JsonPropertyName("default_schema")]
    public string? DefaultSchema { get; set; }

    [JsonPropertyName("default_table")]
    public string? DefaultTable { get; set; }

    [JsonPropertyName("default_operation")]
    public string? DefaultOperation { get; set; }

    [JsonPropertyName("default_sql_template")]
    public string? DefaultSqlTemplate { get; set; }

    [JsonPropertyName("operation_map")]
    public Dictionary<string, string>? OperationMap { get; set; }
}

internal sealed class ManifestDocument
{
    [JsonPropertyName("collected_at_utc")]
    public string? CollectedAtUtc { get; set; }

    [JsonPropertyName("source_type")]
    public string? SourceType { get; set; }

    [JsonPropertyName("server_instance")]
    public string? ServerInstance { get; set; }

    [JsonPropertyName("database")]
    public string? Database { get; set; }

    [JsonPropertyName("tables")]
    public List<string> Tables { get; set; } = new();

    [JsonPropertyName("record_count")]
    public int RecordCount { get; set; }

    [JsonPropertyName("transaction_count")]
    public int TransactionCount { get; set; }

    [JsonPropertyName("note")]
    public string? Note { get; set; }

    [JsonPropertyName("records")]
    public List<ManifestRecord> Records { get; set; } = new();
}

internal sealed class ManifestRecord
{
    [JsonPropertyName("manifest_key")]
    public string ManifestKey { get; set; } = string.Empty;

    [JsonPropertyName("action")]
    public string Action { get; set; } = string.Empty;

    [JsonPropertyName("current_lsn")]
    public string CurrentLsn { get; set; } = string.Empty;

    [JsonPropertyName("tx_id")]
    public string TxId { get; set; } = string.Empty;

    [JsonPropertyName("operation_name")]
    public string OperationName { get; set; } = string.Empty;

    [JsonPropertyName("schema_name")]
    public string? SchemaName { get; set; }

    [JsonPropertyName("table_name")]
    public string? TableName { get; set; }

    [JsonPropertyName("spid")]
    public int? Spid { get; set; }

    [JsonPropertyName("transaction_name")]
    public string? TransactionName { get; set; }

    [JsonPropertyName("user_name")]
    public string? UserName { get; set; }

    [JsonPropertyName("commit_time")]
    public string? CommitTime { get; set; }

    [JsonPropertyName("sql_text")]
    public string? SqlText { get; set; }

    [JsonPropertyName("raw_line")]
    public string? RawLine { get; set; }

    [JsonPropertyName("source_line_number")]
    public int SourceLineNumber { get; set; }
}
