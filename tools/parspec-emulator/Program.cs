using AOtransact.ParspecEmulator.Models;
using AOtransact.ParspecEmulator.Services;
using System.Net;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ParspecEmulatorOptions>(
    builder.Configuration.GetSection(ParspecEmulatorOptions.SectionName));
builder.Services.AddSingleton<WorkbookMappingService>();

var app = builder.Build();

app.MapGet("/", async (HttpContext context, WorkbookMappingService workbook) =>
{
    var catalog = await ParspecCatalog.BuildAsync(workbook, context.RequestAborted);
    var html = HtmlPageBuilder.RenderHomePage(catalog);
    return Results.Content(html, "text/html; charset=utf-8");
});

app.MapGet("/objects/{objectName}", async (
    HttpContext context,
    string objectName,
    WorkbookMappingService workbook) =>
{
    var catalog = await ParspecCatalog.BuildAsync(workbook, context.RequestAborted);
    var selected = catalog.Objects.FirstOrDefault(o =>
        string.Equals(o.Name, objectName, StringComparison.OrdinalIgnoreCase));

    if (selected is null)
    {
        return Results.NotFound($"Parspec object '{objectName}' was not found.");
    }

    var html = HtmlPageBuilder.RenderObjectPage(selected, catalog.Objects);
    return Results.Content(html, "text/html; charset=utf-8");
});

app.Run();

