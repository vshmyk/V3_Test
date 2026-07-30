using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Net.Security;
using System.Text;
using System.Text.RegularExpressions;
using Renci.SshNet;

var options = ParseArgs(args);
if (options.ContainsKey("help") || options.ContainsKey("?"))
{
    PrintUsage();
    return 0;
}

var baseDirectory = AppContext.BaseDirectory;
var configPath = options.TryGetValue("config", out var configOverride) && !string.IsNullOrWhiteSpace(configOverride)
    ? Path.GetFullPath(configOverride, Environment.CurrentDirectory)
    : Path.Combine(baseDirectory, "CompTrans.config");

if (!File.Exists(configPath))
{
    Console.Error.WriteLine($"Config not found: {configPath}");
    return 2;
}

var config = CompTransConfig.Load(configPath);
if (options.ContainsKey("set-password"))
{
    config.PromptAndSaveEncryptedPasswords(forcePrompt: true);
    Console.WriteLine("Upload passwords updated in config.");
    return 0;
}

try
{
    await RunAsync(config);
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static async Task RunAsync(CompTransConfig cfg)
{
    cfg.Validate();

    EnsureDirectoryExists(cfg.WorkDir);
    EnsureDirectoryExists(cfg.ArchiveDir);
    EnsureParentDirectoryExists(cfg.StateFile);
    EnsureParentDirectoryExists(cfg.TransactionCurrentFile);
    EnsureParentDirectoryExists(cfg.TransactionFinalFile);
    EnsureParentDirectoryExists(cfg.TempTransactionFile);

    if (cfg.PreDeleteBackupDir)
        TryDeleteDirectory(cfg.BackupDir);

    if (cfg.PreDeleteAllShadows)
        await TryRunBestEffortAsync("vssadmin", "delete shadows /all /quiet", "pre-run shadow cleanup");

    var lastOffset = ReadLastOffset(cfg.StateFile) ?? cfg.InitialOffset;
    Console.WriteLine($"Using transaction offset: {lastOffset}");
    Console.WriteLine($"Tables: {cfg.TableList}");

    string? shadowId = null;
    string? backupLinkPath = null;
    try
    {
        var createShadow = await RunProcessAsync("vssadmin", $"create shadow /for={cfg.SourceDrive}");
        if (createShadow.ExitCode != 0)
            throw new InvalidOperationException($"Failed to create shadow copy.{Environment.NewLine}{createShadow.AllOutput}");

        shadowId = ParseRequired(createShadow.AllOutput, Regexes.ShadowId, "shadow copy ID");
        var shadowDevice = ParseRequired(createShadow.AllOutput, Regexes.ShadowDevice, "shadow copy volume name");

        PrepareBackupLink(cfg.BackupDir, shadowDevice);
        backupLinkPath = cfg.BackupDir;

        var sourceFile = Path.Combine(cfg.BackupDir, cfg.SourceLogRelativePath);
        Console.WriteLine(sourceFile);

        await RunDbtranAsync(cfg.DbtranPath, sourceFile, lastOffset, cfg.TableList, cfg.TransactionCurrentFile, quiet: cfg.DbtranQuiet);
        await RunDbtranToStateAsync(cfg.DbtranPath, sourceFile, lastOffset, cfg.StateTableList, cfg.TempTransactionFile, cfg.StateFile);

        if (lastOffset == cfg.InitialOffset)
            lastOffset = ReadLastOffset(cfg.StateFile) ?? lastOffset;
    }
    finally
    {
        TryDeleteBackupLink(backupLinkPath);
        if (!string.IsNullOrWhiteSpace(shadowId))
            await TryCleanupShadowAsync(shadowId);
        else if (cfg.DeleteOldestShadowAfterRun)
            await TryRunBestEffortAsync("vssadmin", $"delete shadows /for={cfg.SourceDrive} /oldest /quiet", "post-run oldest shadow cleanup");
    }

    CreateFinalTransactionFile(cfg);

    var zipFile = Path.Combine(cfg.WorkDir, $"{lastOffset}.zip");
    CreateSingleFileZip(zipFile, cfg.TransactionFinalFile);

    foreach (var target in cfg.UploadTargets)
    {
        if (!target.Enabled)
            continue;

        var password = cfg.GetOrInitializeUploadPassword(target);
        await UploadFileAsync(cfg, target, zipFile, password);
        Console.WriteLine($"Uploaded zip to {target.Name}: {Path.GetFileName(zipFile)}");
    }

    var archivedZipFile = Path.Combine(cfg.ArchiveDir, Path.GetFileName(zipFile));
    if (File.Exists(archivedZipFile))
        File.Delete(archivedZipFile);
    File.Move(zipFile, archivedZipFile);

    if (cfg.DeleteTrnFilesAfterRun)
        DeleteFilesByPatterns(cfg.WorkDir, cfg.DeleteFilePatterns);

    DeleteOldZipFiles(cfg.ArchiveDir, cfg.ArchiveRetentionDays);
}

static void CreateFinalTransactionFile(CompTransConfig cfg)
{
    switch (cfg.FinalFileMode)
    {
        case FinalFileMode.CurrentOnly:
            CopyFileOverwrite(cfg.TransactionCurrentFile, cfg.TransactionFinalFile);
            return;
        case FinalFileMode.BackupPlusCurrent:
            ConcatenateFiles(cfg.TransactionFinalFile, cfg.TransactionBackupFile, cfg.TransactionCurrentFile);
            return;
        default:
            throw new InvalidOperationException($"Unsupported FINAL_FILE_MODE: {cfg.FinalFileMode}");
    }
}

static void CopyFileOverwrite(string sourcePath, string destinationPath)
{
    if (!File.Exists(sourcePath))
        throw new FileNotFoundException("Transaction file not found.", sourcePath);

    EnsureParentDirectoryExists(destinationPath);
    File.Copy(sourcePath, destinationPath, overwrite: true);
}

static void ConcatenateFiles(string destinationPath, params string?[] sourcePaths)
{
    EnsureParentDirectoryExists(destinationPath);
    using var destination = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None);

    foreach (var sourcePath in sourcePaths)
    {
        if (string.IsNullOrWhiteSpace(sourcePath))
            continue;

        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("Configured source file for concatenation was not found.", sourcePath);

        using var source = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read);
        source.CopyTo(destination);
    }
}

