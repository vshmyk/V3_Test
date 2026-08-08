using AOtransact.ParspecEmulator.Models;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using System.Text;

namespace AOtransact.ParspecEmulator.Services;

public sealed class OasisSourceService
{
    private readonly ParspecEmulatorOptions _options;

    public OasisSourceService(IOptions<ParspecEmulatorOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<SourceRow>> GetTopRowsAsync(string tableName, int limit, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(tableName))
        {
            return Array.Empty<SourceRow>();
        }

        var safeLimit = Math.Clamp(limit, 1, 100);
        var sql = $"SELECT TOP ({safeLimit}) * FROM oasis.[{tableName}] WITH (NOLOCK);";
        var rows = new List<SourceRow>();

        await using var connection = new SqlConnection(_options.SqlConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(sql, connection)
        {
            CommandTimeout = 60
        };

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
            {
                values[reader.GetName(i)] = await reader.IsDBNullAsync(i, cancellationToken)
                    ? null
                    : reader.GetValue(i);
            }

            rows.Add(new SourceRow
            {
                DisplayKey = BuildKey(values),
                Preview = BuildPreview(values),
                Values = values
            });
        }

        return rows;
    }

    private static string BuildKey(IReadOnlyDictionary<string, object?> values)
    {
        var preferred = new[]
        {
            "DBID", "PROJECTID", "QUOTEID", "POID", "LINEUID", "DISTRIBUTORID", "MANUFACTURERID", "CONTACTID"
        };

        var parts = new List<string>();
        foreach (var key in preferred)
        {
            if (values.TryGetValue(key, out var value) && value is not null && !string.IsNullOrWhiteSpace(value.ToString()))
            {
                parts.Add($"{key}={value}");
            }
        }

        return parts.Count > 0
            ? string.Join(" | ", parts)
            : "Record";
    }

    private static string BuildPreview(IReadOnlyDictionary<string, object?> values)
    {
        var builder = new StringBuilder();
        foreach (var pair in values)
        {
            if (pair.Value is null)
            {
                continue;
            }

            var text = pair.Value.ToString();
            if (string.IsNullOrWhiteSpace(text))
            {
                continue;
            }

            if (builder.Length > 0)
            {
                builder.Append(" | ");
            }

            builder.Append(pair.Key);
            builder.Append('=');
            builder.Append(text.Length > 40 ? text[..40] + "..." : text);

            if (builder.Length > 140)
            {
                break;
            }
        }

        return builder.Length == 0 ? "No preview fields" : builder.ToString();
    }
}
