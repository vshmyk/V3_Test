using Tesseract;

namespace AOtransact.ImageOcr.Core;

public sealed class ImageOcrEngine
{
    private static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".png",
        ".jpg",
        ".jpeg",
        ".tif",
        ".tiff",
        ".bmp"
    };

    public OcrResult RecognizeFile(string imagePath, string language = "eng", PageSegMode pageSegMode = PageSegMode.SingleBlock)
    {
        if (string.IsNullOrWhiteSpace(imagePath))
        {
            throw new ArgumentException("Image path is required.", nameof(imagePath));
        }

        var fullPath = Path.GetFullPath(imagePath);
        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException("Image file not found.", fullPath);
        }

        ValidateExtension(fullPath);

        return ProcessFile(fullPath, language, pageSegMode);
    }

    public async Task<OcrResult> RecognizeBytesAsync(
        byte[] imageBytes,
        string extension,
        string language = "eng",
        PageSegMode pageSegMode = PageSegMode.SingleBlock,
        CancellationToken cancellationToken = default)
    {
        if (imageBytes.Length == 0)
        {
            throw new ArgumentException("Image payload is empty.", nameof(imageBytes));
        }

        extension = NormalizeExtension(extension);
        ValidateExtension("input" + extension);

        var tempFile = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid():N}{extension}");
        await File.WriteAllBytesAsync(tempFile, imageBytes, cancellationToken);

        try
        {
            return ProcessFile(tempFile, language, pageSegMode);
        }
        finally
        {
            if (File.Exists(tempFile))
            {
                File.Delete(tempFile);
            }
        }
    }

    public IReadOnlyList<string> ResolveInputs(string inputPath)
    {
        if (File.Exists(inputPath))
        {
            ValidateExtension(inputPath);
            return [Path.GetFullPath(inputPath)];
        }

        if (!Directory.Exists(inputPath))
        {
            return [];
        }

        return Directory
            .EnumerateFiles(inputPath)
            .Where(path => SupportedExtensions.Contains(Path.GetExtension(path)))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .Select(Path.GetFullPath)
            .ToList();
    }

    private static OcrResult ProcessFile(string fullPath, string language, PageSegMode pageSegMode)
    {
        var safeLanguage = string.IsNullOrWhiteSpace(language) ? "eng" : language.Trim();
        var tessDataPath = Path.Combine(AppContext.BaseDirectory, "tessdata");

        using var engine = new TesseractEngine(tessDataPath, safeLanguage, EngineMode.Default);
        engine.DefaultPageSegMode = pageSegMode;

        using var image = Pix.LoadFromFile(fullPath);
        using var page = engine.Process(image);

        return new OcrResult(
            Path.GetFileName(fullPath),
            page.GetText()?.Trim() ?? string.Empty,
            page.GetMeanConfidence(),
            safeLanguage,
            (int)pageSegMode);
    }

    private static string NormalizeExtension(string extension)
    {
        if (string.IsNullOrWhiteSpace(extension))
        {
            return string.Empty;
        }

        return extension.StartsWith(".", StringComparison.Ordinal) ? extension : "." + extension;
    }

    private static void ValidateExtension(string path)
    {
        var extension = Path.GetExtension(path);
        if (!SupportedExtensions.Contains(extension))
        {
            throw new NotSupportedException(
                $"Unsupported image type '{extension}'. Supported types: {string.Join(", ", SupportedExtensions.OrderBy(x => x))}");
        }
    }
}
