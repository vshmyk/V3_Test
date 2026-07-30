namespace AOtransact.ParspecEmulator.Models;

public sealed class DestinationProjectionPageViewModel
{
    public string ObjectName { get; init; } = string.Empty;
    public string SourceTable { get; init; } = string.Empty;
    public string SourceDescription { get; init; } = string.Empty;
    public IReadOnlyList<string> AvailableSourceTables { get; init; } = Array.Empty<string>();
    public IReadOnlyList<ProjectionFieldViewModel> Fields { get; init; } = Array.Empty<ProjectionFieldViewModel>();
    public IReadOnlyList<DestinationRecordRow> Rows { get; init; } = Array.Empty<DestinationRecordRow>();
    public int DirectFields { get; init; }
    public int DerivedFields { get; init; }
    public int UnresolvedFields { get; init; }
}