static async Task RunDbtranAsync(string dbtranPath, string sourceFile, string offset, string tableList, string outputFile, bool quiet)
{
    EnsureParentDirectoryExists(outputFile);
    var args = new List<string> { Quote(sourceFile), "-y", "-ir", offset };
    if (quiet)
        args.Add("-q");
    args.AddRange(new[] { "-it", Quote(tableList), "-n", Quote(outputFile) });

    var result = await RunProcessAsync(dbtranPath, string.Join(" ", args));
    if (result.ExitCode != 0)
        throw new InvalidOperationException($"dbtran failed writing {outputFile}.{Environment.NewLine}{result.AllOutput}");
}

static async Task RunDbtranToStateAsync(string dbtranPath, string sourceFile, string offset, string tableList, string outputFile, string stateFile)
{
    EnsureParentDirectoryExists(outputFile);
    EnsureParentDirectoryExists(stateFile);
    var args = string.Join(" ", new[]
    {
        Quote(sourceFile),
        "-y",
        "-ir",
        offset,
        "-it",
        Quote(tableList),
        "-n",
        Quote(outputFile)
    });

    var result = await RunProcessAsync(dbtranPath, args);
    await File.WriteAllTextAsync(stateFile, result.AllOutput);
    if (result.ExitCode != 0)
        throw new InvalidOperationException($"dbtran failed writing state.{Environment.NewLine}{result.AllOutput}");
}

static async Task<ProcessResult> RunProcessAsync(string fileName, string arguments)
{
    var psi = new System.Diagnostics.ProcessStartInfo
    {
        FileName = fileName,
        Arguments = arguments,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };

    using var process = System.Diagnostics.Process.Start(psi)
        ?? throw new InvalidOperationException($"Failed to start process: {fileName}");

    var stdoutTask = process.StandardOutput.ReadToEndAsync();
    var stderrTask = process.StandardError.ReadToEndAsync();
    await process.WaitForExitAsync();
    var stdout = await stdoutTask;
    var stderr = await stderrTask;
    return new ProcessResult(process.ExitCode, stdout, stderr);
}

