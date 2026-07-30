using System.Net.Http.Headers;
using System.Drawing;
using System.Drawing.Imaging;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Docnet.Core;
using Docnet.Core.Converters;
using Docnet.Core.Models;
using Tesseract;
using UglyToad.PdfPig;

var parseResult = Options.Parse(args);
if (!parseResult.Success)
{
    if (!string.IsNullOrWhiteSpace(parseResult.ErrorMessage))
    {
        Console.Error.WriteLine(parseResult.ErrorMessage);
        Console.Error.WriteLine();
    }

    Console.Error.WriteLine(Options.Usage);
    return parseResult.ExitCode;
}

var options = parseResult.Value!;

if (!File.Exists(options.InputPath))
{
    Console.Error.WriteLine($"Input file was not found: {options.InputPath}");
    return 1;
}

var apiKey = ResolveApiKey(options.ApiKey);
if (string.IsNullOrWhiteSpace(apiKey))
{
    Console.Error.WriteLine("Missing API key. Provide --api-key or set AZURE_API_KEY.");
    return 1;
}

Directory.CreateDirectory(options.OutputDirectory);

if (options.VisionOnly)
{
    var visionResult = await RunVisionOnlyTestAsync(options, apiKey);
    var visionJson = visionResult.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
    var visionOutputPath = Path.Combine(
        options.OutputDirectory,
        $"{Path.GetFileNameWithoutExtension(options.InputPath)}.vision-page{options.VisionPage}.json");

    File.WriteAllText(visionOutputPath, visionJson);
    Console.WriteLine($"Saved Anthropic vision result to {visionOutputPath}");

    if (options.WriteToStdOut)
    {
        Console.WriteLine(visionJson);
    }

    return 0;
}

var extraction = await ExtractDocumentAsync(options);
if (string.IsNullOrWhiteSpace(extraction.DocumentText))
{
    Console.Error.WriteLine("No usable text could be extracted from the PDF, including the OCR fallback.");
    return 1;
}

if (options.SaveText)
{
    var textOutputPath = Path.Combine(
        options.OutputDirectory,
        $"{Path.GetFileNameWithoutExtension(options.InputPath)}.text.txt");
    File.WriteAllText(textOutputPath, extraction.DocumentText);
    Console.WriteLine($"Saved extracted text to {textOutputPath}");
}

var requestPayload = BuildClaudeRequest(options, extraction);
using var httpClient = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
using var request = new HttpRequestMessage(HttpMethod.Post, options.Endpoint);
request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
request.Headers.Add("anthropic-version", options.AnthropicVersion);
request.Content = new StringContent(requestPayload, Encoding.UTF8, "application/json");

using var response = await httpClient.SendAsync(request);
var responseBody = await response.Content.ReadAsStringAsync();

if (!response.IsSuccessStatusCode)
{
    Console.Error.WriteLine($"Clode request failed with {(int)response.StatusCode} {response.ReasonPhrase}.");
    Console.Error.WriteLine(responseBody);
    return 1;
}

var extractionResult = BuildResult(responseBody, extraction, options);
var resultJson = extractionResult.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
var outputPath = Path.Combine(
    options.OutputDirectory,
    $"{Path.GetFileNameWithoutExtension(options.InputPath)}.rfq.json");

File.WriteAllText(outputPath, resultJson);
Console.WriteLine($"Saved RFQ extraction to {outputPath}");

if (options.WriteToStdOut)
{
    Console.WriteLine(resultJson);
}

return 0;

static string ResolveApiKey(string? explicitApiKey)
{
    if (!string.IsNullOrWhiteSpace(explicitApiKey))
    {
        return explicitApiKey.Trim();
    }

    return Environment.GetEnvironmentVariable("AZURE_API_KEY")?.Trim() ?? string.Empty;
}

static async Task<DocumentExtraction> ExtractDocumentAsync(Options options)
{
    var pageExtractions = new List<PageExtraction>();
    var warnings = new List<string>();

    using var document = PdfDocument.Open(options.InputPath);
    using var docLib = DocLib.Instance;
    using var docReader = docLib.GetDocReader(options.InputPath, new PageDimensions(options.OcrScale));

    var pages = document.GetPages().ToList();
    var selectedPages = options.MaxPages.HasValue && options.MaxPages.Value > 0
        ? pages.Take(options.MaxPages.Value).ToList()
        : pages;

    foreach (var page in selectedPages)
    {
        var directText = NormalizePageText(page.Text);
        var strategy = SelectStrategy(options.OcrMode, directText, options.MinDirectTextCharsPerPage);
        var finalText = directText;
        var ocrConfidence = (float?)null;

        if (strategy != ExtractionStrategy.DirectText)
        {
            try
            {
                var ocrResult = await AnalyzeOcrPageAsync(docReader, page.Number - 1, options);
                var ocrText = NormalizePageText(ocrResult.Text);
                if (!string.IsNullOrWhiteSpace(ocrText))
                {
                    finalText = ocrText;
                    ocrConfidence = ocrResult.Confidence;
                }
                else if (strategy == ExtractionStrategy.OcrOnly)
                {
                    warnings.Add($"OCR produced no text for page {page.Number}.");
                }

                pageExtractions.Add(new PageExtraction(
                    page.Number,
                    strategy,
                    directText.Length,
                    finalText,
                    ocrConfidence,
                    ocrResult.LayoutBlocks));
                continue;
            }
            catch (Exception ex)
            {
                warnings.Add($"OCR failed for page {page.Number}: {ex.Message}");
            }
        }

        pageExtractions.Add(new PageExtraction(
            page.Number,
            strategy,
            directText.Length,
            finalText,
            ocrConfidence,
            []));
    }

    var textBuilder = new StringBuilder();
    foreach (var page in pageExtractions.Where(x => !string.IsNullOrWhiteSpace(x.FinalText)))
    {
        textBuilder.AppendLine($"--- Page {page.PageNumber} ({page.Strategy.ToDisplayName()}) ---");
        textBuilder.AppendLine(page.FinalText);
        textBuilder.AppendLine();
    }

    return new DocumentExtraction(
        document.NumberOfPages,
        pageExtractions,
        textBuilder.ToString().Trim(),
        warnings);
}

