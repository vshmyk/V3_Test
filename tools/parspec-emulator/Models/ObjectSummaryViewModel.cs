namespace AOtransact.ParspecEmulator.Models;

public sealed class ObjectSummaryViewModel
{
    public string ObjectName { get; init; } = string.Empty;
    public string ObjectKind { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public int TotalFields { get; init; }
    public int DirectFields { get; init; }
    public int HeuristicFields { get; init; }
    public int UnresolvedFields { get; init; }
    public double DirectRatio { get; init; }
    public double HeuristicRatio { get; init; }
    public double UnresolvedRatio { get; init; }
}