static async Task TryRunBestEffortAsync(string fileName, string arguments, string operationName)
{
    try
    {
        var result = await RunProcessAsync(fileName, arguments);
        if (result.ExitCode != 0)
            Console.Error.WriteLine($"Warning: {operationName} reported an error.{Environment.NewLine}{result.AllOutput}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Warning: {operationName} failed: {ex.Message}");
    }
}

static string ParseRequired(string text, Regex regex, string label)
{
    var match = regex.Match(text ?? string.Empty);
    if (!match.Success)
        throw new InvalidOperationException($"Could not parse {label} from command output.");
    return match.Groups[1].Value.Trim();
}

static string? ReadLastOffset(string stateFile)
{
    if (!File.Exists(stateFile))
        return null;

    foreach (var line in File.ReadLines(stateFile))
    {
        const string marker = "Transaction log ends at offset ";
        var index = line.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
        if (index < 0)
            continue;

        var value = line[(index + marker.Length)..].Trim();
        if (!string.IsNullOrWhiteSpace(value))
            return value;
    }

    return null;
}

static void PrepareBackupLink(string backupDir, string shadowDevice)
{
    if (Directory.Exists(backupDir))
    {
        var info = new DirectoryInfo(backupDir);
        if ((info.Attributes & FileAttributes.ReparsePoint) == 0)
            throw new InvalidOperationException($"Backup path already exists and is not a symbolic link: {backupDir}");
        info.Delete();
    }

    Directory.CreateSymbolicLink(backupDir, shadowDevice);
}

static void TryDeleteBackupLink(string? backupDir)
{
    if (string.IsNullOrWhiteSpace(backupDir) || !Directory.Exists(backupDir))
        return;

    try
    {
        new DirectoryInfo(backupDir).Delete();
    }
    catch
    {
    }
}

static void TryDeleteDirectory(string directoryPath)
{
    if (!Directory.Exists(directoryPath))
        return;

    try
    {
        Directory.Delete(directoryPath, recursive: false);
    }
    catch
    {
    }
}

static async Task TryCleanupShadowAsync(string shadowId)
{
    try
    {
        var result = await RunProcessAsync("vssadmin", $"delete shadows /Shadow={shadowId} /Quiet");
        if (result.ExitCode != 0)
            Console.Error.WriteLine($"Warning: shadow cleanup reported an error for {shadowId}.{Environment.NewLine}{result.AllOutput}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Warning: failed to clean up shadow copy {shadowId}: {ex.Message}");
    }
}

static void CreateSingleFileZip(string zipPath, string sourceFile)
{
    if (!File.Exists(sourceFile))
        throw new FileNotFoundException("Transaction file not found.", sourceFile);

    EnsureParentDirectoryExists(zipPath);
    if (File.Exists(zipPath))
        File.Delete(zipPath);

    using var archive = ZipFile.Open(zipPath, ZipArchiveMode.Create);
    archive.CreateEntryFromFile(sourceFile, Path.GetFileName(sourceFile), CompressionLevel.Optimal);
}

static void DeleteFilesByPatterns(string workDir, IReadOnlyList<string> patterns)
{
    if (!Directory.Exists(workDir))
        return;

    foreach (var pattern in patterns)
    {
        foreach (var file in Directory.EnumerateFiles(workDir, pattern, SearchOption.TopDirectoryOnly))
        {
            try
            {
                File.Delete(file);
            }
            catch
            {
            }
        }
    }
}

static void DeleteOldZipFiles(string archiveDir, int daysToKeep)
{
    if (!Directory.Exists(archiveDir))
        return;

    var cutoffUtc = DateTime.UtcNow.AddDays(-daysToKeep);
    foreach (var file in new DirectoryInfo(archiveDir).EnumerateFiles("*.zip", SearchOption.TopDirectoryOnly))
    {
        if (file.LastWriteTimeUtc >= cutoffUtc)
            continue;

        try
        {
            file.Delete();
        }
        catch
        {
        }
    }
}

