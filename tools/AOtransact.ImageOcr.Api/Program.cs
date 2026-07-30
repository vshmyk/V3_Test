using AOtransact.ImageOcr.Api;
using AOtransact.ImageOcr.Core;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Options;
using Tesseract;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddOptions<OcrApiOptions>()
    .Bind(builder.Configuration.GetSection(OcrApiOptions.SectionName))
    .Validate(options => !string.IsNullOrWhiteSpace(options.ApiKey), "OcrApi:ApiKey is required.")
    .ValidateOnStart();
builder.Services.AddSingleton<ImageOcrEngine>();

var startupOptions = builder.Configuration.GetSection(OcrApiOptions.SectionName).Get<OcrApiOptions>() ?? new OcrApiOptions();
builder.Services.Configure<FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = startupOptions.MaxUploadBytes;
});

var app = builder.Build();
var runtimeOptions = app.Services.GetRequiredService<IOptions<OcrApiOptions>>().Value;

if (runtimeOptions.RequireHttps)
{
    app.UseHttpsRedirection();
}

app.MapGet("/", () => Results.Ok(new
{
    service = "AOtransact.ImageOcr.Api",
    endpoints = new[]
    {
        "GET /health",
        "POST /ocr"
    },
    auth = $"Send {runtimeOptions.ApiKeyHeaderName} header"
}));

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapPost("/ocr", async (
    HttpRequest request,
    ImageOcrEngine engine,
    CancellationToken cancellationToken) =>
{
    if (!request.HasFormContentType)
    {
        return Results.BadRequest(new { error = "Expected multipart/form-data." });
    }

    var form = await request.ReadFormAsync(cancellationToken);
    var file = form.Files["file"];
    if (file is null || file.Length == 0)
    {
        return Results.BadRequest(new { error = "Form field 'file' is required." });
    }

    if (file.Length > runtimeOptions.MaxUploadBytes)
    {
        return Results.BadRequest(new { error = $"File is too large. Max bytes: {runtimeOptions.MaxUploadBytes}." });
    }

    var language = string.IsNullOrWhiteSpace(form["lang"]) ? "eng" : form["lang"].ToString().Trim();
    var psmRaw = form["psm"].ToString();
    var pageSegMode = PageSegMode.SingleBlock;

    if (!string.IsNullOrWhiteSpace(psmRaw))
    {
        if (!int.TryParse(psmRaw, out var psmValue) || !Enum.IsDefined(typeof(PageSegMode), psmValue))
        {
            return Results.BadRequest(new { error = "Form field 'psm' must be a valid Tesseract page segmentation mode integer." });
        }

        pageSegMode = (PageSegMode)psmValue;
    }

    await using var stream = file.OpenReadStream();
    using var memory = new MemoryStream();
    await stream.CopyToAsync(memory, cancellationToken);

    try
    {
        var result = await engine.RecognizeBytesAsync(
            memory.ToArray(),
            Path.GetExtension(file.FileName),
            language,
            pageSegMode,
            cancellationToken);

        return Results.Ok(result);
    }
    catch (Exception ex) when (ex is ArgumentException or NotSupportedException or InvalidOperationException or FileNotFoundException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
})
.RequireApiKey();

app.Run();