internal static class ParspecCatalog
{
    public static async Task<ParspecCatalogViewModel> BuildAsync(
        WorkbookMappingService workbook,
        CancellationToken cancellationToken)
    {
        var maps = await workbook.GetObjectMapsAsync(cancellationToken);
        var fields = maps
            .SelectMany(map => map.Fields)
            .Where(field => field.HasDestinationField)
            .Select(field => BuildField(field))
            .Where(field => field is not null)
            .Cast<ParspecFieldViewModel>()
            .ToList();

        var objects = fields
            .GroupBy(field => field.ObjectName, StringComparer.OrdinalIgnoreCase)
            .Select(group => new ParspecObjectViewModel
            {
                Name = group.Key,
                Fields = group
                    .OrderBy(field => field.DisplayFieldName, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(field => field.FullPath, StringComparer.OrdinalIgnoreCase)
                    .ToList()
            })
            .OrderBy(group => GetObjectSortOrder(group.Name))
            .ThenBy(group => group.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new ParspecCatalogViewModel
        {
            Objects = objects
        };
    }

    private static ParspecFieldViewModel? BuildField(MappingField field)
    {
        var path = ExtractDestinationPath(field.ParspecField);
        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        var objectName = NormalizeObjectName(path);
        if (string.IsNullOrWhiteSpace(objectName))
        {
            return null;
        }

        return new ParspecFieldViewModel
        {
            ObjectName = objectName,
            FullPath = path,
            DisplayFieldName = field.DestinationFieldName,
            SourceField = field.SourceField,
            SourceTable = InferSourceTable(path, field)
        };
    }

    private static string InferSourceTable(string path, MappingField field)
    {
        if (!string.IsNullOrWhiteSpace(field.SourceDescription))
        {
            return field.SourceDescription;
        }

        return field.SourceField;
    }

    private static string ExtractDestinationPath(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        var path = raw.Replace('→', '>')
            .Split('>', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .LastOrDefault()
            ?? raw;

        path = path.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .FirstOrDefault()
            ?? path;

        return path.Trim();
    }

    private static string NormalizeObjectName(string path)
    {
        if (path.StartsWith("project.Project.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("Project.", StringComparison.OrdinalIgnoreCase))
        {
            return "Project";
        }

        if (path.StartsWith("opportunities.Opportunity.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("Opportunity.", StringComparison.OrdinalIgnoreCase))
        {
            return "Opportunity";
        }

        if (path.StartsWith("quote.QuoteMetadata.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("QuoteMetadata.", StringComparison.OrdinalIgnoreCase))
        {
            return "QuoteMetadata";
        }

        if (path.StartsWith("bom.BOD.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("Bod.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("BOD.", StringComparison.OrdinalIgnoreCase))
        {
            return "BOD";
        }

        if (path.StartsWith("bom.Bom.", StringComparison.OrdinalIgnoreCase)
            || string.Equals(path, "bom", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("bom.", StringComparison.OrdinalIgnoreCase))
        {
            return "bom";
        }

        if (path.StartsWith("quote.", StringComparison.OrdinalIgnoreCase))
        {
            return path.StartsWith("quote.Lot.", StringComparison.OrdinalIgnoreCase)
                ? "Lot"
                : "quote";
        }

        if (path.StartsWith("rolodex.Company.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("rolodex.CompanyRole.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("rolodex.Contact.", StringComparison.OrdinalIgnoreCase))
        {
            return "rolodex";
        }

        if (path.StartsWith("accounts.", StringComparison.OrdinalIgnoreCase))
        {
            return "accounts";
        }

        if (path.StartsWith("crawlers.", StringComparison.OrdinalIgnoreCase))
        {
            return "crawlers";
        }

        if (path.StartsWith("Address.", StringComparison.OrdinalIgnoreCase)
            || string.Equals(path, "Address", StringComparison.OrdinalIgnoreCase))
        {
            return "Address";
        }

        if (path.StartsWith("FileTag.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("project.FileTag.", StringComparison.OrdinalIgnoreCase))
        {
            return "FileTag";
        }

        if (path.StartsWith("Company.", StringComparison.OrdinalIgnoreCase))
        {
            return "Company";
        }

        if (path.StartsWith("OrderManagementMetadata.", StringComparison.OrdinalIgnoreCase))
        {
            return "OrderManagementMetadata";
        }

        if (path.StartsWith("PurchaseOrderLineMapping.", StringComparison.OrdinalIgnoreCase))
        {
            return "PurchaseOrderLineMapping";
        }

        if (path.StartsWith("po_so_compilation.PurchaseOrderDoc.", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("PurchaseOrderDoc.", StringComparison.OrdinalIgnoreCase))
        {
            return "PurchaseOrderDoc";
        }

        if (path.StartsWith("SalesOrderDoc.", StringComparison.OrdinalIgnoreCase))
        {
            return "SalesOrderDoc";
        }

        if (path.StartsWith("Lot.", StringComparison.OrdinalIgnoreCase))
        {
            return "Lot";
        }

        return string.Empty;
    }

    private static int GetObjectSortOrder(string name)
    {
        return name switch
        {
            "quote" => 1,
            "bom" => 2,
            "Project" => 3,
            "Opportunity" => 4,
            "QuoteMetadata" => 5,
            "BOD" => 6,
            "rolodex" => 7,
            "PurchaseOrderDoc" => 8,
            "PurchaseOrderLineMapping" => 9,
            "OrderManagementMetadata" => 10,
            "SalesOrderDoc" => 11,
            "Address" => 12,
            "FileTag" => 13,
            "Lot" => 14,
            "Company" => 15,
            "accounts" => 16,
            "crawlers" => 17,
            _ => 99
        };
    }
}

internal static class HtmlPageBuilder
{
    public static string RenderHomePage(ParspecCatalogViewModel catalog)
    {
        var body = new StringBuilder();
        body.AppendLine("<section class=\"hero\">");
        body.AppendLine("<p class=\"eyebrow\">Parspec Emulator</p>");
        body.AppendLine("<h1>Parspec object review</h1>");
        body.AppendLine("<p class=\"lede\">Start by reviewing the candidate objects. Each object page shows a blank destination grid with all currently detected fields so we can confirm structure before populating records.</p>");
        body.AppendLine("</section>");

        body.AppendLine("<section class=\"panel\">");
        body.AppendLine("<div class=\"panel-head\">");
        body.AppendLine("<h2>Objects</h2>");
        body.AppendFormat("<span class=\"subtle\">{0} candidate objects detected from the mapping workbook.</span>", catalog.Objects.Count);
        body.AppendLine("</div>");
        body.AppendLine("<div class=\"object-list\">");

        foreach (var item in catalog.Objects)
        {
            body.AppendLine("<a class=\"object-card\" href=\"/objects/" + Uri.EscapeDataString(item.Name) + "\">");
            body.AppendLine("<span class=\"object-name\">" + HtmlEncode(item.Name) + "</span>");
            body.AppendLine("<span class=\"object-meta\">" + item.Fields.Count + " fields</span>");
            body.AppendLine("</a>");
        }

        body.AppendLine("</div>");
        body.AppendLine("</section>");

        return RenderDocument("Parspec Emulator", body.ToString());
    }

    public static string RenderObjectPage(
        ParspecObjectViewModel selected,
        IReadOnlyList<ParspecObjectViewModel> allObjects)
    {
        var body = new StringBuilder();
        body.AppendLine("<section class=\"hero hero-small\">");
        body.AppendLine("<p class=\"eyebrow\"><a href=\"/\">Parspec Emulator</a></p>");
        body.AppendLine("<h1>" + HtmlEncode(selected.Name) + "</h1>");
        body.AppendLine("<p class=\"lede\">Blank review grid for the selected Parspec object. This page is intentionally unpopulated so we can validate the destination field shape first.</p>");
        body.AppendLine("</section>");

        body.AppendLine("<section class=\"stats\">");
        body.Append(StatCard("Object", selected.Name));
        body.Append(StatCard("Detected Fields", selected.Fields.Count.ToString()));
        body.Append(StatCard("Preview Rows", "5 blank"));
        body.AppendLine("</section>");

        body.AppendLine("<section class=\"panel\">");
        body.AppendLine("<div class=\"panel-head\">");
        body.AppendLine("<h2>Switch object</h2>");
        body.AppendLine("<span class=\"subtle\">Move through the object set before we start wiring data into the emulator.</span>");
        body.AppendLine("</div>");
        body.AppendLine("<div class=\"chips\">");
        foreach (var item in allObjects)
        {
            var css = string.Equals(item.Name, selected.Name, StringComparison.OrdinalIgnoreCase)
                ? "chip selected"
                : "chip";
            body.AppendFormat(
                "<a class=\"{0}\" href=\"/objects/{1}\">{2}</a>",
                css,
                Uri.EscapeDataString(item.Name),
                HtmlEncode(item.Name));
        }
        body.AppendLine("</div>");
        body.AppendLine("</section>");

        body.AppendLine("<section class=\"panel\">");
        body.AppendLine("<div class=\"panel-head\">");
        body.AppendLine("<h2>Blank record grid</h2>");
        body.AppendLine("<span class=\"subtle\">All detected destination fields for this object are shown as empty columns.</span>");
        body.AppendLine("</div>");

        if (selected.Fields.Count == 0)
        {
            body.AppendLine("<p>No fields were detected for this object.</p>");
        }
        else
        {
            body.AppendLine("<div class=\"table-scroll\">");
            body.AppendLine("<table class=\"grid matrix\">");
            body.AppendLine("<thead><tr><th class=\"sticky-col\">Row</th>");
            foreach (var field in selected.Fields)
            {
                body.AppendFormat(
                    "<th title=\"{0}\">{1}</th>",
                    HtmlEncode(field.FullPath),
                    HtmlEncode(field.DisplayFieldName));
            }
            body.AppendLine("</tr></thead><tbody>");

            for (var index = 1; index <= 5; index++)
            {
                body.Append("<tr>");
                body.AppendFormat("<td class=\"sticky-col record-key\">Row {0}</td>", index);
                foreach (var _ in selected.Fields)
                {
                    body.Append("<td class=\"empty-cell\"></td>");
                }
                body.AppendLine("</tr>");
            }

            body.AppendLine("</tbody></table>");
            body.AppendLine("</div>");
        }

        body.AppendLine("</section>");

        body.AppendLine("<section class=\"panel\">");
        body.AppendLine("<div class=\"panel-head\">");
        body.AppendLine("<h2>Detected fields</h2>");
        body.AppendLine("<span class=\"subtle\">This is the field inventory behind the blank grid.</span>");
        body.AppendLine("</div>");
        body.AppendLine("<table class=\"grid compact\">");
        body.AppendLine("<thead><tr><th>Field</th><th>Detected Path</th><th>Workbook Source</th></tr></thead><tbody>");
        foreach (var field in selected.Fields)
        {
            body.Append("<tr>");
            body.AppendFormat("<td>{0}</td>", HtmlEncode(field.DisplayFieldName));
            body.AppendFormat("<td>{0}</td>", HtmlEncode(field.FullPath));
            body.AppendFormat("<td>{0}</td>", HtmlEncode(field.SourceField));
            body.AppendLine("</tr>");
        }
        body.AppendLine("</tbody></table>");
        body.AppendLine("</section>");

        return RenderDocument($"{selected.Name} - Parspec Emulator", body.ToString());
    }

    private static string StatCard(string label, string value)
    {
        return $"<div class=\"stat\"><span class=\"subtle\">{HtmlEncode(label)}</span><strong>{HtmlEncode(value)}</strong></div>";
    }

    private static string RenderDocument(string title, string body)
    {
        return $$"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{HtmlEncode(title)}}</title>
  <style>
    :root {
      --bg: #f3efe5;
      --panel: #fffdfa;
      --ink: #1f2a22;
      --muted: #687169;
      --line: #d7d0c2;
      --accent: #1a6a5a;
      --accent-soft: #d8eee7;
      --empty: #f6f1e8;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", "Trebuchet MS", sans-serif;
      background: radial-gradient(circle at top left, #fff8ea, var(--bg) 45%, #ebe4d7 100%);
      color: var(--ink);
    }
    main {
      width: min(1680px, calc(100vw - 28px));
      margin: 0 auto;
      padding: 20px 0 36px;
    }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    .hero {
      background: linear-gradient(135deg, #0f433c 0%, #1a5d55 58%, #d39d54 58.5%, #e9c98d 100%);
      color: white;
      border-radius: 24px;
      padding: 28px 32px;
      box-shadow: 0 16px 36px rgba(31, 42, 34, 0.16);
    }
    .hero-small { margin-bottom: 16px; }
    .eyebrow {
      text-transform: uppercase;
      letter-spacing: 0.12em;
      font-size: 0.78rem;
      opacity: 0.86;
      margin: 0 0 10px;
    }
    .eyebrow a { color: white; }
    h1 {
      margin: 0 0 10px;
      font-size: clamp(2rem, 3.4vw, 3.2rem);
      line-height: 1.04;
    }
    h2 {
      margin: 0;
      font-size: 1.08rem;
    }
    .lede {
      margin: 0;
      max-width: 82ch;
      line-height: 1.5;
    }
    .panel, .stat {
      background: var(--panel);
      border: 1px solid rgba(215, 208, 194, 0.95);
      border-radius: 18px;
      padding: 18px;
      box-shadow: 0 10px 24px rgba(42, 47, 43, 0.06);
    }
    .panel {
      margin-top: 16px;
    }
    .panel-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 12px;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
      gap: 14px;
      margin-top: 16px;
    }
    .stat strong {
      display: block;
      margin-top: 8px;
      font-size: 1.6rem;
    }
    .subtle {
      color: var(--muted);
      font-size: 0.92rem;
    }
    .object-list {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
    }
    .object-card {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 14px 16px;
      background: #fbf7f0;
      color: var(--ink);
      text-decoration: none;
    }
    .object-card:hover {
      background: #f2f8f5;
      border-color: #b8d8cf;
      text-decoration: none;
    }
    .object-name {
      font-weight: 700;
      font-size: 1rem;
    }
    .object-meta {
      color: var(--muted);
      font-size: 0.9rem;
      white-space: nowrap;
    }
    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }
    .chip {
      border-radius: 999px;
      border: 1px solid var(--line);
      background: #f7f2ea;
      padding: 8px 12px;
      font-size: 0.92rem;
      color: var(--ink);
      text-decoration: none;
    }
    .chip.selected {
      background: var(--accent-soft);
      border-color: #afd8cd;
      color: var(--accent);
      font-weight: 600;
    }
    .table-scroll {
      overflow-x: auto;
      border-radius: 14px;
      border: 1px solid var(--line);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      min-width: 980px;
    }
    th, td {
      border-top: 1px solid var(--line);
      border-right: 1px solid #ece5d9;
      padding: 9px 8px;
      text-align: left;
      vertical-align: top;
      font-size: 0.9rem;
      white-space: nowrap;
    }
    th:last-child, td:last-child { border-right: 0; }
    th {
      border-top: 0;
      color: var(--muted);
      font-weight: 700;
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      position: sticky;
      top: 0;
      background: #fbf7f0;
      z-index: 2;
    }
    .compact th, .compact td {
      white-space: normal;
      font-size: 0.88rem;
    }
    .sticky-col {
      position: sticky;
      left: 0;
      z-index: 3;
      background: #fbf7f0;
    }
    td.sticky-col {
      background: #fffdfa;
      font-weight: 600;
    }
    .record-key {
      min-width: 110px;
    }
    .empty-cell {
      background: var(--empty);
      min-width: 140px;
      height: 38px;
    }
    @media (max-width: 960px) {
      main { width: calc(100vw - 16px); }
      .panel-head { flex-direction: column; align-items: flex-start; }
    }
  </style>
</head>
<body>
  <main>
    {{body}}
  </main>
</body>
</html>
""";
    }

    private static string HtmlEncode(string? value) => WebUtility.HtmlEncode(value ?? string.Empty);
}

internal sealed class ParspecCatalogViewModel
{
    public IReadOnlyList<ParspecObjectViewModel> Objects { get; init; } = Array.Empty<ParspecObjectViewModel>();
}

internal sealed class ParspecObjectViewModel
{
    public string Name { get; init; } = string.Empty;
    public IReadOnlyList<ParspecFieldViewModel> Fields { get; init; } = Array.Empty<ParspecFieldViewModel>();
}

internal sealed class ParspecFieldViewModel
{
    public string ObjectName { get; init; } = string.Empty;
    public string FullPath { get; init; } = string.Empty;
    public string DisplayFieldName { get; init; } = string.Empty;
    public string SourceField { get; init; } = string.Empty;
    public string SourceTable { get; init; } = string.Empty;
}