static async Task UploadFileAsync(CompTransConfig cfg, UploadTarget target, string localPath, string password)
{
    if (target.Protocol == TransferProtocol.Sftp)
    {
        await UploadFileToSftpAsync(cfg, target, localPath, password);
        return;
    }

    await UploadFileToFtpsAsync(cfg, target, localPath, password);
}

static async Task UploadFileToFtpsAsync(CompTransConfig cfg, UploadTarget target, string localPath, string password)
{
    var remoteUri = BuildFtpFileUri(target, Path.GetFileName(localPath));
    var request = CreateFtpUploadRequest(remoteUri, target, password);
    var debugLog = cfg.FtpDebugLogPath;
    var previousCallback = ServicePointManager.ServerCertificateValidationCallback;

    LogFtpDebug(debugLog, $"Starting upload target={target.Name} localPath={localPath} remoteUri={remoteUri} ssl={target.EnableSsl} passive={target.UsePassive}");

    try
    {
        if (cfg.FtpSkipCertificateValidationForDebug)
        {
            ServicePointManager.ServerCertificateValidationCallback = static (_, _, _, _) => true;
            LogFtpDebug(debugLog, "Certificate validation bypass is enabled for debug.");
        }

        await using (var requestStream = await request.GetRequestStreamAsync())
        await using (var fileStream = File.OpenRead(localPath))
        {
            LogFtpDebug(debugLog, $"Opened request stream. fileLength={fileStream.Length}");
            await fileStream.CopyToAsync(requestStream);
        }

        using var response = (FtpWebResponse)await request.GetResponseAsync();
        var statusText = $"{(int)response.StatusCode} {(response.StatusDescription ?? string.Empty).Trim()}".Trim();
        LogFtpDebug(debugLog, $"Upload completed. status={statusText}");
        Console.WriteLine($"FTP upload status for {target.Name}: {statusText}");
    }
    catch (WebException ex)
    {
        var ftpResponse = ex.Response as FtpWebResponse;
        var statusText = ftpResponse is null
            ? ex.Status.ToString()
            : $"{(int)ftpResponse.StatusCode} {(ftpResponse.StatusDescription ?? string.Empty).Trim()}".Trim();

        LogFtpDebug(debugLog, $"Upload failed. webStatus={ex.Status} ftpStatus={statusText} message={ex.Message}");
        throw new InvalidOperationException($"FTP upload failed for target '{target.Name}'. {statusText}", ex);
    }
    finally
    {
        ServicePointManager.ServerCertificateValidationCallback = previousCallback;
    }
}

static async Task UploadFileToSftpAsync(CompTransConfig cfg, UploadTarget target, string localPath, string password)
{
    var remotePath = BuildSftpRemotePath(target, Path.GetFileName(localPath));
    var debugLog = cfg.FtpDebugLogPath;
    LogFtpDebug(debugLog, $"Starting SFTP upload target={target.Name} localPath={localPath} remotePath={remotePath} host={target.Host} port={target.Port}");

    try
    {
        using var client = new SftpClient(target.Host, target.Port, target.User, password);
        client.ConnectionInfo.Timeout = TimeSpan.FromMinutes(1);
        client.OperationTimeout = TimeSpan.FromMinutes(5);
        client.Connect();
        LogFtpDebug(debugLog, $"SFTP connected. isConnected={client.IsConnected}");

        await using var fileStream = File.OpenRead(localPath);
        client.UploadFile(fileStream, remotePath, canOverride: true);
        LogFtpDebug(debugLog, $"SFTP upload completed. remotePath={remotePath}");

        client.Disconnect();
    }
    catch (Exception ex)
    {
        LogFtpDebug(debugLog, $"SFTP upload failed. type={ex.GetType().FullName} message={ex.Message}");
        throw new InvalidOperationException($"SFTP upload failed for target '{target.Name}'. {ex.Message}", ex);
    }
}

