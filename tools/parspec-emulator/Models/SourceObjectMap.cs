namespace AOtransact.ParspecEmulator.Models;

public sealed class SourceObjectMap
{
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public IReadOnlyList<MappingField> Fields { get; init; } = Array.Empty<MappingField>();
}
