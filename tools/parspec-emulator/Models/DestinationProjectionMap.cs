namespace AOtransact.ParspecEmulator.Models;

public sealed class DestinationProjectionMap
{
    public string EntityFamily { get; init; } = string.Empty;
    public string ObjectName { get; init; } = string.Empty;
    public string SourceTable { get; init; } = string.Empty;
    public string SourceDescription { get; init; } = string.Empty;
    public IReadOnlyList<MappingField> Fields { get; init; } = Array.Empty<MappingField>();
}