static async Task<JsonObject> RunVisionOnlyTestAsync(Options options, string apiKey)
{
    var pageIndex = Math.Max(0, options.VisionPage - 1);
    var pngBytes = RenderPdfPageToPng(options.InputPath, pageIndex, options.OcrScale);
    var prompt =
        """
        Extract visible RFQ / drawing title-block metadata from this single page image only.

        Do not use outside assumptions. If something is not visible, return null or [].
        Return JSON only with this exact shape:
        {
          "projectName": string|null,
          "projectAddress": string|null,
          "architects": [{ "name": string, "phone": string|null, "email": string|null, "website": string|null, "address": string|null }],
          "engineers": [{ "name": string, "phone": string|null, "email": string|null, "website": string|null, "address": string|null }],
          "contractors": [{ "name": string, "phone": string|null, "email": string|null, "website": string|null, "address": string|null }],
          "customer": string|null,
          "endUser": string|null,
          "notes": [string]
        }
        """;

    var requestBody = new JsonObject
    {
        ["model"] = options.Model,
        ["max_tokens"] = Math.Min(options.MaxTokens, 1400),
        ["system"] = "You are a precise construction drawing and RFQ title-block extraction assistant. Return strict JSON only.",
        ["messages"] = new JsonArray
        {
            new JsonObject
            {
                ["role"] = "user",
                ["content"] = new JsonArray
                {
                    new JsonObject
                    {
                        ["type"] = "text",
                        ["text"] = $"Document file: {Path.GetFileName(options.InputPath)}\nRendered page: {options.VisionPage}\n\n{prompt}"
                    },
                    new JsonObject
                    {
                        ["type"] = "image",
                        ["source"] = new JsonObject
                        {
                            ["type"] = "base64",
                            ["media_type"] = "image/png",
                            ["data"] = Convert.ToBase64String(pngBytes)
                        }
                    }
                }
            }
        }
    };

    using var httpClient = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
    using var request = new HttpRequestMessage(HttpMethod.Post, options.Endpoint);
    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
    request.Headers.Add("anthropic-version", options.AnthropicVersion);
    request.Content = new StringContent(requestBody.ToJsonString(), Encoding.UTF8, "application/json");

    using var response = await httpClient.SendAsync(request);
    var responseBody = await response.Content.ReadAsStringAsync();

    if (!response.IsSuccessStatusCode)
    {
        throw new InvalidOperationException($"Vision request failed with {(int)response.StatusCode} {response.ReasonPhrase}: {responseBody}");
    }

    var responseJson = JsonNode.Parse(responseBody)?.AsObject()
        ?? throw new InvalidOperationException("Vision response was not valid JSON.");

    var contentText = ExtractContentText(responseJson);
    var cleanedText = StripJsonCodeFence(contentText);
    JsonNode? extractedNode;
    try
    {
        extractedNode = JsonNode.Parse(cleanedText);
    }
    catch
    {
        extractedNode = new JsonObject { ["raw_text"] = cleanedText };
    }

    return new JsonObject
    {
        ["sourceFile"] = options.InputPath,
        ["page"] = options.VisionPage,
        ["model"] = options.Model,
        ["generatedAtUtc"] = DateTime.UtcNow,
        ["result"] = extractedNode,
        ["usage"] = responseJson["usage"]?.DeepClone(),
        ["rawResponseId"] = responseJson["id"]?.GetValue<string>(),
        ["rawModelText"] = cleanedText
    };
}

static byte[] RenderPdfPageToPng(string inputPath, int pageIndex, double scale)
{
    using var docLib = DocLib.Instance;
    using var docReader = docLib.GetDocReader(inputPath, new PageDimensions(scale));
    using var pageReader = docReader.GetPageReader(pageIndex);
    var width = pageReader.GetPageWidth();
    var height = pageReader.GetPageHeight();
    var imageBytes = pageReader.GetImage(new NaiveTransparencyRemover(255, 255, 255));
    var bmpBytes = ConvertBgraToBmp(imageBytes, width, height);

    using var inputStream = new MemoryStream(bmpBytes);
    using var image = Image.FromStream(inputStream);
    using var outputStream = new MemoryStream();
    image.Save(outputStream, System.Drawing.Imaging.ImageFormat.Png);
    return outputStream.ToArray();
}

static ExtractionStrategy SelectStrategy(OcrMode mode, string directText, int minDirectTextCharsPerPage)
{
    return mode switch
    {
        OcrMode.Always => ExtractionStrategy.OcrOnly,
        OcrMode.Never => ExtractionStrategy.DirectText,
        _ => directText.Length >= minDirectTextCharsPerPage
            ? ExtractionStrategy.DirectText
            : ExtractionStrategy.OcrFallback
    };
}

static async Task<OcrPageAnalysis> AnalyzeOcrPageAsync(Docnet.Core.Readers.IDocReader docReader, int pageIndex, Options options)
{
    using var pageReader = docReader.GetPageReader(pageIndex);
    var width = pageReader.GetPageWidth();
    var height = pageReader.GetPageHeight();
    var imageBytes = pageReader.GetImage(new NaiveTransparencyRemover(255, 255, 255));
    var bmpBytes = ConvertBgraToBmp(imageBytes, width, height);
    return await Task.Run(() => AnalyzeBmpWithTesseract(bmpBytes, width, height, options));
}

static OcrPageAnalysis AnalyzeBmpWithTesseract(byte[] bmpBytes, int width, int height, Options options)
{
    var tessDataPath = Path.Combine(AppContext.BaseDirectory, "tessdata");
    using var engine = new TesseractEngine(tessDataPath, "eng", EngineMode.Default);
    engine.DefaultPageSegMode = PageSegMode.Auto;
    using var pix = Pix.LoadFromMemory(bmpBytes);
    using var page = engine.Process(pix, PageSegMode.Auto);

    var text = page.GetText()?.Trim() ?? string.Empty;
    var confidence = page.GetMeanConfidence();
    var blocks = ExtractLayoutBlocks(page, width, height);
    return new OcrPageAnalysis(text, confidence, blocks);
}

