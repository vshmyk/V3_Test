namespace AOtransact.ParspecEmulator.Models;

public sealed class MappingField
{
    public string SourceField { get; init; } = string.Empty;
    public string SourceDataType { get; init; } = string.Empty;
    public string SourceDescription { get; init; } = string.Empty;
    public string Assessment { get; init; } = string.Empty;
    public string AssessmentNotes { get; init; } = string.Empty;
    public string TransformationRules { get; init; } = string.Empty;
    public string Availability { get; init; } = string.Empty;
    public string ParspecField { get; init; } = string.Empty;
    public string ParspecDataType { get; init; } = string.Empty;
    public string FieldStatus { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
    public string ChrisNotes { get; init; } = string.Empty;
    public string DestinationObject { get; init; } = string.Empty;
    public string DestinationFieldName { get; init; } = string.Empty;
    public bool HasDestinationField => !string.IsNullOrWhiteSpace(DestinationObject)
        && !string.IsNullOrWhiteSpace(DestinationFieldName);
}
