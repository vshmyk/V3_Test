using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

var options = ParseArgs(args);
if (options.ContainsKey("help") || options.ContainsKey("?"))
{
    PrintUsage();
    return 0;
}

if (!options.TryGetValue("client-id", out var clientId) || string.IsNullOrWhiteSpace(clientId))
{
    Console.Error.WriteLine("Required: --client-id <ClientId>");
    return 2;
}

if (!options.TryGetValue("config", out var configPath) || string.IsNullOrWhiteSpace(configPath))
{
    Console.Error.WriteLine("Required: --config <transactions-loader.config.json>");
    return 2;
}

configPath = Path.GetFullPath(configPath, Environment.CurrentDirectory);
if (!File.Exists(configPath))
{
    Console.Error.WriteLine($"Config not found: {configPath}");
    return 2;
}

var cfg = JsonSerializer.Deserialize<LoaderConfig>(File.ReadAllText(configPath), new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true
}) ?? throw new InvalidOperationException($"Failed to parse config: {configPath}");

Validate(cfg);
clientId = clientId.Trim();

await using var conn = new SqlConnection(cfg.ConnectionString);
await conn.OpenAsync();

var clientSettings = await LoadClientSettingsAsync(conn, cfg, clientId);
var sourceDirectory = BuildLogsDirectory(clientSettings.DataSourceLocation);
if (!Directory.Exists(sourceDirectory))
    throw new DirectoryNotFoundException($"Source directory not found: {sourceDirectory}");

var zipFiles = EnumerateZipFiles(sourceDirectory, cfg.Source.ZipSearchPattern).ToList();
Console.WriteLine($"ClientId: {clientId}");
Console.WriteLine($"Source directory: {sourceDirectory}");
Console.WriteLine($"Target database: {clientSettings.OasisDatabase}");
Console.WriteLine($"Discovered {zipFiles.Count} zip file(s) in {sourceDirectory}");
Console.WriteLine($"Checkpoint: {clientSettings.LastTransactionBatch}");

var filesToProcess = ResolveFilesToProcess(zipFiles, clientSettings.LastTransactionBatch!, cfg, sourceDirectory).ToList();
if (cfg.Options.MaxFiles is > 0)
    filesToProcess = filesToProcess.Take(cfg.Options.MaxFiles.Value).ToList();

if (filesToProcess.Count == 0)
{
    Console.WriteLine("No zip files to process.");
    return 0;
}

Console.WriteLine($"Processing {filesToProcess.Count} zip file(s).");

var totalStatements = 0;
foreach (var zipFile in filesToProcess)
{
    Console.WriteLine($"Loading batch {zipFile.Name} ({zipFile.LastWriteTimeUtc:O})");
    var parseResult = ParseStatementsFromZip(zipFile);
    Console.WriteLine($"  Parsed {parseResult.Statements.Count} DML statement(s) from {parseResult.EntryFullName}");

    if (cfg.Options.DryRun)
    {
        totalStatements += parseResult.Statements.Count;
        Console.WriteLine("  Dry run enabled; skipping database writes.");
        continue;
    }

    await LoadBatchAsync(conn, cfg, clientSettings, clientId, zipFile.Name, parseResult.Statements);
    totalStatements += parseResult.Statements.Count;
    Console.WriteLine($"  Loaded {parseResult.Statements.Count} statement(s) and advanced checkpoint to {zipFile.Name}");
}

Console.WriteLine($"Completed. Total statements processed: {totalStatements}");
return 0;

static void Validate(LoaderConfig cfg)
{
    if (string.IsNullOrWhiteSpace(cfg.ConnectionString))
        throw new InvalidOperationException("connection_string is required.");
    if (string.IsNullOrWhiteSpace(cfg.Source.ZipSearchPattern))
        throw new InvalidOperationException("source.zip_search_pattern is required.");
    if (string.IsNullOrWhiteSpace(cfg.Properties.SelectSql))
        throw new InvalidOperationException("properties.select_sql is required.");
    if (string.IsNullOrWhiteSpace(cfg.Properties.UpdateLastBatchSql))
        throw new InvalidOperationException("properties.update_last_batch_sql is required.");
    if (string.IsNullOrWhiteSpace(cfg.Target.InsertTemplate))
        throw new InvalidOperationException("target.insert_template is required.");
}

