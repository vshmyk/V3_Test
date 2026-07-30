using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

var argMap = ParseArgs(args);
if (!argMap.TryGetValue("config", out var configPath) || string.IsNullOrWhiteSpace(configPath))
{
    Console.Error.WriteLine("Required: --config <sqlany.runner.config.json>");
    return 2;
}

configPath = Path.GetFullPath(configPath, Environment.CurrentDirectory);
if (!File.Exists(configPath))
{
    Console.Error.WriteLine($"Config not found: {configPath}");
    return 2;
}

var cfg = JsonSerializer.Deserialize<RunnerConfig>(File.ReadAllText(configPath), new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true
}) ?? throw new InvalidOperationException($"Failed to parse config: {configPath}");

Validate(cfg);
EnsureParent(cfg.Output.SqlOutputPath);
EnsureParent(cfg.Output.LogOutputPath);
EnsureParent(cfg.Output.ResultJsonPath);
EnsureParent(cfg.Output.NormalizedJsonPath);
EnsureParent(cfg.Output.TrnOutputPath);

var arguments = BuildDbtranArgs(cfg);
Console.WriteLine("Starting SQL Anywhere log extraction...");
Console.WriteLine($"dbtran: {cfg.Tools.DbtranPath}");
Console.WriteLine($"log:    {cfg.Source.LogPath}");
Console.WriteLine($"sql:    {cfg.Output.SqlOutputPath}");

using var proc = new Process
{
    StartInfo = new ProcessStartInfo
    {
        FileName = cfg.Tools.DbtranPath,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true,
        WorkingDirectory = Environment.CurrentDirectory
    }
};
foreach (var arg in arguments)
{
    proc.StartInfo.ArgumentList.Add(arg);
}

proc.Start();
var stdoutTask = proc.StandardOutput.ReadToEndAsync();
var stderrTask = proc.StandardError.ReadToEndAsync();
await proc.WaitForExitAsync();
var stdout = await stdoutTask;
var stderr = await stderrTask;

if (!string.IsNullOrWhiteSpace(stdout)) Console.WriteLine(stdout.Trim());
if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr.Trim());
if (proc.ExitCode != 0)
{
    throw new InvalidOperationException($"dbtran failed with exit code {proc.ExitCode}");
}

var normalized = ParseDbtranChronologicalOutput(cfg.Output.SqlOutputPath);
if (!string.IsNullOrWhiteSpace(cfg.Output.NormalizedJsonPath))
{
    File.WriteAllText(cfg.Output.NormalizedJsonPath, JsonSerializer.Serialize(normalized, new JsonSerializerOptions { WriteIndented = true }));
}
if (!string.IsNullOrWhiteSpace(cfg.Output.TrnOutputPath))
{
    File.WriteAllText(cfg.Output.TrnOutputPath, BuildTrn(normalized));
}

var result = new
{
    generated_utc = DateTime.UtcNow.ToString("O"),
    dbtran_path = cfg.Tools.DbtranPath,
    log_path = cfg.Source.LogPath,
    sql_output_path = cfg.Output.SqlOutputPath,
    normalized_json_path = cfg.Output.NormalizedJsonPath,
    trn_output_path = cfg.Output.TrnOutputPath,
    filters = new
    {
        tables = cfg.Filters.Tables,
        include_users = cfg.Filters.IncludeUsers,
        exclude_users = cfg.Filters.ExcludeUsers,
        include_rollbacks = cfg.Filters.IncludeRollbacks,
        chronological = cfg.Filters.Chronological,
        ansi_sql = cfg.Filters.AnsiSql,
        from_most_recent_checkpoint = cfg.Filters.FromMostRecentCheckpoint
    },
    exit_code = proc.ExitCode,
    sql_output_exists = File.Exists(cfg.Output.SqlOutputPath),
    sql_output_length = File.Exists(cfg.Output.SqlOutputPath) ? new FileInfo(cfg.Output.SqlOutputPath).Length : 0,
    normalized = new
    {
        transaction_count = normalized.transaction_count,
        statement_count = normalized.statement_count,
        insert_count = normalized.insert_count,
        update_count = normalized.update_count,
        delete_count = normalized.delete_count,
        tables = normalized.tables
    }
};

