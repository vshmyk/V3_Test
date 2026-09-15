using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;

namespace AOtransactPostgreSQL;

internal static class Program
{
    private const string ResourceName = "AOtransactPostgreSQL.Capture-PostgreSQLLogicalBatch.ps1";
    private const string WizardResourceName = "AOtransactPostgreSQL.Configure-AOtransactPostgreSQL.ps1";

    public static int Main(string[] args)
    {
        try
        {
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

            using var executionLock = TryAcquireExecutionLock(configPath);
            if (executionLock is null)
            {
                Console.Error.WriteLine($"Another AOtransactPostgreSQL process is already using config: {configPath}");
                return 3;
            }

            var scriptPath = ExtractScript(ResourceName, "Capture-PostgreSQLLogicalBatch");
            return RunPowerShell(scriptPath, ["-ConfigPath", configPath], Path.GetDirectoryName(configPath));
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine($"AOtransactPostgreSQL failed: {exception.Message}");
            return 1;
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
        Console.WriteLine("AOtransactPostgreSQL 1.8.1");
        Console.WriteLine("Usage: AOtransactPostgreSQL.exe [--config <path>]");
        Console.WriteLine("       AOtransactPostgreSQL.exe --wizard [--config <path>]");
        Console.WriteLine("Default config: aotransact-postgresql.config.json beside the executable");
    }
}
