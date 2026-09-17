using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text.Json;

namespace AOtransactPostgreSQL;

internal static class Program
{
    private const string ResourceName = "AOtransactPostgreSQL.Capture-PostgreSQLLogicalBatch.ps1";
    private const string WizardResourceName = "AOtransactPostgreSQL.Configure-AOtransactPostgreSQL.ps1";

    public static int Main(string[] args)
    {
        try
        {
            if (args.Contains("--licenses"))
            {
                using var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("AOtransactPostgreSQL.ThirdPartyNotices")!;
                using var reader = new StreamReader(resource);
                Console.Write(reader.ReadToEnd());
                return 0;
            }
            if (args.Any(arg => arg is "--help" or "-h" or "/?"))
            {
                PrintUsage();
                return 0;
            }

            var configPath = GetConfigPath(args);
            if (args.Any(arg => string.Equals(arg, "--wizard", StringComparison.OrdinalIgnoreCase)))
            {
                return RunWizard(args, configPath);
            }
            if (!File.Exists(configPath))
            {
                Console.Error.WriteLine($"Config file not found: {configPath}");
                return 2;
            }

            // SFTP helpers run under the capture parent's existing lock; they never access the slot.
            if (args.Contains("--test-sftp") || args.Contains("--test-sftp-transfer") || args.Contains("--sftp-upload"))
            {
                var transport = NativeSftp.FromConfig(configPath);
                if (args.Contains("--test-sftp-transfer")) transport.TestTransfer();
                else if (args.Contains("--test-sftp")) transport.TestConnection();
                else
                {
                    var receipt = transport.Upload(GetArgument(args, "--local-file"), GetArgument(args, "--remote-name"));
                    var resultPath = GetArgument(args, "--result-file");
                    File.WriteAllText(resultPath, JsonSerializer.Serialize(receipt));
                }
                return 0;
            }

            using var executionLock = TryAcquireExecutionLock(configPath);
            if (executionLock is null)
            {
                Console.Error.WriteLine($"Another AOtransactPostgreSQL process is already using config: {configPath}");
                return 3;
            }

            var scriptPath = ExtractScript(ResourceName, "Capture-PostgreSQLLogicalBatch");
            return RunCaptureBatches(scriptPath, configPath, args.Contains("--single-batch"));
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine($"AOtransactPostgreSQL failed: {exception.Message}");
            return 1;
        }
    }

    private static int RunCaptureBatches(string scriptPath, string configPath, bool singleBatch)
    {
        using var config = JsonDocument.Parse(File.ReadAllText(configPath));
        var capture = config.RootElement.GetProperty("capture");
        var maxBatches = capture.TryGetProperty("max_batches_per_run", out var batchSetting)
            ? batchSetting.GetInt32() : 20;
        var maxSeconds = capture.TryGetProperty("max_run_seconds", out var timeSetting)
            ? timeSetting.GetInt32() : 600;
        if (maxBatches < 1 || maxSeconds < 1)
            throw new ArgumentException("max_batches_per_run and max_run_seconds must be positive integers.");
        if (singleBatch) maxBatches = 1;

        var directory = Path.GetDirectoryName(configPath)!;
        var lastBatchPath = Path.GetFullPath(capture.GetProperty("last_batch_path").GetString()!, directory);
        var slotName = capture.GetProperty("slot_name").GetString();
        var summaryPath = Path.Combine(Path.GetDirectoryName(lastBatchPath)!, "last-run.json");
        var timer = Stopwatch.StartNew();
        var completed = 0;
        long statements = 0;
        var more = false;
        var lastLsn = "";
        string? lastCommit = null;
        var reason = "batch_limit";

        for (var batch = 1; batch <= maxBatches; batch++)
        {
            var result = RunPowerShell(scriptPath,
                ["-ConfigPath", configPath, "-SftpExecutable", Environment.ProcessPath!], directory);
            if (result != 0)
            {
                SaveSummary("batch_failed", result);
                return result;
            }

            using var metadata = JsonDocument.Parse(File.ReadAllText(lastBatchPath));
            var root = metadata.RootElement;
            if (root.GetProperty("slot_name").GetString() != slotName)
                throw new InvalidOperationException("Batch metadata belongs to a different logical slot.");
            more = root.GetProperty("batch_limit_reached").GetBoolean();
            lastLsn = root.GetProperty("slot_confirmed_flush_lsn_after").GetString()!;
            if (more && lastLsn == root.GetProperty("slot_confirmed_flush_lsn_before").GetString())
                throw new InvalidOperationException("Batch limit reached without checkpoint progress; refusing to loop.");
            statements += root.GetProperty("tracked_statement_count").GetInt64();
            completed++;
            if (root.TryGetProperty("last_decoded_commit_utc", out var commit) && commit.ValueKind == JsonValueKind.String)
                lastCommit = commit.GetString();
            Console.WriteLine($"Batch {batch}/{maxBatches}: more WAL hint={more}, latest decoded commit={lastCommit ?? "none"}.");
            if (!more) { reason = "decoder_below_limit"; break; }
            // Stop only between complete batches; never cancel an upload or slot advancement.
            if (timer.Elapsed.TotalSeconds >= maxSeconds) { reason = "time_budget"; break; }
        }

        SaveSummary(reason, 0);
        Console.WriteLine($"Run completed: {completed} batch(es), {statements} statement(s), stop={reason}.");
        return 0;

        void SaveSummary(string stopReason, int exitCode)
        {
            var summary = new
            {
                finished_at_utc = DateTime.UtcNow,
                slot_name = slotName,
                completed_batches = completed,
                total_statements = statements,
                max_batches_per_run = maxBatches,
                max_run_seconds = maxSeconds,
                elapsed_seconds = timer.Elapsed.TotalSeconds,
                stop_reason = stopReason,
                exit_code = exitCode,
                more_wal_hint = more,
                confirmed_flush_lsn = lastLsn,
                last_decoded_commit_utc = lastCommit
            };
            Directory.CreateDirectory(Path.GetDirectoryName(summaryPath)!);
            File.WriteAllText(summaryPath + ".tmp", JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            File.Move(summaryPath + ".tmp", summaryPath, true);
        }
    }

    private static FileStream? TryAcquireExecutionLock(string configPath)
    {
        var lockPath = configPath + ".run.lock";
        try
        {
            var stream = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            stream.SetLength(0);
            using var writer = new StreamWriter(stream, leaveOpen: true);
            writer.WriteLine($"pid={Environment.ProcessId}");
            writer.WriteLine($"started_utc={DateTime.UtcNow:O}");
            writer.Flush();
            stream.Flush(true);
            return stream;
        }
        catch (IOException)
        {
            return null;
        }
    }

    private static int RunWizard(string[] args, string configPath)
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        if (!principal.IsInRole(WindowsBuiltInRole.Administrator))
        {
            var executable = Environment.ProcessPath
                ?? throw new InvalidOperationException("Could not determine executable path for elevation.");
            var startInfo = new ProcessStartInfo
            {
                FileName = executable,
                UseShellExecute = true,
                Verb = "runas"
            };
            foreach (var argument in args)
            {
                startInfo.ArgumentList.Add(argument);
            }
            Process.Start(startInfo);
            return 0;
        }

        var wizardPath = ExtractScript(WizardResourceName, "Configure-AOtransactPostgreSQL");
        return RunPowerShell(
            wizardPath,
            ["-PackageDirectory", AppContext.BaseDirectory, "-ConfigPath", configPath],
            AppContext.BaseDirectory);
    }