#pragma warning disable SYSLIB0014
static System.Net.FtpWebRequest CreateFtpUploadRequest(Uri remoteUri, UploadTarget target, string password)
{
    var request = (System.Net.FtpWebRequest)System.Net.WebRequest.Create(remoteUri);
    request.Method = System.Net.WebRequestMethods.Ftp.UploadFile;
    request.Credentials = new System.Net.NetworkCredential(target.User, password);
    request.EnableSsl = target.EnableSsl;
    request.UseBinary = true;
    request.KeepAlive = false;
    request.UsePassive = target.UsePassive;
    request.Proxy = null;
    request.Timeout = (int)TimeSpan.FromMinutes(5).TotalMilliseconds;
    request.ReadWriteTimeout = (int)TimeSpan.FromMinutes(5).TotalMilliseconds;
    return request;
}
#pragma warning restore SYSLIB0014

static Uri BuildFtpFileUri(UploadTarget target, string fileName)
{
    var remoteDir = (target.RemoteDir ?? string.Empty).Trim();
    remoteDir = remoteDir.Replace('\\', '/').Trim('/');
    var path = string.IsNullOrWhiteSpace(remoteDir) ? fileName : $"{remoteDir}/{fileName}";
    return new UriBuilder("ftp", target.Host, target.Port, path).Uri;
}

static string BuildSftpRemotePath(UploadTarget target, string fileName)
{
    var remoteDir = (target.RemoteDir ?? string.Empty).Trim();
    remoteDir = remoteDir.Replace('\\', '/').Trim('/');
    return string.IsNullOrWhiteSpace(remoteDir) ? fileName : $"{remoteDir}/{fileName}";
}

static void LogFtpDebug(string? debugLogPath, string message)
{
    if (string.IsNullOrWhiteSpace(debugLogPath))
        return;

    EnsureParentDirectoryExists(debugLogPath);
    File.AppendAllText(
        debugLogPath,
        $"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff} UTC] {message}{Environment.NewLine}",
        Encoding.UTF8);
}

static void EnsureDirectoryExists(string path)
{
    if (!Directory.Exists(path))
        Directory.CreateDirectory(path);
}

static void EnsureParentDirectoryExists(string filePath)
{
    var parent = Path.GetDirectoryName(filePath);
    if (!string.IsNullOrWhiteSpace(parent) && !Directory.Exists(parent))
        Directory.CreateDirectory(parent);
}

static string Quote(string value)
{
    if (value.Contains('"'))
        value = value.Replace("\"", "\\\"");
    return $"\"{value}\"";
}

static Dictionary<string, string> ParseArgs(string[] args)
{
    var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
        if (!arg.StartsWith("--", StringComparison.Ordinal))
            continue;

        var key = arg[2..];
        if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
        {
            result[key] = args[++i];
        }
        else
        {
            result[key] = "true";
        }
    }

    return result;
}

static void PrintUsage()
{
    Console.WriteLine("CompTransExtractor");
    Console.WriteLine("  --config <path>       Optional config override.");
    Console.WriteLine("  --set-password        Prompt for upload passwords and save encrypted.");
    Console.WriteLine("  --help                Show this help.");
}

sealed class ProcessResult(int exitCode, string standardOutput, string standardError)
{
    public int ExitCode { get; } = exitCode;
    public string StandardOutput { get; } = standardOutput ?? string.Empty;
    public string StandardError { get; } = standardError ?? string.Empty;
    public string AllOutput => string.Join(Environment.NewLine, new[] { StandardOutput, StandardError }
        .Where(s => !string.IsNullOrWhiteSpace(s)));
}