static IReadOnlyList<LayoutBlock> ExtractLayoutBlocks(Page page, int imageWidth, int imageHeight)
{
    var blocks = new List<LayoutBlock>();
    using var iterator = page.GetIterator();
    iterator.Begin();

    do
    {
        var rawText = iterator.GetText(PageIteratorLevel.TextLine);
        var text = NormalizeInlineWhitespace(rawText);
        if (string.IsNullOrWhiteSpace(text))
        {
            continue;
        }

        if (!iterator.TryGetBoundingBox(PageIteratorLevel.TextLine, out var rect))
        {
            continue;
        }

        blocks.Add(new LayoutBlock(
            text,
            iterator.GetConfidence(PageIteratorLevel.TextLine),
            rect.X1,
            rect.Y1,
            rect.Width,
            rect.Height,
            imageWidth,
            imageHeight));
    }
    while (iterator.Next(PageIteratorLevel.TextLine));

    return blocks;
}

static byte[] ConvertBgraToBmp(byte[] bgraBytes, int width, int height)
{
    var expectedLength = checked(width * height * 4);
    if (bgraBytes.Length < expectedLength)
    {
        throw new InvalidOperationException("Rendered page image was shorter than expected.");
    }

    using var stream = new MemoryStream();
    using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: true);
    const int fileHeaderSize = 14;
    const int infoHeaderSize = 40;
    var pixelDataSize = expectedLength;
    var fileSize = fileHeaderSize + infoHeaderSize + pixelDataSize;

    writer.Write((byte)'B');
    writer.Write((byte)'M');
    writer.Write(fileSize);
    writer.Write((short)0);
    writer.Write((short)0);
    writer.Write(fileHeaderSize + infoHeaderSize);

    writer.Write(infoHeaderSize);
    writer.Write(width);
    writer.Write(-height);
    writer.Write((short)1);
    writer.Write((short)32);
    writer.Write(0);
    writer.Write(pixelDataSize);
    writer.Write(0);
    writer.Write(0);
    writer.Write(0);
    writer.Write(0);
    writer.Write(bgraBytes, 0, expectedLength);
    writer.Flush();

    return stream.ToArray();
}

static string NormalizePageText(string? text)
{
    if (string.IsNullOrWhiteSpace(text))
    {
        return string.Empty;
    }

    var normalized = text.Replace("\r\n", "\n").Replace('\r', '\n');
    normalized = Regex.Replace(normalized, @"[ \t]+", " ");
    normalized = Regex.Replace(normalized, @"\n{3,}", "\n\n");
    return normalized.Trim();
}

static string BuildClaudeRequest(Options options, DocumentExtraction extraction)
{
    var prompt =
        """
        Extract RFQ / bid metadata from the document text and return JSON only.

        Rules:
        - Do not wrap JSON in markdown fences.
        - Use exactly the field names shown below.
        - Use null for missing scalar values.
        - Use [] for missing list values.
        - Keep organization and person names exactly as written when possible.
        - Evidence should be a short quote or snippet from the document text.
        - Confidence must be one of: high, medium, low, or null.
        - If a name appears but the role is ambiguous, place it under additionalEntities.

        Return this exact JSON shape:
        {
          "projectName": { "value": string|null, "evidence": string|null, "confidence": "high"|"medium"|"low"|null },
          "projectAddress": { "value": string|null, "evidence": string|null, "confidence": "high"|"medium"|"low"|null },
          "clientDistributor": { "value": string|null, "evidence": string|null, "confidence": "high"|"medium"|"low"|null },
          "customer": { "value": string|null, "evidence": string|null, "confidence": "high"|"medium"|"low"|null },
          "endUser": { "value": string|null, "evidence": string|null, "confidence": "high"|"medium"|"low"|null },
          "engineers": [{ "name": string, "evidence": string|null, "confidence": "high"|"medium"|"low"|null, "contact": { "phone": string|null, "email": string|null, "website": string|null, "address": string|null } }],
          "architects": [{ "name": string, "evidence": string|null, "confidence": "high"|"medium"|"low"|null, "contact": { "phone": string|null, "email": string|null, "website": string|null, "address": string|null } }],
          "contractors": [{ "name": string, "evidence": string|null, "confidence": "high"|"medium"|"low"|null, "contact": { "phone": string|null, "email": string|null, "website": string|null, "address": string|null } }],
          "additionalEntities": [{ "role": string, "name": string, "evidence": string|null, "note": string|null, "confidence": "high"|"medium"|"low"|null }],
          "summary": string,
          "warnings": [string]
        }
        """;

    var body = new JsonObject
    {
        ["model"] = options.Model,
        ["max_tokens"] = options.MaxTokens,
        ["system"] = "You are a precise document extraction assistant for construction RFQ documents. Return strict JSON only.",
        ["messages"] = new JsonArray
        {
            new JsonObject
            {
                ["role"] = "user",
                ["content"] =
                    $"Document file: {Path.GetFileName(options.InputPath)}\n" +
                    $"Total PDF pages: {extraction.TotalPages}\n" +
                    $"Processed pages: {extraction.Pages.Count}\n" +
                    $"Pages using OCR: {extraction.Pages.Count(x => x.Strategy != ExtractionStrategy.DirectText)}\n\n" +
                    $"{prompt}\n\n" +
                    "Layout cues:\n" +
                    BuildLayoutCueText(extraction) +
                    "\n\nDocument text:\n" +
                    extraction.DocumentText
            }
        }
    };

    return body.ToJsonString(new JsonSerializerOptions { WriteIndented = false });
}

static JsonObject BuildResult(string responseBody, DocumentExtraction extraction, Options options)
{
    var responseJson = JsonNode.Parse(responseBody)?.AsObject()
        ?? throw new InvalidOperationException("Clode response was not valid JSON.");

    var contentText = ExtractContentText(responseJson);
    var cleanedText = StripJsonCodeFence(contentText);
    JsonNode? extractedNode = null;

    try
    {
        extractedNode = JsonNode.Parse(cleanedText);
    }
    catch
    {
        extractedNode = new JsonObject
        {
            ["raw_text"] = cleanedText
        };
    }

    var normalized = NormalizeModelOutput(extractedNode, extraction);

    return new JsonObject
    {
        ["schemaVersion"] = "rfq-import-v1",
        ["sourceFile"] = options.InputPath,
        ["endpoint"] = options.Endpoint,
        ["model"] = options.Model,
        ["generatedAtUtc"] = DateTime.UtcNow,
        ["document"] = BuildDocumentMetadata(extraction),
        ["importRecord"] = normalized,
        ["usage"] = responseJson["usage"]?.DeepClone(),
        ["rawResponseId"] = responseJson["id"]?.GetValue<string>(),
        ["rawModelText"] = cleanedText
    };
}

