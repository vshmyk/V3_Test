using AOtransact.ParspecEmulator.Models;
using Microsoft.Extensions.Options;
using System.IO.Compression;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace AOtransact.ParspecEmulator.Services;

public sealed class WorkbookMappingService
{
    private readonly ParspecEmulatorOptions _options;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private IReadOnlyList<SourceObjectMap>? _cache;

    public WorkbookMappingService(IOptions<ParspecEmulatorOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<SourceObjectMap>> GetObjectMapsAsync(CancellationToken cancellationToken)
    {
        if (_cache is not null)
        {
            return _cache;
        }

        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_cache is null)
            {
                _cache = await LoadWorkbookAsync(cancellationToken);
            }
        }
        finally
        {
            _gate.Release();
        }

        return _cache;
    }

    public async Task<SourceObjectMap?> GetObjectMapAsync(string objectName, CancellationToken cancellationToken)
    {
        var maps = await GetObjectMapsAsync(cancellationToken);
        return maps.FirstOrDefault(m => string.Equals(m.Name, objectName, StringComparison.OrdinalIgnoreCase));
    }

    public async Task<IReadOnlyList<DestinationProjectionMap>> GetDestinationProjectionsAsync(CancellationToken cancellationToken)
    {
        var maps = await GetObjectMapsAsync(cancellationToken);

        return maps
            .SelectMany(map => map.Fields
                .Where(field => field.HasDestinationField)
                .GroupBy(field => field.DestinationObject, StringComparer.OrdinalIgnoreCase)
                .Select(group => new DestinationProjectionMap
                {
                    EntityFamily = GetEntityFamily(group.Key),
                    ObjectName = group.Key,
                    SourceTable = map.Name,
                    SourceDescription = map.Description,
                    Fields = group
                        .OrderBy(field => field.DestinationFieldName, StringComparer.OrdinalIgnoreCase)
                        .ToList()
                }))
            .OrderBy(projection => projection.ObjectName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(projection => projection.SourceTable, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private async Task<IReadOnlyList<SourceObjectMap>> LoadWorkbookAsync(CancellationToken cancellationToken)
    {
        var path = _options.WorkbookPath;
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            throw new FileNotFoundException("Mapping workbook not found.", path);
        }

        await using var stream = File.OpenRead(path);
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: false);

        var sharedStrings = LoadSharedStrings(archive);
        var workbook = XDocument.Load(GetEntryStream(archive, "xl/workbook.xml"));
        var relationships = XDocument.Load(GetEntryStream(archive, "xl/_rels/workbook.xml.rels"));

        XNamespace mainNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        XNamespace relNs = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        XNamespace packageNs = "http://schemas.openxmlformats.org/package/2006/relationships";

        var relMap = relationships.Root?
            .Elements(packageNs + "Relationship")
            .ToDictionary(
                e => (string?)e.Attribute("Id") ?? string.Empty,
                e => (string?)e.Attribute("Target") ?? string.Empty,
                StringComparer.OrdinalIgnoreCase)
            ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        var maps = new List<SourceObjectMap>();
        var sheets = workbook.Root?
            .Element(mainNs + "sheets")?
            .Elements(mainNs + "sheet")
            .Where(s => ((string?)s.Attribute("name"))?.StartsWith("CHSC_", StringComparison.OrdinalIgnoreCase) == true)
            .ToList()
            ?? new List<XElement>();

        foreach (var sheet in sheets)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var name = (string?)sheet.Attribute("name") ?? string.Empty;
            var relationId = (string?)sheet.Attribute(relNs + "id") ?? string.Empty;
            if (!relMap.TryGetValue(relationId, out var target))
            {
                continue;
            }

            var sheetDoc = XDocument.Load(GetEntryStream(archive, $"xl/{target}"));
            var rows = ReadRows(sheetDoc, sharedStrings);
            if (rows.Count < 4)
            {
                continue;
            }

            var description = rows
                .FirstOrDefault(r => r.RowNumber == 2)?.GetValue("D")
                ?? rows.FirstOrDefault(r => r.RowNumber == 1)?.GetValue("C")
                ?? string.Empty;

            var fields = rows
                .Where(r => r.RowNumber >= 4 && !string.IsNullOrWhiteSpace(r.GetValue("A")))
                .Select(r => new MappingField
                {
                    SourceField = r.GetValue("A"),
                    SourceDataType = r.GetValue("B"),
                    SourceDescription = r.GetValue("C"),
                    Assessment = r.GetValue("D"),
                    AssessmentNotes = r.GetValue("E"),
                    TransformationRules = r.GetValue("F"),
                    Availability = r.GetValue("G"),
                    ParspecField = r.GetValue("H"),
                    ParspecDataType = r.GetValue("I"),
                    FieldStatus = r.GetValue("J"),
                    Notes = r.GetValue("K"),
                    ChrisNotes = r.GetValue("L"),
                    DestinationObject = ParseDestinationObject(r.GetValue("H")),
                    DestinationFieldName = ParseDestinationFieldName(r.GetValue("H"))
                })
                .ToList();

            maps.Add(new SourceObjectMap
            {
                Name = name,
                Description = description,
                Fields = fields
            });
        }

        return maps;
    }

    private static List<string> LoadSharedStrings(ZipArchive archive)
    {
        var entry = archive.GetEntry("xl/sharedStrings.xml");
        if (entry is null)
        {
            return new List<string>();
        }

        var doc = XDocument.Load(entry.Open());
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        return doc.Root?
            .Elements(ns + "si")
            .Select(si => string.Concat(si.Descendants(ns + "t").Select(t => t.Value)))
            .ToList()
            ?? new List<string>();
    }

    private static List<WorkbookRow> ReadRows(XDocument sheetDoc, IReadOnlyList<string> sharedStrings)
    {
        XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
        var rows = new List<WorkbookRow>();

        foreach (var rowElement in sheetDoc.Root?
                     .Element(ns + "sheetData")?
                     .Elements(ns + "row") ?? Enumerable.Empty<XElement>())
        {
            var rowNumber = (int?)rowElement.Attribute("r") ?? 0;
            var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            foreach (var cell in rowElement.Elements(ns + "c"))
            {
                var reference = (string?)cell.Attribute("r") ?? string.Empty;
                var column = new string(reference.TakeWhile(char.IsLetter).ToArray());
                if (string.IsNullOrWhiteSpace(column))
                {
                    continue;
                }

                values[column] = GetCellValue(cell, ns, sharedStrings);
            }

            rows.Add(new WorkbookRow(rowNumber, values));
        }

        return rows;
    }

    private static string GetCellValue(XElement cell, XNamespace ns, IReadOnlyList<string> sharedStrings)
    {
        var type = (string?)cell.Attribute("t");
        if (string.Equals(type, "s", StringComparison.OrdinalIgnoreCase))
        {
            var indexText = cell.Element(ns + "v")?.Value;
            if (int.TryParse(indexText, out var index) && index >= 0 && index < sharedStrings.Count)
            {
                return sharedStrings[index];
            }

            return string.Empty;
        }

        if (string.Equals(type, "inlineStr", StringComparison.OrdinalIgnoreCase))
        {
            return string.Concat(cell.Descendants(ns + "t").Select(t => t.Value));
        }

        return cell.Element(ns + "v")?.Value ?? string.Empty;
    }

    private static Stream GetEntryStream(ZipArchive archive, string path)
    {
        var entry = archive.GetEntry(path)
            ?? throw new InvalidOperationException($"Workbook entry '{path}' was not found.");
        return entry.Open();
    }

    private static string ParseDestinationObject(string rawField)
    {
        var path = ExtractDestinationPath(rawField);
        if (string.IsNullOrWhiteSpace(path))
        {
            return string.Empty;
        }

        var parts = path.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Length <= 1
            ? parts[0]
            : string.Join('.', parts[..^1]);
    }

    private static string ParseDestinationFieldName(string rawField)
    {
        var path = ExtractDestinationPath(rawField);
        if (string.IsNullOrWhiteSpace(path))
        {
            return string.Empty;
        }

        var parts = path.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return parts.Length == 0 ? string.Empty : parts[^1];
    }

    private static string ExtractDestinationPath(string rawField)
    {
        if (string.IsNullOrWhiteSpace(rawField) || rawField.Trim() == "-")
        {
            return string.Empty;
        }

        var candidates = rawField.Replace('→', '>')
            .Split('>', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var preferred = candidates.Length > 0 ? candidates[^1] : rawField;
        preferred = preferred.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .FirstOrDefault() ?? preferred;

        var pattern = @"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+";
        var match = Regex.Match(preferred, pattern);
        if (!match.Success)
        {
            match = Regex.Match(rawField, pattern);
        }

        return match.Success ? match.Value.Trim() : string.Empty;
    }

    private static string GetEntityFamily(string destinationObject)
    {
        if (destinationObject.StartsWith("quote.", StringComparison.OrdinalIgnoreCase))
        {
            return destinationObject.Contains("QuoteMetadata", StringComparison.OrdinalIgnoreCase)
                ? "QuoteMetadata"
                : "quote";
        }

        if (destinationObject.StartsWith("bom.BOD", StringComparison.OrdinalIgnoreCase))
        {
            return "Bod";
        }

        if (destinationObject.StartsWith("bom.", StringComparison.OrdinalIgnoreCase))
        {
            return "bom";
        }

        if (destinationObject.StartsWith("project.", StringComparison.OrdinalIgnoreCase))
        {
            return "Project";
        }

        if (destinationObject.StartsWith("opportunities.", StringComparison.OrdinalIgnoreCase))
        {
            return "Opportunity";
        }

        if (destinationObject.StartsWith("rolodex.", StringComparison.OrdinalIgnoreCase)
            || destinationObject.StartsWith("accounts.", StringComparison.OrdinalIgnoreCase)
            || destinationObject.StartsWith("Address", StringComparison.OrdinalIgnoreCase))
        {
            return "rolodex";
        }

        if (destinationObject.Contains("PurchaseOrderLineMapping", StringComparison.OrdinalIgnoreCase))
        {
            return "PurchaseOrderItem";
        }

        if (destinationObject.Contains("PurchaseOrderDoc", StringComparison.OrdinalIgnoreCase)
            || destinationObject.Contains("OrderManagementMetadata", StringComparison.OrdinalIgnoreCase)
            || destinationObject.Contains("SalesOrderDoc", StringComparison.OrdinalIgnoreCase))
        {
            return "PurchaseOrder";
        }

        return destinationObject;
    }

    private sealed record WorkbookRow(int RowNumber, IReadOnlyDictionary<string, string> Values)
    {
        public string GetValue(string column)
            => Values.TryGetValue(column, out var value) ? value : string.Empty;
    }
}