static class Regexes
{
    public static readonly Regex ShadowId = new(@"Shadow Copy ID:\s*(\{[^}]+\})", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    public static readonly Regex ShadowDevice = new(@"Shadow Copy Volume Name:\s*(\\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled);
}

enum FinalFileMode
{
    CurrentOnly,
    BackupPlusCurrent
}

sealed record UploadTarget(
    string Name,
    bool Enabled,
    TransferProtocol Protocol,
    string Host,
    int Port,
    string User,
    bool EnableSsl,
    bool UsePassive,
    string? RemoteDir,
    string PasswordScope,
    string? PasswordEncrypted);

enum TransferProtocol
{
    Ftps,
    Sftp
}

sealed class CompTransConfig
{
    private const string PasswordEntropy = "AOtransact.CompTransExtractor.UploadPassword.v2";
    private readonly string _configPath;
    private readonly Dictionary<string, string> _values;
    private readonly List<string> _rawLines;

    private CompTransConfig(string configPath, Dictionary<string, string> values, List<string> rawLines)
    {
        _configPath = configPath;
        _values = values;
        _rawLines = rawLines;
    }

    public string BackupDir => Require("BACKUP_DIR");
    public string StateFile => Require("STATE_FILE");
    public string TransactionBackupFile => Get("TRANSACTION_BACKUP_FILE") ?? string.Empty;
    public string TransactionCurrentFile => Require("TRANSACTION_CURRENT_FILE");
    public string TransactionFinalFile => Require("TRANSACTION_FINAL_FILE");
    public string TempTransactionFile => Require("TEMP_TRANSACTION_FILE");
    public string WorkDir => Require("WORK_DIR");
    public string ArchiveDir => Require("ARCHIVE_DIR");
    public int ArchiveRetentionDays => GetInt("ARCHIVE_RETENTION_DAYS", 5);
    public string TableList => Require("TABLE_LIST");
    public string StateTableList => Get("STATE_TABLE_LIST") ?? TableList;
    public string DbtranPath => Require("DBTRAN_PATH");
    public bool DbtranQuiet => GetBool("DBTRAN_QUIET", defaultValue: true);
    public string SourceDrive => Require("SOURCE_DRIVE");
    public string SourceLogRelativePath => Require("SOURCE_LOG_RELATIVE_PATH");
    public bool PreDeleteBackupDir => GetBool("PREDELETE_BACKUP_DIR", defaultValue: true);
    public bool PreDeleteAllShadows => GetBool("PREDELETE_ALL_SHADOWS", defaultValue: false);
    public bool DeleteOldestShadowAfterRun => GetBool("DELETE_OLDEST_SHADOW_AFTER_RUN", defaultValue: false);
    public string InitialOffset => Get("INITIAL_OFFSET") ?? "00000000000001";
    public bool DeleteTrnFilesAfterRun => GetBool("DELETE_TRN_FILES_AFTER_RUN", defaultValue: true);
    public IReadOnlyList<string> DeleteFilePatterns => ParseCsv(Get("DELETE_FILE_PATTERNS") ?? "*.trn");
    public FinalFileMode FinalFileMode => ParseFinalFileMode(Get("FINAL_FILE_MODE") ?? "CurrentOnly");
    public string? FtpDebugLogPath => Get("FTP_DEBUG_LOG");
    public bool FtpSkipCertificateValidationForDebug => GetBool("FTP_SKIP_CERT_VALIDATION_FOR_DEBUG", defaultValue: false);
    public IReadOnlyList<UploadTarget> UploadTargets => LoadUploadTargets();

    public static CompTransConfig Load(string configPath)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var rawLines = File.ReadAllLines(configPath).ToList();
        foreach (var line in rawLines)
        {
            var trimmed = line.Trim();
            if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith(";") || trimmed.StartsWith("#"))
                continue;

            var separator = line.IndexOf('=');
            if (separator <= 0)
                continue;

            var key = line[..separator].Trim();
            var value = line[(separator + 1)..].Trim();
            values[key] = value;
        }

        return new CompTransConfig(configPath, values, rawLines);
    }

    public void Validate()
    {
        Require("BACKUP_DIR");
        Require("STATE_FILE");
        Require("TRANSACTION_CURRENT_FILE");
        Require("TRANSACTION_FINAL_FILE");
        Require("TEMP_TRANSACTION_FILE");
        Require("WORK_DIR");
        Require("ARCHIVE_DIR");
        Require("TABLE_LIST");
        Require("DBTRAN_PATH");
        Require("SOURCE_DRIVE");
        Require("SOURCE_LOG_RELATIVE_PATH");

        if (FinalFileMode == FinalFileMode.BackupPlusCurrent && string.IsNullOrWhiteSpace(TransactionBackupFile))
            throw new InvalidOperationException("TRANSACTION_BACKUP_FILE is required when FINAL_FILE_MODE=BackupPlusCurrent.");

        if (!File.Exists(DbtranPath))
            throw new FileNotFoundException("dbtran executable not found.", DbtranPath);

        foreach (var target in UploadTargets.Where(t => t.Enabled))
        {
            if (string.IsNullOrWhiteSpace(target.Host))
                throw new InvalidOperationException($"Upload target '{target.Name}' is missing HOST.");

            if (string.IsNullOrWhiteSpace(target.User))
                throw new InvalidOperationException($"Upload target '{target.Name}' is missing USER.");
        }
    }