static IEnumerable<FileInfo> EnumerateZipFiles(string directoryPath, string zipSearchPattern)
{
    return new DirectoryInfo(directoryPath)
        .EnumerateFiles(zipSearchPattern, SearchOption.TopDirectoryOnly)
        .OrderBy(f => f.LastWriteTimeUtc)
        .ThenBy(f => f.Name, StringComparer.OrdinalIgnoreCase);
}

static async Task<ClientSettings> LoadClientSettingsAsync(SqlConnection conn, LoaderConfig cfg, string clientId)
{
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = cfg.Properties.SelectSql;
    cmd.Parameters.AddWithValue("@ClientId", clientId);

    var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    await using var reader = await cmd.ExecuteReaderAsync();
    while (await reader.ReadAsync())
    {
        if (reader.IsDBNull(0))
            continue;

        var parmName = reader.GetString(0).Trim();
        var parmValue = reader.IsDBNull(1) ? string.Empty : reader.GetString(1).Trim();
        if (!string.IsNullOrWhiteSpace(parmName))
            values[parmName] = parmValue;
    }

    if (!values.TryGetValue("DATASOURCE_LOCATION", out var dataSourceLocation) || string.IsNullOrWhiteSpace(dataSourceLocation))
        throw new InvalidOperationException($"DATASOURCE_LOCATION property is missing for ClientId={clientId}.");
    if (!values.TryGetValue("OASIS_DB", out var oasisDatabase) || string.IsNullOrWhiteSpace(oasisDatabase))
        throw new InvalidOperationException($"OASIS_DB property is missing for ClientId={clientId}.");

    values.TryGetValue("LAST_TRANSACTION_BATCH", out var lastTransactionBatch);
    if (string.IsNullOrWhiteSpace(lastTransactionBatch))
        throw new InvalidOperationException($"LAST_TRANSACTION_BATCH property is missing or empty for ClientId={clientId}. Loader only processes files after a known checkpoint.");

    return new ClientSettings(dataSourceLocation, oasisDatabase, lastTransactionBatch);
}

static string BuildLogsDirectory(string dataSourceLocation)
{
    var basePath = dataSourceLocation.Trim().TrimEnd('\\', '/');
    if (basePath.EndsWith("\\Logs", StringComparison.OrdinalIgnoreCase) ||
        basePath.EndsWith("/Logs", StringComparison.OrdinalIgnoreCase))
    {
        return basePath;
    }

    return Path.Combine(basePath, "Logs");
}

static IReadOnlyList<FileInfo> ResolveFilesToProcess(IReadOnlyList<FileInfo> zipFiles, string checkpointName, LoaderConfig cfg, string sourceDirectory)
{
    if (zipFiles.Count == 0)
        return Array.Empty<FileInfo>();

    var normalizedCheckpointName = NormalizeBatchName(checkpointName);
    var checkpointIndex = -1;
    for (var i = 0; i < zipFiles.Count; i++)
    {
        if (string.Equals(NormalizeBatchName(zipFiles[i].Name), normalizedCheckpointName, StringComparison.OrdinalIgnoreCase))
        {
            checkpointIndex = i;
            break;
        }
    }

    if (checkpointIndex < 0)
    {
        if (cfg.Properties.RequireCheckpointFilePresent)
        {
            throw new FileNotFoundException(
                $"Checkpoint file '{checkpointName}' was not found in source directory '{sourceDirectory}'.");
        }

        Console.WriteLine($"Checkpoint file '{checkpointName}' not found. Continuing from oldest available file because require_checkpoint_file_present=false.");
        return zipFiles;
    }

    return zipFiles.Skip(checkpointIndex + 1).ToList();
}

static string NormalizeBatchName(string batchName)
{
    var trimmed = batchName.Trim();
    return trimmed.EndsWith(".zip", StringComparison.OrdinalIgnoreCase)
        ? trimmed[..^4]
        : trimmed;
}

static ZipParseResult ParseStatementsFromZip(FileInfo zipFile)
{
    using var archive = ZipFile.OpenRead(zipFile.FullName);
    var matches = archive.Entries
        .Where(e => !string.IsNullOrWhiteSpace(e.Name) &&
                    e.Name.EndsWith(".trn", StringComparison.OrdinalIgnoreCase))
        .ToList();

    if (matches.Count == 0)
        throw new InvalidOperationException($"Zip file '{zipFile.FullName}' does not contain a .trn entry.");
    if (matches.Count > 1)
        throw new InvalidOperationException($"Zip file '{zipFile.FullName}' contains multiple .trn entries.");

    var entry = matches[0];
    using var stream = entry.Open();
    using var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
    var content = reader.ReadToEnd();
    var statements = ParseTrnStatements(content);
    return new ZipParseResult(entry.FullName, statements);
}