    private static int RunPowerShell(string scriptPath, IEnumerable<string> arguments, string? workingDirectory)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = FindPowerShell(),
            UseShellExecute = false,
            WorkingDirectory = workingDirectory ?? AppContext.BaseDirectory
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(scriptPath);
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("PowerShell process could not be started.");
        process.WaitForExit();
        return process.ExitCode;
    }

    private static string GetConfigPath(string[] args)
    {
        for (var index = 0; index < args.Length; index++)
        {
            if (!string.Equals(args[index], "--config", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            if (index + 1 >= args.Length)
            {
                throw new ArgumentException("--config requires a file path.");
            }
            return Path.GetFullPath(args[index + 1]);
        }

        return Path.Combine(AppContext.BaseDirectory, "aotransact-postgresql.config.json");
    }

    private static string GetArgument(string[] args, string name)
    {
        var index = Array.IndexOf(args, name);
        if (index < 0 || index + 1 >= args.Length || string.IsNullOrWhiteSpace(args[index + 1]))
            throw new ArgumentException($"{name} requires a value.");
        return args[index + 1];
    }

    private static string ExtractScript(string resourceName, string fileName)
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException($"Embedded resource not found: {resourceName}");
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        var bytes = memory.ToArray();
        var hash = Convert.ToHexString(SHA256.HashData(bytes))[..16];
        var runtimeDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AOTransact",
            "PostgreSQL",
            "runtime");
        Directory.CreateDirectory(runtimeDirectory);
        var scriptPath = Path.Combine(runtimeDirectory, $"{fileName}-{hash}.ps1");
        if (!File.Exists(scriptPath) || !SHA256.HashData(File.ReadAllBytes(scriptPath)).SequenceEqual(SHA256.HashData(bytes)))
        {
            var temporaryPath = scriptPath + ".tmp";
            File.WriteAllBytes(temporaryPath, bytes);
            File.Move(temporaryPath, scriptPath, true);
        }
        return scriptPath;
    }

    private static string FindPowerShell()
    {
        var systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var windowsPowerShell = Path.Combine(systemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (File.Exists(windowsPowerShell))
        {
            return windowsPowerShell;
        }
        return "pwsh.exe";
    }

    private static void PrintUsage()
    {
        Console.WriteLine("AOtransactPostgreSQL 2.0.0");
        Console.WriteLine("Usage: AOtransactPostgreSQL.exe [--config <path>] [--single-batch]");
        Console.WriteLine("       AOtransactPostgreSQL.exe --wizard [--config <path>]");
        Console.WriteLine("       AOtransactPostgreSQL.exe --test-sftp [--config <path>]");
        Console.WriteLine("       AOtransactPostgreSQL.exe --test-sftp-transfer [--config <path>]");
        Console.WriteLine("       AOtransactPostgreSQL.exe --licenses");
        Console.WriteLine("Default config: aotransact-postgresql.config.json beside the executable");
    }
}