    public void PromptAndSaveEncryptedPasswords(bool forcePrompt)
    {
        foreach (var target in UploadTargets.Where(t => t.Enabled))
        {
            if (!forcePrompt && !string.IsNullOrWhiteSpace(target.PasswordEncrypted))
                continue;

            Console.Write($"Upload password for {target.User}@{target.Host} ({target.Name}): ");
            var password = ReadHiddenLine();
            Console.WriteLine();

            if (string.IsNullOrWhiteSpace(password))
                throw new InvalidOperationException($"Upload password was empty for target {target.Name}.");

            var encrypted = EncryptPassword(password, target.PasswordScope);
            Upsert($"UPLOAD_TARGET.{target.Name}.PASSWORD_ENCRYPTED", encrypted);
            _values[$"UPLOAD_TARGET.{target.Name}.PASSWORD_ENCRYPTED"] = encrypted;
        }

        Save();
    }

    public string GetOrInitializeUploadPassword(UploadTarget target)
    {
        if (!string.IsNullOrWhiteSpace(target.PasswordEncrypted))
            return DecryptPassword(target.PasswordEncrypted, target.PasswordScope);

        if (Console.IsInputRedirected)
        {
            throw new InvalidOperationException(
                $"Password is not set for upload target '{target.Name}' in {_configPath}. Run the executable once interactively or use --set-password.");
        }

        PromptAndSaveEncryptedPasswords(forcePrompt: false);
        var refreshed = LoadUploadTargets().FirstOrDefault(t => t.Name.Equals(target.Name, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException($"Upload target '{target.Name}' disappeared after password update.");

        if (string.IsNullOrWhiteSpace(refreshed.PasswordEncrypted))
            throw new InvalidOperationException($"Password was not saved for upload target '{target.Name}'.");

        return DecryptPassword(refreshed.PasswordEncrypted, refreshed.PasswordScope);
    }

    private List<UploadTarget> LoadUploadTargets()
    {
        var names = ParseCsv(Get("UPLOAD_TARGETS") ?? string.Empty);
        if (names.Count == 0 && GetBool("FTP_ENABLED", defaultValue: false))
            names = new List<string> { "default" };

        var targets = new List<UploadTarget>();
        foreach (var name in names)
        {
            var prefix = $"UPLOAD_TARGET.{name}.";
            if (name.Equals("default", StringComparison.OrdinalIgnoreCase) && !_values.Keys.Any(k => k.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
            {
                targets.Add(new UploadTarget(
                    "default",
                    Enabled: GetBool("FTP_ENABLED", defaultValue: true),
                    Protocol: TransferProtocol.Ftps,
                    Host: Require("FTP_HOST"),
                    Port: GetInt("FTP_PORT", 21),
                    User: Require("FTP_USER"),
                    EnableSsl: GetBool("FTP_ENABLE_SSL", defaultValue: true),
                    UsePassive: GetBool("FTP_USE_PASSIVE", defaultValue: true),
                    RemoteDir: Get("FTP_REMOTE_DIR"),
                    PasswordScope: Get("FTP_PASSWORD_SCOPE") ?? "CurrentUser",
                    PasswordEncrypted: Get("FTP_PASSWORD_ENCRYPTED")));
                continue;
            }

            targets.Add(new UploadTarget(
                name,
                Enabled: GetBool(prefix + "ENABLED", defaultValue: true),
                Protocol: ParseTransferProtocol(Get(prefix + "PROTOCOL") ?? "FTPS"),
                Host: Require(prefix + "HOST"),
                Port: GetInt(prefix + "PORT", 21),
                User: Require(prefix + "USER"),
                EnableSsl: GetBool(prefix + "ENABLE_SSL", defaultValue: true),
                UsePassive: GetBool(prefix + "USE_PASSIVE", defaultValue: true),
                RemoteDir: Get(prefix + "REMOTE_DIR"),
                PasswordScope: Get(prefix + "PASSWORD_SCOPE") ?? "CurrentUser",
                PasswordEncrypted: Get(prefix + "PASSWORD_ENCRYPTED")));
        }

        return targets;
    }

    private string EncryptPassword(string plaintext, string scopeName)
    {
        var data = Encoding.UTF8.GetBytes(plaintext);
        var entropy = Encoding.UTF8.GetBytes(PasswordEntropy);
        var scope = ResolveScope(scopeName);
        return Convert.ToBase64String(ProtectedData.Protect(data, entropy, scope));
    }

    private string DecryptPassword(string encrypted, string scopeName)
    {
        try
        {
            var cipher = Convert.FromBase64String(encrypted);
            var entropy = Encoding.UTF8.GetBytes(PasswordEntropy);
            var scope = ResolveScope(scopeName);
            return Encoding.UTF8.GetString(ProtectedData.Unprotect(cipher, entropy, scope));
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                $"Failed to decrypt an upload password from {_configPath}. Run with --set-password on the target server/account. {ex.Message}");
        }
    }

    private static DataProtectionScope ResolveScope(string scope) =>
        scope.Equals("LocalMachine", StringComparison.OrdinalIgnoreCase)
            ? DataProtectionScope.LocalMachine
            : DataProtectionScope.CurrentUser;

    private string Require(string key)
    {
        if (_values.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
            return value;

        throw new InvalidOperationException($"Missing config value: {key}");
    }

    private string? Get(string key) => _values.TryGetValue(key, out var value) ? value : null;

    private bool GetBool(string key, bool defaultValue)
    {
        var raw = Get(key);
        return bool.TryParse(raw, out var value) ? value : defaultValue;
    }

    private int GetInt(string key, int defaultValue)
    {
        var raw = Get(key);
        return int.TryParse(raw, out var value) ? value : defaultValue;
    }

    private static List<string> ParseCsv(string raw) =>
        raw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToList();

    private static FinalFileMode ParseFinalFileMode(string raw) =>
        raw.Equals("BackupPlusCurrent", StringComparison.OrdinalIgnoreCase)
            ? FinalFileMode.BackupPlusCurrent
            : FinalFileMode.CurrentOnly;

    private static TransferProtocol ParseTransferProtocol(string raw) =>
        raw.Equals("SFTP", StringComparison.OrdinalIgnoreCase)
            ? TransferProtocol.Sftp
            : TransferProtocol.Ftps;

    private void Upsert(string key, string value)
    {
        var replaced = false;
        for (var i = 0; i < _rawLines.Count; i++)
        {
            var line = _rawLines[i];
            var trimmed = line.TrimStart();
            if (trimmed.StartsWith(";") || trimmed.StartsWith("#"))
                continue;

            var separator = line.IndexOf('=');
            if (separator <= 0)
                continue;

            var existingKey = line[..separator].Trim();
            if (!existingKey.Equals(key, StringComparison.OrdinalIgnoreCase))
                continue;

            _rawLines[i] = $"{key}={value}";
            replaced = true;
            break;
        }

        if (!replaced)
            _rawLines.Add($"{key}={value}");
    }

    private void Save()
    {
        File.WriteAllLines(_configPath, _rawLines, Encoding.ASCII);
    }

    private static string ReadHiddenLine()
    {
        var builder = new StringBuilder();
        while (true)
        {
            var key = Console.ReadKey(intercept: true);
            if (key.Key == ConsoleKey.Enter)
                break;

            if (key.Key == ConsoleKey.Backspace)
            {
                if (builder.Length > 0)
                    builder.Length--;
                continue;
            }

            if (key.KeyChar != '\u0000')
                builder.Append(key.KeyChar);
        }

        return builder.ToString();
    }
}