static IReadOnlyList<ParsedStatement> ParseTrnStatements(string content)
{
    var results = new List<ParsedStatement>();
    using var reader = new StringReader(content);
    var pendingComments = new List<string>();
    var currentStatement = new StringBuilder();
    string? currentHeader = null;
    var activeVariables = new Dictionary<string, VariableContext>(StringComparer.OrdinalIgnoreCase);
    var sourceLineNumber = 0;
    string? line;

    while ((line = reader.ReadLine()) is not null)
    {
        sourceLineNumber++;
        line = NormalizeRawLine(line);

        if (currentStatement.Length == 0)
        {
            if (IsGo(line))
            {
                pendingComments.Clear();
                continue;
            }

            if (line.TrimStart().StartsWith("--", StringComparison.Ordinal))
            {
                var trimmedComment = line.Trim();
                pendingComments.Add(trimmedComment);
                if (TryExtractHeader(trimmedComment, out var header))
                    currentHeader = header;
                continue;
            }

            if (TryHandleVariableDeclaration(line, sourceLineNumber, activeVariables))
                continue;

            if (TryHandleVariableAssignment(line, activeVariables))
                continue;

            if (TryHandleVariableDrop(line, activeVariables))
                continue;

            if (string.IsNullOrWhiteSpace(line))
                continue;

            currentStatement.AppendLine(RewriteVariableReferences(line, activeVariables));
            continue;
        }

        if (IsGo(line))
        {
            FlushStatement(results, currentStatement, pendingComments, currentHeader, activeVariables);
            pendingComments.Clear();
            continue;
        }

        currentStatement.AppendLine(RewriteVariableReferences(line, activeVariables));
    }

    FlushStatement(results, currentStatement, pendingComments, currentHeader, activeVariables);
    return results;
}

static void FlushStatement(List<ParsedStatement> results, StringBuilder currentStatement, List<string> pendingComments, string? currentHeader, IReadOnlyDictionary<string, VariableContext> activeVariables)
{
    if (currentStatement.Length == 0)
        return;

    var statementText = currentStatement.ToString().Trim();
    currentStatement.Clear();
    if (string.IsNullOrWhiteSpace(statementText) || !LooksLikeDml(statementText))
        return;

    var ordinal = results.Count + 1;
    var transactionId = DeriveTransactionId(pendingComments, currentHeader, ordinal);
    var executableStatementText = BuildExecutableStatement(statementText, activeVariables);
    results.Add(new ParsedStatement(transactionId, executableStatementText, ordinal));
}

static bool LooksLikeDml(string statementText)
{
    var trimmed = statementText.TrimStart();
    return trimmed.StartsWith("INSERT ", StringComparison.OrdinalIgnoreCase) ||
           trimmed.StartsWith("UPDATE ", StringComparison.OrdinalIgnoreCase) ||
           trimmed.StartsWith("DELETE ", StringComparison.OrdinalIgnoreCase) ||
           trimmed.StartsWith("MERGE ", StringComparison.OrdinalIgnoreCase);
}

