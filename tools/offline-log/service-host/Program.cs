using System.Diagnostics;
using System.ServiceProcess;
using System.Text.Json;

internal sealed class ServiceHostSettings
{
    public string ServiceName { get; set; } = "AOTransact";
    public string RunnerExecutablePath { get; set; } = "..\\aotransact-runner\\AOtransact.Runner.exe";
    public string ConfigPath { get; set; } = "..\\production.service.config.json";
    public string WorkingDirectory { get; set; } = "..\\..\\..";
    public int RestartDelaySeconds { get; set; } = 5;
    public bool RestartOnUnexpectedExit { get; set; } = true;
    public string LogPath { get; set; } = ".\\logs\\service-host.log";
}

internal static class Program
{
    private static int Main(string[] args)
    {
        var baseDir = AppContext.BaseDirectory;
        var settingsPath = ResolveSettingsPath(args, baseDir);
        var settings = LoadSettings(settingsPath, baseDir);
        Directory.CreateDirectory(Path.GetDirectoryName(settings.LogPath)!);

        if (args.Any(a => a.Equals("--console", StringComparison.OrdinalIgnoreCase)))
        {
            var runner = new RunnerController(settings);
            Console.CancelKeyPress += (_, e) =>
            {
                e.Cancel = true;
                runner.Stop();
            };

            Log.Write(settings.LogPath, $"Console mode start. settings={settingsPath}");
            runner.Start();
            runner.WaitUntilStopped();
            return 0;
        }

        ServiceBase.Run(new AoTransactWindowsService(settings, settingsPath));
        return 0;
    }

    private static string ResolveSettingsPath(string[] args, string baseDir)
    {
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (args[i].Equals("--settings", StringComparison.OrdinalIgnoreCase))
            {
                return Path.GetFullPath(args[i + 1], baseDir);
            }
        }

        return Path.GetFullPath(Path.Combine(baseDir, "service-host.settings.json"));
    }

    private static ServiceHostSettings LoadSettings(string settingsPath, string baseDir)
    {
        var settings = new ServiceHostSettings();
        if (File.Exists(settingsPath))
        {
            var loaded = JsonSerializer.Deserialize<ServiceHostSettings>(
                File.ReadAllText(settingsPath),
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (loaded is not null)
            {
                settings = loaded;
            }
        }

        settings.RunnerExecutablePath = ResolvePath(settings.RunnerExecutablePath, baseDir);
        settings.ConfigPath = ResolvePath(settings.ConfigPath, baseDir);
        settings.WorkingDirectory = ResolvePath(settings.WorkingDirectory, baseDir);
        settings.LogPath = ResolvePath(settings.LogPath, baseDir);
        settings.RestartDelaySeconds = Math.Max(1, settings.RestartDelaySeconds);
        return settings;
    }

    private static string ResolvePath(string value, string baseDir)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return baseDir;
        }

        return Path.IsPathRooted(value)
            ? value
            : Path.GetFullPath(Path.Combine(baseDir, value));
    }
}

internal sealed class AoTransactWindowsService : ServiceBase
{
    private readonly ServiceHostSettings settings;
    private readonly string settingsPath;
    private readonly RunnerController runner;

    public AoTransactWindowsService(ServiceHostSettings settings, string settingsPath)
    {
        this.settings = settings;
        this.settingsPath = settingsPath;
        runner = new RunnerController(settings);
        ServiceName = settings.ServiceName;
        CanStop = true;
        AutoLog = false;
    }

    protected override void OnStart(string[] args)
    {
        Log.Write(settings.LogPath, $"Service start. settings={settingsPath}");
        runner.Start();
    }

    protected override void OnStop()
    {
        Log.Write(settings.LogPath, "Service stop requested.");
        runner.Stop();
    }
}

internal sealed class RunnerController
{
    private readonly ServiceHostSettings settings;
    private readonly object sync = new();
    private readonly ManualResetEventSlim stopped = new(true);
    private Process? process;
    private bool stopping;
    private Task? supervisorTask;

    public RunnerController(ServiceHostSettings settings)
    {
        this.settings = settings;
    }

    public void Start()
    {
        lock (sync)
        {
            if (supervisorTask is not null)
            {
                return;
            }

            stopping = false;
            stopped.Reset();
            supervisorTask = Task.Run(SuperviseAsync);
        }
    }

    public void Stop()
    {
        lock (sync)
        {
            stopping = true;
            TryKillProcess_NoThrow();
        }

        if (supervisorTask is not null)
        {
            supervisorTask.Wait(TimeSpan.FromSeconds(30));
        }
    }

    public void WaitUntilStopped() => stopped.Wait();

    private async Task SuperviseAsync()
    {
        try
        {
            while (true)
            {
                if (stopping)
                {
                    return;
                }

                process = StartRunnerProcess();
                await process.WaitForExitAsync().ConfigureAwait(false);
                var exitCode = process.ExitCode;
                Log.Write(settings.LogPath, $"Runner exited. code={exitCode}");
                process.Dispose();
                process = null;

                if (stopping || !settings.RestartOnUnexpectedExit)
                {
                    return;
                }

                Log.Write(settings.LogPath, $"Restarting runner in {settings.RestartDelaySeconds}s.");
                await Task.Delay(TimeSpan.FromSeconds(settings.RestartDelaySeconds)).ConfigureAwait(false);
            }
        }
        catch (Exception ex)
        {
            Log.Write(settings.LogPath, $"Service host failure: {ex}");
            throw;
        }
        finally
        {
            stopped.Set();
        }
    }

    private Process StartRunnerProcess()
    {
        ValidateSettings();

        var psi = new ProcessStartInfo
        {
            FileName = settings.RunnerExecutablePath,
            WorkingDirectory = settings.WorkingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        psi.ArgumentList.Add("--config");
        psi.ArgumentList.Add(settings.ConfigPath);

        var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        proc.OutputDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data))
            {
                Log.Write(settings.LogPath, $"runner: {e.Data}");
            }
        };
        proc.ErrorDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data))
            {
                Log.Write(settings.LogPath, $"runner-err: {e.Data}");
            }
        };

        Log.Write(settings.LogPath, $"Starting runner. exe={settings.RunnerExecutablePath}; config={settings.ConfigPath}");
        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
        return proc;
    }

    private void ValidateSettings()
    {
        if (!File.Exists(settings.RunnerExecutablePath))
        {
            throw new FileNotFoundException("Runner executable not found", settings.RunnerExecutablePath);
        }
        if (!File.Exists(settings.ConfigPath))
        {
            throw new FileNotFoundException("Production config not found", settings.ConfigPath);
        }
        if (!Directory.Exists(settings.WorkingDirectory))
        {
            throw new DirectoryNotFoundException($"Working directory not found: {settings.WorkingDirectory}");
        }
    }

    private void TryKillProcess_NoThrow()
    {
        try
        {
            if (process is { HasExited: false })
            {
                Log.Write(settings.LogPath, $"Stopping runner pid={process.Id}");
                process.Kill(entireProcessTree: true);
            }
        }
        catch (Exception ex)
        {
            Log.Write(settings.LogPath, $"Runner stop warning: {ex.Message}");
        }
    }
}

internal static class Log
{
    private static readonly object Sync = new();

    public static void Write(string path, string message)
    {
        var line = $"{DateTime.UtcNow:O} {message}";
        lock (Sync)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.AppendAllText(path, line + Environment.NewLine);
        }
    }
}
