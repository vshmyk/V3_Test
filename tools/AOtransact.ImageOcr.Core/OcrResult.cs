namespace AOtransact.ImageOcr.Core;

public sealed record OcrResult(
    string FileName,
    string Text,
    float Confidence,
    string Language,
    int PageSegmentationMode);
