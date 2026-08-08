namespace AOtransact.ParspecEmulator.Models;

public sealed class DestinationRecordRow
{
    public string RecordKey { get; init; } = string.Empty;
    public IReadOnlyList<DestinationRecordCell> Cells { get; init; } = Array.Empty<DestinationRecordCell>();
}