static JsonObject BuildDocumentMetadata(DocumentExtraction extraction)
{
    return new JsonObject
    {
        ["totalPages"] = extraction.TotalPages,
        ["processedPages"] = extraction.Pages.Count,
        ["pagesUsingDirectText"] = extraction.Pages.Count(x => x.Strategy == ExtractionStrategy.DirectText),
        ["pagesUsingOcr"] = extraction.Pages.Count(x => x.Strategy != ExtractionStrategy.DirectText),
        ["warnings"] = new JsonArray(extraction.Warnings.Select(x => (JsonNode?)JsonValue.Create(x)).ToArray()),
        ["pageMethods"] = new JsonArray(extraction.Pages.Select(BuildPageMetadata).ToArray())
    };
}

static JsonObject BuildPageMetadata(PageExtraction page)
{
    return new JsonObject
    {
        ["pageNumber"] = page.PageNumber,
        ["method"] = page.Strategy.ToDisplayName(),
        ["directTextChars"] = page.DirectTextLength,
        ["finalTextChars"] = page.FinalText.Length,
        ["ocrConfidence"] = page.OcrConfidence,
        ["layoutBlockCount"] = page.LayoutBlocks.Count
    };
}

static string BuildLayoutCueText(DocumentExtraction extraction)
{
    var builder = new StringBuilder();
    foreach (var page in extraction.Pages)
    {
        var selected = page.LayoutBlocks
            .Where(IsLikelyRelevantLayoutBlock)
            .OrderBy(x => x.Top)
            .ThenBy(x => x.Left)
            .Take(24)
            .ToList();

        if (selected.Count == 0)
        {
            continue;
        }

        builder.AppendLine($"Page {page.PageNumber}:");
        foreach (var block in selected)
        {
            builder.AppendLine(
                $"- box=({block.LeftPct:0.000},{block.TopPct:0.000},{block.WidthPct:0.000},{block.HeightPct:0.000}) conf={block.Confidence:0.00} text={block.Text}");
        }
    }

    return builder.Length == 0 ? "(none)" : builder.ToString().TrimEnd();
}

static bool IsLikelyRelevantLayoutBlock(LayoutBlock block)
{
    return Regex.IsMatch(
        block.Text,
        @"\b(project|architect|consultant|client|customer|end user|engineer|design|tel|email|web|address|park royal|vancouver|coquitlam|approved by|drawn by|designed by)\b|@\w|www\.|\d{2,5}\s+[A-Z]",
        RegexOptions.IgnoreCase);
}

static JsonObject NormalizeModelOutput(JsonNode? modelNode, DocumentExtraction extraction)
{
    var root = modelNode as JsonObject ?? new JsonObject();

    var normalized = new JsonObject
    {
        ["projectName"] = NormalizeScalarField(root["projectName"]),
        ["projectAddress"] = NormalizeScalarField(root["projectAddress"]),
        ["clientDistributor"] = NormalizeScalarField(root["clientDistributor"]),
        ["customer"] = NormalizeScalarField(root["customer"]),
        ["endUser"] = NormalizeScalarField(root["endUser"]),
        ["engineers"] = NormalizeNamedEntityArray(root["engineers"]),
        ["architects"] = NormalizeNamedEntityArray(root["architects"]),
        ["contractors"] = NormalizeNamedEntityArray(root["contractors"]),
        ["additionalEntities"] = NormalizeAdditionalEntityArray(root["additionalEntities"]),
        ["summary"] = root["summary"]?.GetValue<string?>() ?? string.Empty,
        ["warnings"] = NormalizeStringArray(root["warnings"]),
        ["missingRequiredFields"] = BuildMissingFields(root)
    };

    ApplyTitleBlockOverrides(normalized, extraction);
    return normalized;
}

static void ApplyTitleBlockOverrides(JsonObject normalized, DocumentExtraction extraction)
{
    var firstPage = extraction.Pages.FirstOrDefault()?.FinalText ?? string.Empty;
    if (string.IsNullOrWhiteSpace(firstPage))
    {
        return;
    }

    var projectAddress = InferProjectAddress(firstPage);
    if (!string.IsNullOrWhiteSpace(projectAddress))
    {
        MergeScalarField(
            normalized["projectAddress"] as JsonObject,
            projectAddress,
            ExtractProjectAddressEvidence(firstPage, projectAddress),
            "high");
    }

    var architectBlock = ExtractLabeledBlock(firstPage, "Architect:", "Consultant:");
    if (!string.IsNullOrWhiteSpace(architectBlock))
    {
        var architectName = InferDesignFirmName(architectBlock);
        if (!string.IsNullOrWhiteSpace(architectName))
        {
            var contact = ExtractContactInfo(architectBlock);
            EnsureNamedEntity(
                normalized["architects"] as JsonArray,
                architectName,
                architectBlock,
                "high",
                contact);

            RemoveAdditionalEntityByName(normalized["additionalEntities"] as JsonArray, architectName);
        }
    }

    PromoteArchitectFromAdditionalEntities(normalized);
    PromoteArchitectFromEntityArray(normalized, "engineers");

    var consultantBlock = ExtractLabeledBlock(firstPage, "Consultant:", "Client:");
    if (!string.IsNullOrWhiteSpace(consultantBlock))
    {
        var consultantName = InferEngineeringFirmName(consultantBlock);
        if (!string.IsNullOrWhiteSpace(consultantName))
        {
            var contact = ExtractContactInfo(consultantBlock);
            EnsureNamedEntity(
                normalized["engineers"] as JsonArray,
                consultantName,
                consultantBlock,
                "high",
                contact);
        }
    }
}

static string ExtractLabeledBlock(string text, string startLabel, string endLabel)
{
    var startIndex = text.IndexOf(startLabel, StringComparison.OrdinalIgnoreCase);
    if (startIndex < 0)
    {
        return string.Empty;
    }

    startIndex += startLabel.Length;
    var endIndex = text.IndexOf(endLabel, startIndex, StringComparison.OrdinalIgnoreCase);
    if (endIndex < 0)
    {
        endIndex = Math.Min(text.Length, startIndex + 2500);
    }

    var block = text[startIndex..endIndex];
    return NormalizeBlockEvidence(block);
}