if (!string.IsNullOrWhiteSpace(cfg.Output.ResultJsonPath))
{
    File.WriteAllText(cfg.Output.ResultJsonPath, JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
}

Console.WriteLine("SQL Anywhere extraction finished.");
return 0;

static ParsedOutput ParseDbtranChronologicalOutput(string path)
{
    var transactions = new List<ParsedTransaction>();
    var current = new ParsedTransaction();
    var currentStatement = new StringBuilder();

    foreach (var rawLine in File.ReadLines(path))
    {
        var line = rawLine.TrimEnd();
        if (string.IsNullOrWhiteSpace(line))
        {
            continue;
        }

        if (line.StartsWith("-----------------------------------------", StringComparison.Ordinal))
        {
            continue;
        }

        if (line.StartsWith("-- WARNING:", StringComparison.Ordinal))
        {
            continue;
        }

        if (line.StartsWith("--BEGIN TRANSACTION-", StringComparison.OrdinalIgnoreCase))
        {
            FlushStatement(current, currentStatement);
            if (current.Statements.Count > 0)
            {
                transactions.Add(current);
            }
            current = new ParsedTransaction { TransactionTag = line.Substring(2) };
            continue;
        }

        if (line.StartsWith("--COMMIT", StringComparison.OrdinalIgnoreCase))
        {
            FlushStatement(current, currentStatement);
            current.CommitTag = line.Substring(2);
            continue;
        }

        if (line.Equals("BEGIN TRANSACTION", StringComparison.OrdinalIgnoreCase) || line.Equals("COMMIT WORK", StringComparison.OrdinalIgnoreCase) || line.Equals("go", StringComparison.OrdinalIgnoreCase))
        {
            continue;
        }

        if (line.StartsWith("--INSERT-", StringComparison.OrdinalIgnoreCase) || line.StartsWith("--UPDATE-", StringComparison.OrdinalIgnoreCase) || line.StartsWith("--DELETE-", StringComparison.OrdinalIgnoreCase))
        {
            FlushStatement(current, currentStatement);
            current.CurrentStatementTag = line.Substring(2);
            continue;
        }

        if (line.StartsWith("--INSERT ", StringComparison.OrdinalIgnoreCase) || line.StartsWith("--UPDATE ", StringComparison.OrdinalIgnoreCase) || line.StartsWith("--DELETE ", StringComparison.OrdinalIgnoreCase) ||
            line.StartsWith("--   ", StringComparison.Ordinal) || line.StartsWith("--VALUES ", StringComparison.OrdinalIgnoreCase) || line.StartsWith("-- WHERE ", StringComparison.OrdinalIgnoreCase) || line.StartsWith("--SET ", StringComparison.OrdinalIgnoreCase))
        {
            var content = line[2..];
            currentStatement.AppendLine(content);
            continue;
        }
    }

    FlushStatement(current, currentStatement);
    if (current.Statements.Count > 0)
    {
        transactions.Add(current);
    }

    var flattened = transactions.SelectMany(t => t.Statements).ToList();
    return new ParsedOutput
    {
        generated_utc = DateTime.UtcNow.ToString("O"),
        transaction_count = transactions.Count,
        statement_count = flattened.Count,
        insert_count = flattened.Count(s => s.Action == "INSERT"),
        update_count = flattened.Count(s => s.Action == "UPDATE"),
        delete_count = flattened.Count(s => s.Action == "DELETE"),
        tables = flattened.Select(s => s.Table).Where(t => !string.IsNullOrWhiteSpace(t)).Select(t => t!).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(t => t).ToList(),
        transactions = transactions
    };
}

static string BuildTrn(ParsedOutput parsed)
{
    var sb = new StringBuilder();
    sb.AppendLine($"-- SQL Anywhere extracted TRN");
    sb.AppendLine($"-- Generated UTC: {DateTime.UtcNow:O}");
    sb.AppendLine($"-- Transactions: {parsed.transaction_count}; Statements: {parsed.statement_count}; Inserts: {parsed.insert_count}; Updates: {parsed.update_count}; Deletes: {parsed.delete_count}");
    sb.AppendLine();

    foreach (var tx in parsed.transactions)
    {
        foreach (var stmt in tx.Statements)
        {
            if (string.IsNullOrWhiteSpace(stmt.Sql) || string.Equals(stmt.Action, "OTHER", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            sb.AppendLine($"--{stmt.Action} ({stmt.Tag})");
            if (!string.IsNullOrWhiteSpace(stmt.Table))
            {
                sb.AppendLine($"-- table={stmt.Table}");
            }
            sb.AppendLine(stmt.Sql.Trim());
            sb.AppendLine("GO");
            sb.AppendLine();
        }
    }

    return sb.ToString();
}

static void FlushStatement(ParsedTransaction transaction, StringBuilder currentStatement)
{
    if (currentStatement.Length == 0 || string.IsNullOrWhiteSpace(transaction.CurrentStatementTag))
    {
        currentStatement.Clear();
        return;
    }

    var sql = currentStatement.ToString().Trim();
    var action = transaction.CurrentStatementTag.StartsWith("INSERT-", StringComparison.OrdinalIgnoreCase) ? "INSERT" :
        transaction.CurrentStatementTag.StartsWith("UPDATE-", StringComparison.OrdinalIgnoreCase) ? "UPDATE" :
        transaction.CurrentStatementTag.StartsWith("DELETE-", StringComparison.OrdinalIgnoreCase) ? "DELETE" :
        "OTHER";
    var table = ExtractTableName(sql, action);
    transaction.Statements.Add(new ParsedStatement
    {
        Tag = transaction.CurrentStatementTag,
        Action = action,
        Table = table,
        Sql = sql
    });
    transaction.CurrentStatementTag = null;
    currentStatement.Clear();
}

static string? ExtractTableName(string sql, string action)
{
    var pattern = action switch
    {
        "INSERT" => @"^INSERT\s+INTO\s+([^\(\s]+)",
        "UPDATE" => @"^UPDATE\s+([^\s]+)",
        "DELETE" => @"^DELETE\s+FROM\s+([^\s]+)",
        _ => ""
    };
    if (string.IsNullOrWhiteSpace(pattern)) return null;
    var match = Regex.Match(sql, pattern, RegexOptions.IgnoreCase | RegexOptions.Multiline);
    return match.Success ? match.Groups[1].Value.Trim() : null;
}

static List<string> BuildDbtranArgs(RunnerConfig cfg)
{
    var args = new List<string>();
    if (cfg.Filters.IncludeRollbacks) args.Add("-a");
    else args.Add("-r");
    if (cfg.Filters.Chronological) args.Add("-d");
    if (cfg.Filters.AnsiSql) args.Add("-s");
    if (cfg.Filters.FromMostRecentCheckpoint) args.Add("-f");
    if (!string.IsNullOrWhiteSpace(cfg.Source.EncryptionKey))
    {
        args.Add("-ek");
        args.Add(cfg.Source.EncryptionKey);
    }
    if (cfg.Filters.Tables.Count > 0)
    {
        args.Add("-it");
        args.Add(string.Join(",", cfg.Filters.Tables));
    }
    if (cfg.Filters.IncludeUsers.Count > 0)
    {
        args.Add("-u");
        args.Add(string.Join(",", cfg.Filters.IncludeUsers));
    }
    if (cfg.Filters.ExcludeUsers.Count > 0)
    {
        args.Add("-x");
        args.Add(string.Join(",", cfg.Filters.ExcludeUsers));
    }
    if (!string.IsNullOrWhiteSpace(cfg.Output.LogOutputPath))
    {
        args.Add("-o");
        args.Add(cfg.Output.LogOutputPath);
    }
    args.Add("-y");
    args.Add("-n");
    args.Add(cfg.Output.SqlOutputPath);
    args.Add(cfg.Source.LogPath);
    return args;
}

static void Validate(RunnerConfig cfg)
{
    if (string.IsNullOrWhiteSpace(cfg.Tools.DbtranPath) || !File.Exists(cfg.Tools.DbtranPath))
        throw new FileNotFoundException("dbtran.exe not found", cfg.Tools.DbtranPath);
    if (string.IsNullOrWhiteSpace(cfg.Source.LogPath) || !File.Exists(cfg.Source.LogPath))
        throw new FileNotFoundException("Transaction log file not found", cfg.Source.LogPath);
    if (string.IsNullOrWhiteSpace(cfg.Output.SqlOutputPath))
        throw new InvalidOperationException("output.sql_output_path is required.");
}

static void EnsureParent(string? path)
{
    if (string.IsNullOrWhiteSpace(path)) return;
    var parent = Path.GetDirectoryName(path);
    if (!string.IsNullOrWhiteSpace(parent)) Directory.CreateDirectory(parent);
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

sealed class RunnerConfig
{
    public ToolSection Tools { get; set; } = new();
    public SourceSection Source { get; set; } = new();
    public FilterSection Filters { get; set; } = new();
    public OutputSection Output { get; set; } = new();
}

sealed class ToolSection
{
    public string DbtranPath { get; set; } = @"E:\ASE\Bin64\dbtran.exe";
}

sealed class SourceSection
{
    public string LogPath { get; set; } = @"E:\DATA\MACSII\oasis.log";
    public string? EncryptionKey { get; set; }
}

sealed class FilterSection
{
    public List<string> Tables { get; set; } = new();
    public List<string> IncludeUsers { get; set; } = new();
    public List<string> ExcludeUsers { get; set; } = new();
    public bool IncludeRollbacks { get; set; }
    public bool Chronological { get; set; } = true;
    public bool AnsiSql { get; set; }
    public bool FromMostRecentCheckpoint { get; set; }
}

sealed class OutputSection
{
    public string SqlOutputPath { get; set; } = @"C:\Temp\sqlany_oasis.sql";
    public string? LogOutputPath { get; set; } = @"C:\Temp\sqlany_oasis.dbtran.log";
    public string? ResultJsonPath { get; set; } = @"C:\Temp\sqlany_oasis.result.json";
    public string? NormalizedJsonPath { get; set; } = @"C:\Temp\sqlany_oasis.normalized.json";
    public string? TrnOutputPath { get; set; } = @"C:\Temp\sqlany_oasis.trn";
}

sealed class ParsedOutput
{
    public string? generated_utc { get; set; }
    public int transaction_count { get; set; }
    public int statement_count { get; set; }
    public int insert_count { get; set; }
    public int update_count { get; set; }
    public int delete_count { get; set; }
    public List<string> tables { get; set; } = new();
    public List<ParsedTransaction> transactions { get; set; } = new();
}

sealed class ParsedTransaction
{
    public string? TransactionTag { get; set; }
    public string? CommitTag { get; set; }
    public string? CurrentStatementTag { get; set; }
    public List<ParsedStatement> Statements { get; set; } = new();
}

sealed class ParsedStatement
{
    public string? Tag { get; set; }
    public string? Action { get; set; }
    public string? Table { get; set; }
    public string? Sql { get; set; }
}


