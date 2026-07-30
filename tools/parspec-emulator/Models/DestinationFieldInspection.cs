namespace AOtransact.ParspecEmulator.Models;

public sealed class DestinationFieldInspection
{
    public string ParspecField { get; init; } = string.Empty;
    public string ValueDisplay { get; init; } = string.Empty;
    public string ResolutionLabel { get; init; } = string.Empty;
    public string ResolutionCssClass { get; init; } = string.Empty;
    public string SourceField { get; init; } = string.Empty;
    public string MappingStatus { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
}
