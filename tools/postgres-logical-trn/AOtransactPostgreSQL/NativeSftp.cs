using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Renci.SshNet;
using Renci.SshNet.Common;

namespace AOtransactPostgreSQL;

internal sealed class NativeSftp
{
    private readonly string host;
    private readonly int port;
    private readonly string username;
    private readonly string password;
    private readonly string remoteDirectory;
    private readonly TimeSpan timeout;
    private readonly int retryCount;
    private readonly (string? Algorithm, string Hash)[] fingerprints;

    private NativeSftp(JsonElement settings, string configDirectory)
    {
        host = Required(settings, "host");
        username = Required(settings, "username");
        port = settings.GetProperty("port").GetInt32();
        if (port is < 1 or > 65535) throw new ArgumentException("Invalid SFTP port.");
        remoteDirectory = Required(settings, "remote_directory").TrimEnd('/');
        if (remoteDirectory.Contains('\r') || remoteDirectory.Contains('\n'))
            throw new ArgumentException("Invalid remote directory.");
        var timeoutSeconds = settings.TryGetProperty("timeout_seconds", out var seconds) ? seconds.GetInt32() : 60;
        retryCount = settings.TryGetProperty("retry_count", out var retries) ? retries.GetInt32() : 2;
        if (timeoutSeconds < 1 || retryCount is < 0 or > 10)
            throw new ArgumentException("SFTP timeout_seconds must be positive and retry_count must be 0 through 10.");
        timeout = TimeSpan.FromSeconds(timeoutSeconds);
        fingerprints = Required(settings, "ssh_host_key_fingerprint").Split(';').Select(ParseFingerprint).ToArray();
        password = ReadPassword(Path.GetFullPath(Required(settings, "credentials_path"), configDirectory));
    }

    public static NativeSftp FromConfig(string configPath)
    {
        using var config = JsonDocument.Parse(File.ReadAllText(configPath));
        return new NativeSftp(config.RootElement.GetProperty("sftp"), Path.GetDirectoryName(Path.GetFullPath(configPath))!);
    }

    public void TestConnection()
    {
        using var client = Connect();
        client.GetAttributes(string.IsNullOrEmpty(remoteDirectory) ? "/" : remoteDirectory);
        Console.WriteLine("Native SFTP authentication, host key, and remote directory verified.");
    }

    public void TestTransfer()
    {
        var name = $".aotransact-test-{Guid.NewGuid():N}.tmp";
        var local = Path.Combine(Path.GetTempPath(), name);
        var original = RandomNumberGenerator.GetBytes(8192);
        try
        {
            File.WriteAllBytes(local, original);
            Upload(local, name);
            Upload(local, name); // An identical remote file must be recognized without overwriting.
            File.WriteAllBytes(local, RandomNumberGenerator.GetBytes(original.Length));
            var collisionRejected = false;
            try { Upload(local, name); }
            catch (InvalidDataException) { collisionRejected = true; }
            if (!collisionRejected) throw new InvalidOperationException("SFTP content collision was not rejected.");
            File.WriteAllBytes(local, original);
            Upload(local, name); // The collision attempt must leave the original remote content untouched.
            Console.WriteLine("Native SFTP upload, SHA-256 readback, rename, identical retry, and collision rejection verified.");
        }
        finally
        {
            try
            {
                using var cleanup = Connect();
                var remote = RemotePath(name);
                if (cleanup.Exists(remote)) cleanup.DeleteFile(remote);
                if (cleanup.Exists(remote)) throw new IOException("Native SFTP probe cleanup failed.");
            }
            finally { if (File.Exists(local)) File.Delete(local); }
        }
    }

    public sealed record Receipt(string RemotePath, long Size, string Sha256, bool AlreadyPresent);