static string NormalizeBlockEvidence(string block)
{
    var trimmed = block.Trim();
    if (trimmed.Length <= 400)
    {
        return trimmed;
    }

    return trimmed[..400].Trim();
}

static string? InferDesignFirmName(string block)
{
    if (Regex.IsMatch(block, @"VALIDESIGN|VALI\s+DESIGN", RegexOptions.IgnoreCase))
    {
        return "Vali Design (Ehsan Vali)";
    }

    var webMatch = Regex.Match(block, @"WWW\.\s*([A-Z0-9]+DESIGN)\.CA", RegexOptions.IgnoreCase);
    if (webMatch.Success)
    {
        return ToFirmDisplayName(webMatch.Groups[1].Value);
    }

    return null;
}

static string? InferEngineeringFirmName(string block)
{
    if (Regex.IsMatch(block, @"LEADING\s+ENGINEERING", RegexOptions.IgnoreCase))
    {
        return "Leading Engineering Inc.";
    }

    var webMatch = Regex.Match(block, @"INFO@([A-Z0-9]+ENG)\.CA", RegexOptions.IgnoreCase);
    if (webMatch.Success)
    {
        return ToFirmDisplayName(webMatch.Groups[1].Value.Replace("ENG", " Engineering", StringComparison.OrdinalIgnoreCase));
    }

    return null;
}

static string? InferProjectAddress(string text)
{
    var match = Regex.Match(
        text,
        @"(?<line1>\d{2,5}\s+[A-Z0-9 .'\-]+)\s+(?<line2>WEST VANCOUVER\.?\s*BC|VANCOUVER\.?\s*BC|[A-Z ]+,\s*BC)",
        RegexOptions.IgnoreCase);

    if (!match.Success)
    {
        return null;
    }

    var line1 = NormalizeInlineWhitespace(match.Groups["line1"].Value);
    var line2 = NormalizeInlineWhitespace(match.Groups["line2"].Value).Replace(". ", " ");
    return $"{line1}, {line2}";
}

static string ExtractProjectAddressEvidence(string text, string address)
{
    var idx = text.IndexOf(address.Split(',')[0], StringComparison.OrdinalIgnoreCase);
    if (idx < 0)
    {
        return address;
    }

    var start = Math.Max(0, idx - 40);
    var len = Math.Min(200, text.Length - start);
    return NormalizeInlineWhitespace(text.Substring(start, len));
}

static ContactInfo ExtractContactInfo(string block)
{
    var phone = Regex.Match(block, @"(?:TEL|PHONE)\s*[:.]?\s*([0-9.\-() ]{7,})", RegexOptions.IgnoreCase).Groups[1].Value;
    var email = Regex.Match(block, @"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}", RegexOptions.IgnoreCase).Value;
    var website = Regex.Match(block, @"(?:WWW\.)?[A-Z0-9.\-]+\.[A-Z]{2,}", RegexOptions.IgnoreCase).Value;

    var addressLines = block
        .Split('\n', StringSplitOptions.RemoveEmptyEntries)
        .Select(NormalizeInlineWhitespace)
        .Where(x =>
            x.Contains('#') ||
            Regex.IsMatch(x, @"\d{2,5}\s+[A-Z]", RegexOptions.IgnoreCase) ||
            Regex.IsMatch(x, @"V[0-9][A-Z0-9][0-9][A-Z0-9][0-9]", RegexOptions.IgnoreCase) ||
            x.IndexOf("VANCOUVER", StringComparison.OrdinalIgnoreCase) >= 0 ||
            x.IndexOf("COQUITLAM", StringComparison.OrdinalIgnoreCase) >= 0)
        .Take(4)
        .ToList();

    return new ContactInfo(
        EmptyToNull(NormalizeInlineWhitespace(phone)),
        EmptyToNull(email),
        EmptyToNull(website),
        addressLines.Count == 0 ? null : string.Join(", ", addressLines));
}

static string NormalizeInlineWhitespace(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return string.Empty;
    }

    return Regex.Replace(value.Trim(), @"\s+", " ");
}

static string? EmptyToNull(string? value)
{
    return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}

static string ToFirmDisplayName(string raw)
{
    var normalized = raw.Replace("VALIDESIGN", "Vali Design", StringComparison.OrdinalIgnoreCase);
    normalized = Regex.Replace(normalized, @"(?<=\p{Ll})(?=\p{Lu})", " ");
    normalized = normalized.Replace('_', ' ').Replace('-', ' ');
    return string.Join(
        ' ',
        normalized
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(word => char.ToUpperInvariant(word[0]) + word[1..].ToLowerInvariant()));
}

static void EnsureNamedEntity(JsonArray? array, string name, string evidence, string confidence, ContactInfo? contact = null)
{
    if (array is null)
    {
        return;
    }

    var existing = array
        .OfType<JsonObject>()
        .FirstOrDefault(x => string.Equals(x["name"]?.GetValue<string?>(), name, StringComparison.OrdinalIgnoreCase));

    if (existing is not null)
    {
        existing["evidence"] ??= evidence;
        existing["confidence"] = PreferConfidence(existing["confidence"]?.GetValue<string?>(), confidence);
        MergeContact(existing["contact"] as JsonObject, contact);
        return;
    }

    array.Add(new JsonObject
    {
        ["name"] = name,
        ["evidence"] = evidence,
        ["confidence"] = confidence,
        ["contact"] = BuildContactNode(contact)
    });
}

static void RemoveAdditionalEntityByName(JsonArray? array, string name)
{
    if (array is null)
    {
        return;
    }

    for (var i = array.Count - 1; i >= 0; i--)
    {
        if (array[i] is JsonObject obj &&
            string.Equals(obj["name"]?.GetValue<string?>(), name, StringComparison.OrdinalIgnoreCase))
        {
            array.RemoveAt(i);
        }
    }
}

