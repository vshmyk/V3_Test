namespace AOtransact.ParspecEmulator.Models;

public sealed class ObjectInspectionViewModel
{
    public int TotalFields { get; init; }
    public int DirectFields { get; init; }
    public int HeuristicFields { get; init; }
    public int UnresolvedFields { get; init; }
    public IReadOnlyList<DestinationFieldInspection> Fields { get; init; } = Array.Empty<DestinationFieldInspection>();
}
