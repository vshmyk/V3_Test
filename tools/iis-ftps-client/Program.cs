using System.Net;
using System.Net.Security;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

var options = ParseArgs(args);

if (options.ContainsKey("help") || options.ContainsKey("?") || args.Length == 0)
{
    PrintUsage();
    return 0;
}

try
{
    var command = args[0].Trim().ToLowerInvariant();
    return command switch
    {
        "install" => RunInstall(options),
        "send" => await RunSendAsync(options),
        _ => throw new InvalidOperationException($"Unknown command '{args[0]}'.")
    };
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static int RunInstall(Dictionary<string, string?> options)
{
    var installRoot = GetInstallRoot(options);
    Directory.CreateDirectory(installRoot);

    var settingsPath = Path.Combine(installRoot, "ftps-settings.json");
    var credentialPath = Path.Combine(installRoot, "ftps-credential.bin");
    var launcherPath = Path.Combine(installRoot, "Send-CompPassFile.cmd");

    var userName = options.TryGetValue("username", out var suppliedUserName) && !string.IsNullOrWhiteSpace(suppliedUserName)
        ? suppliedUserName.Trim()
        : PromptRequired("FTP user name");

    var password = options.TryGetValue("password", out var suppliedPassword) && !string.IsNullOrEmpty(suppliedPassword)
        ? suppliedPassword
        : PromptPassword("FTP password");

    if (string.IsNullOrWhiteSpace(password))
        throw new InvalidOperationException("Password is required.");

    var settings = new FtpsSettings(
        "comppass.westus.cloudapp.azure.com",
        21,
        EnableSsl: true,
        UsePassive: true,
        CredentialPath: credentialPath);

    SaveSettings(settingsPath, settings);
    SaveCredential(credentialPath, userName, password);
    WriteLauncher(launcherPath);

    Console.WriteLine($"FTPS uploader installed to {installRoot}");
    Console.WriteLine("Command:");
    Console.WriteLine($@"  {launcherPath} C:\Path\To\File.ext [remote/path/on/server.ext]");
    Console.WriteLine("Credentials were saved with Windows DPAPI for the current user.");
    Console.WriteLine("If you use another computer, copy the EXE there and run install again on that computer.");
    return 0;
}

static async Task<int> RunSendAsync(Dictionary<string, string?> options)
{
    if (!options.TryGetValue("path", out var localPath) || string.IsNullOrWhiteSpace(localPath))
        throw new InvalidOperationException("Missing required --path argument.");

    var installRoot = GetInstallRoot(options);
    var settingsPath = options.TryGetValue("settings", out var settingsOverride) && !string.IsNullOrWhiteSpace(settingsOverride)
        ? Path.GetFullPath(settingsOverride)
        : Path.Combine(installRoot, "ftps-settings.json");

    if (!File.Exists(settingsPath))
        throw new InvalidOperationException($"Settings file not found: {settingsPath}. Run the install command first.");

    var settings = LoadSettings(settingsPath);
    var credential = LoadCredential(settings.CredentialPath);

    var resolvedLocalPath = Path.GetFullPath(localPath);
    if (!File.Exists(resolvedLocalPath))
        throw new InvalidOperationException($"Local file not found: {resolvedLocalPath}");

    var fileInfo = new FileInfo(resolvedLocalPath);
    var remotePath = options.TryGetValue("remote-path", out var remotePathOverride) && !string.IsNullOrWhiteSpace(remotePathOverride)
        ? remotePathOverride
        : fileInfo.Name;

    var requestUri = BuildUploadUri(settings, remotePath);
    var skipCertificateCheck = options.ContainsKey("skip-certificate-check");

    var previousCallback = ServicePointManager.ServerCertificateValidationCallback;
    var previousProtocol = ServicePointManager.SecurityProtocol;

    try
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        if (skipCertificateCheck)
            ServicePointManager.ServerCertificateValidationCallback = static (_, _, _, _) => true;

        #pragma warning disable SYSLIB0014
        var request = (FtpWebRequest)WebRequest.Create(requestUri);
        #pragma warning restore SYSLIB0014
        request.Method = WebRequestMethods.Ftp.UploadFile;
        request.Credentials = new NetworkCredential(credential.UserName, credential.Password);
        request.EnableSsl = settings.EnableSsl;
        request.UseBinary = true;
        request.UsePassive = settings.UsePassive;
        request.KeepAlive = false;
        request.Timeout = 120000;
        request.ReadWriteTimeout = 120000;

        await using (var requestStream = await request.GetRequestStreamAsync())
        await using (var fileStream = File.OpenRead(resolvedLocalPath))
        {
            await fileStream.CopyToAsync(requestStream);
        }

        using var response = (FtpWebResponse)await request.GetResponseAsync();
        Console.WriteLine("Upload completed.");
        Console.WriteLine($"Remote URI: {requestUri.AbsoluteUri}");
        Console.WriteLine($"Server status: {(response.StatusDescription ?? string.Empty).Trim()}");
        return 0;
    }
    finally
    {
        ServicePointManager.ServerCertificateValidationCallback = previousCallback;
        ServicePointManager.SecurityProtocol = previousProtocol;
    }
}