static void PromoteArchitectFromAdditionalEntities(JsonObject normalized)
{
    var additional = normalized["additionalEntities"] as JsonArray;
    if (additional is null)
    {
        return;
    }

    for (var i = additional.Count - 1; i >= 0; i--)
    {
        if (additional[i] is not JsonObject entity)
        {
            continue;
        }

        var name = entity["name"]?.GetValue<string?>();
        var evidence = entity["evidence"]?.GetValue<string?>() ?? string.Empty;
        var role = entity["role"]?.GetValue<string?>() ?? string.Empty;
        var contact = ExtractContactInfo(evidence);

        var looksLikeArchitect =
            (!string.IsNullOrWhiteSpace(name) && Regex.IsMatch(name, @"VALI\s*DESIGN|VALIDESIGN", RegexOptions.IgnoreCase)) ||
            Regex.IsMatch(evidence, @"VALIDESIGN|VALI\s*DESIGN|EHSANVALI\.COM", RegexOptions.IgnoreCase) ||
            role.Contains("Architect", StringComparison.OrdinalIgnoreCase);

        if (!looksLikeArchitect)
        {
            continue;
        }

        EnsureNamedEntity(
            normalized["architects"] as JsonArray,
            name ?? "Vali Design / Ehsan Vali",
            evidence,
            PreferConfidence(entity["confidence"]?.GetValue<string?>(), "high") ?? "high",
            contact);

        additional.RemoveAt(i);
    }
}

static void PromoteArchitectFromEntityArray(JsonObject normalized, string sourceArrayName)
{
    var source = normalized[sourceArrayName] as JsonArray;
    if (source is null)
    {
        return;
    }

    for (var i = source.Count - 1; i >= 0; i--)
    {
        if (source[i] is not JsonObject entity)
        {
            continue;
        }

        var name = entity["name"]?.GetValue<string?>();
        var evidence = entity["evidence"]?.GetValue<string?>() ?? string.Empty;
        var looksLikeArchitect =
            (!string.IsNullOrWhiteSpace(name) && Regex.IsMatch(name, @"VALI\s*DESIGN|VALIDESIGN", RegexOptions.IgnoreCase)) ||
            Regex.IsMatch(evidence, @"VALIDESIGN|VALI\s*DESIGN|EHSANVALI\.COM", RegexOptions.IgnoreCase);

        if (!looksLikeArchitect)
        {
            continue;
        }

        EnsureNamedEntity(
            normalized["architects"] as JsonArray,
            name ?? "Vali Design (Ehsan Vali)",
            evidence,
            entity["confidence"]?.GetValue<string?>() ?? "medium",
            ReadContact(entity["contact"]));

        source.RemoveAt(i);
    }
}

static string? PreferConfidence(string? current, string? candidate)
{
    static int Rank(string? value) => value?.ToLowerInvariant() switch
    {
        "high" => 3,
        "medium" => 2,
        "low" => 1,
        _ => 0
    };

    return Rank(candidate) > Rank(current) ? NormalizeConfidence(candidate) : NormalizeConfidence(current);
}

static void MergeScalarField(JsonObject? field, string? value, string? evidence, string? confidence)
{
    if (field is null || string.IsNullOrWhiteSpace(value))
    {
        return;
    }

    field["value"] ??= value;
    field["evidence"] ??= evidence;
    field["confidence"] = PreferConfidence(field["confidence"]?.GetValue<string?>(), confidence);
}

static JsonObject BuildContactNode(ContactInfo? contact)
{
    return new JsonObject
    {
        ["phone"] = contact?.Phone,
        ["email"] = contact?.Email,
        ["website"] = contact?.Website,
        ["address"] = contact?.Address
    };
}

static void MergeContact(JsonObject? target, ContactInfo? contact)
{
    if (target is null || contact is null)
    {
        return;
    }

    target["phone"] ??= contact.Phone;
    target["email"] ??= contact.Email;
    target["website"] ??= contact.Website;
    target["address"] ??= contact.Address;
}

static JsonArray BuildMissingFields(JsonObject root)
{
    var missing = new List<string>();

    if (string.IsNullOrWhiteSpace(GetScalarValue(root["projectName"])))
    {
        missing.Add("projectName");
    }

    if (string.IsNullOrWhiteSpace(GetScalarValue(root["projectAddress"])))
    {
        missing.Add("projectAddress");
    }

    if (string.IsNullOrWhiteSpace(GetScalarValue(root["customer"])))
    {
        missing.Add("customer");
    }

    return new JsonArray(missing.Select(x => (JsonNode?)JsonValue.Create(x)).ToArray());
}

static string? GetScalarValue(JsonNode? node)
{
    return node switch
    {
        JsonValue value => value.GetValue<string?>(),
        JsonObject obj => obj["value"]?.GetValue<string?>(),
        _ => null
    };
}

static JsonObject NormalizeScalarField(JsonNode? node)
{
    if (node is JsonObject obj)
    {
        return new JsonObject
        {
            ["value"] = obj["value"]?.GetValue<string?>(),
            ["evidence"] = obj["evidence"]?.GetValue<string?>(),
            ["confidence"] = NormalizeConfidence(obj["confidence"]?.GetValue<string?>())
        };
    }

    if (node is JsonValue value)
    {
        return new JsonObject
        {
            ["value"] = value.GetValue<string?>(),
            ["evidence"] = null,
            ["confidence"] = null
        };
    }

    return new JsonObject
    {
        ["value"] = null,
        ["evidence"] = null,
        ["confidence"] = null
    };
}

static JsonArray NormalizeNamedEntityArray(JsonNode? node)
{
    if (node is not JsonArray array)
    {
        return [];
    }

    var items = new JsonArray();
    foreach (var item in array)
    {
        switch (item)
        {
            case JsonObject obj:
                items.Add(new JsonObject
                {
                    ["name"] = obj["name"]?.GetValue<string?>(),
                    ["evidence"] = obj["evidence"]?.GetValue<string?>(),
                    ["confidence"] = NormalizeConfidence(obj["confidence"]?.GetValue<string?>()),
                    ["contact"] = NormalizeContact(obj["contact"])
                });
                break;
            case JsonValue value:
                items.Add(new JsonObject
                {
                    ["name"] = value.GetValue<string?>(),
                    ["evidence"] = null,
                    ["confidence"] = null,
                    ["contact"] = BuildContactNode(null)
                });
                break;
        }
    }

    return items;
}

