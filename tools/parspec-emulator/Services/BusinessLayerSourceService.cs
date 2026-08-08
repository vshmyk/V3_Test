using AOtransact.ParspecEmulator.Models;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using System.Text;

namespace AOtransact.ParspecEmulator.Services;

public sealed class BusinessLayerSourceService
{
    private readonly ParspecEmulatorOptions _options;

    public BusinessLayerSourceService(IOptions<ParspecEmulatorOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<SourceRow>> GetRowsAsync(DestinationProjectionMap projection, int limit, CancellationToken cancellationToken)
    {
        var table = ResolveBusinessTable(projection);
        if (string.IsNullOrWhiteSpace(table))
        {
            return Array.Empty<SourceRow>();
        }

        var sql = $"SELECT TOP ({Math.Clamp(limit, 1, 100)}) * FROM {table} WITH (NOLOCK);";
        var rows = new List<SourceRow>();

        await using var connection = new SqlConnection(_options.BusinessSqlConnectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection) { CommandTimeout = 60 };
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
                Preview = $"{projection.EntityFamily} via {table}",
                Values = values
            });
        }

        return rows;
    }

    public string ResolveBusinessTable(DestinationProjectionMap projection)
    {
        return projection.EntityFamily switch
        {
            "Project" => "SRC.Project",
            "Opportunity" => "SRC.Project",
            "QuoteMetadata" => "SRC.Bid",
            "quote" => "SRC.Bid",
            "bom" => "SRC.QuoteItem",
            "Bod" => "SRC.QuoteItem",
            "PurchaseOrder" => "SRC.PurchaseOrder",
            "PurchaseOrderItem" => "SRC.PurchaseOrderItem",
            "rolodex" => projection.ObjectName.Contains("Contact", StringComparison.OrdinalIgnoreCase)
                ? "SRC.Contact"
                : "SRC.Account",
            _ => string.Empty
        };
    }

    private static string BuildKey(IReadOnlyDictionary<string, object?> values)
    {
        var preferred = new[]
        {
            "ProjectId", "ExternalId", "QuoteId", "BidId", "ItemNumber", "AccountId", "CONTACTID", "POID", "LineUID"
        };

        var parts = new List<string>();
        foreach (var key in preferred)
        {
            if (values.TryGetValue(key, out var value) && value is not null && !string.IsNullOrWhiteSpace(value.ToString()))
            {
                parts.Add($"{key}={value}");
            }
        }

        if (parts.Count > 0)
        {
            return string.Join(" | ", parts);
        }

        var builder = new StringBuilder();
        foreach (var pair in values.Take(3))
        {
            if (pair.Value is null)
            {
                continue;
            }

            if (builder.Length > 0)
            {
                builder.Append(" | ");
            }

            builder.Append(pair.Key);
            builder.Append('=');
            builder.Append(pair.Value);
        }

        return builder.Length == 0 ? "Record" : builder.ToString();
    }
}