static string DeriveTransactionId(IReadOnlyList<string> pendingComments, string? currentHeader, int ordinal)
{
    for (var i = pendingComments.Count - 1; i >= 0; i--)
    {
        var comment = pendingComments[i].Trim();
        if (TryExtractHeader(comment, out var header))
            return header;

        var txMatch = Regex.Match(comment, @"^--\s*tx\s*=\s*([^;]+)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        if (txMatch.Success)
            return $"--{txMatch.Groups[1].Value.Trim()}";

        var headerMatch = Regex.Match(comment, @"^--\s*(?:INSERT|UPDATE|DELETE|MERGE)\s*\(([^)]+)\)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        if (headerMatch.Success)
            return $"--{headerMatch.Groups[1].Value.Trim()}";
    }

    if (!string.IsNullOrWhiteSpace(currentHeader))
        return currentHeader;

    return $"SEQ-{ordinal.ToString("D8", CultureInfo.InvariantCulture)}";
}

static bool TryExtractHeader(string comment, out string header)
{
    var trimmed = comment.Trim();
    if (Regex.IsMatch(trimmed, @"^--(?:INSERT|UPDATE|DELETE|MERGE)-", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
    {
        header = trimmed;
        return true;
    }

    header = string.Empty;
    return false;
}

static string NormalizeRawLine(string line)
{
    return line.Replace("SET ATTACHMENT=''", "SET ATTACHMENT=NULL", StringComparison.OrdinalIgnoreCase);
}

static bool TryHandleVariableDeclaration(string line, int sourceLineNumber, IDictionary<string, VariableContext> activeVariables)
{
    var match = Regex.Match(line, @"^CREATE\s+VARIABLE\s+(\w+)\s+(.+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (!match.Success)
        return false;

    var originalName = match.Groups[1].Value;
    var rawType = match.Groups[2].Value.Trim();
    var normalizedType = rawType
        .Replace("LONG VARCHAR", "NVARCHAR(MAX)", StringComparison.OrdinalIgnoreCase)
        .Replace("LONG BINARY", "VARBINARY(MAX)", StringComparison.OrdinalIgnoreCase);
    var mappedName = $"@{originalName}_{sourceLineNumber}";
    var tempTableName = normalizedType.Equals("VARBINARY(MAX)", StringComparison.OrdinalIgnoreCase)
        ? $"@TempBinaryData_{sourceLineNumber}"
        : null;

    activeVariables[originalName] = new VariableContext(
        originalName,
        mappedName,
        normalizedType,
        sourceLineNumber,
        tempTableName);

    return true;
}

static bool TryHandleVariableAssignment(string line, IDictionary<string, VariableContext> activeVariables)
{
    var binaryInitMatch = Regex.Match(line, @"^SET\s+(\w+)\s*=\s*0x(.+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (binaryInitMatch.Success && activeVariables.TryGetValue(binaryInitMatch.Groups[1].Value, out var binaryInitContext) && binaryInitContext.IsBinary)
    {
        binaryInitContext.BinaryChunks.Add(binaryInitMatch.Groups[2].Value.Trim());
        return true;
    }

    var binaryConcatMatch = Regex.Match(line, @"^SET\s+(\w+)\s*=\s*\1\s*\|\|\s*0x(.+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (binaryConcatMatch.Success && activeVariables.TryGetValue(binaryConcatMatch.Groups[1].Value, out var binaryConcatContext) && binaryConcatContext.IsBinary)
    {
        binaryConcatContext.BinaryChunks.Add(binaryConcatMatch.Groups[2].Value.Trim());
        return true;
    }

    var setMatch = Regex.Match(line, @"^SET\s+(\w+)\s*=\s*(.+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (setMatch.Success && activeVariables.TryGetValue(setMatch.Groups[1].Value, out var textContext))
    {
        if (textContext.IsBinary)
            return true;

        var rewrittenAssignment = RewriteVariableReferences(line, activeVariables);
        textContext.AssignmentLines.Add(RewriteSqlConcatenationOperators(rewrittenAssignment));
        return true;
    }

    return false;
}

static bool TryHandleVariableDrop(string line, IDictionary<string, VariableContext> activeVariables)
{
    var match = Regex.Match(line, @"^DROP\s+VARIABLE\s+(\w+)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (!match.Success)
        return false;

    activeVariables.Remove(match.Groups[1].Value);
    return true;
}

static string RewriteVariableReferences(string line, IDictionary<string, VariableContext> activeVariables)
{
    var rewritten = line;
    foreach (var variable in activeVariables.Values.OrderBy(v => v.CreatedOrder))
    {
        rewritten = Regex.Replace(
            rewritten,
            $@"(?<![A-Za-z0-9_@]){Regex.Escape(variable.OriginalName)}(?![A-Za-z0-9_])",
            variable.MappedName,
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    }

    return rewritten;
}

static string RewriteSqlConcatenationOperators(string sql)
{
    var sb = new StringBuilder(sql.Length);
    var inString = false;

    for (var i = 0; i < sql.Length; i++)
    {
        var ch = sql[i];
        if (ch == '\'')
        {
            sb.Append(ch);
            if (inString)
            {
                if (i + 1 < sql.Length && sql[i + 1] == '\'')
                {
                    sb.Append(sql[i + 1]);
                    i++;
                }
                else
                {
                    inString = false;
                }
            }
            else
            {
                inString = true;
            }

            continue;
        }

        if (!inString && ch == '|' && i + 1 < sql.Length && sql[i + 1] == '|')
        {
            sb.Append(" + ");
            i++;
            continue;
        }

        sb.Append(ch);
    }

    return sb.ToString();
}

static string BuildExecutableStatement(string statementText, IReadOnlyDictionary<string, VariableContext> activeVariables)
{
    var requiredVariables = activeVariables.Values
        .Where(v => v.IsReferencedBy(statementText))
        .OrderBy(v => v.CreatedOrder)
        .ToList();

    if (requiredVariables.Count == 0)
        return statementText;

    var setupSql = string.Join(Environment.NewLine, requiredVariables.Select(v => v.RenderSetupSql()));
    return string.Concat(setupSql, Environment.NewLine, statementText);
}

static bool IsGo(string line) => string.Equals(line.Trim(), "GO", StringComparison.OrdinalIgnoreCase);

static async Task LoadBatchAsync(SqlConnection conn, LoaderConfig cfg, ClientSettings clientSettings, string clientId, string batchFileName, IReadOnlyList<ParsedStatement> statements)
{
    await using var tx = await conn.BeginTransactionAsync();
    var primaryKeyCache = new Dictionary<string, IReadOnlyList<string>>(StringComparer.OrdinalIgnoreCase);

    await using var insertCmd = conn.CreateCommand();
    insertCmd.Transaction = (SqlTransaction)tx;
    insertCmd.CommandText = BuildInsertSql(cfg.Target.InsertTemplate, clientSettings.OasisDatabase);
    insertCmd.Parameters.Add(new SqlParameter("@Id", System.Data.SqlDbType.Int));
    insertCmd.Parameters.Add(new SqlParameter("@TransactionId", System.Data.SqlDbType.NVarChar, 255));
    insertCmd.Parameters.Add(new SqlParameter("@TransactionStatement", System.Data.SqlDbType.NVarChar, -1));
    insertCmd.Parameters.Add(new SqlParameter("@BatchId", System.Data.SqlDbType.NVarChar, 260));

    var normalizedBatchId = NormalizeBatchName(batchFileName);
    foreach (var statement in statements)
    {
        var statementText = cfg.Options.PredeleteBeforeInsert
            ? await MaybeInjectPreDeleteAsync(conn, (SqlTransaction)tx, clientSettings.OasisDatabase, statement.StatementText, primaryKeyCache)
            : statement.StatementText;

        insertCmd.Parameters["@Id"].Value = statement.Ordinal;
        insertCmd.Parameters["@TransactionId"].Value = statement.TransactionId;
        insertCmd.Parameters["@TransactionStatement"].Value = statementText;
        insertCmd.Parameters["@BatchId"].Value = normalizedBatchId;
        await insertCmd.ExecuteNonQueryAsync();
    }

    if (cfg.Options.UpdateCheckpoint)
    {
        await using var updateCmd = conn.CreateCommand();
        updateCmd.Transaction = (SqlTransaction)tx;
        updateCmd.CommandText = cfg.Properties.UpdateLastBatchSql;
        updateCmd.Parameters.AddWithValue("@ClientId", clientId);
        updateCmd.Parameters.AddWithValue("@ParmValue", normalizedBatchId);
        var rows = await updateCmd.ExecuteNonQueryAsync();
        if (rows <= 0)
            throw new InvalidOperationException($"Checkpoint update did not affect any rows for ClientId={clientId}.");
    }

    await tx.CommitAsync();
}

static string BuildInsertSql(string insertTemplate, string databaseName)
{
    return insertTemplate.Replace("{OASIS_DB}", EscapeSqlIdentifier(databaseName), StringComparison.Ordinal);
}

static async Task<string> MaybeInjectPreDeleteAsync(
    SqlConnection conn,
    SqlTransaction tx,
    string databaseName,
    string executableStatementText,
    IDictionary<string, IReadOnlyList<string>> primaryKeyCache)
{
    if (!TrySplitExecutableStatement(executableStatementText, out var setupSql, out var dmlSql))
        return executableStatementText;

    if (!TryParseInsertStatement(dmlSql, out var insertInfo))
        return executableStatementText;

    var tableKey = insertInfo.SchemaName is null
        ? insertInfo.TableName
        : $"{insertInfo.SchemaName}.{insertInfo.TableName}";

    if (!primaryKeyCache.TryGetValue(tableKey, out var primaryKeyColumns))
    {
        primaryKeyColumns = await LoadPrimaryKeyColumnsAsync(conn, tx, databaseName, insertInfo.SchemaName ?? "dbo", insertInfo.TableName);
        primaryKeyCache[tableKey] = primaryKeyColumns;
    }

    if (primaryKeyColumns.Count == 0)
        return executableStatementText;

    var valueMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < insertInfo.Columns.Count; i++)
        valueMap[NormalizeIdentifier(insertInfo.Columns[i])] = insertInfo.Values[i].Trim();

    var predicates = new List<string>();
    foreach (var primaryKeyColumn in primaryKeyColumns)
    {
        if (!valueMap.TryGetValue(primaryKeyColumn, out var valueExpression))
            return executableStatementText;

        predicates.Add(valueExpression.Equals("NULL", StringComparison.OrdinalIgnoreCase)
            ? $"{EscapeSqlIdentifier(primaryKeyColumn)} IS NULL"
            : $"{EscapeSqlIdentifier(primaryKeyColumn)} = {valueExpression}");
    }

    var deleteSql = $"DELETE FROM {insertInfo.TargetTableExpression}{Environment.NewLine} WHERE {string.Join($"{Environment.NewLine}   AND ", predicates)};";
    if (string.IsNullOrWhiteSpace(setupSql))
        return string.Concat(deleteSql, Environment.NewLine, dmlSql);

    return string.Concat(setupSql.TrimEnd(), Environment.NewLine, deleteSql, Environment.NewLine, dmlSql);
}

static async Task<IReadOnlyList<string>> LoadPrimaryKeyColumnsAsync(
    SqlConnection conn,
    SqlTransaction tx,
    string databaseName,
    string schemaName,
    string tableName)
{
    await using var cmd = conn.CreateCommand();
    cmd.Transaction = tx;
    cmd.CommandText =
        $"""
        SELECT c.name
        FROM {EscapeSqlIdentifier(databaseName)}.sys.key_constraints kc
        INNER JOIN {EscapeSqlIdentifier(databaseName)}.sys.tables t
            ON t.object_id = kc.parent_object_id
        INNER JOIN {EscapeSqlIdentifier(databaseName)}.sys.schemas s
            ON s.schema_id = t.schema_id
        INNER JOIN {EscapeSqlIdentifier(databaseName)}.sys.index_columns ic
            ON ic.object_id = kc.parent_object_id
           AND ic.index_id = kc.unique_index_id
        INNER JOIN {EscapeSqlIdentifier(databaseName)}.sys.columns c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
        WHERE kc.type = 'PK'
          AND s.name = @SchemaName
          AND t.name = @TableName
        ORDER BY ic.key_ordinal;
        """;
    cmd.Parameters.AddWithValue("@SchemaName", schemaName);
    cmd.Parameters.AddWithValue("@TableName", tableName);

    var results = new List<string>();
    await using var reader = await cmd.ExecuteReaderAsync();
    while (await reader.ReadAsync())
        results.Add(reader.GetString(0));

    return results;
}

static bool TrySplitExecutableStatement(string executableStatementText, out string setupSql, out string dmlSql)
{
    var matches = Regex.Matches(executableStatementText, @"(?im)^\s*(INSERT|UPDATE|DELETE|MERGE)\b");
    if (matches.Count == 0)
    {
        setupSql = string.Empty;
        dmlSql = string.Empty;
        return false;
    }

    var match = matches[^1];
    setupSql = executableStatementText[..match.Index];
    dmlSql = executableStatementText[match.Index..].TrimStart();
    return true;
}

static bool TryParseInsertStatement(string statementText, out InsertStatementInfo insertInfo)
{
    static InsertStatementInfo EmptyInsertInfo() => new(
        string.Empty,
        null,
        string.Empty,
        Array.Empty<string>(),
        Array.Empty<string>());

    var match = Regex.Match(
        statementText,
        @"(?is)^\s*INSERT\s+INTO\s+(?<table>[\[\]\w\.]+)\s*\((?<columns>.*?)\)\s*VALUES\s*\((?<values>.*)\)\s*;?\s*$",
        RegexOptions.CultureInvariant);

    if (!match.Success)
    {
        insertInfo = EmptyInsertInfo();
        return false;
    }

    var targetTableExpression = match.Groups["table"].Value.Trim();
    var columns = SplitSqlCsv(match.Groups["columns"].Value);
    var values = SplitSqlCsv(match.Groups["values"].Value);
    if (columns.Count == 0 || columns.Count != values.Count)
    {
        insertInfo = EmptyInsertInfo();
        return false;
    }

    if (!TryParseSchemaAndTable(targetTableExpression, out var schemaName, out var tableName))
    {
        insertInfo = EmptyInsertInfo();
        return false;
    }

    insertInfo = new InsertStatementInfo(targetTableExpression, schemaName, tableName, columns, values);
    return true;
}

static IReadOnlyList<string> SplitSqlCsv(string text)
{
    var results = new List<string>();
    var current = new StringBuilder();
    var inString = false;
    var depth = 0;

    for (var i = 0; i < text.Length; i++)
    {
        var ch = text[i];
        if (ch == '\'')
        {
            current.Append(ch);
            if (inString)
            {
                if (i + 1 < text.Length && text[i + 1] == '\'')
                {
                    current.Append(text[i + 1]);
                    i++;
                }
                else
                {
                    inString = false;
                }
            }
            else
            {
                inString = true;
            }

            continue;
        }

        if (!inString)
        {
            if (ch == '(')
                depth++;
            else if (ch == ')' && depth > 0)
                depth--;
            else if (ch == ',' && depth == 0)
            {
                results.Add(current.ToString().Trim());
                current.Clear();
                continue;
            }
        }

        current.Append(ch);
    }

    var final = current.ToString().Trim();
    if (final.Length > 0)
        results.Add(final);

    return results;
}

static bool TryParseSchemaAndTable(string targetTableExpression, out string? schemaName, out string tableName)
{
    var parts = targetTableExpression.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Select(NormalizeIdentifier)
        .ToArray();

    if (parts.Length == 1)
    {
        schemaName = "dbo";
        tableName = parts[0];
        return true;
    }

    if (parts.Length == 2)
    {
        schemaName = parts[0];
        tableName = parts[1];
        return true;
    }

    if (parts.Length == 3)
    {
        schemaName = parts[1];
        tableName = parts[2];
        return true;
    }

    schemaName = null;
    tableName = string.Empty;
    return false;
}

static string EscapeSqlIdentifier(string identifier)
{
    return $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";
}

static string NormalizeIdentifier(string identifier)
{
    return identifier.Trim().Trim('[', ']');
}

static Dictionary<string, string?> ParseArgs(string[] args)
{
    var map = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
        if (!arg.StartsWith("--", StringComparison.Ordinal))
            continue;

        var key = arg[2..];
        string? value = null;
        if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
            value = args[++i];

        map[key] = value;
    }

    return map;
}

static void PrintUsage()
{
    Console.WriteLine("Transactions Loader");
    Console.WriteLine("Usage:");
    Console.WriteLine("  dotnet run --project .\\tools\\transactions-loader\\AOtransact.TransactionsLoader.csproj -- --client-id PLS --config .\\tools\\transactions-loader\\transactions-loader.config.sample.json");
    Console.WriteLine();
    Console.WriteLine("Behavior:");
    Console.WriteLine("  Resolves DATASOURCE_LOCATION, LAST_TRANSACTION_BATCH, and OASIS_DB from INTEGRAMASTER_V2.dbo.ClientProperties for the supplied ClientId, then loads zip batches in order.");
}

sealed record ParsedStatement(string TransactionId, string StatementText, int Ordinal);

sealed record ZipParseResult(string EntryFullName, IReadOnlyList<ParsedStatement> Statements);

sealed record ClientSettings(string DataSourceLocation, string OasisDatabase, string? LastTransactionBatch);

sealed record InsertStatementInfo(
    string TargetTableExpression,
    string? SchemaName,
    string TableName,
    IReadOnlyList<string> Columns,
    IReadOnlyList<string> Values);

sealed class VariableContext
{
    public VariableContext(string originalName, string mappedName, string sqlType, int createdOrder, string? tempTableName)
    {
        OriginalName = originalName;
        MappedName = mappedName;
        SqlType = sqlType;
        CreatedOrder = createdOrder;
        TempTableName = tempTableName;
    }

    public string OriginalName { get; }
    public string MappedName { get; }
    public string SqlType { get; }
    public int CreatedOrder { get; }
    public string? TempTableName { get; }
    public bool IsBinary => SqlType.Equals("VARBINARY(MAX)", StringComparison.OrdinalIgnoreCase);
    public List<string> AssignmentLines { get; } = new();
    public List<string> BinaryChunks { get; } = new();

    public bool IsReferencedBy(string statementText)
    {
        return Regex.IsMatch(
            statementText,
            $@"(?<![A-Za-z0-9_]){Regex.Escape(MappedName)}(?![A-Za-z0-9_])",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    }

    public string RenderSetupSql()
    {
        var sb = new StringBuilder();
        sb.Append("DECLARE ").Append(MappedName).Append(' ').Append(SqlType).Append(';');

        if (IsBinary)
        {
            sb.Append(' ').Append("DECLARE ").Append(TempTableName).Append(" TABLE (Id INT IDENTITY(1,1), BinData NVARCHAR(MAX));");

            if (BinaryChunks.Count > 0)
            {
                foreach (var chunkGroup in BinaryChunks.Chunk(1000))
                {
                    sb.Append(' ')
                        .Append("INSERT INTO ")
                        .Append(TempTableName)
                        .Append(" (BinData) VALUES ")
                        .Append(string.Join(", ", chunkGroup.Select(chunk => $"('{chunk}')")))
                        .Append(';');
                }

                sb.Append(' ')
                    .Append("SELECT ")
                    .Append(MappedName)
                    .Append(" = CONVERT(VARBINARY(MAX), '0x' + STRING_AGG(BinData, '') WITHIN GROUP (ORDER BY Id), 1) FROM ")
                    .Append(TempTableName)
                    .Append(';');
            }
        }
        else
        {
            foreach (var assignmentLine in AssignmentLines)
            {
                sb.Append(' ').Append(assignmentLine.TrimEnd(';')).Append(';');
            }
        }

        return sb.ToString();
    }
}

sealed class LoaderConfig
{
    [JsonPropertyName("connection_string")]
    public string ConnectionString { get; set; } = string.Empty;

    [JsonPropertyName("source")]
    public SourceConfig Source { get; set; } = new();

    [JsonPropertyName("properties")]
    public PropertiesConfig Properties { get; set; } = new();

    [JsonPropertyName("target")]
    public TargetConfig Target { get; set; } = new();

    [JsonPropertyName("options")]
    public LoaderOptions Options { get; set; } = new();
}

sealed class SourceConfig
{
    [JsonPropertyName("zip_search_pattern")]
    public string ZipSearchPattern { get; set; } = "*.zip";
}

sealed class PropertiesConfig
{
    [JsonPropertyName("require_checkpoint_file_present")]
    public bool RequireCheckpointFilePresent { get; set; } = true;

    [JsonPropertyName("select_sql")]
    public string SelectSql { get; set; } =
        """
        SELECT ParmName, ParmValue
        FROM INTEGRAMASTER_V2.dbo.ClientProperties
        WHERE ClientId = @ClientId
          AND ParmName IN ('DATASOURCE_LOCATION', 'LAST_TRANSACTION_BATCH', 'OASIS_DB');
        """;

    [JsonPropertyName("update_last_batch_sql")]
    public string UpdateLastBatchSql { get; set; } =
        """
        UPDATE INTEGRAMASTER_V2.dbo.ClientProperties
        SET ParmValue = @ParmValue
        WHERE ClientId = @ClientId
          AND ParmName = 'LAST_TRANSACTION_BATCH';
        """;
}

sealed class TargetConfig
{
    [JsonPropertyName("insert_template")]
    public string InsertTemplate { get; set; } =
        """
        INSERT INTO {OASIS_DB}.dbo.TransactionLog
        (
            Id,
            TransactionId,
            TransactionStatement,
            BatchTime,
            BatchId
        )
        VALUES
        (
            @Id,
            @TransactionId,
            @TransactionStatement,
            GETDATE(),
            @BatchId
        );
        """;
}

sealed class LoaderOptions
{
    [JsonPropertyName("dry_run")]
    public bool DryRun { get; set; }

    [JsonPropertyName("update_checkpoint")]
    public bool UpdateCheckpoint { get; set; } = true;

    [JsonPropertyName("max_files")]
    public int? MaxFiles { get; set; }

    [JsonPropertyName("predelete_before_insert")]
    public bool PredeleteBeforeInsert { get; set; }
}
