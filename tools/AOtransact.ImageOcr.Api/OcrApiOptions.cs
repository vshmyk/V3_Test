namespace AOtransact.ImageOcr.Api;

internal sealed class OcrApiOptions
{
    public const string SectionName = "OcrApi";

    public string ApiKey { get; set; } = string.Empty;

    public string ApiKeyHeaderName { get; set; } = "X-Api-Key";

    public int MaxUploadBytes { get; set; } = 10 * 1024 * 1024;

    public bool RequireHttps { get; set; } = true;
}