    public Receipt Upload(string localPath, string remoteName)
    {
        var remotePath = RemotePath(remoteName);
        // Keep the source immutable while it is hashed, uploaded, and verified.
        using var local = new FileStream(localPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        var hash = Convert.ToHexString(SHA256.HashData(local));
        for (var attempt = 0; ; attempt++)
        {
            try { return UploadOnce(local, remotePath, hash); }
            catch (Exception exception) when (attempt < retryCount && exception is not InvalidDataException &&
                (exception is SshConnectionException or SshOperationTimeoutException or SocketException or IOException))
            {
                Console.Error.WriteLine($"SFTP transient failure; retry {attempt + 1}/{retryCount}.");
                Thread.Sleep(TimeSpan.FromSeconds(2));
            }
        }
    }

    private Receipt UploadOnce(FileStream local, string remotePath, string hash)
    {
        using var client = Connect();
        if (client.Exists(remotePath))
        {
            Verify(client, remotePath, local.Length, hash);
            return new Receipt(remotePath, local.Length, hash, true);
        }
        var temporary = remotePath + $".uploading-{Guid.NewGuid():N}";
        try
        {
            local.Position = 0;
            client.UploadFile(local, temporary, false);
            Verify(client, temporary, local.Length, hash);
            // Final names are published only after full content verification. Do not delete an existing final file.
            client.RenameFile(temporary, remotePath);
            return new Receipt(remotePath, local.Length, hash, false);
        }
        finally
        {
            try { if (client.IsConnected && client.Exists(temporary)) client.DeleteFile(temporary); }
            catch { /* A lost connection can leave an unpublished temporary file; retain the local ZIP for retry. */ }
        }
    }

    private static void Verify(SftpClient client, string path, long length, string hash)
    {
        if (client.GetAttributes(path).Size != length)
            throw new InvalidDataException("Remote SFTP file size differs; refusing to overwrite or acknowledge delivery.");
        using var remote = client.OpenRead(path);
        if (!CryptographicOperations.FixedTimeEquals(Convert.FromHexString(hash), SHA256.HashData(remote)))
            throw new InvalidDataException("Remote SFTP file checksum differs; refusing to overwrite or acknowledge delivery.");
    }

    private SftpClient Connect()
    {
        var client = new SftpClient(host, port, username, password)
        {
            OperationTimeout = timeout,
            KeepAliveInterval = TimeSpan.FromSeconds(15)
        };
        client.ConnectionInfo.Timeout = timeout;
        var rejected = false;
        client.HostKeyReceived += (_, key) =>
        {
            var hash = Convert.ToBase64String(SHA256.HashData(key.HostKey)).TrimEnd('=');
            // OpenSSH renders RSA fingerprints as ssh-rsa even when RSA-SHA2 was negotiated.
            var algorithm = key.HostKeyName is "rsa-sha2-256" or "rsa-sha2-512" ? "ssh-rsa" : key.HostKeyName;
            key.CanTrust = fingerprints.Any(expected =>
                (expected.Algorithm is null || expected.Algorithm == algorithm) &&
                CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected.Hash), Encoding.ASCII.GetBytes(hash)));
            rejected = !key.CanTrust;
        };
        try { client.Connect(); return client; }
        catch (Exception exception)
        {
            client.Dispose();
            if (rejected) throw new InvalidDataException("SFTP server host key does not match the configured fingerprint.", exception);
            throw;
        }
    }

    private string RemotePath(string name)
    {
        if (string.IsNullOrWhiteSpace(name) || name is "." or ".." || name.IndexOfAny(['/', '\\', '\r', '\n', '\0']) >= 0)
            throw new ArgumentException("SFTP remote filename must be a single filename.");
        return remoteDirectory + "/" + name;
    }

    private static (string? Algorithm, string Hash) ParseFingerprint(string input)
    {
        var match = Regex.Match(input.Trim(), @"^(?:(?<algorithm>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp(?:256|384|521))[ -])?(?:\d+ )?(?:SHA256:)?(?<hash>[A-Za-z0-9+/]{43}=?)$");
        if (!match.Success) throw new ArgumentException("SFTP host key must be an explicit SHA-256 fingerprint; wildcards are not accepted.");
        var hash = match.Groups["hash"].Value.TrimEnd('=');
        if (Convert.FromBase64String(hash + "=").Length != 32) throw new ArgumentException("Invalid SFTP fingerprint.");
        return (match.Groups["algorithm"].Success ? match.Groups["algorithm"].Value : null, hash);
    }

    private static string Required(JsonElement settings, string name)
    {
        if (!settings.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()))
            throw new ArgumentException($"SFTP config value '{name}' is required.");
        return value.GetString()!;
    }

    private static string ReadPassword(string path)
    {
        var lines = File.ReadAllLines(path);
        var encrypted = lines.FirstOrDefault(line => line.StartsWith("DPAPI_LOCAL_MACHINE=", StringComparison.OrdinalIgnoreCase));
        if (encrypted is not null)
        {
            var plain = ProtectedData.Unprotect(Convert.FromBase64String(encrypted["DPAPI_LOCAL_MACHINE=".Length..]),
                Encoding.UTF8.GetBytes("AOtransactPostgreSQL|Credential|v1"), DataProtectionScope.LocalMachine);
            try { return Encoding.UTF8.GetString(plain); }
            finally { CryptographicOperations.ZeroMemory(plain); }
        }
        var legacy = lines.FirstOrDefault(line => line.StartsWith("Password=", StringComparison.OrdinalIgnoreCase));
        return legacy?["Password=".Length..] ?? throw new InvalidDataException("Credential file contains no encrypted or legacy password entry.");
    }
}