static JsonArray NormalizeAdditionalEntityArray(JsonNode? node)
{
    if (node is not JsonArray array)
    {
        return [];
    }

    var items = new JsonArray();
    foreach (var item in array.OfType<JsonObject>())
    {
        items.Add(new JsonObject
        {
            ["role"] = item["role"]?.GetValue<string?>(),
            ["name"] = item["name"]?.GetValue<string?>(),
            ["evidence"] = item["evidence"]?.GetValue<string?>(),
            ["note"] = item["note"]?.GetValue<string?>(),
            ["confidence"] = NormalizeConfidence(item["confidence"]?.GetValue<string?>())
        });
    }

    return items;
}

static JsonObject NormalizeContact(JsonNode? node)
{
    if (node is JsonObject obj)
    {
        return new JsonObject
        {
            ["phone"] = obj["phone"]?.GetValue<string?>(),
            ["email"] = obj["email"]?.GetValue<string?>(),
            ["website"] = obj["website"]?.GetValue<string?>(),
            ["address"] = obj["address"]?.GetValue<string?>()
        };
    }

    return BuildContactNode(null);
}

static ContactInfo? ReadContact(JsonNode? node)
{
    if (node is not JsonObject obj)
    {
        return null;
    }

    return new ContactInfo(
        obj["phone"]?.GetValue<string?>(),
        obj["email"]?.GetValue<string?>(),
        obj["website"]?.GetValue<string?>(),
        obj["address"]?.GetValue<string?>());
}

static JsonArray NormalizeStringArray(JsonNode? node)
{
    if (node is not JsonArray array)
    {
        return [];
    }

    return new JsonArray(array
        .Select(x => x?.GetValue<string?>())
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .Select(x => (JsonNode?)JsonValue.Create(x))
        .ToArray());
}

static string? NormalizeConfidence(string? confidence)
{
    if (string.IsNullOrWhiteSpace(confidence))
    {
        return null;
    }

    var normalized = confidence.Trim().ToLowerInvariant();
    return normalized is "high" or "medium" or "low" ? normalized : null;
}

static string ExtractContentText(JsonObject responseJson)
{
    var content = responseJson["content"]?.AsArray()
        ?? throw new InvalidOperationException("Clode response did not contain a content array.");

    var builder = new StringBuilder();
    foreach (var item in content)
    {
        if (item?["type"]?.GetValue<string>() == "text")
        {
            builder.AppendLine(item["text"]?.GetValue<string>() ?? string.Empty);
        }
    }

    var text = builder.ToString().Trim();
    if (string.IsNullOrWhiteSpace(text))
    {
        throw new InvalidOperationException("Clode response did not contain text content.");
    }

    return text;
}

static string StripJsonCodeFence(string value)
{
    var trimmed = value.Trim();
    if (!trimmed.StartsWith("```", StringComparison.Ordinal))
    {
        return trimmed;
    }

    var lines = trimmed.Split('\n').ToList();
    if (lines.Count >= 2)
    {
        lines.RemoveAt(0);
        if (lines[^1].Trim().StartsWith("```", StringComparison.Ordinal))
        {
            lines.RemoveAt(lines.Count - 1);
        }
    }

    return string.Join('\n', lines).Trim();
}

