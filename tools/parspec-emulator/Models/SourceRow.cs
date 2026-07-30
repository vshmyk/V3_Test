namespace AOtransact.ParspecEmulator.Models;

public sealed class SourceRow
{
    public string DisplayKey { get; init; } = string.Empty;
    public string Preview { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, object?> Values { get; init; } = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
}
