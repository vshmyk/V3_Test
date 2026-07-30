namespace AOtransact.ParspecEmulator.Models;

public sealed class DestinationObjectSummary
{
    public string ObjectName { get; init; } = string.Empty;
    public int ProjectionCount { get; init; }
    public int TotalFields { get; init; }
    public int DirectFields { get; init; }
    public int DerivedFields { get; init; }
    public int UnresolvedFields { get; init; }
    public IReadOnlyList<string> SourceTables { get; init; } = Array.Empty<string>();
}
