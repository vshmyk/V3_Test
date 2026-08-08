namespace AOtransact.ParspecEmulator.Models;

public sealed class ParspecEmulatorOptions
{
    public const string SectionName = "ParspecEmulator";

    public string WorkbookPath { get; set; } = string.Empty;
    public string SqlConnectionString { get; set; } = string.Empty;
    public string BusinessSqlConnectionString { get; set; } = string.Empty;
    public int DefaultRecordLimit { get; set; } = 25;
}