static string GetInstallRoot(Dictionary<string, string?> options)
{
    if (options.TryGetValue("install-root", out var installRootOverride) && !string.IsNullOrWhiteSpace(installRootOverride))
        return Path.GetFullPath(installRootOverride);

    var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    return Path.Combine(localAppData, "AOtransact", "FtpsUploader");
}

static void SaveSettings(string settingsPath, FtpsSettings settings)
{
    var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
    File.WriteAllText(settingsPath, json, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
}

static FtpsSettings LoadSettings(string settingsPath)
{
    var json = File.ReadAllText(settingsPath);
    return JsonSerializer.Deserialize<FtpsSettings>(json)
        ?? throw new InvalidOperationException($"Could not parse settings file: {settingsPath}");
}

static void SaveCredential(string credentialPath, string userName, string password)
{
    var credential = new StoredCredential(userName, password);
    var bytes = JsonSerializer.SerializeToUtf8Bytes(credential);
    var protectedBytes = ProtectedData.Protect(bytes, optionalEntropy: null, DataProtectionScope.CurrentUser);
    File.WriteAllBytes(credentialPath, protectedBytes);
}

static StoredCredential LoadCredential(string credentialPath)
{
    if (!File.Exists(credentialPath))
        throw new InvalidOperationException($"Credential file not found: {credentialPath}. Run the install command first.");

    var protectedBytes = File.ReadAllBytes(credentialPath);
    var bytes = ProtectedData.Unprotect(protectedBytes, optionalEntropy: null, DataProtectionScope.CurrentUser);
    return JsonSerializer.Deserialize<StoredCredential>(bytes)
        ?? throw new InvalidOperationException($"Could not parse credential file: {credentialPath}");
}

static void WriteLauncher(string launcherPath)
{
    var exeName = Path.GetFileName(Environment.ProcessPath);
    if (string.IsNullOrWhiteSpace(exeName))
        throw new InvalidOperationException("Could not determine the executable file name.");
    var lines = new[]
    {
        "@echo off",
        "setlocal",
        $@"""%~dp0{exeName}"" send --path ""%~1"" --remote-path ""%~2""",
        "exit /b %errorlevel%"
    };

    File.WriteAllLines(launcherPath, lines, Encoding.ASCII);
}

static Uri BuildUploadUri(FtpsSettings settings, string remotePath)
{
    var normalized = remotePath.Replace("\\", "/").Trim('/');
    if (string.IsNullOrWhiteSpace(normalized))
        throw new InvalidOperationException("Remote path cannot be empty.");

    var escapedSegments = normalized
        .Split('/', StringSplitOptions.RemoveEmptyEntries)
        .Select(Uri.EscapeDataString);

    var builder = new UriBuilder("ftp", settings.Host, settings.Port, string.Join('/', escapedSegments));
    return builder.Uri;
}

static string PromptRequired(string label)
{
    Console.Write($"{label}: ");
    var value = Console.ReadLine();
    if (string.IsNullOrWhiteSpace(value))
        throw new InvalidOperationException($"{label} is required.");
    return value.Trim();
}

static string PromptPassword(string label)
{
    Console.Write($"{label}: ");
    var buffer = new StringBuilder();

    while (true)
    {
        var key = Console.ReadKey(intercept: true);
        if (key.Key == ConsoleKey.Enter)
        {
            Console.WriteLine();
            break;
        }

        if (key.Key == ConsoleKey.Backspace)
        {
            if (buffer.Length > 0)
            {
                buffer.Length--;
            }

            continue;
        }

        if (!char.IsControl(key.KeyChar))
            buffer.Append(key.KeyChar);
    }

    return buffer.ToString();
}

static Dictionary<string, string?> ParseArgs(string[] args)
{
    var result = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    for (var i = 1; i < args.Length; i++)
    {
        var arg = args[i];
        if (!arg.StartsWith("--", StringComparison.Ordinal))
            continue;

        var key = arg[2..];
        if (i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal))
        {
            result[key] = args[i + 1];
            i++;
        }
        else
        {
            result[key] = null;
        }
    }

    return result;
}

static void PrintUsage()
{
    Console.WriteLine("AOtransact.FtpsUploader");
    Console.WriteLine();
    Console.WriteLine("Install and save credentials:");
    Console.WriteLine(@"  AOtransact.FtpsUploader.exe install");
    Console.WriteLine();
    Console.WriteLine("Upload one file:");
    Console.WriteLine(@"  AOtransact.FtpsUploader.exe send --path C:\Temp\example.txt [--remote-path incoming/example.txt]");
    Console.WriteLine();
    Console.WriteLine("Optional arguments:");
    Console.WriteLine("  --install-root <path>");
    Console.WriteLine("  --settings <path>");
    Console.WriteLine("  --skip-certificate-check");
}

internal sealed record FtpsSettings(
    string Host,
    int Port,
    bool EnableSsl,
    bool UsePassive,
    string CredentialPath);

internal sealed record StoredCredential(
    string UserName,
    string Password);