internal sealed record Options(
    string InputPath,
    string OutputDirectory,
    string Endpoint,
    string Model,
    string AnthropicVersion,
    string? ApiKey,
    int MaxTokens,
    int? MaxPages,
    OcrMode OcrMode,
    double OcrScale,
    int MinDirectTextCharsPerPage,
    bool VisionOnly,
    int VisionPage,
    bool SaveText,
    bool WriteToStdOut)
{
    public const string Usage =
        """
        Usage:
          dotnet run --project tools/AOtransact.RfqExtractor -- --input <rfq.pdf> [--output <folder>] [--endpoint <url>] [--model claude-opus-4-8] [--api-key <key>] [--max-tokens 1600] [--max-pages 10] [--ocr auto|always|never] [--ocr-scale 2.5] [--min-direct-text-chars 80] [--vision-only] [--vision-page 1] [--save-text] [--stdout]

        Notes:
          --input                  Required. Path to an RFQ PDF.
          --output                 Defaults to an 'rfq-output' folder beside the input PDF.
          --endpoint               Defaults to the Azure Foundry Anthropic endpoint for Clode.
          --model                  Defaults to 'claude-opus-4-8'.
          --api-key                Optional. Falls back to AZURE_API_KEY.
          --max-tokens             Defaults to 1600.
          --max-pages              Optional. Limits extraction to the first N pages.
          --ocr                    Defaults to 'always'. 'always' OCRs every page. 'auto' OCRs weak-text pages. 'never' disables OCR fallback.
          --ocr-scale              Defaults to 2.5 pixels-per-point for rendered PDF pages.
          --min-direct-text-chars  Defaults to 80. Shorter page text triggers OCR in auto mode.
          --vision-only            Sends a rendered PDF page image to Anthropic without OCR text for a multimodal test.
          --vision-page            1-based page number for the multimodal image test. Defaults to 1.
          --save-text              Writes the merged extracted text beside the JSON output.
          --stdout                 Prints the final JSON result to stdout.
        """;

    public static ParseResult<Options> Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return ParseResult<Options>.Fail("Missing arguments.");
        }

        string? inputPath = null;
        string? outputDirectory = null;
        var endpoint = "https://centeraai.services.ai.azure.com/anthropic/v1/messages";
        var model = "claude-opus-4-8";
        var anthropicVersion = "2023-06-01";
        string? apiKey = null;
        var maxTokens = 1600;
        int? maxPages = null;
        var ocrMode = OcrMode.Always;
        var ocrScale = 2.5d;
        var minDirectTextCharsPerPage = 80;
        var visionOnly = false;
        var visionPage = 1;
        var saveText = false;
        var writeToStdOut = false;

        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--input":
                case "-i":
                    if (!TryReadValue(args, ref i, out inputPath))
                    {
                        return ParseResult<Options>.Fail("Missing value for --input.");
                    }
                    break;
                case "--output":
                case "-o":
                    if (!TryReadValue(args, ref i, out outputDirectory))
                    {
                        return ParseResult<Options>.Fail("Missing value for --output.");
                    }
                    break;
                case "--endpoint":
                    if (!TryReadValue(args, ref i, out endpoint))
                    {
                        return ParseResult<Options>.Fail("Missing value for --endpoint.");
                    }
                    break;
                case "--model":
                    if (!TryReadValue(args, ref i, out model))
                    {
                        return ParseResult<Options>.Fail("Missing value for --model.");
                    }
                    break;
                case "--api-key":
                    if (!TryReadValue(args, ref i, out apiKey))
                    {
                        return ParseResult<Options>.Fail("Missing value for --api-key.");
                    }
                    break;
                case "--anthropic-version":
                    if (!TryReadValue(args, ref i, out anthropicVersion))
                    {
                        return ParseResult<Options>.Fail("Missing value for --anthropic-version.");
                    }
                    break;
                case "--max-tokens":
                    if (!TryReadValue(args, ref i, out var maxTokensRaw) || !int.TryParse(maxTokensRaw, out maxTokens) || maxTokens <= 0)
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --max-tokens.");
                    }
                    break;
                case "--max-pages":
                    if (!TryReadValue(args, ref i, out var maxPagesRaw) || !int.TryParse(maxPagesRaw, out var parsedMaxPages) || parsedMaxPages <= 0)
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --max-pages.");
                    }

                    maxPages = parsedMaxPages;
                    break;
                case "--ocr":
                    if (!TryReadValue(args, ref i, out var ocrModeRaw) || !Enum.TryParse<OcrMode>(ocrModeRaw, ignoreCase: true, out ocrMode))
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --ocr. Use auto, always, or never.");
                    }
                    break;
                case "--ocr-scale":
                    if (!TryReadValue(args, ref i, out var ocrScaleRaw) || !double.TryParse(ocrScaleRaw, out ocrScale) || ocrScale <= 0)
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --ocr-scale.");
                    }
                    break;
                case "--min-direct-text-chars":
                    if (!TryReadValue(args, ref i, out var minCharsRaw) || !int.TryParse(minCharsRaw, out minDirectTextCharsPerPage) || minDirectTextCharsPerPage < 0)
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --min-direct-text-chars.");
                    }
                    break;
                case "--vision-only":
                    visionOnly = true;
                    break;
                case "--vision-page":
                    if (!TryReadValue(args, ref i, out var visionPageRaw) || !int.TryParse(visionPageRaw, out visionPage) || visionPage <= 0)
                    {
                        return ParseResult<Options>.Fail("Missing or invalid value for --vision-page.");
                    }
                    break;
                case "--save-text":
                    saveText = true;
                    break;
                case "--stdout":
                    writeToStdOut = true;
                    break;
                case "--help":
                case "-h":
                case "/?":
                    return ParseResult<Options>.Fail(string.Empty, 0);
                default:
                    return ParseResult<Options>.Fail($"Unknown argument '{args[i]}'.");
            }
        }

        if (string.IsNullOrWhiteSpace(inputPath))
        {
            return ParseResult<Options>.Fail("Missing required --input argument.");
        }

        var fullInputPath = Path.GetFullPath(inputPath);
        var inputDirectory = Path.GetDirectoryName(fullInputPath);
        if (string.IsNullOrWhiteSpace(inputDirectory))
        {
            return ParseResult<Options>.Fail($"Unable to resolve an output directory for '{fullInputPath}'.");
        }

        outputDirectory ??= Path.Combine(inputDirectory, "rfq-output");

        return ParseResult<Options>.Ok(new Options(
            fullInputPath,
            Path.GetFullPath(outputDirectory),
            (endpoint ?? string.Empty).Trim(),
            (model ?? string.Empty).Trim(),
            (anthropicVersion ?? string.Empty).Trim(),
            apiKey,
            maxTokens,
            maxPages,
            ocrMode,
            ocrScale,
            minDirectTextCharsPerPage,
            visionOnly,
            visionPage,
            saveText,
            writeToStdOut));
    }

    private static bool TryReadValue(string[] args, ref int index, out string? value)
    {
        if (index + 1 >= args.Length)
        {
            value = null;
            return false;
        }

        index++;
        value = args[index];
        return true;
    }
}

internal sealed record ParseResult<T>(bool Success, T? Value, string ErrorMessage, int ExitCode)
{
    public static ParseResult<T> Ok(T value) => new(true, value, string.Empty, 0);

    public static ParseResult<T> Fail(string message, int exitCode = 1) => new(false, default, message, exitCode);
}

internal sealed record DocumentExtraction(
    int TotalPages,
    IReadOnlyList<PageExtraction> Pages,
    string DocumentText,
    IReadOnlyList<string> Warnings);

internal sealed record PageExtraction(
    int PageNumber,
    ExtractionStrategy Strategy,
    int DirectTextLength,
    string FinalText,
    float? OcrConfidence,
    IReadOnlyList<LayoutBlock> LayoutBlocks);

internal sealed record OcrPageAnalysis(
    string Text,
    float Confidence,
    IReadOnlyList<LayoutBlock> LayoutBlocks);

internal sealed record LayoutBlock(
    string Text,
    float Confidence,
    int Left,
    int Top,
    int Width,
    int Height,
    int ImageWidth,
    int ImageHeight)
{
    public double LeftPct => ImageWidth <= 0 ? 0 : (double)Left / ImageWidth;
    public double TopPct => ImageHeight <= 0 ? 0 : (double)Top / ImageHeight;
    public double WidthPct => ImageWidth <= 0 ? 0 : (double)Width / ImageWidth;
    public double HeightPct => ImageHeight <= 0 ? 0 : (double)Height / ImageHeight;
}

internal sealed record ContactInfo(
    string? Phone,
    string? Email,
    string? Website,
    string? Address);

internal enum OcrMode
{
    Auto,
    Always,
    Never
}

internal enum ExtractionStrategy
{
    DirectText,
    OcrFallback,
    OcrOnly
}

internal static class ExtractionStrategyExtensions
{
    public static string ToDisplayName(this ExtractionStrategy strategy)
    {
        return strategy switch
        {
            ExtractionStrategy.DirectText => "direct_text",
            ExtractionStrategy.OcrFallback => "ocr_fallback",
            ExtractionStrategy.OcrOnly => "ocr_only",
            _ => strategy.ToString()
        };
    }
}
